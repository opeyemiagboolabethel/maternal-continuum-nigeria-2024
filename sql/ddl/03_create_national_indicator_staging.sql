-- ============================================================
-- STAGING TABLE
-- Weighted National Indicator Estimates
-- ============================================================

CREATE TABLE IF NOT EXISTS staging.weighted_national_indicator_estimates (

    variable TEXT NOT NULL,

    indicator TEXT NOT NULL,

    unweighted_n BIGINT NOT NULL,

    unweighted_positive_n BIGINT NOT NULL,

    weighted_percent DOUBLE PRECISION NOT NULL,

    standard_error_percent DOUBLE PRECISION NOT NULL,

    confidence_interval_low_percent DOUBLE PRECISION NOT NULL,

    confidence_interval_high_percent DOUBLE PRECISION NOT NULL,

    estimate_95ci TEXT NOT NULL
);


COMMENT ON TABLE staging.weighted_national_indicator_estimates IS
'Staging table containing survey-weighted national maternal continuum-of-care indicator estimates exported from the validated R analytical pipeline.';


-- ============================================================
-- VERIFY TABLE CREATION
-- ============================================================

SELECT
    table_schema,
    table_name
FROM information_schema.tables
WHERE table_schema = 'staging'
  AND table_name = 'weighted_national_indicator_estimates';