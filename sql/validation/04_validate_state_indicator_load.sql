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

SELECT COUNT(*) AS current_rows
FROM staging.state_indicator_estimates_public;

SELECT COUNT(*) AS rows_loaded
FROM staging.state_indicator_estimates_public;

-- ============================================================
-- STATE INDICATOR STAGING QA
-- ============================================================

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
    ) AS missing_key_fields,

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

FROM staging.state_indicator_estimates_public;

SELECT
    zone,
    COUNT(DISTINCT state) AS states,
    COUNT(*) AS estimate_rows
FROM staging.state_indicator_estimates_public
GROUP BY zone
ORDER BY zone;

SELECT
    state,
    zone,
    COUNT(*) AS indicator_rows
FROM staging.state_indicator_estimates_public
GROUP BY state, zone
ORDER BY zone, state;

SELECT
    reporting_status,
    COUNT(*) AS rows
FROM staging.state_indicator_estimates_public
GROUP BY reporting_status
ORDER BY reporting_status;

INSERT INTO audit.data_load_log (
    source_file,
    target_schema,
    target_table,
    load_completed_at,
    rows_loaded,
    load_status
)
SELECT
    'state_indicator_estimates_public.csv',
    'staging',
    'state_indicator_estimates_public',
    CURRENT_TIMESTAMP,
    COUNT(*),
    'SUCCESS'
FROM staging.state_indicator_estimates_public
WHERE NOT EXISTS (
    SELECT 1
    FROM audit.data_load_log
    WHERE source_file = 'state_indicator_estimates_public.csv'
      AND target_schema = 'staging'
      AND target_table = 'state_indicator_estimates_public'
      AND load_status = 'SUCCESS'
)
RETURNING
    load_id,
    source_file,
    target_table,
    rows_loaded,
    load_status;