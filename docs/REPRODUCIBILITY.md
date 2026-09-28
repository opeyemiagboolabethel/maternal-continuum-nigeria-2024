# Reproducibility guide

## 1. Clone the repository

```bash
git clone https://github.com/opeyemiagboolabethel/maternal-continuum-nigeria-2024.git
cd maternal-continuum-nigeria-2024
```

## 2. Obtain authorised NDHS microdata

Register with The DHS Program and obtain authorised access to the relevant 2024 Nigeria DHS Pregnancy and Postnatal Care Recode file. Place the authorised Stata file in `data/raw/`.

The repository intentionally does not supply the microdata.

## 3. Restore the R environment

Open the `.Rproj` file, then run:

```r
install.packages("renv")
renv::restore()
```

## 4. Run the R analytical pipeline

Run the scripts under `R/` in numeric order. The pipeline imports and audits the data, derives the analytical cohort, produces weighted estimates, runs equity/geographic analyses and survey-weighted models, performs sensitivity analyses, and finishes with QA/reconciliation.

## 5. Build PostgreSQL

Create a PostgreSQL database, then from the repository root run:

```bash
psql -d maternal_health_portfolio -f sql/run_all.sql
```

The command builds schemas/tables, loads aggregate CSV files to staging, populates analytics objects, creates reporting views, and runs SQL validation.

## 6. Recreate or connect the Power BI report

The final report was developed locally in Power BI Project (PBIP) format against the PostgreSQL `reporting` schema. The public repository documents the report design and analytical outputs without distributing local caches, credentials, or restricted data. Exported report screenshots are stored under `docs/images/` when available.

## 7. Verify final QA

Key status files include:

- `data/powerbi/project_pipeline_status.csv`
- `data/powerbi/project_qa_summary.csv`
- `outputs/tables/final_r_pipeline_status.csv`
- `outputs/tables/final_r_reconciliation_summary.csv`

The checked-in final run reports PASS with zero critical failures.
