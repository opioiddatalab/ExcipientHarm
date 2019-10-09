

//	Purpose: To identify a simple list of brand names of controlled substances (e.g., claims, EHR, PMP, etc.)  for literature review search string

// set directories
	global one "/Drug names/"
	cd "${one}"
	
//	Import BCBSNC list of selected drugs (from separate project) 2006-18
import excel "${one}druglist_bcbs_2006_2018.xlsx", firstrow case(lower) clear
	
	order product_name, b(generic_name)
	
	keep product_name generic_name-drug rxcount
	
	drop if regexm(lower(class), "muscle")
	drop if class=="Misc"
	
	* Recode dosage forms into 3 simple categories
		qui:tab form, m sort
			rename form temp
				gen form=.
					order form, a(temp)
			replace form = 1 if regexm(lower(temp), "tablet|capsule|suppository|lozenge|troche|powder|pellets|efferv")
			replace form = 2 if regexm(lower(temp), "liquid|syrup|spray|suspen|solution|infusion|syringe|elixir|tincture|drops|epidural| iv| inj| subq")
			replace form = 3 if regexm(lower(temp), "patch|gel|film|transdermal|ointment|topical")
				tab form, m sort
					label define formlabel 1 "solid" 2 "liquid" 3 "matrix"
						label values form formlabel
							drop if form==2

	* run program for BCBSNC
	do trim

		
	collapse (sum) rxcount, by(flag brand drug product_name form class)
			quietly compress
				egen zrxno=std(rxcount)
					la var zrxno "Z-score for prescriptions within data source"
						rename drug api
							gen source="bcbsnc 2006-18"

	 save "${one}bcbsnc.dta", replace
		

//	Import CSRS drug  list
	 import delim using "${one}CSRS_Top400_09to13.txt", case(lower) clear
		rename drugname product_name
		rename freq rxcount
		rename api generic_name
			drop pct classcode formulation
				* Drop drugs not of interest
				drop if inlist(class, "notcs", "steroid", "sleep aid", "other", "cough" )
					replace class="opioid" if inlist(class,"weak opioid", "addiction")

* run program for csrs		
	trim

	
	collapse (sum) rxcount, by(generic_name brand flag product_name class)
		rename generic_name api
			egen zrxno=std(rxcount)
					la var zrxno "Z-score for prescriptions within data source"
						gen source="nc csrs 2009-13"

	 
	 save "${one}csrs.dta", replace
	 
	 append using "${one}bcbsnc.dta"
		replace class=lower(class)
			save "${one}bcbs_csrs.dta", replace

			
// Import data from ATC via Linerberger Cypher

* combine multiple csv files into one using python
python
import os
import glob
import pandas as pd
os.chdir("${one}Cipher/")

extension = 'csv'
all_filenames = [i for i in glob.glob('*.{}'.format(extension))]
#combine all files in the list
combined_csv = pd.concat([pd.read_csv(f) for f in all_filenames ])
#export to csv
combined_csv.to_csv( "combined_cipher.csv", index=False, encoding='utf-8-sig')
end

	* IMPORT and data formatting
		import delim "combined_cipher.csv", clear
			keep if drug_type=="Brand"
				drop strengt* availability ndc package_size manuf*	dea *_date
					rename ïatc atc
						rename drug_name product_name
							gen generic_name=lower(atc_label)
		
	* limit to solid oral and transdermal and gels
		keep if inlist(route, "buccal", "inhalation", "nasal", "oral", "rectal", "sublingual", "transdermal")
		
		rename form temp
		gen form = .
			order form, a(temp)
			replace form = 1 if regexm(lower(temp), "tablet|capsule|suppository|lozenge|troche|powder|pellets|efferv")
			replace form = 2 if regexm(lower(temp), "liquid|syrup|spray|suspen|solution|infusion|syringe|elixir|tincture|drops|epidural| iv| inj| subq")
			replace form = 3 if regexm(lower(temp), "patch|gel|film|transdermal|ointment|topical")
				tab form, m sort
					label values form formlabel
						drop if form==2
		
	* Use ATC N02BA to drop aspirin, acetaminophen, etc. OTC analgesics
		drop if atc=="N02BA"	
			/// SALICYLIC ACID AND DERIVATIVES
		drop if atc=="N02BA01"
			/// ACETYLSALICYLIC ACID
		drop if atc=="N02BA06"
			/// SALSALATE
		drop if atc=="N02BA11"
			///	DIFLUNISAL
		drop if atc=="N02BA51"
			/// ACETYLSALICYLIC ACID, COMB. EXCL. PSYCHOLEPTICS
		drop if atc=="N02BE01"
			///	PARACETAMOL
		drop if atc=="N02BE51"
			///	PARACETAMOL, COMBINATIONS EXCL. PSYCHOLEPTICS
		drop if regexm(atc,"N02CC|N02CX")
			/// Migraine meds
		drop if regexm(atc,"N05CF0")
			/// Z drug sleep aids
	
	* run program
		trim
		
	* clean up and collapse
		duplicates drop brand, force
			gen counter=1
				collapse (sum) counter, by(brand flag product_name generic_name)
					drop counter
						gen source = "UNC Cipher"
					
	 save "${one}cipher.dta", replace
	 
	 append using "${one}bcbs_csrs.dta"
		replace class=lower(class)
			save "${one}bcbs_csrs_cipher.dta", replace
			
// Wikipedia 

	import delim using "${one}wikipediabenzos.csv", varn(1) clear
	* keep only marketed drugs
		drop if regexm(lower(fda), "not|research")
			drop fda
			
	* split out comma separated brand list from Wikipedia table and save for merge
		split brand, parse(,)
			rename brand product
				gen no=_n
					reshape long brand, i(no) j(list)
						drop if brand==""
							drop no list product
								save "${one}wikiparse", replace
	
	* merge back into original wikipedia file
		import delim using "${one}wikipediabenzos.csv", varn(1) clear
			drop if regexm(lower(fda), "not|research")
				drop fda 
		
		append using "${one}wikiparse"
			drop if regexm(brand,"\,")
				drop if brand==""
			* get rid of footnotes
				replace generic_name = regexr(generic_name, "\[.*", "")
					replace brand = regexr(brand, "\[.*", "")

	* run program
		replace generic_name=lower(generic_name)
			replace brand=lower(brand)
				rename brand product_name
				trim
					replace source="WADA" if type=="stimulant"
					
					append using "${one}bcbs_csrs_cipher.dta"
						save "${one}bcbs_csrs_cipher_wikipedia_wada.dta", replace
						
					
			
//	COMBINING
	duplicates drop brand, force
		replace generic_name=api if generic_name==""

		* more cleanup
			replace brand = regexr(brand, " \#|\-|( |\-+)hc|( |\-+)pb|( |\-+)ap|\-c|( |\-+)mg|( |\-+)cf|( |\-+)ii|( |\-+)m$|( |\-+)iii|( |\-+)dh", "")
			
		* generate string length to winnow down (3 or less or more than 13 characters)
			gen lengthflag = 0
				replace lengthflag =1 if strlen(brand)<=3 | strlen(brand)>13
					order lengthflag, a(brand)
						drop if lengthflag==1
							duplicates drop brand, force
								drop lengthflag
								 drop api-form
		
		* manual fixes
			replace brand="acetam" if regexm(product_name, "acetam")
			replace brand="acetaminoph" if regexm(product_name, "acetaminoph\)")
			drop if brand=="bb.s."
			drop if brand=="ceta"
			replace flag=0 if brand=="dexmet"
			replace flag=0 if brand=="barbita"
			drop if regexm(brand, "\_")
	
		* drop if brand with a space in it
			drop if regexm(brand, " ")
		
		* drop ergotamine compounds
			drop if regexm(generic_name, "ergotamine")
	
		* drop chlordiazepoxide compounds
			drop if regexm(generic_name, "chlordiazepoxide")
	
		* generate flag for reconsider whether to include
			gen reconsider=1 if (strlen(brand)<=5 | strlen(brand)>11) & flag==0
				order reconsider, a(brand)
				replace reconsider=. if inlist(brand, "soma", "actiq", "arymo","xanax","norco", "opana", "serax", "oxyir")
				replace reconsider=. if inlist(brand, "tylox","lynox","xolox","arcet","bucet","bupap","butex","ezol")
				replace reconsider=. if inlist(brand, "xyrem","rybix","xylon","gabazolamine", "xodol","theratramadol","onfi")
			drop if reconsider==1
			
	
		sort generic_name brand
								 
			save "${one}rawbrandlist", replace
				export excel using "${one}rawbrandlist", replace firstrow(variables)

	//	Save file for PubMed Python query
			keep brand
				export delimited using "searchdrug.csv", replace
 
				
				
