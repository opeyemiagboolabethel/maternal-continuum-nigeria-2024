-- ============================================================
-- REPORTING VIEW
-- Equity Gap Rankings
-- Maternal Continuum of Care and Postnatal Equity in Nigeria
-- ============================================================


CREATE OR REPLACE VIEW reporting.vw_equity_gap_rankings AS

WITH ranked_gaps AS (

    SELECT

        equity_gap_id,

        equity_variable,
        equity_dimension,

        indicator_variable,
        indicator,

        highest_group,
        highest_percent,
        highest_ci_low,
        highest_ci_high,
        highest_group_n,
        highest_reporting_status,

        lowest_group,
        lowest_percent,
        lowest_ci_low,
        lowest_ci_high,
        lowest_group_n,
        lowest_reporting_status,

        groups_compared,
        caution_groups,

        absolute_gap_pp,
        relative_ratio,
        relative_shortfall_percent,

        comparison_status,

        source_file,
        created_at,

        DENSE_RANK() OVER (
            ORDER BY absolute_gap_pp DESC
        ) AS national_gap_rank,

        DENSE_RANK() OVER (
            PARTITION BY equity_dimension
            ORDER BY absolute_gap_pp DESC
        ) AS dimension_gap_rank

    FROM analytics.equity_gap_summary
)

SELECT

    equity_gap_id,

    equity_variable,
    equity_dimension,

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

    highest_group,
    highest_percent,
    highest_ci_low,
    highest_ci_high,
    highest_group_n,
    highest_reporting_status,

    lowest_group,
    lowest_percent,
    lowest_ci_low,
    lowest_ci_high,
    lowest_group_n,
    lowest_reporting_status,

    groups_compared,
    caution_groups,

    absolute_gap_pp,
    relative_ratio,
    relative_shortfall_percent,

    comparison_status,

    national_gap_rank,
    dimension_gap_rank,

    CASE

        WHEN absolute_gap_pp >= 30
            THEN 'Very large gap'

        WHEN absolute_gap_pp >= 20
            THEN 'Large gap'

        WHEN absolute_gap_pp >= 10
            THEN 'Moderate gap'

        ELSE 'Smaller gap'

    END AS gap_magnitude,

    CASE
        WHEN caution_groups > 0
            THEN TRUE
        ELSE FALSE
    END AS caution_flag,

    source_file,
    created_at

FROM ranked_gaps;

COMMENT ON VIEW reporting.vw_equity_gap_rankings IS
'Power BI-ready equity disparity reporting view containing absolute and relative inequality measures, national and within-dimension rankings, gap magnitude classifications and caution indicators.';

SELECT

    COUNT(*) AS reporting_rows,

    COUNT(DISTINCT equity_dimension)
        AS equity_dimensions,

    COUNT(DISTINCT indicator_variable)
        AS indicators,

    MIN(national_gap_rank)
        AS best_rank,

    MAX(national_gap_rank)
        AS lowest_rank

FROM reporting.vw_equity_gap_rankings;

SELECT

    national_gap_rank,
    equity_dimension,
    indicator,
    highest_group,
    lowest_group,

    ROUND(
        absolute_gap_pp::numeric,
        2
    ) AS absolute_gap_pp,

    ROUND(
        relative_ratio::numeric,
        2
    ) AS relative_ratio,

    gap_magnitude,
    caution_flag

FROM reporting.vw_equity_gap_rankings

ORDER BY
    national_gap_rank,
    equity_dimension;