-- ============================================================
-- FINAL SQL QA AND FULL DATABASE RECONCILIATION
-- Maternal Continuum of Care in Nigeria
-- ============================================================


-- ============================================================
-- 1. CONFIRM CORE SCHEMAS
-- ============================================================

SELECT
    schema_name
FROM information_schema.schemata
WHERE schema_name IN (
    'staging',
    'analytics',
    'reporting',
    'audit'
)
ORDER BY schema_name;


-- Expected:
-- analytics
-- audit
-- reporting
-- staging



-- ============================================================
-- 2. INVENTORY OF PROJECT TABLES
-- ============================================================

SELECT
    table_schema,
    table_name
FROM information_schema.tables
WHERE table_schema IN (
    'staging',
    'analytics',
    'audit'
)
ORDER BY
    table_schema,
    table_name;



-- ============================================================
-- 3. INVENTORY OF REPORTING VIEWS
-- ============================================================

SELECT
    table_schema,
    table_name
FROM information_schema.views
WHERE table_schema = 'reporting'
ORDER BY table_name;



-- ============================================================
-- 4. STAGING LAYER ROW COUNTS
-- ============================================================

SELECT
    'weighted_national_indicator_estimates' AS object_name,
    COUNT(*) AS row_count
FROM staging.weighted_national_indicator_estimates

UNION ALL

SELECT
    'weighted_equity_estimates_public',
    COUNT(*)
FROM staging.weighted_equity_estimates_public

UNION ALL

SELECT
    'equity_gap_summary',
    COUNT(*)
FROM staging.equity_gap_summary

UNION ALL

SELECT
    'state_indicator_estimates_public',
    COUNT(*)
FROM staging.state_indicator_estimates_public

UNION ALL

SELECT
    'adjusted_odds_ratios',
    COUNT(*)
FROM staging.adjusted_odds_ratios

UNION ALL

SELECT
    'unadjusted_odds_ratios',
    COUNT(*)
FROM staging.unadjusted_odds_ratios

UNION ALL

SELECT
    'sensitivity_adjusted_models',
    COUNT(*)
FROM staging.sensitivity_adjusted_models

UNION ALL

SELECT
    'sensitivity_prevalence_comparison',
    COUNT(*)
FROM staging.sensitivity_prevalence_comparison

ORDER BY object_name;



-- ============================================================
-- 5. ANALYTICS LAYER ROW COUNTS
-- ============================================================

SELECT
    'national_indicator_estimates' AS object_name,
    COUNT(*) AS row_count
FROM analytics.national_indicator_estimates

UNION ALL

SELECT
    'equity_estimates',
    COUNT(*)
FROM analytics.equity_estimates

UNION ALL

SELECT
    'equity_gap_summary',
    COUNT(*)
FROM analytics.equity_gap_summary

UNION ALL

SELECT
    'state_indicator_estimates',
    COUNT(*)
FROM analytics.state_indicator_estimates

UNION ALL

SELECT
    'regression_results',
    COUNT(*)
FROM analytics.regression_results

UNION ALL

SELECT
    'sensitivity_adjusted_models',
    COUNT(*)
FROM analytics.sensitivity_adjusted_models

UNION ALL

SELECT
    'sensitivity_prevalence_comparison',
    COUNT(*)
FROM analytics.sensitivity_prevalence_comparison

ORDER BY object_name;



-- ============================================================
-- 6. REPORTING LAYER ROW COUNTS
-- ============================================================

SELECT
    'vw_national_indicator_estimates' AS object_name,
    COUNT(*) AS row_count
FROM reporting.vw_national_indicator_estimates

UNION ALL

SELECT
    'vw_equity_estimates',
    COUNT(*)
FROM reporting.vw_equity_estimates

UNION ALL

SELECT
    'vw_equity_gap_rankings',
    COUNT(*)
FROM reporting.vw_equity_gap_rankings

UNION ALL

SELECT
    'vw_state_indicator_rankings',
    COUNT(*)
FROM reporting.vw_state_indicator_rankings

UNION ALL

SELECT
    'vw_regression_comparison',
    COUNT(*)
FROM reporting.vw_regression_comparison

UNION ALL

SELECT
    'vw_sensitivity_robustness',
    COUNT(*)
FROM reporting.vw_sensitivity_robustness

ORDER BY object_name;



-- ============================================================
-- 7. CRITICAL EXPECTED ROW COUNTS
-- ============================================================

SELECT
    'National indicators' AS dataset,
    14 AS expected_rows,
    COUNT(*) AS actual_rows,
    CASE
        WHEN COUNT(*) = 14 THEN 'PASS'
        ELSE 'FAIL'
    END AS qa_status
FROM analytics.national_indicator_estimates

UNION ALL

SELECT
    'Equity estimates',
    192,
    COUNT(*),
    CASE
        WHEN COUNT(*) = 192 THEN 'PASS'
        ELSE 'FAIL'
    END
FROM analytics.equity_estimates

UNION ALL

SELECT
    'Equity gaps',
    40,
    COUNT(*),
    CASE
        WHEN COUNT(*) = 40 THEN 'PASS'
        ELSE 'FAIL'
    END
FROM analytics.equity_gap_summary

UNION ALL

SELECT
    'State estimates',
    296,
    COUNT(*),
    CASE
        WHEN COUNT(*) = 296 THEN 'PASS'
        ELSE 'FAIL'
    END
FROM analytics.state_indicator_estimates

UNION ALL

SELECT
    'Combined regression results',
    38,
    COUNT(*),
    CASE
        WHEN COUNT(*) = 38 THEN 'PASS'
        ELSE 'FAIL'
    END
FROM analytics.regression_results

UNION ALL

SELECT
    'Regression comparisons',
    19,
    COUNT(*),
    CASE
        WHEN COUNT(*) = 19 THEN 'PASS'
        ELSE 'FAIL'
    END
FROM reporting.vw_regression_comparison

UNION ALL

SELECT
    'Sensitivity models',
    57,
    COUNT(*),
    CASE
        WHEN COUNT(*) = 57 THEN 'PASS'
        ELSE 'FAIL'
    END
FROM analytics.sensitivity_adjusted_models

UNION ALL

SELECT
    'Sensitivity prevalence',
    3,
    COUNT(*),
    CASE
        WHEN COUNT(*) = 3 THEN 'PASS'
        ELSE 'FAIL'
    END
FROM analytics.sensitivity_prevalence_comparison

UNION ALL

SELECT
    'Sensitivity reporting',
    57,
    COUNT(*),
    CASE
        WHEN COUNT(*) = 57 THEN 'PASS'
        ELSE 'FAIL'
    END
FROM reporting.vw_sensitivity_robustness;



-- ============================================================
-- 8. STAGING VS ANALYTICS RECONCILIATION
-- ============================================================

SELECT
    'National indicators' AS dataset,

    (
        SELECT COUNT(*)
        FROM staging.weighted_national_indicator_estimates
    ) AS staging_rows,

    (
        SELECT COUNT(*)
        FROM analytics.national_indicator_estimates
    ) AS analytics_rows,

    CASE
        WHEN
            (
                SELECT COUNT(*)
                FROM staging.weighted_national_indicator_estimates
            )
            =
            (
                SELECT COUNT(*)
                FROM analytics.national_indicator_estimates
            )
        THEN 'PASS'
        ELSE 'FAIL'
    END AS reconciliation_status

UNION ALL

SELECT
    'Equity estimates',

    (
        SELECT COUNT(*)
        FROM staging.weighted_equity_estimates_public
    ),

    (
        SELECT COUNT(*)
        FROM analytics.equity_estimates
    ),

    CASE
        WHEN
            (
                SELECT COUNT(*)
                FROM staging.weighted_equity_estimates_public
            )
            =
            (
                SELECT COUNT(*)
                FROM analytics.equity_estimates
            )
        THEN 'PASS'
        ELSE 'FAIL'
    END

UNION ALL

SELECT
    'Equity gaps',

    (
        SELECT COUNT(*)
        FROM staging.equity_gap_summary
    ),

    (
        SELECT COUNT(*)
        FROM analytics.equity_gap_summary
    ),

    CASE
        WHEN
            (
                SELECT COUNT(*)
                FROM staging.equity_gap_summary
            )
            =
            (
                SELECT COUNT(*)
                FROM analytics.equity_gap_summary
            )
        THEN 'PASS'
        ELSE 'FAIL'
    END

UNION ALL

SELECT
    'State estimates',

    (
        SELECT COUNT(*)
        FROM staging.state_indicator_estimates_public
    ),

    (
        SELECT COUNT(*)
        FROM analytics.state_indicator_estimates
    ),

    CASE
        WHEN
            (
                SELECT COUNT(*)
                FROM staging.state_indicator_estimates_public
            )
            =
            (
                SELECT COUNT(*)
                FROM analytics.state_indicator_estimates
            )
        THEN 'PASS'
        ELSE 'FAIL'
    END

UNION ALL

SELECT
    'Sensitivity models',

    (
        SELECT COUNT(*)
        FROM staging.sensitivity_adjusted_models
    ),

    (
        SELECT COUNT(*)
        FROM analytics.sensitivity_adjusted_models
    ),

    CASE
        WHEN
            (
                SELECT COUNT(*)
                FROM staging.sensitivity_adjusted_models
            )
            =
            (
                SELECT COUNT(*)
                FROM analytics.sensitivity_adjusted_models
            )
        THEN 'PASS'
        ELSE 'FAIL'
    END

UNION ALL

SELECT
    'Sensitivity prevalence',

    (
        SELECT COUNT(*)
        FROM staging.sensitivity_prevalence_comparison
    ),

    (
        SELECT COUNT(*)
        FROM analytics.sensitivity_prevalence_comparison
    ),

    CASE
        WHEN
            (
                SELECT COUNT(*)
                FROM staging.sensitivity_prevalence_comparison
            )
            =
            (
                SELECT COUNT(*)
                FROM analytics.sensitivity_prevalence_comparison
            )
        THEN 'PASS'
        ELSE 'FAIL'
    END;



-- ============================================================
-- 9. REGRESSION RECONCILIATION
-- ============================================================

SELECT
    (
        SELECT COUNT(*)
        FROM staging.adjusted_odds_ratios
    ) AS adjusted_staging_rows,

    (
        SELECT COUNT(*)
        FROM staging.unadjusted_odds_ratios
    ) AS unadjusted_staging_rows,

    (
        SELECT COUNT(*)
        FROM analytics.regression_results
    ) AS combined_analytics_rows,

    (
        SELECT COUNT(*)
        FROM reporting.vw_regression_comparison
    ) AS comparison_rows,

    CASE
        WHEN
            (
                SELECT COUNT(*)
                FROM staging.adjusted_odds_ratios
            ) = 19

            AND

            (
                SELECT COUNT(*)
                FROM staging.unadjusted_odds_ratios
            ) = 19

            AND

            (
                SELECT COUNT(*)
                FROM analytics.regression_results
            ) = 38

            AND

            (
                SELECT COUNT(*)
                FROM reporting.vw_regression_comparison
            ) = 19

        THEN 'PASS'
        ELSE 'FAIL'
    END AS regression_reconciliation;



-- ============================================================
-- 10. CHECK REPORTING VIEW UNIQUENESS
-- ============================================================

SELECT
    'National indicator variables' AS check_name,

    COUNT(*) AS total_rows,

    COUNT(DISTINCT variable)
        AS distinct_keys,

    CASE
        WHEN COUNT(*) = COUNT(DISTINCT variable)
            THEN 'PASS'
        ELSE 'REVIEW'
    END AS qa_status

FROM reporting.vw_national_indicator_estimates

UNION ALL

SELECT
    'Regression terms',

    COUNT(*),

    COUNT(DISTINCT term),

    CASE
        WHEN COUNT(*) = COUNT(DISTINCT term)
            THEN 'PASS'
        ELSE 'REVIEW'
    END

FROM reporting.vw_regression_comparison;



-- ============================================================
-- 11. CHECK NULLS IN CRITICAL REPORTING FIELDS
-- ============================================================

SELECT
    'National reporting view' AS reporting_object,

    COUNT(*) FILTER (
        WHERE variable IS NULL
           OR weighted_percent IS NULL
    ) AS critical_nulls

FROM reporting.vw_national_indicator_estimates

UNION ALL

SELECT
    'State reporting view',

    COUNT(*) FILTER (
        WHERE state IS NULL
           OR indicator_variable IS NULL
           OR weighted_percent IS NULL
    )

FROM reporting.vw_state_indicator_rankings

UNION ALL

SELECT
    'Regression reporting view',

    COUNT(*) FILTER (
        WHERE term IS NULL
           OR adjusted_odds_ratio IS NULL
           OR unadjusted_odds_ratio IS NULL
    )

FROM reporting.vw_regression_comparison

UNION ALL

SELECT
    'Sensitivity reporting view',

    COUNT(*) FILTER (
        WHERE outcome_variable IS NULL
           OR term IS NULL
           OR adjusted_odds_ratio IS NULL
    )

FROM reporting.vw_sensitivity_robustness;


-- Expected critical_nulls = 0



-- ============================================================
-- 12. VERIFY AUDIT LOAD HISTORY
-- ============================================================

SELECT
    source_file,
    target_schema,
    target_table,
    rows_loaded,
    load_status,
    load_completed_at
FROM audit.data_load_log
ORDER BY
    load_completed_at,
    source_file;



-- ============================================================
-- 13. CHECK FOR FAILED LOADS
-- ============================================================

SELECT
    COUNT(*) AS failed_load_records
FROM audit.data_load_log
WHERE UPPER(load_status) <> 'SUCCESS';


-- Ideally:
-- failed_load_records = 0



-- ============================================================
-- 14. FINAL REPORTING OBJECT CHECK
-- ============================================================

SELECT
    table_name AS reporting_view
FROM information_schema.views
WHERE table_schema = 'reporting'
  AND table_name IN (
      'vw_national_indicator_estimates',
      'vw_equity_estimates',
      'vw_equity_gap_rankings',
      'vw_state_indicator_rankings',
      'vw_regression_comparison',
      'vw_sensitivity_robustness'
  )
ORDER BY table_name;


-- Expected:
-- 6 reporting views



-- ============================================================
-- 15. FINAL SQL PIPELINE STATUS
-- ============================================================

WITH qa AS (

    SELECT
        (
            SELECT COUNT(*)
            FROM analytics.national_indicator_estimates
        ) = 14 AS national_ok,

        (
            SELECT COUNT(*)
            FROM analytics.equity_estimates
        ) = 192 AS equity_ok,

        (
            SELECT COUNT(*)
            FROM analytics.equity_gap_summary
        ) = 40 AS equity_gap_ok,

        (
            SELECT COUNT(*)
            FROM analytics.state_indicator_estimates
        ) = 296 AS state_ok,

        (
            SELECT COUNT(*)
            FROM analytics.regression_results
        ) = 38 AS regression_ok,

        (
            SELECT COUNT(*)
            FROM reporting.vw_regression_comparison
        ) = 19 AS regression_comparison_ok,

        (
            SELECT COUNT(*)
            FROM analytics.sensitivity_adjusted_models
        ) = 57 AS sensitivity_models_ok,

        (
            SELECT COUNT(*)
            FROM analytics.sensitivity_prevalence_comparison
        ) = 3 AS sensitivity_prevalence_ok,

        (
            SELECT COUNT(*)
            FROM reporting.vw_sensitivity_robustness
        ) = 57 AS sensitivity_reporting_ok

)

SELECT

    CASE

        WHEN
            national_ok
            AND equity_ok
            AND equity_gap_ok
            AND state_ok
            AND regression_ok
            AND regression_comparison_ok
            AND sensitivity_models_ok
            AND sensitivity_prevalence_ok
            AND sensitivity_reporting_ok

        THEN
            'PASS - CORE SQL ANALYTICAL PIPELINE RECONCILED'

        ELSE
            'REVIEW REQUIRED - ONE OR MORE CORE SQL CHECKS FAILED'

    END AS final_sql_qa_status

FROM qa;