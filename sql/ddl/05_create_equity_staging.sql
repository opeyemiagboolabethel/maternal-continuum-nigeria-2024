-- ============================================================
-- STAGING TABLE
-- Public Survey-Weighted Equity Estimates
-- Maternal Continuum of Care and Postnatal Equity in Nigeria
-- ============================================================


-- ------------------------------------------------------------
-- 1. CREATE STAGING TABLE
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS staging.weighted_equity_estimates_public (

    equity_variable TEXT,

    equity_dimension TEXT,

    equity_category TEXT,

    indicator_variable TEXT,

    indicator TEXT,

    unweighted_n BIGINT,

    unweighted_positive_n BIGINT,

    weighted_percent DOUBLE PRECISION,

    standard_error_percent DOUBLE PRECISION,

    confidence_interval_low_percent DOUBLE PRECISION,

    confidence_interval_high_percent DOUBLE PRECISION,

    reporting_status TEXT,

    estimate_95ci TEXT,

    public_weighted_percent DOUBLE PRECISION,

    public_ci_low DOUBLE PRECISION,

    public_ci_high DOUBLE PRECISION,

    public_estimate TEXT
);


-- ------------------------------------------------------------
-- 2. DOCUMENT TABLE
-- ------------------------------------------------------------

COMMENT ON TABLE staging.weighted_equity_estimates_public IS
'Staging table containing public-facing survey-weighted equity estimates exported from the validated R analytical pipeline. Includes disclosure-control reporting status and public reporting estimates.';


-- ------------------------------------------------------------
-- 3. VERIFY TABLE CREATION
-- ------------------------------------------------------------

SELECT
    table_schema,
    table_name
FROM information_schema.tables
WHERE table_schema = 'staging'
  AND table_name = 'weighted_equity_estimates_public';