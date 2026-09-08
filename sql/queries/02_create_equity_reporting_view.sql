-- ============================================================
-- REPORTING VIEW
-- Public Equity Estimates
-- Maternal Continuum of Care and Postnatal Equity in Nigeria
-- ============================================================


CREATE OR REPLACE VIEW reporting.vw_equity_estimates AS

SELECT

    equity_estimate_id,

    equity_variable,

    equity_dimension,

    equity_category,

    indicator_variable,

    indicator,

    CASE
        WHEN indicator_variable IN (
            'anc_any',
            'early_anc',
            'anc_4plus',
            'anc_8plus',
            'skilled_anc',
            'complete_anc_content'
        )
        THEN 'Antenatal Care'

        WHEN indicator_variable IN (
            'facility_delivery',
            'skilled_birth'
        )
        THEN 'Delivery Care'

        WHEN indicator_variable IN (
            'mother_pnc_2days',
            'newborn_pnc_2days',
            'paired_pnc_2days'
        )
        THEN 'Postnatal Care'

        WHEN indicator_variable IN (
            'complete_continuum',
            'complete_continuum_anc8',
            'complete_continuum_facility'
        )
        THEN 'Continuum of Care'

        ELSE 'Other'
    END AS indicator_group,

    CASE
        WHEN indicator_variable = 'anc_any' THEN 1
        WHEN indicator_variable = 'early_anc' THEN 2
        WHEN indicator_variable = 'anc_4plus' THEN 3
        WHEN indicator_variable = 'anc_8plus' THEN 4
        WHEN indicator_variable = 'skilled_anc' THEN 5
        WHEN indicator_variable = 'complete_anc_content' THEN 6
        WHEN indicator_variable = 'facility_delivery' THEN 7
        WHEN indicator_variable = 'skilled_birth' THEN 8
        WHEN indicator_variable = 'mother_pnc_2days' THEN 9
        WHEN indicator_variable = 'newborn_pnc_2days' THEN 10
        WHEN indicator_variable = 'paired_pnc_2days' THEN 11
        WHEN indicator_variable = 'complete_continuum' THEN 12
        WHEN indicator_variable = 'complete_continuum_anc8' THEN 13
        WHEN indicator_variable = 'complete_continuum_facility' THEN 14
        ELSE 999
    END AS indicator_display_order,

    reporting_status,

    CASE
        WHEN LOWER(reporting_status) IN (
            'report',
            'reportable',
            'reported'
        )
        THEN TRUE
        ELSE FALSE
    END AS reportable_flag,

    public_weighted_percent AS weighted_percent,

    public_ci_low AS confidence_interval_low_percent,

    public_ci_high AS confidence_interval_high_percent,

    public_estimate AS estimate_95ci,

    source_file,

    created_at

FROM analytics.equity_estimates;

COMMENT ON VIEW reporting.vw_equity_estimates IS
'Power BI-ready public equity reporting view. Uses disclosure-controlled public estimates rather than internal analytical estimates.';

SELECT
    COUNT(*) AS reporting_rows,
    COUNT(DISTINCT equity_dimension) AS equity_dimensions,
    COUNT(DISTINCT indicator_variable) AS indicators
FROM reporting.vw_equity_estimates;

SELECT
    reporting_status,
    reportable_flag,
    COUNT(*) AS rows
FROM reporting.vw_equity_estimates
GROUP BY
    reporting_status,
    reportable_flag
ORDER BY reporting_status;

SELECT
    equity_dimension,
    equity_category,
    indicator_group,
    indicator_variable,
    indicator,
    weighted_percent,
    confidence_interval_low_percent,
    confidence_interval_high_percent,
    estimate_95ci,
    reporting_status
FROM reporting.vw_equity_estimates
ORDER BY
    equity_dimension,
    equity_category,
    indicator_display_order;