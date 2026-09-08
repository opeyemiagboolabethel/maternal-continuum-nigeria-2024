-- ============================================================
-- STAGING TABLES
-- Adjusted and Unadjusted Odds Ratios
-- Maternal Continuum of Care and Postnatal Equity in Nigeria
-- ============================================================


-- ------------------------------------------------------------
-- 1. ADJUSTED ODDS RATIOS
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS staging.adjusted_odds_ratios (

    model TEXT,

    predictor TEXT,

    term TEXT,

    log_odds DOUBLE PRECISION,

    standard_error DOUBLE PRECISION,

    odds_ratio DOUBLE PRECISION,

    confidence_interval_low DOUBLE PRECISION,

    confidence_interval_high DOUBLE PRECISION,

    p_value DOUBLE PRECISION,

    statistical_significance TEXT,

    estimate_95ci TEXT
);


COMMENT ON TABLE staging.adjusted_odds_ratios IS
'Staging table containing adjusted survey-weighted logistic regression results exported from the validated R analytical pipeline.';


-- ------------------------------------------------------------
-- 2. UNADJUSTED ODDS RATIOS
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS staging.unadjusted_odds_ratios (

    model TEXT,

    predictor TEXT,

    term TEXT,

    log_odds DOUBLE PRECISION,

    standard_error DOUBLE PRECISION,

    odds_ratio DOUBLE PRECISION,

    confidence_interval_low DOUBLE PRECISION,

    confidence_interval_high DOUBLE PRECISION,

    p_value DOUBLE PRECISION,

    statistical_significance TEXT,

    estimate_95ci TEXT
);


COMMENT ON TABLE staging.unadjusted_odds_ratios IS
'Staging table containing unadjusted survey-weighted logistic regression results exported from the validated R analytical pipeline.';


-- ------------------------------------------------------------
-- 3. VERIFY BOTH TABLES
-- ------------------------------------------------------------

SELECT
    table_schema,
    table_name
FROM information_schema.tables
WHERE table_schema = 'staging'
  AND table_name IN (
      'adjusted_odds_ratios',
      'unadjusted_odds_ratios'
  )
ORDER BY table_name;

SELECT
    'adjusted' AS model_type,
    COUNT(*) AS current_rows
FROM staging.adjusted_odds_ratios

UNION ALL

SELECT
    'unadjusted',
    COUNT(*)
FROM staging.unadjusted_odds_ratios;

SELECT
    'adjusted' AS model_type,
    COUNT(*) AS rows_loaded
FROM staging.adjusted_odds_ratios

UNION ALL

SELECT
    'unadjusted',
    COUNT(*)
FROM staging.unadjusted_odds_ratios;

-- ============================================================
-- REGRESSION STAGING QA
-- ============================================================

WITH regression_results AS (

    SELECT
        'Adjusted' AS model_type,
        *
    FROM staging.adjusted_odds_ratios

    UNION ALL

    SELECT
        'Unadjusted' AS model_type,
        *
    FROM staging.unadjusted_odds_ratios
)

SELECT

    model_type,

    COUNT(*) AS total_rows,

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
           OR confidence_interval_low > confidence_interval_high
    ) AS invalid_confidence_intervals,

    COUNT(*) FILTER (
        WHERE p_value < 0
           OR p_value > 1
    ) AS invalid_p_values

FROM regression_results

GROUP BY model_type

ORDER BY model_type;

SELECT
    'Adjusted' AS model_type,
    statistical_significance,
    COUNT(*) AS terms
FROM staging.adjusted_odds_ratios
GROUP BY statistical_significance

UNION ALL

SELECT
    'Unadjusted',
    statistical_significance,
    COUNT(*)
FROM staging.unadjusted_odds_ratios
GROUP BY statistical_significance

ORDER BY
    model_type,
    statistical_significance;

INSERT INTO audit.data_load_log (
    source_file,
    target_schema,
    target_table,
    load_completed_at,
    rows_loaded,
    load_status
)
SELECT
    'adjusted_odds_ratios.csv',
    'staging',
    'adjusted_odds_ratios',
    CURRENT_TIMESTAMP,
    COUNT(*),
    'SUCCESS'
FROM staging.adjusted_odds_ratios
WHERE NOT EXISTS (
    SELECT 1
    FROM audit.data_load_log
    WHERE source_file = 'adjusted_odds_ratios.csv'
      AND target_schema = 'staging'
      AND target_table = 'adjusted_odds_ratios'
      AND load_status = 'SUCCESS'
);


INSERT INTO audit.data_load_log (
    source_file,
    target_schema,
    target_table,
    load_completed_at,
    rows_loaded,
    load_status
)
SELECT
    'unadjusted_odds_ratios.csv',
    'staging',
    'unadjusted_odds_ratios',
    CURRENT_TIMESTAMP,
    COUNT(*),
    'SUCCESS'
FROM staging.unadjusted_odds_ratios
WHERE NOT EXISTS (
    SELECT 1
    FROM audit.data_load_log
    WHERE source_file = 'unadjusted_odds_ratios.csv'
      AND target_schema = 'staging'
      AND target_table = 'unadjusted_odds_ratios'
      AND load_status = 'SUCCESS'
);

SELECT
    source_file,
    target_table,
    rows_loaded,
    load_status
FROM audit.data_load_log
WHERE source_file IN (
    'adjusted_odds_ratios.csv',
    'unadjusted_odds_ratios.csv'
)
ORDER BY source_file;