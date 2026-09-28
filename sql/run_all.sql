-- END-TO-END POSTGRESQL BUILD
-- Invoke from repository root:
-- psql -d maternal_health_portfolio -f sql/run_all.sql

\set ON_ERROR_STOP on

\ir ddl/01_create_schemas.sql
\ir ddl/02_create_audit_framework.sql
\ir ddl/03_create_national_indicator_staging.sql
\ir ddl/04_create_national_indicator_analytics.sql
\ir ddl/05_create_equity_staging.sql
\ir ddl/06_create_equity_analytics.sql
\ir ddl/07_create_equity_gap_staging.sql
\ir ddl/08_create_equity_gap_analytics.sql
\ir ddl/09_create_state_indicator_staging.sql
\ir ddl/10_create_state_indicator_analytics.sql
\ir ddl/11_create_regression_staging.sql
\ir ddl/12_create_regression_analytics.sql
\ir ddl/13_create_sensitivity_staging.sql
\ir ddl/14_create_sensitivity_analytics.sql

\ir load/01_load_validated_outputs.sql

\ir ddl/04_create_national_indicator_analytics.sql
\ir ddl/06_create_equity_analytics.sql
\ir ddl/08_create_equity_gap_analytics.sql
\ir ddl/10_create_state_indicator_analytics.sql
\ir ddl/12_create_regression_analytics.sql
\ir ddl/14_create_sensitivity_analytics.sql

\ir queries/01_create_national_indicator_reporting_view.sql
\ir queries/02_create_equity_reporting_view.sql
\ir queries/03_create_equity_gap_reporting_view.sql
\ir queries/04_create_state_indicator_reporting_view.sql
\ir queries/05_create_regression_reporting_view.sql
\ir queries/06_create_sensitivity_reporting_view.sql
\ir queries/07_powerbi_handoff.sql

\ir validation/01_validate_national_indicator_load.sql
\ir validation/02_validate_equity_load.sql
\ir validation/03_validate_equity_gap_load.sql
\ir validation/04_validate_state_indicator_load.sql
\ir validation/05_validate_regression_load.sql
\ir validation/06_validate_sensitivity_load.sql
\ir validation/07_final_sql_qa.sql
\ir validation/08_sql_repository_validation.sql
