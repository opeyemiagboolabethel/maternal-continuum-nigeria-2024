# Methods summary

## Data source

The analysis uses authorised microdata from the 2024 Nigeria Demographic and Health Survey (NDHS). The public repository does not redistribute respondent-level data.

## Analytical cohort

The cohort was restricted to the most recent live birth within the preceding 24 months. The analytical cohort contained 10,522 records; 10,236 complete cases were available for the adjusted primary model.

## Survey design

National, equity, and geographic estimates use the NDHS survey design variables for weighting, clustering, and stratification. The final design summary contained 1,364 primary sampling units and 74 strata.

## Primary continuum outcome

The primary project-defined continuum requires:

1. four or more ANC contacts;
2. skilled birth attendance; and
3. maternal and newborn postnatal care within two days.

Alternative sensitivity definitions use ANC8 instead of ANC4 and facility delivery instead of skilled birth attendance.

## Equity dimensions

Coverage is assessed across age group, education, household wealth quintile, urban/rural residence, and geopolitical zone. Public subgroup estimates use disclosure rules configured in `config/config.yml`.

## Geographic analysis

State-level estimates cover all 36 states and the Federal Capital Territory. Public state reporting applies the same small-cell safeguards used for equity outputs.

## Regression

Survey-weighted logistic regression models complete continuum coverage. Reference categories are age 20-24 years, no education, poorest quintile, rural residence, and North West zone.

Adjusted odds ratios are reported with 95% confidence intervals and p-values. They describe association, not causation.

## Quality assurance

The R pipeline performs variable validation, outcome checks, confidence-interval checks, national/geographic reconciliation, disclosure-control checks, regression validation, sensitivity validation, file-manifest checks, and final critical-failure reconciliation. The final pipeline status is PASS with zero critical failures.
