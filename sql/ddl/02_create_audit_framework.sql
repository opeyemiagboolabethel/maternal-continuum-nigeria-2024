-- ============================================================
-- AUDIT FRAMEWORK
-- Maternal Continuum of Care and Postnatal Equity in Nigeria
-- ============================================================

CREATE TABLE IF NOT EXISTS audit.data_load_log (

    load_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    source_file VARCHAR(255) NOT NULL,

    target_schema VARCHAR(100) NOT NULL,

    target_table VARCHAR(150) NOT NULL,

    load_started_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    load_completed_at TIMESTAMPTZ,

    rows_loaded BIGINT,

    load_status VARCHAR(20) NOT NULL DEFAULT 'STARTED',

    error_message TEXT,

    loaded_by VARCHAR(100) NOT NULL DEFAULT CURRENT_USER,

    CONSTRAINT chk_load_status
        CHECK (
            load_status IN (
                'STARTED',
                'SUCCESS',
                'FAILED'
            )
        ),

    CONSTRAINT chk_rows_loaded
        CHECK (
            rows_loaded IS NULL
            OR rows_loaded >= 0
        )
);


COMMENT ON TABLE audit.data_load_log IS
'Tracks data files loaded into the maternal health analytics database, including destination, row counts, timestamps and load status.';


COMMENT ON COLUMN audit.data_load_log.source_file IS
'Name of the source analytical file being loaded.';


COMMENT ON COLUMN audit.data_load_log.target_schema IS
'PostgreSQL schema receiving the data.';


COMMENT ON COLUMN audit.data_load_log.target_table IS
'PostgreSQL table receiving the data.';


COMMENT ON COLUMN audit.data_load_log.rows_loaded IS
'Number of records successfully loaded.';


COMMENT ON COLUMN audit.data_load_log.load_status IS
'Current load state: STARTED, SUCCESS or FAILED.';


-- ============================================================
-- VERIFY TABLE
-- ============================================================

SELECT
    table_schema,
    table_name
FROM information_schema.tables
WHERE table_schema = 'audit'
  AND table_name = 'data_load_log';