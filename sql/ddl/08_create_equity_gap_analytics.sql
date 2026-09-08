-- ============================================================
-- ANALYTICS TABLE
-- Equity Gap Summary
-- Maternal Continuum of Care and Postnatal Equity in Nigeria
-- ============================================================


-- ------------------------------------------------------------
-- 1. CREATE CURATED ANALYTICS TABLE
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS analytics.equity_gap_summary (

    equity_gap_id BIGINT
        GENERATED ALWAYS AS IDENTITY
        PRIMARY KEY,

    equity_variable TEXT NOT NULL,

    equity_dimension TEXT NOT NULL,

    indicator_variable TEXT NOT NULL,

    indicator TEXT NOT NULL,

    highest_group TEXT NOT NULL,

    highest_percent DOUBLE PRECISION NOT NULL,

    highest_ci_low DOUBLE PRECISION NOT NULL,

    highest_ci_high DOUBLE PRECISION NOT NULL,

    highest_group_n DOUBLE PRECISION NOT NULL,

    highest_reporting_status TEXT NOT NULL,

    lowest_group TEXT NOT NULL,

    lowest_percent DOUBLE PRECISION NOT NULL,

    lowest_ci_low DOUBLE PRECISION NOT NULL,

    lowest_ci_high DOUBLE PRECISION NOT NULL,

    lowest_group_n DOUBLE PRECISION NOT NULL,

    lowest_reporting_status TEXT NOT NULL,

    groups_compared DOUBLE PRECISION NOT NULL,

    caution_groups DOUBLE PRECISION NOT NULL,

    absolute_gap_pp DOUBLE PRECISION NOT NULL,

    relative_ratio DOUBLE PRECISION NOT NULL,

    relative_shortfall_percent DOUBLE PRECISION NOT NULL,

    comparison_status TEXT NOT NULL,

    source_file TEXT NOT NULL
        DEFAULT 'equity_gap_summary.csv',

    created_at TIMESTAMPTZ NOT NULL
        DEFAULT CURRENT_TIMESTAMP,


    -- --------------------------------------------------------
    -- UNIQUENESS
    -- --------------------------------------------------------

    CONSTRAINT uq_equity_gap
        UNIQUE (
            equity_variable,
            equity_dimension,
            indicator_variable
        ),


    -- --------------------------------------------------------
    -- VALIDATION CONSTRAINTS
    -- --------------------------------------------------------

    CONSTRAINT chk_gap_highest_percent
        CHECK (
            highest_percent >= 0
            AND highest_percent <= 100
        ),

    CONSTRAINT chk_gap_lowest_percent
        CHECK (
            lowest_percent >= 0
            AND lowest_percent <= 100
        ),

    CONSTRAINT chk_gap_highest_ci
        CHECK (
            highest_ci_low >= 0
            AND highest_ci_high <= 100
            AND highest_ci_low <= highest_ci_high
        ),

    CONSTRAINT chk_gap_lowest_ci
        CHECK (
            lowest_ci_low >= 0
            AND lowest_ci_high <= 100
            AND lowest_ci_low <= lowest_ci_high
        ),

    CONSTRAINT chk_gap_absolute_gap
        CHECK (
            absolute_gap_pp >= 0
        ),

    CONSTRAINT chk_gap_relative_ratio
        CHECK (
            relative_ratio >= 0
        ),

    CONSTRAINT chk_gap_groups_compared
        CHECK (
            groups_compared >= 0
        ),

    CONSTRAINT chk_gap_caution_groups
        CHECK (
            caution_groups >= 0
        )
);


-- ------------------------------------------------------------
-- 2. DOCUMENT TABLE
-- ------------------------------------------------------------

COMMENT ON TABLE analytics.equity_gap_summary IS
'Curated equity disparity table containing highest and lowest performing groups and absolute and relative inequality measures derived from the validated R analytical pipeline.';


-- ------------------------------------------------------------
-- 3. CLEAR BEFORE REBUILD
-- ------------------------------------------------------------

TRUNCATE TABLE
    analytics.equity_gap_summary
RESTART IDENTITY;


-- ------------------------------------------------------------
-- 4. LOAD FROM VALIDATED STAGING TABLE
-- ------------------------------------------------------------

INSERT INTO analytics.equity_gap_summary (

    equity_variable,
    equity_dimension,
    indicator_variable,
    indicator,
    highest_group,
    highest_percent,
    highest_ci_low,
    highest_ci_high,
    highest_group_n,
    highest_reporting_status,
    lowest_group,
    lowest_percent,
    lowest_ci_low,
    lowest_ci_high,
    lowest_group_n,
    lowest_reporting_status,
    groups_compared,
    caution_groups,
    absolute_gap_pp,
    relative_ratio,
    relative_shortfall_percent,
    comparison_status

)

SELECT

    equity_variable,
    equity_dimension,
    indicator_variable,
    indicator,
    highest_group,
    highest_percent,
    highest_ci_low,
    highest_ci_high,
    highest_group_n,
    highest_reporting_status,
    lowest_group,
    lowest_percent,
    lowest_ci_low,
    lowest_ci_high,
    lowest_group_n,
    lowest_reporting_status,
    groups_compared,
    caution_groups,
    absolute_gap_pp,
    relative_ratio,
    relative_shortfall_percent,
    comparison_status

FROM staging.equity_gap_summary

ORDER BY
    equity_dimension,
    indicator_variable;


-- ------------------------------------------------------------
-- 5. RECONCILE STAGING VS ANALYTICS
-- ------------------------------------------------------------

SELECT

    (
        SELECT COUNT(*)
        FROM staging.equity_gap_summary
    ) AS staging_rows,

    (
        SELECT COUNT(*)
        FROM analytics.equity_gap_summary
    ) AS analytics_rows;

-- ============================================================
-- 6. ANALYTICS QA
-- ============================================================

SELECT

    COUNT(*) AS total_rows,

    COUNT(DISTINCT equity_dimension)
        AS equity_dimensions,

    COUNT(DISTINCT indicator_variable)
        AS indicators,

    COUNT(*) FILTER (
        WHERE absolute_gap_pp < 0
    ) AS invalid_absolute_gaps,

    COUNT(*) FILTER (
        WHERE relative_ratio < 0
    ) AS invalid_relative_ratios,

    COUNT(*) FILTER (
        WHERE highest_percent < lowest_percent
    ) AS reversed_high_low,

    COUNT(*) FILTER (
        WHERE highest_ci_low > highest_ci_high
           OR lowest_ci_low > lowest_ci_high
    ) AS invalid_confidence_intervals

FROM analytics.equity_gap_summary;

SELECT

    equity_dimension,
    indicator_variable,
    indicator,
    highest_group,
    lowest_group,
    ROUND(absolute_gap_pp::numeric, 2) AS absolute_gap_pp,

    DENSE_RANK() OVER (
        ORDER BY absolute_gap_pp DESC
    ) AS national_gap_rank,

    DENSE_RANK() OVER (
        PARTITION BY equity_dimension
        ORDER BY absolute_gap_pp DESC
    ) AS dimension_gap_rank

FROM analytics.equity_gap_summary

ORDER BY
    national_gap_rank,
    equity_dimension;