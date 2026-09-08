# SQL Analytical Pipeline

This directory contains the PostgreSQL implementation for the Maternal Continuum of Care in Nigeria analytics project.

## Architecture

The database uses four functional schemas:

- `staging` - receives validated analytical outputs generated in R
- `analytics` - stores curated and quality-controlled analytical datasets
- `reporting` - exposes business intelligence-ready views
- `audit` - records data-loading activity and pipeline traceability

## Analytical Coverage

The SQL pipeline supports:

- National maternal healthcare indicators
- Equity and subgroup estimates
- Equity gap analysis
- State-level geographic performance
- Adjusted and unadjusted regression results
- Sensitivity and robustness analysis
- Power BI-ready reporting datasets

## Directory Structure

### `ddl`
Database objects, schemas, staging tables, analytics tables, constraints and supporting structures.

### `load`
Scripts associated with loading analytical outputs into PostgreSQL.

### `queries`
Reporting views and analytical datasets prepared for downstream consumption.

### `validation`
Data-quality checks, reconciliation procedures and final database validation.

## Quality Assurance

The pipeline includes:

- Row-count reconciliation between staging and analytics layers
- Primary-key and uniqueness controls
- Numeric and confidence-interval validation
- Regression-result reconciliation
- Sensitivity-analysis validation
- Critical-null checks
- Data-load auditing
- Reporting-object availability checks
- Final database architecture validation

The final SQL validation confirms that the core analytical pipeline and required database architecture reconcile successfully.

## Power BI Handoff

Power BI should primarily consume objects from the `reporting` schema rather than querying staging or intermediate analytical tables directly.

The approved reporting layer includes national indicators, equity estimates, equity gaps, state performance, regression comparisons, and sensitivity/robustness results.