-- ============================================================
-- REPORTING VIEW
-- State Geographic Performance and Rankings
-- Maternal Continuum of Care and Postnatal Equity in Nigeria
-- ============================================================


CREATE OR REPLACE VIEW reporting.vw_state_indicator_rankings AS

WITH state_base AS (

    SELECT

        s.state_estimate_id,
        s.state,
        s.zone,
        s.indicator_variable,
        s.indicator,

        s.unweighted_n,
        s.unweighted_positive_n,

        s.reporting_status,

        s.public_weighted_percent AS weighted_percent,
        s.public_ci_low AS confidence_interval_low_percent,
        s.public_ci_high AS confidence_interval_high_percent,
        s.public_estimate AS estimate_95ci,

        s.source_file,
        s.created_at,


        -- ----------------------------------------------------
        -- INDICATOR GROUP
        -- ----------------------------------------------------

        CASE

            WHEN s.indicator_variable IN (
                'anc_any',
                'early_anc',
                'anc_4plus',
                'anc_8plus',
                'skilled_anc',
                'complete_anc_content'
            )
            THEN 'Antenatal Care'

            WHEN s.indicator_variable IN (
                'facility_delivery',
                'skilled_birth'
            )
            THEN 'Delivery Care'

            WHEN s.indicator_variable IN (
                'mother_pnc_2days',
                'newborn_pnc_2days',
                'paired_pnc_2days'
            )
            THEN 'Postnatal Care'

            WHEN s.indicator_variable IN (
                'complete_continuum',
                'complete_continuum_anc8',
                'complete_continuum_facility'
            )
            THEN 'Continuum of Care'

            ELSE 'Other'

        END AS indicator_group,


        -- ----------------------------------------------------
        -- DISPLAY ORDER
        -- ----------------------------------------------------

        CASE
            WHEN s.indicator_variable = 'anc_any' THEN 1
            WHEN s.indicator_variable = 'early_anc' THEN 2
            WHEN s.indicator_variable = 'anc_4plus' THEN 3
            WHEN s.indicator_variable = 'anc_8plus' THEN 4
            WHEN s.indicator_variable = 'skilled_anc' THEN 5
            WHEN s.indicator_variable = 'complete_anc_content' THEN 6
            WHEN s.indicator_variable = 'facility_delivery' THEN 7
            WHEN s.indicator_variable = 'skilled_birth' THEN 8
            WHEN s.indicator_variable = 'mother_pnc_2days' THEN 9
            WHEN s.indicator_variable = 'newborn_pnc_2days' THEN 10
            WHEN s.indicator_variable = 'paired_pnc_2days' THEN 11
            WHEN s.indicator_variable = 'complete_continuum' THEN 12
            WHEN s.indicator_variable = 'complete_continuum_anc8' THEN 13
            WHEN s.indicator_variable = 'complete_continuum_facility' THEN 14
            ELSE 999
        END AS indicator_display_order,


        -- ----------------------------------------------------
        -- RANKING
        -- ----------------------------------------------------

        DENSE_RANK() OVER (
            PARTITION BY s.indicator_variable
            ORDER BY s.public_weighted_percent DESC
        ) AS national_state_rank,

        DENSE_RANK() OVER (
            PARTITION BY s.indicator_variable
            ORDER BY s.public_weighted_percent ASC
        ) AS national_state_low_rank,

        DENSE_RANK() OVER (
            PARTITION BY s.indicator_variable, s.zone
            ORDER BY s.public_weighted_percent DESC
        ) AS zone_state_rank,


        -- ----------------------------------------------------
        -- ZONE BENCHMARK
        -- ----------------------------------------------------

        AVG(s.public_weighted_percent) OVER (
            PARTITION BY s.indicator_variable, s.zone
        ) AS zone_mean_percent

    FROM analytics.state_indicator_estimates AS s
),

national_reference AS (

    SELECT

        variable AS indicator_variable,

        weighted_percent
            AS national_weighted_percent

    FROM reporting.vw_national_indicator_estimates
)

SELECT

    sb.state_estimate_id,

    sb.state,
    sb.zone,

    sb.indicator_variable,
    sb.indicator,

    sb.indicator_group,
    sb.indicator_display_order,

    sb.unweighted_n,
    sb.unweighted_positive_n,

    sb.weighted_percent,
    sb.confidence_interval_low_percent,
    sb.confidence_interval_high_percent,
    sb.estimate_95ci,

    sb.reporting_status,

    sb.national_state_rank,
    sb.national_state_low_rank,
    sb.zone_state_rank,

    ROUND(
        sb.zone_mean_percent::numeric,
        2
    ) AS zone_mean_percent,

    nr.national_weighted_percent,

    ROUND(
        (
            sb.weighted_percent
            - nr.national_weighted_percent
        )::numeric,
        2
    ) AS difference_from_national_pp,

    ROUND(
        (
            sb.weighted_percent
            - sb.zone_mean_percent
        )::numeric,
        2
    ) AS difference_from_zone_pp,


    -- --------------------------------------------------------
    -- PERFORMANCE RELATIVE TO NATIONAL VALUE
    -- --------------------------------------------------------

    CASE

        WHEN nr.national_weighted_percent IS NULL
            THEN 'National benchmark unavailable'

        WHEN sb.weighted_percent >
             nr.national_weighted_percent
            THEN 'Above national estimate'

        WHEN sb.weighted_percent <
             nr.national_weighted_percent
            THEN 'Below national estimate'

        ELSE 'At national estimate'

    END AS national_performance_status,


    -- --------------------------------------------------------
    -- SIMPLE RANKING BAND
    -- --------------------------------------------------------

    CASE

        WHEN sb.national_state_rank <= 5
            THEN 'Top 5'

        WHEN sb.national_state_low_rank <= 5
            THEN 'Bottom 5'

        ELSE 'Middle performing'

    END AS performance_band,

    sb.source_file,
    sb.created_at

FROM state_base AS sb

LEFT JOIN national_reference AS nr
    ON sb.indicator_variable = nr.indicator_variable;

COMMENT ON VIEW reporting.vw_state_indicator_rankings IS
'Power BI-ready state geographic performance view containing public state estimates, national and within-zone rankings, zone averages, national benchmarks and performance bands.';

SELECT

    COUNT(*) AS reporting_rows,

    COUNT(DISTINCT state)
        AS states,

    COUNT(DISTINCT zone)
        AS zones,

    COUNT(DISTINCT indicator_variable)
        AS indicators

FROM reporting.vw_state_indicator_rankings;

SELECT

    indicator_variable,
    state,
    zone,

    weighted_percent,

    national_weighted_percent,

    difference_from_national_pp,

    national_state_rank,

    zone_state_rank,

    performance_band

FROM reporting.vw_state_indicator_rankings

ORDER BY
    indicator_variable,
    national_state_rank,
    state;

SELECT

    indicator,
    state,
    zone,
    weighted_percent,
    national_state_rank,
    national_state_low_rank,
    performance_band

FROM reporting.vw_state_indicator_rankings

WHERE national_state_rank <= 5
   OR national_state_low_rank <= 5

ORDER BY
    indicator_display_order,
    national_state_rank,
    state;