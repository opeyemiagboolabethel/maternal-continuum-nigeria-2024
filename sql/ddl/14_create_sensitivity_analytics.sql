-- ============================================================
-- PART 46.4
-- CURATED SENSITIVITY AND ROBUSTNESS ANALYTICS TABLES
-- Maternal Continuum of Care in Nigeria
-- ============================================================


-- ============================================================
-- 1. REMOVE PREVIOUS VERSIONS IF THEY EXIST
-- ============================================================

DROP TABLE IF EXISTS analytics.sensitivity_adjusted_models CASCADE;

DROP TABLE IF EXISTS analytics.sensitivity_prevalence_comparison CASCADE;



-- ============================================================
-- 2. CREATE CURATED SENSITIVITY MODEL TABLE
-- ============================================================

CREATE TABLE analytics.sensitivity_adjusted_models (

    sensitivity_model_id BIGINT
        GENERATED ALWAYS AS IDENTITY
        PRIMARY KEY,

    outcome_variable TEXT NOT NULL,

    outcome_definition TEXT NOT NULL,

    term TEXT NOT NULL,

    log_odds DOUBLE PRECISION NOT NULL,

    standard_error DOUBLE PRECISION NOT NULL,

    adjusted_odds_ratio DOUBLE PRECISION NOT NULL,

    confidence_interval_low DOUBLE PRECISION NOT NULL,

    confidence_interval_high DOUBLE PRECISION NOT NULL,

    p_value DOUBLE PRECISION NOT NULL,

    association_direction TEXT NOT NULL,

    statistically_significant TEXT NOT NULL,

    estimate_95ci TEXT NOT NULL,

    source_file TEXT NOT NULL
        DEFAULT 'sensitivity_adjusted_models.csv',

    created_at TIMESTAMPTZ NOT NULL
        DEFAULT CURRENT_TIMESTAMP,


    -- --------------------------------------------------------
    -- UNIQUENESS
    -- --------------------------------------------------------

    CONSTRAINT uq_sensitivity_outcome_term
        UNIQUE (
            outcome_variable,
            term
        ),


    -- --------------------------------------------------------
    -- NUMERIC VALIDATION
    -- --------------------------------------------------------

    CONSTRAINT chk_sensitivity_standard_error
        CHECK (
            standard_error >= 0
        ),

    CONSTRAINT chk_sensitivity_odds_ratio
        CHECK (
            adjusted_odds_ratio > 0
        ),

    CONSTRAINT chk_sensitivity_ci
        CHECK (
            confidence_interval_low > 0
            AND confidence_interval_high > 0
            AND confidence_interval_low
                <= confidence_interval_high
        ),

    CONSTRAINT chk_sensitivity_p_value
        CHECK (
            p_value >= 0
            AND p_value <= 1
        )
);


COMMENT ON TABLE analytics.sensitivity_adjusted_models IS
'Curated survey-weighted adjusted regression results across alternative maternal continuum-of-care outcome definitions for sensitivity and robustness assessment.';



-- ============================================================
-- 3. LOAD CURATED SENSITIVITY MODELS
-- ============================================================

INSERT INTO analytics.sensitivity_adjusted_models (

    outcome_variable,
    outcome_definition,
    term,
    log_odds,
    standard_error,
    adjusted_odds_ratio,
    confidence_interval_low,
    confidence_interval_high,
    p_value,
    association_direction,
    statistically_significant,
    estimate_95ci

)

SELECT

    outcome_variable,
    outcome_definition,
    term,
    log_odds,
    standard_error,
    adjusted_odds_ratio,
    confidence_interval_low,
    confidence_interval_high,
    p_value,
    association_direction,
    statistically_significant,
    estimate_95ci

FROM staging.sensitivity_adjusted_models

ORDER BY
    outcome_variable,
    term;



-- ============================================================
-- 4. CREATE CURATED SENSITIVITY PREVALENCE TABLE
-- ============================================================

CREATE TABLE analytics.sensitivity_prevalence_comparison (

    sensitivity_prevalence_id BIGINT
        GENERATED ALWAYS AS IDENTITY
        PRIMARY KEY,

    outcome_variable TEXT NOT NULL,

    outcome_definition TEXT NOT NULL,

    unweighted_n BIGINT NOT NULL,

    unweighted_positive_n BIGINT NOT NULL,

    weighted_percent DOUBLE PRECISION NOT NULL,

    confidence_interval_low_percent DOUBLE PRECISION NOT NULL,

    confidence_interval_high_percent DOUBLE PRECISION NOT NULL,

    estimate_95ci TEXT NOT NULL,

    difference_from_primary_pp DOUBLE PRECISION NOT NULL,

    source_file TEXT NOT NULL
        DEFAULT 'sensitivity_prevalence_comparison.csv',

    created_at TIMESTAMPTZ NOT NULL
        DEFAULT CURRENT_TIMESTAMP,


    -- --------------------------------------------------------
    -- UNIQUENESS
    -- --------------------------------------------------------

    CONSTRAINT uq_sensitivity_prevalence_outcome
        UNIQUE (
            outcome_variable
        ),


    -- --------------------------------------------------------
    -- COUNT VALIDATION
    -- --------------------------------------------------------

    CONSTRAINT chk_sensitivity_prevalence_n
        CHECK (
            unweighted_n >= 0
        ),

    CONSTRAINT chk_sensitivity_prevalence_positive_n
        CHECK (
            unweighted_positive_n >= 0
            AND unweighted_positive_n <= unweighted_n
        ),


    -- --------------------------------------------------------
    -- PREVALENCE VALIDATION
    -- --------------------------------------------------------

    CONSTRAINT chk_sensitivity_prevalence_percent
        CHECK (
            weighted_percent >= 0
            AND weighted_percent <= 100
        ),

    -- Survey CIs may extend slightly outside 0-100.
    -- Validate ordering only.

    CONSTRAINT chk_sensitivity_prevalence_ci
        CHECK (
            confidence_interval_low_percent
            <= confidence_interval_high_percent
        )
);


COMMENT ON TABLE analytics.sensitivity_prevalence_comparison IS
'Curated comparison of survey-weighted prevalence estimates across primary and alternative maternal continuum-of-care outcome definitions.';



-- ============================================================
-- 5. LOAD CURATED PREVALENCE RESULTS
-- ============================================================

INSERT INTO analytics.sensitivity_prevalence_comparison (

    outcome_variable,
    outcome_definition,
    unweighted_n,
    unweighted_positive_n,
    weighted_percent,
    confidence_interval_low_percent,
    confidence_interval_high_percent,
    estimate_95ci,
    difference_from_primary_pp

)

SELECT

    outcome_variable,
    outcome_definition,
    unweighted_n,
    unweighted_positive_n,
    weighted_percent,
    confidence_interval_low_percent,
    confidence_interval_high_percent,
    estimate_95ci,
    difference_from_primary_pp

FROM staging.sensitivity_prevalence_comparison

ORDER BY outcome_variable;



-- ============================================================
-- 6. RECONCILE STAGING AND ANALYTICS
-- ============================================================

SELECT

    (
        SELECT COUNT(*)
        FROM staging.sensitivity_adjusted_models
    ) AS staging_model_rows,

    (
        SELECT COUNT(*)
        FROM analytics.sensitivity_adjusted_models
    ) AS analytics_model_rows,

    (
        SELECT COUNT(*)
        FROM staging.sensitivity_prevalence_comparison
    ) AS staging_prevalence_rows,

    (
        SELECT COUNT(*)
        FROM analytics.sensitivity_prevalence_comparison
    ) AS analytics_prevalence_rows;

	-- ============================================================
-- 7. ANALYTICS MODEL QA
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
        WHERE adjusted_odds_ratio <= 0
    ) AS invalid_odds_ratios,

    COUNT(*) FILTER (
        WHERE standard_error < 0
    ) AS invalid_standard_errors,

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

FROM analytics.sensitivity_adjusted_models;



-- ============================================================
-- 8. ANALYTICS PREVALENCE QA
-- ============================================================

SELECT

    COUNT(*) AS total_rows,

    COUNT(DISTINCT outcome_variable)
        AS outcomes,

    COUNT(*) FILTER (
        WHERE unweighted_n < 0
           OR unweighted_positive_n < 0
           OR unweighted_positive_n > unweighted_n
    ) AS invalid_counts,

    COUNT(*) FILTER (
        WHERE weighted_percent < 0
           OR weighted_percent > 100
    ) AS invalid_percentages,

    COUNT(*) FILTER (
        WHERE confidence_interval_low_percent >
              confidence_interval_high_percent
    ) AS invalid_confidence_intervals

FROM analytics.sensitivity_prevalence_comparison;



-- ============================================================
-- 9. CHECK 19 TERMS ACROSS EACH OF THE 3 OUTCOMES
-- ============================================================

SELECT

    outcome_variable,
    outcome_definition,

    COUNT(*) AS model_terms,

    COUNT(DISTINCT term)
        AS distinct_terms,

    COUNT(*) FILTER (
        WHERE p_value < 0.05
    ) AS significant_terms

FROM analytics.sensitivity_adjusted_models

GROUP BY
    outcome_variable,
    outcome_definition

ORDER BY outcome_variable;



-- ============================================================
-- 10. COMPARE PREVALENCE ACROSS OUTCOME DEFINITIONS
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

FROM analytics.sensitivity_prevalence_comparison

ORDER BY
    difference_from_primary_pp,
    outcome_variable;



-- ============================================================
-- 11. REVIEW EFFECT CONSISTENCY ACROSS OUTCOMES
-- ============================================================

SELECT

    term,

    COUNT(*) AS outcomes_compared,

    MIN(adjusted_odds_ratio)
        AS minimum_adjusted_or,

    MAX(adjusted_odds_ratio)
        AS maximum_adjusted_or,

    COUNT(*) FILTER (
        WHERE adjusted_odds_ratio > 1
    ) AS outcomes_with_higher_odds,

    COUNT(*) FILTER (
        WHERE adjusted_odds_ratio < 1
    ) AS outcomes_with_lower_odds,

    COUNT(*) FILTER (
        WHERE p_value < 0.05
    ) AS outcomes_significant

FROM analytics.sensitivity_adjusted_models

GROUP BY term

ORDER BY term;



-- ============================================================
-- 12. IDENTIFY TERMS WITH CONSISTENT EFFECT DIRECTION
-- ============================================================

SELECT

    term,

    CASE

        WHEN COUNT(*) FILTER (
            WHERE adjusted_odds_ratio > 1
        ) = COUNT(*)
            THEN 'Consistently higher odds'

        WHEN COUNT(*) FILTER (
            WHERE adjusted_odds_ratio < 1
        ) = COUNT(*)
            THEN 'Consistently lower odds'

        ELSE 'Direction varies across outcomes'

    END AS robustness_direction,

    COUNT(*) FILTER (
        WHERE p_value < 0.05
    ) AS significant_in_n_outcomes,

    COUNT(*) AS total_outcomes

FROM analytics.sensitivity_adjusted_models

GROUP BY term

ORDER BY term;



-- ============================================================
-- 13. FINAL PREVIEW
-- ============================================================

SELECT

    outcome_variable,
    outcome_definition,
    term,
    adjusted_odds_ratio,
    confidence_interval_low,
    confidence_interval_high,
    p_value,
    association_direction,
    statistically_significant,
    estimate_95ci

FROM analytics.sensitivity_adjusted_models

ORDER BY
    term,
    outcome_variable;