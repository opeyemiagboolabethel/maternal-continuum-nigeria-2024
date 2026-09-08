-- ============================================================
-- PART 46.2
-- STAGING TABLES
-- Sensitivity and Robustness Analysis
-- Maternal Continuum of Care in Nigeria
-- ============================================================


-- ------------------------------------------------------------
-- 1. SENSITIVITY ADJUSTED MODELS
-- Source: sensitivity_adjusted_models.csv
-- Expected: 57 rows x 12 columns
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS staging.sensitivity_adjusted_models (

    outcome_variable TEXT,

    outcome_definition TEXT,

    term TEXT,

    log_odds DOUBLE PRECISION,

    standard_error DOUBLE PRECISION,

    adjusted_odds_ratio DOUBLE PRECISION,

    confidence_interval_low DOUBLE PRECISION,

    confidence_interval_high DOUBLE PRECISION,

    p_value DOUBLE PRECISION,

    association_direction TEXT,

    statistically_significant TEXT,

    estimate_95ci TEXT
);


COMMENT ON TABLE staging.sensitivity_adjusted_models IS
'Staging table containing survey-weighted adjusted regression results across alternative sensitivity outcome definitions exported from the validated R analytical pipeline.';


-- ------------------------------------------------------------
-- 2. SENSITIVITY PREVALENCE COMPARISON
-- Source: sensitivity_prevalence_comparison.csv
-- Expected: 3 rows x 9 columns
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS staging.sensitivity_prevalence_comparison (

    outcome_variable TEXT,

    outcome_definition TEXT,

    unweighted_n BIGINT,

    unweighted_positive_n BIGINT,

    weighted_percent DOUBLE PRECISION,

    confidence_interval_low_percent DOUBLE PRECISION,

    confidence_interval_high_percent DOUBLE PRECISION,

    estimate_95ci TEXT,

    difference_from_primary_pp DOUBLE PRECISION
);


COMMENT ON TABLE staging.sensitivity_prevalence_comparison IS
'Staging table comparing survey-weighted prevalence estimates across primary and alternative maternal continuum-of-care outcome definitions.';


-- ------------------------------------------------------------
-- 3. VERIFY TABLE CREATION
-- ------------------------------------------------------------

SELECT
    table_schema,
    table_name
FROM information_schema.tables
WHERE table_schema = 'staging'
  AND table_name IN (
      'sensitivity_adjusted_models',
      'sensitivity_prevalence_comparison'
  )
ORDER BY table_name;