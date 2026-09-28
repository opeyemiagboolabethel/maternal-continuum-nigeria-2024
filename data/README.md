# Data directory

This project intentionally separates restricted respondent-level data from public aggregate outputs.

- `raw/`: local authorised DHS microdata. Not committed to Git.
- `interim/`: intermediate respondent-level R objects. Not committed.
- `processed/`: final respondent-level analytical R object. Not committed.
- `powerbi/`: aggregate, disclosure-controlled CSV outputs prepared for reporting and BI use.

Do not add DHS respondent-level `.dta`, `.sav`, `.rds`, or equivalent microdata to the public repository.
