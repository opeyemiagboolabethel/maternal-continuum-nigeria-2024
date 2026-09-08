SELECT COUNT(*) AS rows_loaded
FROM staging.weighted_national_indicator_estimates;
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT variable) AS distinct_variables,
    COUNT(*) FILTER (WHERE variable IS NULL) AS missing_variable,
    COUNT(*) FILTER (WHERE indicator IS NULL) AS missing_indicator,
    COUNT(*) FILTER (WHERE weighted_percent IS NULL) AS missing_weighted_percent
FROM staging.weighted_national_indicator_estimates;

SELECT
    COUNT(*) FILTER (
        WHERE weighted_percent < 0
           OR weighted_percent > 100
    ) AS invalid_percentages,

    COUNT(*) FILTER (
        WHERE confidence_interval_low_percent >
              confidence_interval_high_percent
    ) AS invalid_confidence_intervals,

    COUNT(*) FILTER (
        WHERE unweighted_positive_n > unweighted_n
    ) AS invalid_counts

FROM staging.weighted_national_indicator_estimates;
INSERT INTO audit.data_load_log (
    source_file,
    target_schema,
    target_table,
    load_completed_at,
    rows_loaded,
    load_status
)
VALUES (
    'weighted_national_indicator_estimates.csv',
    'staging',
    'weighted_national_indicator_estimates',
    CURRENT_TIMESTAMP,
    14,
    'SUCCESS'
)
RETURNING
    load_id,
    source_file,
    target_schema,
    target_table,
    rows_loaded,
    load_status,
    load_completed_at;

	SELECT *
FROM audit.data_load_log
ORDER BY load_id DESC;