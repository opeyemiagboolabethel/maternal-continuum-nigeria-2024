-- ============================================================
-- PART 48
-- FINAL POWER BI HANDOFF LAYER
-- Maternal Continuum of Care in Nigeria
-- ============================================================


-- ============================================================
-- 1. REMOVE PREVIOUS VERSION
-- ============================================================

DROP VIEW IF EXISTS reporting.vw_powerbi_dataset_catalog;


-- ============================================================
-- 2. CREATE POWER BI DATASET CATALOG
-- ============================================================

CREATE VIEW reporting.vw_powerbi_dataset_catalog AS


-- ------------------------------------------------------------
-- NATIONAL MATERNAL HEALTH INDICATORS
-- ------------------------------------------------------------

SELECT

    1 AS dataset_order,

    'National Indicators'::TEXT
        AS dataset_name,

    'reporting.vw_national_indicator_estimates'::TEXT
        AS reporting_object,

    'One row per national maternal-health indicator'::TEXT
        AS dataset_grain,

    'National Overview'::TEXT
        AS recommended_dashboard_area,

    COUNT(*)::BIGINT
        AS current_rows

FROM reporting.vw_national_indicator_estimates


UNION ALL


-- ------------------------------------------------------------
-- EQUITY ESTIMATES
-- ------------------------------------------------------------

SELECT

    2,

    'Equity Estimates',

    'reporting.vw_equity_estimates',

    'One row per indicator and population subgroup',

    'Equity and Population Disparities',

    COUNT(*)::BIGINT

FROM reporting.vw_equity_estimates


UNION ALL


-- ------------------------------------------------------------
-- EQUITY GAP RANKINGS
-- ------------------------------------------------------------

SELECT

    3,

    'Equity Gap Rankings',

    'reporting.vw_equity_gap_rankings',

    'One row per indicator and equity comparison',

    'Equity Gap Analysis',

    COUNT(*)::BIGINT

FROM reporting.vw_equity_gap_rankings


UNION ALL


-- ------------------------------------------------------------
-- STATE GEOGRAPHIC PERFORMANCE
-- ------------------------------------------------------------

SELECT

    4,

    'State Indicator Rankings',

    'reporting.vw_state_indicator_rankings',

    'One row per state and maternal-health indicator',

    'Geographic and State Performance',

    COUNT(*)::BIGINT

FROM reporting.vw_state_indicator_rankings


UNION ALL


-- ------------------------------------------------------------
-- REGRESSION RESULTS
-- ------------------------------------------------------------

SELECT

    5,

    'Adjusted vs Unadjusted Regression',

    'reporting.vw_regression_comparison',

    'One row per regression term',

    'Determinants and Statistical Modelling',

    COUNT(*)::BIGINT

FROM reporting.vw_regression_comparison


UNION ALL


-- ------------------------------------------------------------
-- SENSITIVITY AND ROBUSTNESS
-- ------------------------------------------------------------

SELECT

    6,

    'Sensitivity and Robustness',

    'reporting.vw_sensitivity_robustness',

    'One row per regression term and sensitivity outcome',

    'Sensitivity and Robustness',

    COUNT(*)::BIGINT

FROM reporting.vw_sensitivity_robustness;



-- ============================================================
-- 3. DOCUMENT VIEW
-- ============================================================

COMMENT ON VIEW reporting.vw_powerbi_dataset_catalog IS
'Final Power BI handoff catalog identifying the approved reporting-layer datasets, analytical grain, dashboard purpose and current database row counts.';


-- ============================================================
-- 4. REVIEW FINAL POWER BI CATALOG
-- ============================================================

SELECT
    dataset_order,
    dataset_name,
    reporting_object,
    dataset_grain,
    recommended_dashboard_area,
    current_rows

FROM reporting.vw_powerbi_dataset_catalog

ORDER BY dataset_order;



-- ============================================================
-- 5. VERIFY ALL REQUIRED REPORTING VIEWS EXIST
-- ============================================================

SELECT

    required_view,

    CASE
        WHEN actual_view IS NOT NULL
            THEN 'PASS'
        ELSE 'FAIL'
    END AS availability_status

FROM (

    VALUES

        ('vw_national_indicator_estimates'),
        ('vw_equity_estimates'),
        ('vw_equity_gap_rankings'),
        ('vw_state_indicator_rankings'),
        ('vw_regression_comparison'),
        ('vw_sensitivity_robustness'),
        ('vw_powerbi_dataset_catalog')

) AS required(required_view)

LEFT JOIN (

    SELECT
        table_name AS actual_view

    FROM information_schema.views

    WHERE table_schema = 'reporting'

) AS available

ON required.required_view = available.actual_view

ORDER BY required_view;



-- ============================================================
-- 6. CHECK FOR EMPTY POWER BI DATASETS
-- ============================================================

SELECT

    dataset_name,
    reporting_object,
    current_rows,

    CASE

        WHEN current_rows > 0
            THEN 'PASS'

        ELSE 'FAIL - EMPTY DATASET'

    END AS dataset_status

FROM reporting.vw_powerbi_dataset_catalog

ORDER BY dataset_order;



-- ============================================================
-- 7. EXPECTED CORE REPORTING COUNTS
-- ============================================================

SELECT

    dataset_name,
    current_rows,

    CASE

        WHEN dataset_name = 'National Indicators'
             AND current_rows = 14
            THEN 'PASS'

        WHEN dataset_name = 'Equity Estimates'
             AND current_rows = 192
            THEN 'PASS'

        WHEN dataset_name = 'Equity Gap Rankings'
             AND current_rows = 40
            THEN 'PASS'

        WHEN dataset_name = 'State Indicator Rankings'
             AND current_rows = 296
            THEN 'PASS'

        WHEN dataset_name = 'Adjusted vs Unadjusted Regression'
             AND current_rows = 19
            THEN 'PASS'

        WHEN dataset_name = 'Sensitivity and Robustness'
             AND current_rows = 57
            THEN 'PASS'

        ELSE 'REVIEW'

    END AS expected_count_status

FROM reporting.vw_powerbi_dataset_catalog

ORDER BY dataset_order;



-- ============================================================
-- 8. FINAL POWER BI HANDOFF STATUS
-- ============================================================

WITH handoff_check AS (

    SELECT

        COUNT(*) AS datasets,

        COUNT(*) FILTER (
            WHERE current_rows > 0
        ) AS populated_datasets

    FROM reporting.vw_powerbi_dataset_catalog

)

SELECT

    datasets,

    populated_datasets,

    CASE

        WHEN datasets = 6
         AND populated_datasets = 6

            THEN
            'PASS - DATABASE READY FOR POWER BI'

        ELSE
            'REVIEW REQUIRED - POWER BI HANDOFF INCOMPLETE'

    END AS powerbi_handoff_status

FROM handoff_check;