-- ============================================================
-- REPORTING VIEW
-- Adjusted vs Unadjusted Regression Comparison
-- Maternal Continuum of Care and Postnatal Equity in Nigeria
-- ============================================================


-- ------------------------------------------------------------
-- 1. REMOVE PREVIOUS VIEW
-- ------------------------------------------------------------

DROP VIEW IF EXISTS reporting.vw_regression_comparison;


-- ------------------------------------------------------------
-- 2. CREATE CORRECTED REPORTING VIEW
-- ------------------------------------------------------------

CREATE VIEW reporting.vw_regression_comparison AS

WITH unadjusted AS (

    SELECT

        regression_result_id,
        model,
        predictor,
        term,

        log_odds,
        standard_error,
        odds_ratio,
        confidence_interval_low,
        confidence_interval_high,
        p_value,
        statistical_significance,
        estimate_95ci

    FROM analytics.regression_results

    WHERE model_type = 'Unadjusted'
),

adjusted AS (

    SELECT

        regression_result_id,
        model,
        predictor,
        term,

        log_odds,
        standard_error,
        odds_ratio,
        confidence_interval_low,
        confidence_interval_high,
        p_value,
        statistical_significance,
        estimate_95ci

    FROM analytics.regression_results

    WHERE model_type = 'Adjusted'
)

SELECT

    -- Use predictor category from the unadjusted model
    u.predictor AS predictor,

    u.term,

    u.model AS unadjusted_model,
    a.model AS adjusted_model,


    -- --------------------------------------------------------
    -- UNADJUSTED RESULTS
    -- --------------------------------------------------------

    u.log_odds
        AS unadjusted_log_odds,

    u.standard_error
        AS unadjusted_standard_error,

    u.odds_ratio
        AS unadjusted_odds_ratio,

    u.confidence_interval_low
        AS unadjusted_ci_low,

    u.confidence_interval_high
        AS unadjusted_ci_high,

    u.p_value
        AS unadjusted_p_value,

    u.statistical_significance
        AS unadjusted_statistical_significance,

    u.estimate_95ci
        AS unadjusted_estimate_95ci,


    -- --------------------------------------------------------
    -- ADJUSTED RESULTS
    -- --------------------------------------------------------

    a.log_odds
        AS adjusted_log_odds,

    a.standard_error
        AS adjusted_standard_error,

    a.odds_ratio
        AS adjusted_odds_ratio,

    a.confidence_interval_low
        AS adjusted_ci_low,

    a.confidence_interval_high
        AS adjusted_ci_high,

    a.p_value
        AS adjusted_p_value,

    a.statistical_significance
        AS adjusted_statistical_significance,

    a.estimate_95ci
        AS adjusted_estimate_95ci,


    -- --------------------------------------------------------
    -- CHANGE IN ODDS RATIO
    -- --------------------------------------------------------

    ROUND(
        (
            a.odds_ratio -
            u.odds_ratio
        )::numeric,
        3
    ) AS absolute_or_change,

    ROUND(
        (
            (
                a.odds_ratio -
                u.odds_ratio
            )
            /
            NULLIF(u.odds_ratio, 0)
            * 100
        )::numeric,
        2
    ) AS percent_or_change,


    -- --------------------------------------------------------
    -- ADJUSTED EFFECT DIRECTION
    -- --------------------------------------------------------

    CASE

        WHEN a.odds_ratio > 1
            THEN 'Higher odds'

        WHEN a.odds_ratio < 1
            THEN 'Lower odds'

        ELSE 'No difference'

    END AS adjusted_effect_direction,


    -- --------------------------------------------------------
    -- SIGNIFICANCE FLAGS
    -- --------------------------------------------------------

    CASE
        WHEN u.p_value < 0.05
            THEN TRUE
        ELSE FALSE
    END AS unadjusted_significant_flag,

    CASE
        WHEN a.p_value < 0.05
            THEN TRUE
        ELSE FALSE
    END AS adjusted_significant_flag,


    -- --------------------------------------------------------
    -- SIGNIFICANCE CHANGE AFTER ADJUSTMENT
    -- --------------------------------------------------------

    CASE

        WHEN u.p_value < 0.05
         AND a.p_value < 0.05
            THEN 'Remained significant'

        WHEN u.p_value < 0.05
         AND a.p_value >= 0.05
            THEN 'Lost significance after adjustment'

        WHEN u.p_value >= 0.05
         AND a.p_value < 0.05
            THEN 'Became significant after adjustment'

        ELSE 'Remained non-significant'

    END AS significance_change,


    -- --------------------------------------------------------
    -- ADJUSTED CI INTERPRETATION
    -- --------------------------------------------------------

    CASE

        WHEN a.confidence_interval_low > 1
            THEN 'Entirely above 1'

        WHEN a.confidence_interval_high < 1
            THEN 'Entirely below 1'

        ELSE 'Includes 1'

    END AS adjusted_ci_interpretation,


    -- --------------------------------------------------------
    -- EFFECT CHANGE AFTER ADJUSTMENT
    -- --------------------------------------------------------

    CASE

        WHEN ABS(a.odds_ratio - 1)
             < ABS(u.odds_ratio - 1)
            THEN 'Attenuated after adjustment'

        WHEN ABS(a.odds_ratio - 1)
             > ABS(u.odds_ratio - 1)
            THEN 'Strengthened after adjustment'

        ELSE 'No material change'

    END AS adjustment_effect,


    -- --------------------------------------------------------
    -- EFFECT-DIRECTION CONSISTENCY
    -- --------------------------------------------------------

    CASE

        WHEN
            (
                u.odds_ratio > 1
                AND a.odds_ratio > 1
            )

            OR

            (
                u.odds_ratio < 1
                AND a.odds_ratio < 1
            )

            OR

            (
                u.odds_ratio = 1
                AND a.odds_ratio = 1
            )

        THEN TRUE

        ELSE FALSE

    END AS effect_direction_consistent

FROM unadjusted AS u

INNER JOIN adjusted AS a

    -- Correct matching key
    ON u.term = a.term;

COMMENT ON VIEW reporting.vw_regression_comparison IS
'Power BI-ready comparison of matched adjusted and unadjusted survey-weighted logistic regression estimates. Models are matched by regression term because adjusted results identify predictor as Multivariable model while unadjusted results retain the substantive predictor category.';

SELECT

    COUNT(*) AS comparison_rows,

    COUNT(DISTINCT predictor)
        AS predictors,

    COUNT(DISTINCT term)
        AS terms,

    COUNT(*) FILTER (
        WHERE adjusted_odds_ratio IS NULL
           OR unadjusted_odds_ratio IS NULL
    ) AS unmatched_results

FROM reporting.vw_regression_comparison;

SELECT

    predictor,
    term,

    unadjusted_odds_ratio,
    adjusted_odds_ratio,

    unadjusted_p_value,
    adjusted_p_value,

    significance_change,
    adjustment_effect,
    effect_direction_consistent

FROM reporting.vw_regression_comparison

ORDER BY
    predictor,
    term;