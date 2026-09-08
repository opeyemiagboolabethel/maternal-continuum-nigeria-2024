-- ============================================================
-- ANALYTICS TABLE
-- State-Level Indicator Estimates
-- Maternal Continuum of Care and Postnatal Equity in Nigeria
-- ============================================================


-- ------------------------------------------------------------
-- 1. REMOVE ANY PREVIOUS/PARTIAL VERSION
-- ------------------------------------------------------------

DROP TABLE IF EXISTS analytics.state_indicator_estimates CASCADE;


-- ------------------------------------------------------------
-- 2. CREATE CURATED ANALYTICS TABLE
-- ------------------------------------------------------------

CREATE TABLE analytics.state_indicator_estimates (

    state_estimate_id BIGINT
        GENERATED ALWAYS AS IDENTITY
        PRIMARY KEY,

    state TEXT NOT NULL,

    zone TEXT NOT NULL,

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
        DEFAULT 'state_indicator_estimates_public.csv',

    created_at TIMESTAMPTZ NOT NULL
        DEFAULT CURRENT_TIMESTAMP,


    -- --------------------------------------------------------
    -- UNIQUENESS
    -- --------------------------------------------------------

    CONSTRAINT uq_state_indicator
        UNIQUE (
            state,
            indicator_variable
        ),


    -- --------------------------------------------------------
    -- COUNT VALIDATION
    -- --------------------------------------------------------

    CONSTRAINT chk_state_unweighted_n
        CHECK (
            unweighted_n >= 0
        ),

    CONSTRAINT chk_state_positive_n
        CHECK (
            unweighted_positive_n >= 0
            AND unweighted_positive_n <= unweighted_n
        ),


    -- --------------------------------------------------------
    -- POINT ESTIMATE VALIDATION
    -- --------------------------------------------------------

    CONSTRAINT chk_state_weighted_percent
        CHECK (
            weighted_percent >= 0
            AND weighted_percent <= 100
        ),

    CONSTRAINT chk_state_standard_error
        CHECK (
            standard_error_percent >= 0
        ),


    -- --------------------------------------------------------
    -- CONFIDENCE INTERVAL VALIDATION
    --
    -- Important:
    -- Survey-derived confidence intervals may legitimately
    -- extend slightly below 0 or above 100.
    -- We therefore validate ORDER only.
    -- --------------------------------------------------------

    CONSTRAINT chk_state_ci
        CHECK (
            confidence_interval_low_percent
            <= confidence_interval_high_percent
        ),


    -- --------------------------------------------------------
    -- PUBLIC ESTIMATE VALIDATION
    -- --------------------------------------------------------

    CONSTRAINT chk_state_public_percent
        CHECK (
            public_weighted_percent >= 0
            AND public_weighted_percent <= 100
        ),

    CONSTRAINT chk_state_public_ci
        CHECK (
            public_ci_low <= public_ci_high
        )
);


-- ------------------------------------------------------------
-- 3. DOCUMENT TABLE
-- ------------------------------------------------------------

COMMENT ON TABLE analytics.state_indicator_estimates IS
'Curated public state-level survey-weighted maternal continuum-of-care estimates for Nigerian states and geopolitical zones. Confidence intervals preserve the original survey-derived values from the validated R analytical pipeline.';


-- ------------------------------------------------------------
-- 4. LOAD VALIDATED STAGING DATA
-- ------------------------------------------------------------

INSERT INTO analytics.state_indicator_estimates (

    state,
    zone,
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

    state,
    zone,
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

FROM staging.state_indicator_estimates_public

ORDER BY
    state,
    indicator_variable;


-- ------------------------------------------------------------
-- 5. RECONCILE STAGING AND ANALYTICS
-- ------------------------------------------------------------

SELECT

    (
        SELECT COUNT(*)
        FROM staging.state_indicator_estimates_public
    ) AS staging_rows,

    (
        SELECT COUNT(*)
        FROM analytics.state_indicator_estimates
    ) AS analytics_rows;


-- ------------------------------------------------------------
-- 6. ANALYTICS QUALITY ASSURANCE
-- ------------------------------------------------------------

SELECT

    COUNT(*) AS total_rows,

    COUNT(DISTINCT state)
        AS states,

    COUNT(DISTINCT zone)
        AS zones,

    COUNT(DISTINCT indicator_variable)
        AS indicators,

    COUNT(*) FILTER (
        WHERE state IS NULL
           OR zone IS NULL
           OR indicator_variable IS NULL
           OR indicator IS NULL
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
    ) AS invalid_internal_ci,

    COUNT(*) FILTER (
        WHERE public_weighted_percent < 0
           OR public_weighted_percent > 100
    ) AS invalid_public_percent,

    COUNT(*) FILTER (
        WHERE public_ci_low >
              public_ci_high
    ) AS invalid_public_ci

FROM analytics.state_indicator_estimates;


-- ------------------------------------------------------------
-- 7. CONFIRM STATE AND ZONE COVERAGE
-- ------------------------------------------------------------

SELECT

    zone,

    COUNT(DISTINCT state)
        AS states,

    COUNT(*)
        AS estimate_rows

FROM analytics.state_indicator_estimates

GROUP BY zone

ORDER BY zone;


-- ------------------------------------------------------------
-- 8. CHECK INDICATOR COVERAGE BY STATE
-- ------------------------------------------------------------

SELECT

    state,
    zone,

    COUNT(*)
        AS indicators_available

FROM analytics.state_indicator_estimates

GROUP BY
    state,
    zone

ORDER BY
    zone,
    state;


-- ------------------------------------------------------------
-- 9. REVIEW REPORTING STATUS
-- ------------------------------------------------------------

SELECT

    reporting_status,

    COUNT(*)
        AS rows

FROM analytics.state_indicator_estimates

GROUP BY reporting_status

ORDER BY reporting_status;


-- ------------------------------------------------------------
-- 10. PREVIEW STATE PERFORMANCE RANKINGS
-- ------------------------------------------------------------

SELECT

    indicator_variable,
    indicator,

    state,
    zone,

    public_weighted_percent,

    DENSE_RANK() OVER (
        PARTITION BY indicator_variable
        ORDER BY public_weighted_percent DESC
    ) AS state_rank,

    DENSE_RANK() OVER (
        PARTITION BY indicator_variable
        ORDER BY public_weighted_percent ASC
    ) AS state_low_rank

FROM analytics.state_indicator_estimates

ORDER BY
    indicator_variable,
    state_rank,
    state;


-- ------------------------------------------------------------
-- 11. FINAL TABLE PREVIEW
-- ------------------------------------------------------------

SELECT
    state_estimate_id,
    state,
    zone,
    indicator_variable,
    indicator,
    unweighted_n,
    unweighted_positive_n,
    weighted_percent,
    standard_error_percent,
    confidence_interval_low_percent,
    confidence_interval_high_percent,
    reporting_status,
    public_weighted_percent,
    public_ci_low,
    public_ci_high,
    public_estimate
FROM analytics.state_indicator_estimates
ORDER BY
    state,
    indicator_variable;