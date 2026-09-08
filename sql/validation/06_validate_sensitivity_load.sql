-- ============================================================
-- PART 46.3
-- SENSITIVITY AND ROBUSTNESS ANALYSIS
-- LOAD VALIDATION AND AUDIT
-- Maternal Continuum of Care in Nigeria
-- ============================================================


-- ============================================================
-- 1. CONFIRM BOTH SOURCE LOADS
-- ============================================================

SELECT
    'sensitivity_adjusted_models' AS table_name,
    COUNT(*) AS rows_loaded
FROM staging.sensitivity_adjusted_models

UNION ALL

SELECT
    'sensitivity_prevalence_comparison',
    COUNT(*)
FROM staging.sensitivity_prevalence_comparison;


-- Expected:
-- sensitivity_adjusted_models         = 57
-- sensitivity_prevalence_comparison  = 3



-- ============================================================
-- 2. VALIDATE SENSITIVITY ADJUSTED MODELS
-- ============================================================

SELECT

    COUNT(*) AS total_rows,

    COUNT(DISTINCT outcome_variable)
        AS outcomes,

    COUNT(DISTINCT term)
        AS terms,

    COUNT(*) FILTER (
        WHERE outcome_variable IS NULL
           OR outcome_definition IS NULL
           OR term IS NULL
    ) AS missing_keys,

    COUNT(*) FILTER (
        WHERE standard_error < 0
    ) AS invalid_standard_errors,

    COUNT(*) FILTER (
        WHERE adjusted_odds_ratio <= 0
    ) AS invalid_odds_ratios,

    COUNT(*) FILTER (
        WHERE confidence_interval_low <= 0
           OR confidence_interval_high <= 0
           OR confidence_interval_low >
              confidence_interval_high
    ) AS invalid_confidence_intervals,

    COUNT(*) FILTER (
        WHERE p_value < 0
           OR p_value > 1
    ) AS invalid_p_values

FROM staging.sensitivity_adjusted_models;


-- Expected:
-- total_rows                   = 57
-- outcomes                     = 3
-- terms                        = 19
-- missing_keys                 = 0
-- invalid_standard_errors      = 0
-- invalid_odds_ratios          = 0
-- invalid_confidence_intervals = 0
-- invalid_p_values             = 0



-- ============================================================
-- 3. VALIDATE SENSITIVITY PREVALENCE COMPARISON
-- ============================================================

SELECT

    COUNT(*) AS total_rows,

    COUNT(DISTINCT outcome_variable)
        AS outcomes,

    COUNT(*) FILTER (
        WHERE outcome_variable IS NULL
           OR outcome_definition IS NULL
    ) AS missing_keys,

    COUNT(*) FILTER (
        WHERE unweighted_n < 0
           OR unweighted_positive_n < 0
           OR unweighted_positive_n > unweighted_n
    ) AS invalid_counts,

    COUNT(*) FILTER (
        WHERE weighted_percent < 0
           OR weighted_percent > 100
    ) AS invalid_weighted_percent,

    COUNT(*) FILTER (
        WHERE confidence_interval_low_percent >
              confidence_interval_high_percent
    ) AS invalid_confidence_intervals

FROM staging.sensitivity_prevalence_comparison;


-- Expected:
-- total_rows                   = 3
-- outcomes                     = 3
-- missing_keys                 = 0
-- invalid_counts               = 0
-- invalid_weighted_percent     = 0
-- invalid_confidence_intervals = 0



-- ============================================================
-- 4. REVIEW PREVALENCE SENSITIVITY RESULTS
-- ============================================================

SELECT

    outcome_variable,
    outcome_definition,

    unweighted_n,
    unweighted_positive_n,

    weighted_percent,

    confidence_interval_low_percent,
    confidence_interval_high_percent,

    difference_from_primary_pp,

    estimate_95ci

FROM staging.sensitivity_prevalence_comparison

ORDER BY
    difference_from_primary_pp,
    outcome_variable;



-- ============================================================
-- 5. REVIEW MODEL COVERAGE ACROSS OUTCOME DEFINITIONS
-- ============================================================

SELECT

    outcome_variable,
    outcome_definition,

    COUNT(*) AS model_terms,

    COUNT(*) FILTER (
        WHERE p_value < 0.05
    ) AS statistically_significant_terms

FROM staging.sensitivity_adjusted_models

GROUP BY
    outcome_variable,
    outcome_definition

ORDER BY
    outcome_variable;


-- Expected structure:
-- 3 outcome definitions
-- 19 model terms per outcome
-- 57 model rows in total



-- ============================================================
-- 6. VERIFY TERM COVERAGE
-- ============================================================

SELECT

    outcome_variable,

    COUNT(*) AS rows,

    COUNT(DISTINCT term) AS distinct_terms

FROM staging.sensitivity_adjusted_models

GROUP BY outcome_variable

ORDER BY outcome_variable;


-- Each outcome should contain:
-- rows = 19
-- distinct_terms = 19



-- ============================================================
-- 7. AUDIT SENSITIVITY ADJUSTED MODELS LOAD
-- ============================================================

INSERT INTO audit.data_load_log (

    source_file,
    target_schema,
    target_table,
    load_completed_at,
    rows_loaded,
    load_status

)

SELECT

    'sensitivity_adjusted_models.csv',
    'staging',
    'sensitivity_adjusted_models',
    CURRENT_TIMESTAMP,
    COUNT(*),
    'SUCCESS'

FROM staging.sensitivity_adjusted_models

WHERE NOT EXISTS (

    SELECT 1

    FROM audit.data_load_log

    WHERE source_file = 'sensitivity_adjusted_models.csv'
      AND target_schema = 'staging'
      AND target_table = 'sensitivity_adjusted_models'
      AND load_status = 'SUCCESS'
);



-- ============================================================
-- 8. AUDIT SENSITIVITY PREVALENCE LOAD
-- ============================================================

INSERT INTO audit.data_load_log (

    source_file,
    target_schema,
    target_table,
    load_completed_at,
    rows_loaded,
    load_status

)

SELECT

    'sensitivity_prevalence_comparison.csv',
    'staging',
    'sensitivity_prevalence_comparison',
    CURRENT_TIMESTAMP,
    COUNT(*),
    'SUCCESS'

FROM staging.sensitivity_prevalence_comparison

WHERE NOT EXISTS (

    SELECT 1

    FROM audit.data_load_log

    WHERE source_file = 'sensitivity_prevalence_comparison.csv'
      AND target_schema = 'staging'
      AND target_table = 'sensitivity_prevalence_comparison'
      AND load_status = 'SUCCESS'
);



-- ============================================================
-- 9. VERIFY AUDIT RECORDS
-- ============================================================

SELECT

    source_file,
    target_schema,
    target_table,
    rows_loaded,
    load_status,
    load_completed_at

FROM audit.data_load_log

WHERE source_file IN (

    'sensitivity_adjusted_models.csv',
    'sensitivity_prevalence_comparison.csv'

)

ORDER BY source_file;


-- Expected:
--
-- sensitivity_adjusted_models.csv
-- rows_loaded = 57
-- load_status = SUCCESS
--
-- sensitivity_prevalence_comparison.csv
-- rows_loaded = 3
-- load_status = SUCCESS



-- ============================================================
-- 10. FINAL PART 46.3 RECONCILIATION
-- ============================================================

SELECT

    (
        SELECT COUNT(*)
        FROM staging.sensitivity_adjusted_models
    ) AS sensitivity_model_rows,

    (
        SELECT COUNT(DISTINCT outcome_variable)
        FROM staging.sensitivity_adjusted_models
    ) AS sensitivity_model_outcomes,

    (
        SELECT COUNT(DISTINCT term)
        FROM staging.sensitivity_adjusted_models
    ) AS sensitivity_model_terms,

    (
        SELECT COUNT(*)
        FROM staging.sensitivity_prevalence_comparison
    ) AS prevalence_comparison_rows;


-- Expected final result:
--
-- sensitivity_model_rows      = 57
-- sensitivity_model_outcomes  = 3
-- sensitivity_model_terms     = 19
-- prevalence_comparison_rows  = 3