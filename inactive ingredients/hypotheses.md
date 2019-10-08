In addition to extracting search terms for systematic review, we are also interested in visualizing the excipient data to understand trends in the manufacture of these drugs over decades. We welcome anyone to help us develop data visualizations (which we will post here with attribution) to evaluate these three hypotheses. The [CSV with extracted inactive ingredients](https://github.com/opioiddatalab/ExcipientHarm/blob/master/inactive%20ingredients/inactiveIngredientList.csv) may be noisy due to minimal cleanup after the extraction with regular expressions:<br>

```python
druglist.append(re.findall( r'inactive ingredients:\s(.*?\.)', text_data, flags=re.IGNORECASE))
```

However, the [full corpus of 2k+ drug label texts](https://github.com/opioiddatalab/ExcipientHarm/blob/master/inactive%20ingredients/DrugLabelCorpus.md) is also available if you want to run your own NLP.

## Hypotheses

1. There will be differences in excipients between the 4 therapeutic classes.
2. There will be differences in dominant excipients over time.
3. There will be differences in excipients between manufacturers.

