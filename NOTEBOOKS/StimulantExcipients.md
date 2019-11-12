# LAB NOTEBOOK

# Finding Inactive Ingredients in Current CNS Stimulants

## Background
Solid oral (e.g., pills) and transdermal (e.g., patches) formulations of pharmaceutical medicines are not intended to be injected (subcutaneous, intravenous or intra-arterial). But we know from a century of experience that some people will invariably try to inject opioids, stimulants, benzodiazepines and barbiturates. In response to opioid misuse, pharmaceutical manufacturers have tried to make pills harder to crush and suck into a syringe. Abuse deterrent formulations (ADFs) attempt to deter tampering by making it more difficult to extract the active ingredient (via crush, cut, grate or grinding), make it difficult to solubilize extracted particles (e.g., high viscosity when in contact with water), or contain aversive agents (e.g., opioid antagonists naloxone or naltrexone are released when the tablet is crushed). Stimulants are [now being considered](https://www.fda.gov/news-events/fda-brief/fda-brief-fda-seeks-input-development-and-evaluation-abuse-deterrent-formulations-central-nervous) for ADF reformulation. Solid oral pharmaceuticals contain bulking agents or fillers (“excipients”) such as talc or starch; ADFs may contain new propietary excipients with limited population exposure. These inactive excipient ingredients are often insoluble, leading to additional complications (local skin irritation, vascular damage, pulmonary dysfunction) when injected. Inactive ingredients in new oral ADF stimulants should be evaluated for safety via intravenous and intra-arterial routes, since they will surely be subjected to injection in the community.

## Intent of the Analysis
We are replying to the FDA [call for Docket comments](https://www.federalregister.gov/documents/2019/09/20/2019-20372/the-food-and-drug-administration-solicits-input-on-potential-role-for-abuse-deterrent-formulations) (Docket No. FDA-2019-N-3403, Due November 19, 2019) on about abuse-derrent formulations of central nervous system stimulants (e.g., amphetamine, methamphetamine, methylphenidate, lisdexamfetamine). We are responding by compiling a list of inactive ingredients ("excipients") that are in currently approved stimulants, ingredients that may be injected.
1. Identify inactive ingredients used in prescription stimulants.
2. Calculate relative use of inactives by ranked order of declaration.

## Data Source
The beta version of [FDALabel version 2.4](https://www.fda.gov/science-research/bioinformatics-tools/fdalabel-full-text-search-drug-labeling) was queried on Thursday October 3, 2019 to identify all Established Product Classes (EPC) for the following ([permanent link to query at FDA](https://nctr-crs.fda.gov/fdalabel/ui/search/spl-summaries/criteria/50827), [CSV version](https://github.com/opioiddatalab/ExcipientHarm/blob/master/inactive%20ingredients/fdalabel-query-50827-stimulants.csv)):
>The FDALabel Database is a web-based application used to perform customizable searches of over 110,000 human prescription, biological, over-the-counter (OTC), and animal drug labeling documents. The source of FDALabel's data is the FDA's Structured Product Labeling (SPL) archive which stores labeling documents submitted by manufacturers. FDALabel is implemented as a secure three-tier platform with an Oracle database. 

Python code to retrieve the list of drugs and download the full text of the label from [DailyMed](https://dailymed.nlm.nih.gov/dailymed/index.cfm). The resulting file is [available here](https://github.com/opioiddatalab/ExcipientHarm/blob/master/inactive%20ingredients/stim_UNII_full.csv).

```Python
import urllib
from bs4 import BeautifulSoup
import os
import re
import pandas as pd

os.chdir("/working directory/")

# STIMULANTS

## Open the FDALabel query results listing drugs by established product class, extract URLs for DailyMed
df = pd.read_csv('original query/fdalabel-query-50827-stimulants.csv', delimiter=',')
druglinks=df['DailyMed Link']
druglinks=druglinks.replace(regex=r'http',value='https')

## Scrape drug labels
for index, url in enumerate(druglinks):

    # Open the URLs list
    
    fp = urllib.request.urlopen(url)
    test = fp.read()
    soup = BeautifulSoup(test,"lxml")
    output=soup.get_text()

    # Save the get_text() results to a unique file
    
    file=open("unii/stimulants/%s" % index,"w",encoding='utf-8')
    file.write(output)
    file.close()

stimulantunii = []

for subdir, dirs, files in os.walk("unii/stimulants/"):
    files.sort()
    for file in sorted(files, key=int):
        with open(os.path.join(subdir, file), 'r', encoding="utf8", errors='ignore') as text_file:
            text_data = text_file.read()
            # regex for entire line that contains (UNII 
            mylist=re.findall(r'(.*?)\(UNII:.*',text_data)
            mylist = list(dict.fromkeys(mylist))
            # add file name since os pulls in arbitraity file order
            mylist.insert(0,file)
            stimulantunii.append(mylist)
    else:
        pass

# Convert to dataframe and save as CSV
stim_excipients=pd.DataFrame(stimulantunii)
stim_excipients.to_csv('stim_UNII_full.csv', sep="|", header=0)

```

The Stata MP (v16) code below process the [resulting file](https://github.com/opioiddatalab/ExcipientHarm/blob/master/inactive%20ingredients/stim_UNII_full.csv) for analysis, which also includes simplified manufacturer names.

```Stata
import delimited "${two}stim_UNII_full.csv", encoding(ISO-8859-2) delimiter("|") clear
	gen type = ""
		replace type="Stimulants"	
			rename v2 index
				destring index, force replace
					drop v1
						save stimulantsunii, replace

import delimited "${two}original query/fdalabel-query-50827-stimulants.csv", encoding(ISO-8859-2) clear
	gen index=_n
		replace index=index-1
			order index, first
				merge 1:1 index using stimulantsunii, keep(3) 

// Variable cleanup

	* Year of market launch
		replace marketingdatesyyyymmdd=regexr(marketingdatesyyyymmdd,"completed:","")
			gen marketyear=substr(marketingdatesyyyymmdd, 1, 4) 
				order marketyear, a(marketingdatesyyyymmdd)
					la var marketyear "Extracted year of market launch"
	
	* Create dichotomous category indicators for active ingredients
		
		* Check for duplicates using URL for label
		duplicates tag dailymedlink, gen(dup)
			sort dailymedlink 
				order dup, a(type)
		
		* Fill in missing applicationnumber
		gsort dailymedlink -applicationnumber
		bysort dailymedlink: replace applicationnumber=applicationnumber[_n+1] if applicationnumber==""
		bysort dailymedlink: replace applicationnumber=applicationnumber[_n-1] if applicationnumber==""
		
		* Generate dichotomous flags for active ingredient classes
		gen opioid=0
			la var opioid "1 if any active ingredient is opioid"
				replace opioid = 1 if regexm(lower(establishedpharmacologicclasses),"opioid")
		gen barbiturate=0
			la var barbiturate "1 if any active ingredient is barbiturate"
				replace barbiturate = 1 if regexm(lower(establishedpharmacologicclasses),"barbiturate")
		gen benzodiazepine=0
			la var benzodiazepine "1 if any active ingredient is benzodiazepine"
				replace benzodiazepine = 1 if regexm(lower(establishedpharmacologicclasses),"benzodiazepine")
		gen stimulant=0
			la var stimulant "1 if any active ingredient is stimulant"
				replace stimulant = 1 if regexm(lower(establishedpharmacologicclasses),"stimulant")
		gen stimulan_notonlycaff=0
			la var stimulan_notonlycaff "1 if any active ingredient is stimulant but not caffeine"
				replace stimulan_notonlycaff = 1 if regexm(lower(establishedpharmacologicclasses),"stimulant") & regexm(lower(activeingredients),"caffeine")==0
	
	* Drop duplicates
	drop type dailymedpdflink setid fdalabellink genericpropernames labelingtype _merge index dup
	duplicates drop
	
	* Drop any empty columns
	foreach var of varlist v3-v32 {
		capture assert mi(`var')
     if !_rc {
        drop `var'
     }
	 
	 replace `var'=strtrim(`var')
	 
	 replace `var' = regexr(`var',"May contain","")
	 replace `var' = regexr(`var',".ALPHA.-TOCOPHEROL","ALPHA-TOCOPHEROL")
	
	}
	
// SAVE wide file
	quietly compress
	save allcsingredientswide, replace
			
// RESHAPE
	gen drugid = _n
	reshape long v, i(drugid) j(rank)
		replace rank=rank-2
			rename v ingredientverbatim
				drop if ingredientverbatim==""

	* Reorder variables for clarity
		order dailymedlink, last
		order tradename, a(rank)
		order establishedpharmacologicclasses, a(tradename)
		order shortcompany, b(dailymedlink)
		order applicationnumber, b(shortcompany)
		order mostrecentspldateyyyymmdd, b(applicationnumber)
		order initialusapproval, b(mostrecentspldateyyyymmdd)
		order marketingdatesyyyymmdd, b(initialusapproval)
		order ndcs, b(applicationnumber)
		order activeingredientuniis, b(marketingdatesyyyymmdd)
		order activeingredients, b(activeingredientuniis)
		order activemoietyuniis, b(activeingredientuniis)
		order activemoietynames, a(establishedpharmacologicclasses)
		replace activemoietynames = lower(activemoietynames)
		replace dosageforms = lower(dosageforms)
		replace routesofadministration = lower(routesofadministration)
	
 // Clean Drug Names
	* Separating Active and Inactive ingredients
		gen active = 0
			replace active=1 if (regexm(lower(activeingredients),lower(ingredientverbatim)) | regexm(lower(activemoietynames),lower(ingredientverbatim)) ) & ingredient!=""
				order active, a(ingredientverbatim)
					la var active "Active ingredient=1; inactive=0"
	
	* Flag for colorant
		gen coloring = 0
			la var coloring "Inactive ingredient is a coloring = 1"
				replace coloring=1 if active==0 & regexm(lower(ingredientverbatim),"color|d\&c|ferr|lake|yellow|blue|red|black|aluminium")
					order coloring, a(active)
	
	* Simplify ingredient names
		gen ingredient = lower(ingredientverbatim)
			la var ingredient "Cleaned up ingredient name"
				order ingredient, a(ingredientverbatim)
				
				replace ingredient= regexr(lower(ingredientverbatim),"starch, corn","CORN STARCH")
				replace ingredient= subinstr(lower(ingredientverbatim),"cellulose, microcrystalline","microcrystalline cellulose", 100)
				replace ingredient= regexr(lower(ingredientverbatim),", unspecified form","")
				replace ingredient= regexr(lower(ingredientverbatim),", unspecified","")
				
	* Generate rank order of ingredients					
		order rank, a(ingredient)
			la var rank "Order of declaration postion for all ingredients"
						
		bys drugid (rank): egen rankinactive = rank(rank) if active!=1, unique
			la var rankinactive "Order of declaration position of ALL inactive ingredients"
		
		bys drugid (rank): egen rankinactivesub = rank(rank) if (active!=1 & coloring!=1), unique
			la var rankinactivesub "NOT including colorings: Order of declaration position of inactive ingredients"
				order rankinactive rankinactivesub, a(rank)
```

### Analysis
The analysis was descriptive and simple. The "order of declaration" in the ingredient list is supposed to be the rank order of inactive ingredients by volume (mass?). 

```Stata
//	Extract stimulants for FDA ADF Docket November 2019
	* Limit to amphetamine, methamphetamine, methylphenidate, lisdexamfetamine
		keep if stimulan_notonlycaff==1

	* Generate table for export
		* table ingredient if active!=1 & coloring!=1, c(count drugid median rankinactivesub mean rankinactivesub)
		
		collapse (count) drugid (median) rankinactivesub if active!=1 & coloring!=1 & stimulan_notonlycaff==1, by(ingredient)
			rename drugid label_count
			rename rankinactivesub median_declared_position
			gsort  median_declared_position -label_count
		export excel stimulant_inactives, firstrow(var) replace
 ```
 
 The resulting file is [available here](https://github.com/opioiddatalab/ExcipientHarm/blob/master/inactive%20ingredients/stim_UNII_full.csv)
