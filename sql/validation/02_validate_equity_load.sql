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
SELECT COUNT(*) AS current_rows
FROM staging.weighted_equity_estimates_public;
SELECT COUNT(*) AS rows_loaded
FROM staging.weighted_equity_estimates_public;

-- ============================================================
-- VALIDATE EQUITY STAGING LOAD
-- ============================================================

SELECT
    COUNT(*) AS total_rows,

    COUNT(DISTINCT equity_dimension)
        AS equity_dimensions,

    COUNT(DISTINCT equity_category)
        AS equity_categories,

    COUNT(DISTINCT indicator_variable)
        AS indicators,

    COUNT(*) FILTER (
        WHERE equity_variable IS NULL
           OR equity_dimension IS NULL
           OR equity_category IS NULL
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

FROM staging.weighted_equity_estimates_public;

SELECT
    reporting_status,
    COUNT(*) AS rows
FROM staging.weighted_equity_estimates_public
GROUP BY reporting_status
ORDER BY reporting_status;

SELECT
    equity_dimension,
    COUNT(*) AS rows,
    COUNT(DISTINCT equity_category) AS categories,
    COUNT(DISTINCT indicator_variable) AS indicators
FROM staging.weighted_equity_estimates_public
GROUP BY equity_dimension
ORDER BY equity_dimension;

INSERT INTO audit.data_load_log (
    source_file,
    target_schema,
    target_table,
    load_completed_at,
    rows_loaded,
    load_status
)
SELECT
    'weighted_equity_estimates_public.csv',
    'staging',
    'weighted_equity_estimates_public',
    CURRENT_TIMESTAMP,
    COUNT(*),
    'SUCCESS'
FROM staging.weighted_equity_estimates_public
WHERE NOT EXISTS (
    SELECT 1
    FROM audit.data_load_log
    WHERE source_file = 'weighted_equity_estimates_public.csv'
      AND target_schema = 'staging'
      AND target_table = 'weighted_equity_estimates_public'
      AND load_status = 'SUCCESS'
)
RETURNING
    load_id,
    source_file,
    target_table,
    rows_loaded,
    load_status;