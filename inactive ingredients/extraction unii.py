#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Thu Oct  3 14:27:30 2019

@author: nabarun
"""

import os as os
import re
import pandas as pd

os.chdir("/Users/nabarun/Dropbox/OneDrive - University of North Carolina at Chapel Hill/Excipients/Search terms/Excipient names/")

opioidsunii = []

for subdir, dirs, files in os.walk("opioids/"):
    for file in files:
        if file.endswith('.txt'):
            with open(os.path.join(subdir, file), 'r', encoding='utf8') as text_file:
                text_data = text_file.read().replace('\n', '')
            opioidsunii.append(re.search(r'^.*UNII:.*([0-9]*[A-B]*)', text_data, flags=re.MULTILINE))
        else:
            pass
        
print(opioidsunii)

# convert to dataframe and save as CSV
opioids_excipients=pd.DataFrame(opioidsunii)
opioids_excipients.to_csv('opioids_UNII.csv', header=0)