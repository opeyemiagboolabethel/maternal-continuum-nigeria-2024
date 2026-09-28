# PostgreSQL analytical pipeline

This directory contains the PostgreSQL implementation for the Maternal Continuum of Care in Nigeria project.

## Architecture

- `staging` receives validated aggregate analytical outputs generated in R.
- `analytics` stores curated and quality-controlled analytical tables.
- `reporting` exposes BI-ready views.
- `audit` records load activity and pipeline traceability.

## Execution order

From the repository root, create a database and run:

```bash
psql -d maternal_health_portfolio -f sql/run_all.sql
```

`run_all.sql` executes the DDL, load, reporting-view, and validation scripts in order. The CSV load step uses `\copy`, so invoke `psql` from the repository root.

## Analytical coverage

The SQL layer supports national indicators, equity estimates, equity-gap analysis, state performance, adjusted/unadjusted regression results, sensitivity/robustness results, and Power BI reporting views.

## Power BI handoff

Power BI should consume objects from the `reporting` schema.
