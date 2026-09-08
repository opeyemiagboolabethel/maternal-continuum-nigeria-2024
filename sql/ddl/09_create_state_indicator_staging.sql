-- ============================================================
-- STAGING TABLE
-- Public State-Level Indicator Estimates
-- Maternal Continuum of Care and Postnatal Equity in Nigeria
-- ============================================================


-- ------------------------------------------------------------
-- 1. CREATE STAGING TABLE
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS staging.state_indicator_estimates_public (

    state TEXT,

    zone TEXT,

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

COMMENT ON TABLE staging.state_indicator_estimates_public IS
'Staging table containing public survey-weighted maternal continuum-of-care indicator estimates for Nigerian states and geopolitical zones, exported from the validated R analytical pipeline.';


-- ------------------------------------------------------------
-- 3. VERIFY TABLE CREATION
-- ------------------------------------------------------------

SELECT
    table_schema,
    table_name
FROM information_schema.tables
WHERE table_schema = 'staging'
  AND table_name = 'state_indicator_estimates_public';