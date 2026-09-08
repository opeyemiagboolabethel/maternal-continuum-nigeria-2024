-- ============================================================
-- REPORTING VIEW
-- National Indicator Estimates
-- Maternal Continuum of Care and Postnatal Equity in Nigeria
-- ============================================================


CREATE OR REPLACE VIEW reporting.vw_national_indicator_estimates AS

SELECT

    indicator_id,

    variable,

    indicator,

    CASE

        WHEN variable IN (
            'anc_any',
            'early_anc',
            'anc_4plus',
            'anc_8plus',
            'skilled_anc',
            'complete_anc_content'
        )
        THEN 'Antenatal Care'

        WHEN variable IN (
            'facility_delivery',
            'skilled_birth'
        )
        THEN 'Delivery Care'

        WHEN variable IN (
            'mother_pnc_2days',
            'newborn_pnc_2days',
            'paired_pnc_2days'
        )
        THEN 'Postnatal Care'

        WHEN variable IN (
            'complete_continuum',
            'complete_continuum_anc8',
            'complete_continuum_facility'
        )
        THEN 'Continuum of Care'

        ELSE 'Other'

    END AS indicator_group,

    CASE

        WHEN variable = 'anc_any' THEN 1
        WHEN variable = 'early_anc' THEN 2
        WHEN variable = 'anc_4plus' THEN 3
        WHEN variable = 'anc_8plus' THEN 4
        WHEN variable = 'skilled_anc' THEN 5
        WHEN variable = 'complete_anc_content' THEN 6

        WHEN variable = 'facility_delivery' THEN 7
        WHEN variable = 'skilled_birth' THEN 8

        WHEN variable = 'mother_pnc_2days' THEN 9
        WHEN variable = 'newborn_pnc_2days' THEN 10
        WHEN variable = 'paired_pnc_2days' THEN 11

        WHEN variable = 'complete_continuum' THEN 12
        WHEN variable = 'complete_continuum_anc8' THEN 13
        WHEN variable = 'complete_continuum_facility' THEN 14

        ELSE 999

    END AS display_order,

    unweighted_n,

    unweighted_positive_n,

    weighted_percent,

    standard_error_percent,

    confidence_interval_low_percent,

    confidence_interval_high_percent,

    estimate_95ci,

    source_file,

    created_at

FROM analytics.national_indicator_estimates;

COMMENT ON VIEW reporting.vw_national_indicator_estimates IS
'Power BI-ready reporting view containing national maternal continuum-of-care indicators, thematic groupings and presentation order.';

-- ============================================================
-- VERIFY REPORTING VIEW
-- ============================================================

SELECT
    COUNT(*) AS reporting_rows,
    COUNT(DISTINCT variable) AS distinct_variables
FROM reporting.vw_national_indicator_estimates;

SELECT
    display_order,
    indicator_group,
    variable,
    indicator,
    weighted_percent,
    confidence_interval_low_percent,
    confidence_interval_high_percent,
    estimate_95ci
FROM reporting.vw_national_indicator_estimates
ORDER BY display_order;