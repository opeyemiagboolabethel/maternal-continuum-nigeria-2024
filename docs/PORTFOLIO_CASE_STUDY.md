# Portfolio case study: Maternal Continuum of Care in Nigeria

## The problem

Headline maternal-health indicators can obscure where women are lost between antenatal care, delivery, and early postnatal follow-up. This project treats maternal care as a pathway rather than a set of disconnected contacts.

## The analytical question

How many women complete a defined continuum of maternal care in Nigeria, where are the largest drop-offs, how unequal is completion across socioeconomic and geographic groups, and which characteristics are associated with completion after accounting for other factors?

## What I built

An end-to-end analytics workflow spanning:

- survey-weighted analysis in R;
- national, equity, geographic, regression, and sensitivity outputs;
- disclosure-controlled public reporting tables;
- a four-schema PostgreSQL analytical/reporting layer;
- a Power BI semantic model and nine-page interactive report;
- final QA and reconciliation across analytical layers.

## Headline result

Any ANC coverage was 73.7%, while 24.5% completed the primary ANC4 + skilled birth + paired early PNC continuum.

## Equity story

Complete continuum coverage was 69.7% among women with higher education versus 6.5% among women with no education, and 65.8% among the richest quintile versus 4.6% among the poorest. Urban coverage was 43.3% compared with 13.3% in rural areas.

## Geographic story

State-level public reporting showed pronounced variation. Complete-continuum coverage ranged from 72.7% in Lagos to 3.3% in Kebbi, a 69.4 percentage-point gap.

## Modelling story

Survey-weighted logistic regression was used to examine associations with complete continuum coverage. After adjustment, higher education, greater wealth, urban residence, and several geopolitical zones remained positively associated with completion relative to their reference categories. Results are interpreted as associations rather than causal effects.

## Robustness

Two alternative outcome definitions were tested. Requiring ANC8 reduced prevalence to 11.0%, whereas replacing skilled birth attendance with facility delivery left the estimate almost unchanged at 24.6%.

## Technical value demonstrated

This case study demonstrates complex-survey analysis, health-equity measurement, logistic regression, reproducible R workflows, relational/analytical SQL design, BI semantic modelling, Power BI report development, data disclosure controls, QA, Git-based project management, and communication of health-system findings.

## Portfolio positioning

This is best presented as a **health analytics / public-health intelligence project**, not simply a dashboard. The visual report is the presentation layer of a larger reproducible analytical system.
