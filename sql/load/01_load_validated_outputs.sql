-- LOAD VALIDATED R OUTPUTS INTO POSTGRESQL STAGING TABLES
-- Run with psql from the repository root.

\set ON_ERROR_STOP on

TRUNCATE TABLE
    staging.weighted_national_indicator_estimates,
    staging.weighted_equity_estimates_public,
    staging.equity_gap_summary,
    staging.state_indicator_estimates_public,
    staging.adjusted_odds_ratios,
    staging.unadjusted_odds_ratios,
    staging.sensitivity_adjusted_models,
    staging.sensitivity_prevalence_comparison;

\copy staging.weighted_national_indicator_estimates FROM 'outputs/tables/weighted_national_indicator_estimates.csv' WITH (FORMAT csv, HEADER true);
\copy staging.weighted_equity_estimates_public FROM 'outputs/tables/weighted_equity_estimates_public.csv' WITH (FORMAT csv, HEADER true);
\copy staging.equity_gap_summary FROM 'outputs/tables/equity_gap_summary.csv' WITH (FORMAT csv, HEADER true);
\copy staging.state_indicator_estimates_public FROM 'outputs/tables/state_indicator_estimates_public.csv' WITH (FORMAT csv, HEADER true);
\copy staging.adjusted_odds_ratios FROM 'outputs/tables/adjusted_odds_ratios.csv' WITH (FORMAT csv, HEADER true);
\copy staging.unadjusted_odds_ratios FROM 'outputs/tables/unadjusted_odds_ratios.csv' WITH (FORMAT csv, HEADER true);
\copy staging.sensitivity_adjusted_models FROM 'outputs/tables/sensitivity_adjusted_models.csv' WITH (FORMAT csv, HEADER true);
\copy staging.sensitivity_prevalence_comparison FROM 'outputs/tables/sensitivity_prevalence_comparison.csv' WITH (FORMAT csv, HEADER true);
