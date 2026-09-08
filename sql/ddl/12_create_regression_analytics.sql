-- ============================================================
-- ANALYTICS TABLE
-- Combined Adjusted and Unadjusted Regression Results
-- Maternal Continuum of Care and Postnatal Equity in Nigeria
-- ============================================================


-- ------------------------------------------------------------
-- 1. REMOVE ANY PREVIOUS VERSION
-- ------------------------------------------------------------

DROP TABLE IF EXISTS analytics.regression_results CASCADE;


-- ------------------------------------------------------------
-- 2. CREATE CURATED REGRESSION TABLE
-- ------------------------------------------------------------

CREATE TABLE analytics.regression_results (

    regression_result_id BIGINT
        GENERATED ALWAYS AS IDENTITY
        PRIMARY KEY,

    model_type TEXT NOT NULL,

    model TEXT NOT NULL,

    predictor TEXT NOT NULL,

    term TEXT NOT NULL,

    log_odds DOUBLE PRECISION NOT NULL,

    standard_error DOUBLE PRECISION NOT NULL,

    odds_ratio DOUBLE PRECISION NOT NULL,

    confidence_interval_low DOUBLE PRECISION NOT NULL,

    confidence_interval_high DOUBLE PRECISION NOT NULL,

    p_value DOUBLE PRECISION NOT NULL,

    statistical_significance TEXT NOT NULL,

    estimate_95ci TEXT NOT NULL,

    source_file TEXT NOT NULL,

    created_at TIMESTAMPTZ NOT NULL
        DEFAULT CURRENT_TIMESTAMP,


    -- --------------------------------------------------------
    -- UNIQUENESS
    -- --------------------------------------------------------

    CONSTRAINT uq_regression_result
        UNIQUE (
            model_type,
            predictor,
            term
        ),


    -- --------------------------------------------------------
    -- MODEL TYPE
    -- --------------------------------------------------------

    CONSTRAINT chk_regression_model_type
        CHECK (
            model_type IN (
                'Adjusted',
                'Unadjusted'
            )
        ),


    -- --------------------------------------------------------
    -- NUMERIC VALIDATION
    -- --------------------------------------------------------

    CONSTRAINT chk_regression_standard_error
        CHECK (
            standard_error >= 0
        ),

    CONSTRAINT chk_regression_odds_ratio
        CHECK (
            odds_ratio > 0
        ),

    CONSTRAINT chk_regression_ci
        CHECK (
            confidence_interval_low > 0
            AND confidence_interval_high > 0
            AND confidence_interval_low
                <= confidence_interval_high
        ),

    CONSTRAINT chk_regression_p_value
        CHECK (
            p_value >= 0
            AND p_value <= 1
        )
);


-- ------------------------------------------------------------
-- 3. DOCUMENT TABLE
-- ------------------------------------------------------------

COMMENT ON TABLE analytics.regression_results IS
'Curated combined survey-weighted logistic regression results containing adjusted and unadjusted odds ratios for determinants of the primary maternal continuum-of-care outcome.';


-- ------------------------------------------------------------
-- 4. LOAD UNADJUSTED RESULTS
-- ------------------------------------------------------------

INSERT INTO analytics.regression_results (

    model_type,
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
    estimate_95ci,
    source_file

)

SELECT

    'Unadjusted',
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
    estimate_95ci,
    'unadjusted_odds_ratios.csv'

FROM staging.unadjusted_odds_ratios;


-- ------------------------------------------------------------
-- 5. LOAD ADJUSTED RESULTS
-- ------------------------------------------------------------

INSERT INTO analytics.regression_results (

    model_type,
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
    estimate_95ci,
    source_file

)

SELECT

    'Adjusted',
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
    estimate_95ci,
    'adjusted_odds_ratios.csv'

FROM staging.adjusted_odds_ratios;


-- ------------------------------------------------------------
-- 6. RECONCILE SOURCE AND ANALYTICS COUNTS
-- ------------------------------------------------------------

SELECT

    (
        SELECT COUNT(*)
        FROM staging.unadjusted_odds_ratios
    ) AS unadjusted_staging_rows,

    (
        SELECT COUNT(*)
        FROM staging.adjusted_odds_ratios
    ) AS adjusted_staging_rows,

    (
        SELECT COUNT(*)
        FROM analytics.regression_results
    ) AS analytics_rows;

-- ============================================================
-- 7. ANALYTICS QA
-- ============================================================

SELECT

    model_type,

    COUNT(*) AS total_rows,

    COUNT(DISTINCT predictor)
        AS predictors,

    COUNT(*) FILTER (
        WHERE model IS NULL
           OR predictor IS NULL
           OR term IS NULL
    ) AS missing_keys,

    COUNT(*) FILTER (
        WHERE odds_ratio <= 0
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

FROM analytics.regression_results

GROUP BY model_type

ORDER BY model_type;

SELECT

    u.predictor,
    u.term,

    u.odds_ratio
        AS unadjusted_or,

    a.odds_ratio
        AS adjusted_or,

    ROUND(
        (a.odds_ratio - u.odds_ratio)::numeric,
        3
    ) AS absolute_or_change,

    ROUND(
        (
            (
                a.odds_ratio - u.odds_ratio
            )
            / NULLIF(u.odds_ratio, 0)
            * 100
        )::numeric,
        2
    ) AS percent_or_change,

    u.p_value
        AS unadjusted_p_value,

    a.p_value
        AS adjusted_p_value,

    u.statistical_significance
        AS unadjusted_significance,

    a.statistical_significance
        AS adjusted_significance

FROM analytics.regression_results AS u

INNER JOIN analytics.regression_results AS a

    ON u.predictor = a.predictor
   AND u.term = a.term

WHERE u.model_type = 'Unadjusted'
  AND a.model_type = 'Adjusted'

ORDER BY
    u.predictor,
    u.term;