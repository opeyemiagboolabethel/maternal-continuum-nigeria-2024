-- ============================================================
-- SQL DOCUMENTATION, OBJECT INVENTORY
-- AND FINAL REPOSITORY VALIDATION
-- Maternal Continuum of Care in Nigeria
-- ============================================================


-- ============================================================
-- 1. DATABASE OBJECT INVENTORY
-- ============================================================

SELECT
    table_schema AS schema_name,
    table_name AS object_name,
    table_type AS object_type
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
-- 2. REPORTING VIEW INVENTORY
-- ============================================================

SELECT
    table_schema AS schema_name,
    table_name AS view_name
FROM information_schema.views
WHERE table_schema = 'reporting'
ORDER BY table_name;


-- ============================================================
-- 3. VERIFY ALL CORE STAGING TABLES
-- ============================================================

WITH required_objects(object_name) AS (

    VALUES
        ('weighted_national_indicator_estimates'),
        ('weighted_equity_estimates_public'),
        ('equity_gap_summary'),
        ('state_indicator_estimates_public'),
        ('adjusted_odds_ratios'),
        ('unadjusted_odds_ratios'),
        ('sensitivity_adjusted_models'),
        ('sensitivity_prevalence_comparison')

),

available_objects AS (

    SELECT table_name
    FROM information_schema.tables
    WHERE table_schema = 'staging'

)

SELECT
    r.object_name,
    CASE
        WHEN a.table_name IS NOT NULL
            THEN 'PASS'
        ELSE 'FAIL'
    END AS staging_status

FROM required_objects AS r

LEFT JOIN available_objects AS a
    ON r.object_name = a.table_name

ORDER BY r.object_name;


-- ============================================================
-- 4. VERIFY ALL CORE ANALYTICS TABLES
-- ============================================================

WITH required_objects(object_name) AS (

    VALUES
        ('national_indicator_estimates'),
        ('equity_estimates'),
        ('equity_gap_summary'),
        ('state_indicator_estimates'),
        ('regression_results'),
        ('sensitivity_adjusted_models'),
        ('sensitivity_prevalence_comparison')

),

available_objects AS (

    SELECT table_name
    FROM information_schema.tables
    WHERE table_schema = 'analytics'

)

SELECT
    r.object_name,
    CASE
        WHEN a.table_name IS NOT NULL
            THEN 'PASS'
        ELSE 'FAIL'
    END AS analytics_status

FROM required_objects AS r

LEFT JOIN available_objects AS a
    ON r.object_name = a.table_name

ORDER BY r.object_name;


-- ============================================================
-- 5. VERIFY ALL REPORTING VIEWS
-- ============================================================

WITH required_views(view_name) AS (

    VALUES
        ('vw_national_indicator_estimates'),
        ('vw_equity_estimates'),
        ('vw_equity_gap_rankings'),
        ('vw_state_indicator_rankings'),
        ('vw_regression_comparison'),
        ('vw_sensitivity_robustness'),
        ('vw_powerbi_dataset_catalog')

),

available_views AS (

    SELECT table_name
    FROM information_schema.views
    WHERE table_schema = 'reporting'

)

SELECT
    r.view_name,
    CASE
        WHEN a.table_name IS NOT NULL
            THEN 'PASS'
        ELSE 'FAIL'
    END AS reporting_status

FROM required_views AS r

LEFT JOIN available_views AS a
    ON r.view_name = a.table_name

ORDER BY r.view_name;


-- ============================================================
-- 6. VERIFY AUDIT TABLE
-- ============================================================

SELECT

    CASE

        WHEN EXISTS (

            SELECT 1
            FROM information_schema.tables
            WHERE table_schema = 'audit'
              AND table_name = 'data_load_log'

        )

        THEN 'PASS'

        ELSE 'FAIL'

    END AS audit_table_status;


-- ============================================================
-- 7. REVIEW DATABASE COMMENTS / DOCUMENTATION
-- ============================================================

SELECT

    n.nspname AS schema_name,

    c.relname AS object_name,

    CASE c.relkind

        WHEN 'r' THEN 'TABLE'
        WHEN 'v' THEN 'VIEW'
        WHEN 'm' THEN 'MATERIALIZED VIEW'
        ELSE c.relkind::TEXT

    END AS object_type,

    obj_description(
        c.oid,
        'pg_class'
    ) AS object_description

FROM pg_class AS c

INNER JOIN pg_namespace AS n
    ON n.oid = c.relnamespace

WHERE n.nspname IN (
    'staging',
    'analytics',
    'reporting',
    'audit'
)

AND c.relkind IN (
    'r',
    'v',
    'm'
)

ORDER BY
    n.nspname,
    c.relname;


-- ============================================================
-- 8. IDENTIFY UNDOCUMENTED CORE OBJECTS
-- ============================================================

SELECT

    n.nspname AS schema_name,

    c.relname AS object_name,

    CASE c.relkind
        WHEN 'r' THEN 'TABLE'
        WHEN 'v' THEN 'VIEW'
        ELSE c.relkind::TEXT
    END AS object_type

FROM pg_class AS c

INNER JOIN pg_namespace AS n
    ON n.oid = c.relnamespace

WHERE n.nspname IN (
    'staging',
    'analytics',
    'reporting',
    'audit'
)

AND c.relkind IN (
    'r',
    'v'
)

AND obj_description(
        c.oid,
        'pg_class'
    ) IS NULL

ORDER BY
    n.nspname,
    c.relname;


-- This does not necessarily mean failure.
-- It simply identifies objects that do not yet have COMMENT ON
-- documentation attached.


-- ============================================================
-- 9. FINAL DATASET CATALOG REVIEW
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
-- 10. VERIFY AUDITED SUCCESSFUL LOADS
-- ============================================================

SELECT

    source_file,

    MAX(rows_loaded)
        AS rows_loaded,

    MAX(load_status)
        AS load_status

FROM audit.data_load_log

GROUP BY source_file

ORDER BY source_file;


-- ============================================================
-- 11. FINAL DATABASE ARCHITECTURE SUMMARY
-- ============================================================

SELECT

    (
        SELECT COUNT(*)
        FROM information_schema.tables
        WHERE table_schema = 'staging'
    ) AS staging_tables,

    (
        SELECT COUNT(*)
        FROM information_schema.tables
        WHERE table_schema = 'analytics'
    ) AS analytics_tables,

    (
        SELECT COUNT(*)
        FROM information_schema.views
        WHERE table_schema = 'reporting'
    ) AS reporting_views,

    (
        SELECT COUNT(*)
        FROM information_schema.tables
        WHERE table_schema = 'audit'
    ) AS audit_tables;


-- ============================================================
-- 12. FINAL REQUIRED OBJECT COUNT
-- ============================================================

WITH checks AS (

    SELECT

        (
            SELECT COUNT(*)
            FROM information_schema.tables
            WHERE table_schema = 'staging'
              AND table_name IN (
                    'weighted_national_indicator_estimates',
                    'weighted_equity_estimates_public',
                    'equity_gap_summary',
                    'state_indicator_estimates_public',
                    'adjusted_odds_ratios',
                    'unadjusted_odds_ratios',
                    'sensitivity_adjusted_models',
                    'sensitivity_prevalence_comparison'
              )
        ) AS staging_required,

        (
            SELECT COUNT(*)
            FROM information_schema.tables
            WHERE table_schema = 'analytics'
              AND table_name IN (
                    'national_indicator_estimates',
                    'equity_estimates',
                    'equity_gap_summary',
                    'state_indicator_estimates',
                    'regression_results',
                    'sensitivity_adjusted_models',
                    'sensitivity_prevalence_comparison'
              )
        ) AS analytics_required,

        (
            SELECT COUNT(*)
            FROM information_schema.views
            WHERE table_schema = 'reporting'
              AND table_name IN (
                    'vw_national_indicator_estimates',
                    'vw_equity_estimates',
                    'vw_equity_gap_rankings',
                    'vw_state_indicator_rankings',
                    'vw_regression_comparison',
                    'vw_sensitivity_robustness',
                    'vw_powerbi_dataset_catalog'
              )
        ) AS reporting_required,

        (
            SELECT COUNT(*)
            FROM information_schema.tables
            WHERE table_schema = 'audit'
              AND table_name = 'data_load_log'
        ) AS audit_required

)

SELECT

    staging_required,

    analytics_required,

    reporting_required,

    audit_required,

    CASE

        WHEN staging_required = 8
         AND analytics_required = 7
         AND reporting_required = 7
         AND audit_required = 1

        THEN
            'PASS - SQL DATABASE ARCHITECTURE COMPLETE'

        ELSE
            'REVIEW REQUIRED - SQL OBJECTS MISSING'

    END AS architecture_status

FROM checks;