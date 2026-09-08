-- ============================================================
-- CREATE PROJECT SCHEMAS
-- Maternal Continuum of Care and Postnatal Equity in Nigeria
-- ============================================================

CREATE SCHEMA IF NOT EXISTS staging;

CREATE SCHEMA IF NOT EXISTS analytics;

CREATE SCHEMA IF NOT EXISTS reporting;

CREATE SCHEMA IF NOT EXISTS audit;


COMMENT ON SCHEMA staging IS
'Landing area for validated files exported from the R analytical pipeline before SQL transformation.';

COMMENT ON SCHEMA analytics IS
'Curated analytical tables used for SQL analysis, joins, aggregation and reusable analytical logic.';

COMMENT ON SCHEMA reporting IS
'Business intelligence and reporting layer containing Power BI-ready views and reporting tables.';

COMMENT ON SCHEMA audit IS
'Metadata, data-load history, quality assurance results, validation records and pipeline monitoring objects.';


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