-- ============================================================
-- ANALYTICS TABLE
-- Public Equity Estimates
-- Maternal Continuum of Care and Postnatal Equity in Nigeria
-- ============================================================


-- ------------------------------------------------------------
-- 1. CREATE CURATED ANALYTICS TABLE
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS analytics.equity_estimates (

    equity_estimate_id BIGINT
        GENERATED ALWAYS AS IDENTITY
        PRIMARY KEY,

    equity_variable TEXT NOT NULL,

    equity_dimension TEXT NOT NULL,

    equity_category TEXT NOT NULL,

    indicator_variable TEXT NOT NULL,

    indicator TEXT NOT NULL,

    unweighted_n BIGINT NOT NULL,

    unweighted_positive_n BIGINT NOT NULL,

    weighted_percent DOUBLE PRECISION NOT NULL,

    standard_error_percent DOUBLE PRECISION NOT NULL,

    confidence_interval_low_percent DOUBLE PRECISION NOT NULL,

    confidence_interval_high_percent DOUBLE PRECISION NOT NULL,

    reporting_status TEXT NOT NULL,

    estimate_95ci TEXT NOT NULL,

    public_weighted_percent DOUBLE PRECISION NOT NULL,

    public_ci_low DOUBLE PRECISION NOT NULL,

    public_ci_high DOUBLE PRECISION NOT NULL,

    public_estimate TEXT NOT NULL,

    source_file TEXT NOT NULL
        DEFAULT 'weighted_equity_estimates_public.csv',

    created_at TIMESTAMPTZ NOT NULL
        DEFAULT CURRENT_TIMESTAMP,


    -- --------------------------------------------------------
    -- UNIQUENESS
    -- --------------------------------------------------------

    CONSTRAINT uq_equity_estimate
        UNIQUE (
            equity_variable,
            equity_dimension,
            equity_category,
            indicator_variable
        ),


    -- --------------------------------------------------------
    -- COUNT VALIDATION
    -- --------------------------------------------------------

    CONSTRAINT chk_equity_unweighted_n
        CHECK (
            unweighted_n >= 0
        ),

    CONSTRAINT chk_equity_positive_n
        CHECK (
            unweighted_positive_n >= 0
            AND unweighted_positive_n <= unweighted_n
        ),


    -- --------------------------------------------------------
    -- WEIGHTED ESTIMATE VALIDATION
    -- --------------------------------------------------------

    CONSTRAINT chk_equity_weighted_percent
        CHECK (
            weighted_percent >= 0
            AND weighted_percent <= 100
        ),

    CONSTRAINT chk_equity_standard_error
        CHECK (
            standard_error_percent >= 0
        ),

    CONSTRAINT chk_equity_ci_low
        CHECK (
            confidence_interval_low_percent >= 0
            AND confidence_interval_low_percent <= 100
        ),

    CONSTRAINT chk_equity_ci_high
        CHECK (
            confidence_interval_high_percent >= 0
            AND confidence_interval_high_percent <= 100
        ),

    CONSTRAINT chk_equity_ci_order
        CHECK (
            confidence_interval_low_percent
            <= confidence_interval_high_percent
        ),


    -- --------------------------------------------------------
    -- PUBLIC REPORTING ESTIMATE VALIDATION
    -- --------------------------------------------------------

    CONSTRAINT chk_equity_public_percent
        CHECK (
            public_weighted_percent >= 0
            AND public_weighted_percent <= 100
        ),

    CONSTRAINT chk_equity_public_ci_low
        CHECK (
            public_ci_low >= 0
            AND public_ci_low <= 100
        ),

    CONSTRAINT chk_equity_public_ci_high
        CHECK (
            public_ci_high >= 0
            AND public_ci_high <= 100
        ),

    CONSTRAINT chk_equity_public_ci_order
        CHECK (
            public_ci_low <= public_ci_high
        )
);


-- ------------------------------------------------------------
-- 2. DOCUMENT TABLE
-- ------------------------------------------------------------

COMMENT ON TABLE analytics.equity_estimates IS
'Curated survey-weighted equity estimates for maternal continuum-of-care indicators, including public reporting fields and disclosure-control status.';


-- ------------------------------------------------------------
-- 3. CLEAR TABLE BEFORE REBUILD
-- ------------------------------------------------------------

TRUNCATE TABLE
    analytics.equity_estimates
RESTART IDENTITY;


-- ------------------------------------------------------------
-- 4. LOAD VALIDATED STAGING DATA
-- ------------------------------------------------------------

INSERT INTO analytics.equity_estimates (

    equity_variable,
    equity_dimension,
    equity_category,
    indicator_variable,
    indicator,
    unweighted_n,
    unweighted_positive_n,
    weighted_percent,
    standard_error_percent,
    confidence_interval_low_percent,
    confidence_interval_high_percent,
    reporting_status,
    estimate_95ci,
    public_weighted_percent,
    public_ci_low,
    public_ci_high,
    public_estimate

)

SELECT

    equity_variable,
    equity_dimension,
    equity_category,
    indicator_variable,
    indicator,
    unweighted_n,
    unweighted_positive_n,
    weighted_percent,
    standard_error_percent,
    confidence_interval_low_percent,
    confidence_interval_high_percent,
    reporting_status,
    estimate_95ci,
    public_weighted_percent,
    public_ci_low,
    public_ci_high,
    public_estimate

FROM staging.weighted_equity_estimates_public

ORDER BY
    equity_dimension,
    equity_category,
    indicator_variable;


-- ------------------------------------------------------------
-- 5. RECONCILE STAGING AND ANALYTICS
-- ------------------------------------------------------------

SELECT

    (
        SELECT COUNT(*)
        FROM staging.weighted_equity_estimates_public
    ) AS staging_rows,

    (
        SELECT COUNT(*)
        FROM analytics.equity_estimates
    ) AS analytics_rows;


-- ------------------------------------------------------------
-- 6. QUALITY ASSURANCE
-- ------------------------------------------------------------

SELECT

    COUNT(*) AS total_rows,

    COUNT(DISTINCT equity_dimension)
        AS equity_dimensions,

    COUNT(DISTINCT indicator_variable)
        AS indicators,

    COUNT(*) FILTER (
        WHERE equity_variable IS NULL
           OR equity_dimension IS NULL
           OR equity_category IS NULL
           OR indicator_variable IS NULL
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
    ) AS invalid_confidence_intervals,

    COUNT(*) FILTER (
        WHERE public_weighted_percent < 0
           OR public_weighted_percent > 100
    ) AS invalid_public_percent,

    COUNT(*) FILTER (
        WHERE public_ci_low > public_ci_high
    ) AS invalid_public_confidence_intervals

FROM analytics.equity_estimates;


-- ------------------------------------------------------------
-- 7. REVIEW REPORTING STATUS
-- ------------------------------------------------------------

SELECT
    reporting_status,
    COUNT(*) AS rows
FROM analytics.equity_estimates
GROUP BY reporting_status
ORDER BY reporting_status;


-- ------------------------------------------------------------
-- 8. REVIEW FINAL CURATED DATA
-- ------------------------------------------------------------

SELECT
    equity_estimate_id,
    equity_dimension,
    equity_category,
    indicator_variable,
    indicator,
    public_weighted_percent,
    public_ci_low,
    public_ci_high,
    reporting_status,
    public_estimate
FROM analytics.equity_estimates
ORDER BY
    equity_dimension,
    equity_category,
    indicator_variable;