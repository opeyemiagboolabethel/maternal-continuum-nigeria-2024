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