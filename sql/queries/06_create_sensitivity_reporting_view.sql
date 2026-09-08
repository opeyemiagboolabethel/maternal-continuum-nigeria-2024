-- ============================================================
-- PART 46.5
-- POWER BI-READY SENSITIVITY AND ROBUSTNESS REPORTING VIEW
-- Maternal Continuum of Care in Nigeria
-- ============================================================


-- ============================================================
-- 1. REMOVE PREVIOUS VERSION IF IT EXISTS
-- ============================================================

DROP VIEW IF EXISTS reporting.vw_sensitivity_robustness;


-- ============================================================
-- 2. CREATE REPORTING VIEW
-- ============================================================

CREATE VIEW reporting.vw_sensitivity_robustness AS

WITH sensitivity_base AS (

    SELECT

        m.sensitivity_model_id,

        m.outcome_variable,
        m.outcome_definition,
        m.term,

        m.log_odds,
        m.standard_error,

        m.adjusted_odds_ratio,

        m.confidence_interval_low,
        m.confidence_interval_high,

        m.p_value,

        m.association_direction,
        m.statistically_significant,

        m.estimate_95ci,

        p.unweighted_n,
        p.unweighted_positive_n,

        p.weighted_percent
            AS outcome_weighted_percent,

        p.confidence_interval_low_percent
            AS outcome_ci_low_percent,

        p.confidence_interval_high_percent
            AS outcome_ci_high_percent,

        p.estimate_95ci
            AS outcome_estimate_95ci,

        p.difference_from_primary_pp,

        m.source_file,
        m.created_at

    FROM analytics.sensitivity_adjusted_models AS m

    LEFT JOIN analytics.sensitivity_prevalence_comparison AS p

        ON m.outcome_variable = p.outcome_variable
),


robustness AS (

    SELECT

        *,

        -- ----------------------------------------------------
        -- NUMBER OF OUTCOMES AVAILABLE FOR EACH TERM
        -- ----------------------------------------------------

        COUNT(*) OVER (
            PARTITION BY term
        ) AS outcomes_compared,


        -- ----------------------------------------------------
        -- EFFECT DIRECTION COUNTS
        -- ----------------------------------------------------

        COUNT(*) FILTER (
            WHERE adjusted_odds_ratio > 1
        ) OVER (
            PARTITION BY term
        ) AS higher_odds_outcomes,

        COUNT(*) FILTER (
            WHERE adjusted_odds_ratio < 1
        ) OVER (
            PARTITION BY term
        ) AS lower_odds_outcomes,


        -- ----------------------------------------------------
        -- SIGNIFICANCE COUNT
        -- ----------------------------------------------------

        COUNT(*) FILTER (
            WHERE p_value < 0.05
        ) OVER (
            PARTITION BY term
        ) AS significant_outcomes,


        -- ----------------------------------------------------
        -- OR RANGE ACROSS SENSITIVITY OUTCOMES
        -- ----------------------------------------------------

        MIN(adjusted_odds_ratio) OVER (
            PARTITION BY term
        ) AS minimum_adjusted_or,

        MAX(adjusted_odds_ratio) OVER (
            PARTITION BY term
        ) AS maximum_adjusted_or

    FROM sensitivity_base
)


SELECT

    sensitivity_model_id,

    outcome_variable,
    outcome_definition,

    term,


    -- ========================================================
    -- OUTCOME PREVALENCE
    -- ========================================================

    unweighted_n,
    unweighted_positive_n,

    outcome_weighted_percent,

    outcome_ci_low_percent,
    outcome_ci_high_percent,

    outcome_estimate_95ci,

    difference_from_primary_pp,


    -- ========================================================
    -- MODEL ESTIMATE
    -- ========================================================

    log_odds,
    standard_error,

    adjusted_odds_ratio,

    confidence_interval_low,
    confidence_interval_high,

    p_value,

    association_direction,
    statistically_significant,

    estimate_95ci,


    -- ========================================================
    -- SIMPLE SIGNIFICANCE FLAG
    -- ========================================================

    CASE

        WHEN p_value < 0.05
            THEN TRUE

        ELSE FALSE

    END AS significant_flag,


    -- ========================================================
    -- EFFECT DIRECTION
    -- ========================================================

    CASE

        WHEN adjusted_odds_ratio > 1
            THEN 'Higher odds'

        WHEN adjusted_odds_ratio < 1
            THEN 'Lower odds'

        ELSE 'No difference'

    END AS effect_direction,


    -- ========================================================
    -- CI RELATIONSHIP TO NULL VALUE OR = 1
    -- ========================================================

    CASE

        WHEN confidence_interval_low > 1
            THEN 'Entirely above 1'

        WHEN confidence_interval_high < 1
            THEN 'Entirely below 1'

        ELSE 'Includes 1'

    END AS ci_interpretation,


    -- ========================================================
    -- ROBUSTNESS COUNTS
    -- ========================================================

    outcomes_compared,

    higher_odds_outcomes,

    lower_odds_outcomes,

    significant_outcomes,

    minimum_adjusted_or,

    maximum_adjusted_or,


    -- ========================================================
    -- EFFECT-DIRECTION ROBUSTNESS
    -- ========================================================

    CASE

        WHEN higher_odds_outcomes = outcomes_compared
            THEN 'Consistently higher odds'

        WHEN lower_odds_outcomes = outcomes_compared
            THEN 'Consistently lower odds'

        ELSE 'Direction varies across outcomes'

    END AS direction_robustness,


    -- ========================================================
    -- STATISTICAL SIGNIFICANCE ROBUSTNESS
    -- ========================================================

    CASE

        WHEN significant_outcomes = outcomes_compared
            THEN 'Significant across all outcomes'

        WHEN significant_outcomes = 0
            THEN 'Non-significant across all outcomes'

        ELSE 'Significance varies across outcomes'

    END AS significance_robustness,


    -- ========================================================
    -- OVERALL ROBUSTNESS CLASSIFICATION
    -- ========================================================

    CASE

        WHEN
            (
                higher_odds_outcomes = outcomes_compared
                OR
                lower_odds_outcomes = outcomes_compared
            )
            AND significant_outcomes = outcomes_compared

            THEN 'Highly robust'

        WHEN
            (
                higher_odds_outcomes = outcomes_compared
                OR
                lower_odds_outcomes = outcomes_compared
            )

            THEN 'Directionally robust'

        ELSE 'Sensitive to outcome definition'

    END AS overall_robustness,


    source_file,
    created_at

FROM robustness;
    

-- ============================================================
-- 3. DOCUMENT REPORTING VIEW
-- ============================================================

COMMENT ON VIEW reporting.vw_sensitivity_robustness IS
'Power BI-ready sensitivity and robustness reporting view combining alternative outcome prevalence estimates with adjusted model results and cross-outcome robustness classifications.';


-- ============================================================
-- 4. VALIDATE REPORTING VIEW
-- ============================================================

SELECT

    COUNT(*) AS reporting_rows,

    COUNT(DISTINCT outcome_variable)
        AS outcomes,

    COUNT(DISTINCT term)
        AS terms,

    COUNT(*) FILTER (
        WHERE outcome_weighted_percent IS NULL
    ) AS missing_prevalence_matches

FROM reporting.vw_sensitivity_robustness;


-- Expected:
-- reporting_rows             = 57
-- outcomes                   = 3
-- terms                      = 19
-- missing_prevalence_matches = 0


-- ============================================================
-- 5. CONFIRM 19 TERMS PER OUTCOME
-- ============================================================

SELECT

    outcome_variable,
    outcome_definition,

    COUNT(*) AS model_terms,

    COUNT(DISTINCT term)
        AS distinct_terms

FROM reporting.vw_sensitivity_robustness

GROUP BY
    outcome_variable,
    outcome_definition

ORDER BY outcome_variable;


-- Expected:
-- 3 outcome definitions
-- 19 rows per outcome
-- 19 distinct terms per outcome


-- ============================================================
-- 6. REVIEW ROBUSTNESS BY TERM
-- ============================================================

SELECT DISTINCT

    term,

    outcomes_compared,

    minimum_adjusted_or,
    maximum_adjusted_or,

    higher_odds_outcomes,
    lower_odds_outcomes,

    significant_outcomes,

    direction_robustness,
    significance_robustness,
    overall_robustness

FROM reporting.vw_sensitivity_robustness

ORDER BY term;


-- Expected:
-- 19 terms


-- ============================================================
-- 7. ROBUSTNESS SUMMARY
-- ============================================================

SELECT

    overall_robustness,

    COUNT(DISTINCT term)
        AS terms

FROM reporting.vw_sensitivity_robustness

GROUP BY overall_robustness

ORDER BY overall_robustness;


-- ============================================================
-- 8. PREVALENCE SENSITIVITY SUMMARY
-- ============================================================

SELECT DISTINCT

    outcome_variable,
    outcome_definition,

    unweighted_n,
    unweighted_positive_n,

    outcome_weighted_percent,

    outcome_ci_low_percent,
    outcome_ci_high_percent,

    difference_from_primary_pp,

    outcome_estimate_95ci

FROM reporting.vw_sensitivity_robustness

ORDER BY difference_from_primary_pp;


-- ============================================================
-- 9. REVIEW RESULTS THAT REMAIN SIGNIFICANT
--    ACROSS ALL SENSITIVITY OUTCOMES
-- ============================================================

SELECT DISTINCT

    term,

    minimum_adjusted_or,
    maximum_adjusted_or,

    direction_robustness,
    significance_robustness,
    overall_robustness

FROM reporting.vw_sensitivity_robustness

WHERE significant_outcomes = outcomes_compared

ORDER BY term;


-- ============================================================
-- 10. FINAL POWER BI PREVIEW
-- ============================================================

SELECT

    outcome_variable,
    outcome_definition,

    term,

    outcome_weighted_percent,
    difference_from_primary_pp,

    adjusted_odds_ratio,

    confidence_interval_low,
    confidence_interval_high,

    p_value,

    effect_direction,

    direction_robustness,
    significance_robustness,
    overall_robustness

FROM reporting.vw_sensitivity_robustness

ORDER BY
    term,
    outcome_variable;