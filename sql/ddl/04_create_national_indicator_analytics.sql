-- ============================================================
-- ANALYTICS TABLE
-- National Indicator Estimates
-- Maternal Continuum of Care and Postnatal Equity in Nigeria
-- ============================================================


-- ------------------------------------------------------------
-- 1. CREATE CURATED ANALYTICS TABLE
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS analytics.national_indicator_estimates (

    indicator_id BIGINT
        GENERATED ALWAYS AS IDENTITY
        PRIMARY KEY,

    variable TEXT NOT NULL,

    indicator TEXT NOT NULL,

    unweighted_n BIGINT NOT NULL,

    unweighted_positive_n BIGINT NOT NULL,

    weighted_percent DOUBLE PRECISION NOT NULL,

    standard_error_percent DOUBLE PRECISION NOT NULL,

    confidence_interval_low_percent DOUBLE PRECISION NOT NULL,

    confidence_interval_high_percent DOUBLE PRECISION NOT NULL,

    estimate_95ci TEXT NOT NULL,

    source_file TEXT NOT NULL
        DEFAULT 'weighted_national_indicator_estimates.csv',

    created_at TIMESTAMPTZ NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_national_indicator_variable
        UNIQUE (variable),

    CONSTRAINT chk_national_unweighted_n
        CHECK (unweighted_n >= 0),

    CONSTRAINT chk_national_positive_n
        CHECK (
            unweighted_positive_n >= 0
            AND unweighted_positive_n <= unweighted_n
        ),

    CONSTRAINT chk_national_weighted_percent
        CHECK (
            weighted_percent >= 0
            AND weighted_percent <= 100
        ),

    CONSTRAINT chk_national_standard_error
        CHECK (
            standard_error_percent >= 0
        ),

    CONSTRAINT chk_national_ci_low
        CHECK (
            confidence_interval_low_percent >= 0
            AND confidence_interval_low_percent <= 100
        ),

    CONSTRAINT chk_national_ci_high
        CHECK (
            confidence_interval_high_percent >= 0
            AND confidence_interval_high_percent <= 100
        ),

    CONSTRAINT chk_national_ci_order
        CHECK (
            confidence_interval_low_percent
            <= confidence_interval_high_percent
        )
);


-- ------------------------------------------------------------
-- 2. DOCUMENT TABLE
-- ------------------------------------------------------------

COMMENT ON TABLE analytics.national_indicator_estimates IS
'Curated survey-weighted national maternal continuum-of-care indicator estimates derived from the validated R analytical pipeline.';


-- ------------------------------------------------------------
-- 3. CLEAR TABLE BEFORE REBUILD
-- ------------------------------------------------------------

TRUNCATE TABLE
    analytics.national_indicator_estimates
RESTART IDENTITY;


-- ------------------------------------------------------------
-- 4. LOAD VALIDATED STAGING DATA
-- ------------------------------------------------------------

INSERT INTO analytics.national_indicator_estimates (

    variable,
    indicator,
    unweighted_n,
    unweighted_positive_n,
    weighted_percent,
    standard_error_percent,
    confidence_interval_low_percent,
    confidence_interval_high_percent,
    estimate_95ci

)

SELECT

    variable,
    indicator,
    unweighted_n,
    unweighted_positive_n,
    weighted_percent,
    standard_error_percent,
    confidence_interval_low_percent,
    confidence_interval_high_percent,
    estimate_95ci

FROM staging.weighted_national_indicator_estimates

ORDER BY variable;


-- ------------------------------------------------------------
-- 5. VERIFY ROW RECONCILIATION
-- ------------------------------------------------------------

SELECT

    (SELECT COUNT(*)
     FROM staging.weighted_national_indicator_estimates)
        AS staging_rows,

    (SELECT COUNT(*)
     FROM analytics.national_indicator_estimates)
        AS analytics_rows;


-- ------------------------------------------------------------
-- 6. VALIDATE CURATED TABLE
-- ------------------------------------------------------------

SELECT

    COUNT(*) AS total_rows,

    COUNT(DISTINCT variable)
        AS distinct_variables,

    COUNT(*) FILTER (
        WHERE weighted_percent < 0
           OR weighted_percent > 100
    ) AS invalid_percentages,

    COUNT(*) FILTER (
        WHERE confidence_interval_low_percent >
              confidence_interval_high_percent
    ) AS invalid_confidence_intervals,

    COUNT(*) FILTER (
        WHERE unweighted_positive_n >
              unweighted_n
    ) AS invalid_counts

FROM analytics.national_indicator_estimates;


-- ------------------------------------------------------------
-- 7. REVIEW FINAL ANALYTICS TABLE
-- ------------------------------------------------------------

SELECT
    indicator_id,
    variable,
    indicator,
    unweighted_n,
    unweighted_positive_n,
    weighted_percent,
    standard_error_percent,
    confidence_interval_low_percent,
    confidence_interval_high_percent,
    estimate_95ci,
    source_file,
    created_at
FROM analytics.national_indicator_estimates
ORDER BY indicator_id;