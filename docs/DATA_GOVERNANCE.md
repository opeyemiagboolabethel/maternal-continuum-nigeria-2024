# Data governance and disclosure controls

The 2024 NDHS respondent-level microdata are controlled-access data obtained through The DHS Program. They are not included in the public repository.

## Repository rules

- Do not commit DHS `.dta`, `.sav`, `.rds`, or other respondent-level files.
- Do not commit intermediate or processed row-level datasets.
- Do not commit database dumps that could contain row-level data.
- Do not commit Power BI caches (`.pbi/`, `cache.abf`) or PBIX binaries.
- Commit only analytical code, schema definitions, documentation, QA outputs, and disclosure-controlled aggregate reporting tables.

## Small-cell rules

The project configuration uses:

- **suppress below n=25**;
- **caution for n=25 to 49**.

Public equity and state outputs are generated so suppressed estimates are not exposed. Final QA explicitly checks for disclosure-control failures.

## Reproduction

Researchers independently authorised to use the NDHS microdata can place their copy in `data/raw/` and run the pipeline locally. Access rights are not transferred by this repository.
