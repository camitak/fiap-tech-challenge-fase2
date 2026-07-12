-- Etapa 08 — Observabilidade operacional e FinOps.
DECLARE collected_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP();

CREATE TABLE IF NOT EXISTS
  `__PROJECT_ID__.alfabetizacao_ops.silver_validation_history`
PARTITION BY DATE(executed_at)
CLUSTER BY check_type, object_name, status
AS
SELECT *
FROM `__PROJECT_ID__.alfabetizacao_ops.latest_silver_validation`
WHERE FALSE;

MERGE `__PROJECT_ID__.alfabetizacao_ops.silver_validation_history` T
USING `__PROJECT_ID__.alfabetizacao_ops.latest_silver_validation` S
ON T.batch_id = S.batch_id
AND T.check_type = S.check_type
AND T.object_name = S.object_name
AND T.executed_at = S.executed_at
WHEN NOT MATCHED THEN
INSERT (
  check_type, object_name, expected_value, actual_value, status,
  ingestion_date, batch_id, executed_at
)
VALUES (
  S.check_type, S.object_name, S.expected_value, S.actual_value, S.status,
  S.ingestion_date, S.batch_id, S.executed_at
);

CREATE TABLE IF NOT EXISTS
  `__PROJECT_ID__.alfabetizacao_ops.gold_validation_history`
PARTITION BY DATE(executed_at)
CLUSTER BY check_type, object_name, status
AS
SELECT *
FROM `__PROJECT_ID__.alfabetizacao_ops.latest_gold_validation`
WHERE FALSE;

MERGE `__PROJECT_ID__.alfabetizacao_ops.gold_validation_history` T
USING `__PROJECT_ID__.alfabetizacao_ops.latest_gold_validation` S
ON T.check_type = S.check_type
AND T.object_name = S.object_name
AND T.executed_at = S.executed_at
WHEN NOT MATCHED THEN
INSERT (
  check_type, object_name, expected_value, actual_value, status, executed_at
)
VALUES (
  S.check_type, S.object_name, S.expected_value, S.actual_value, S.status,
  S.executed_at
);

CREATE TABLE IF NOT EXISTS
  `__PROJECT_ID__.alfabetizacao_ops.streaming_validation_history`
PARTITION BY DATE(executed_at)
CLUSTER BY check_type, object_name, status
AS
SELECT *
FROM `__PROJECT_ID__.alfabetizacao_ops.latest_streaming_validation`
WHERE FALSE;

MERGE `__PROJECT_ID__.alfabetizacao_ops.streaming_validation_history` T
USING `__PROJECT_ID__.alfabetizacao_ops.latest_streaming_validation` S
ON T.simulation_run_id = S.simulation_run_id
AND T.check_type = S.check_type
AND T.object_name = S.object_name
AND T.executed_at = S.executed_at
WHEN NOT MATCHED THEN
INSERT (
  check_type, object_name, expected_value, actual_value, status,
  simulation_run_id, executed_at
)
VALUES (
  S.check_type, S.object_name, S.expected_value, S.actual_value, S.status,
  S.simulation_run_id, S.executed_at
);

CREATE TABLE IF NOT EXISTS
  `__PROJECT_ID__.alfabetizacao_ops.pipeline_health_history` (
    pipeline_name STRING,
    run_id STRING,
    executed_at TIMESTAMP,
    checks_total INT64,
    checks_ok INT64,
    checks_failed INT64,
    pipeline_status STRING,
    collected_at TIMESTAMP
  )
PARTITION BY DATE(executed_at)
CLUSTER BY pipeline_name, pipeline_status;

MERGE `__PROJECT_ID__.alfabetizacao_ops.pipeline_health_history` T
USING (
  SELECT
    'silver_batch' AS pipeline_name,
    batch_id AS run_id,
    MAX(executed_at) AS executed_at,
    COUNT(*) AS checks_total,
    COUNTIF(status = 'OK') AS checks_ok,
    COUNTIF(status != 'OK') AS checks_failed,
    IF(COUNTIF(status != 'OK') = 0, 'SUCCEEDED', 'FAILED') AS pipeline_status,
    collected_at
  FROM `__PROJECT_ID__.alfabetizacao_ops.latest_silver_validation`
  GROUP BY batch_id

  UNION ALL

  SELECT
    'gold_batch',
    CONCAT('gold_', FORMAT_TIMESTAMP('%Y%m%dT%H%M%SZ', MAX(executed_at), 'UTC')),
    MAX(executed_at),
    COUNT(*),
    COUNTIF(status = 'OK'),
    COUNTIF(status != 'OK'),
    IF(COUNTIF(status != 'OK') = 0, 'SUCCEEDED', 'FAILED'),
    collected_at
  FROM `__PROJECT_ID__.alfabetizacao_ops.latest_gold_validation`

  UNION ALL

  SELECT
    'streaming',
    simulation_run_id,
    MAX(executed_at),
    COUNT(*),
    COUNTIF(status = 'OK'),
    COUNTIF(status != 'OK'),
    IF(COUNTIF(status != 'OK') = 0, 'SUCCEEDED', 'FAILED'),
    collected_at
  FROM `__PROJECT_ID__.alfabetizacao_ops.latest_streaming_validation`
  GROUP BY simulation_run_id
) S
ON T.pipeline_name = S.pipeline_name
AND T.run_id = S.run_id
AND T.executed_at = S.executed_at
WHEN NOT MATCHED THEN
INSERT (
  pipeline_name, run_id, executed_at, checks_total, checks_ok,
  checks_failed, pipeline_status, collected_at
)
VALUES (
  S.pipeline_name, S.run_id, S.executed_at, S.checks_total, S.checks_ok,
  S.checks_failed, S.pipeline_status, S.collected_at
);

CREATE OR REPLACE VIEW
  `__PROJECT_ID__.alfabetizacao_ops.vw_pipeline_health_latest`
AS
SELECT * EXCEPT(row_number)
FROM (
  SELECT
    *,
    ROW_NUMBER() OVER (
      PARTITION BY pipeline_name
      ORDER BY executed_at DESC, collected_at DESC
    ) AS row_number
  FROM `__PROJECT_ID__.alfabetizacao_ops.pipeline_health_history`
)
WHERE row_number = 1;

CREATE OR REPLACE VIEW
  `__PROJECT_ID__.alfabetizacao_ops.vw_quality_failures`
AS
SELECT
  'silver' AS pipeline_layer,
  batch_id AS run_id,
  check_type,
  object_name,
  expected_value,
  actual_value,
  status,
  executed_at
FROM `__PROJECT_ID__.alfabetizacao_ops.silver_validation_history`
WHERE status != 'OK'

UNION ALL

SELECT
  'gold',
  CONCAT('gold_', FORMAT_TIMESTAMP('%Y%m%dT%H%M%SZ', executed_at, 'UTC')),
  check_type,
  object_name,
  expected_value,
  actual_value,
  status,
  executed_at
FROM `__PROJECT_ID__.alfabetizacao_ops.gold_validation_history`
WHERE status != 'OK'

UNION ALL

SELECT
  'streaming',
  simulation_run_id,
  check_type,
  object_name,
  expected_value,
  actual_value,
  status,
  executed_at
FROM `__PROJECT_ID__.alfabetizacao_ops.streaming_validation_history`
WHERE status != 'OK';

CREATE OR REPLACE TABLE
  `__PROJECT_ID__.alfabetizacao_ops.streaming_latency_summary`
PARTITION BY DATE(last_event_time)
CLUSTER BY simulation_run_id, event_type
AS
SELECT
  simulation_run_id,
  event_type,
  COUNT(*) AS event_count,
  MIN(event_time) AS first_event_time,
  MAX(event_time) AS last_event_time,
  ROUND(
    AVG(TIMESTAMP_DIFF(processing_timestamp, event_time, MILLISECOND)) / 1000,
    3
  ) AS avg_end_to_end_latency_seconds,
  ROUND(
    APPROX_QUANTILES(
      TIMESTAMP_DIFF(processing_timestamp, event_time, MILLISECOND) / 1000.0,
      100
    )[OFFSET(95)],
    3
  ) AS p95_end_to_end_latency_seconds,
  ROUND(
    MAX(TIMESTAMP_DIFF(processing_timestamp, event_time, MILLISECOND)) / 1000,
    3
  ) AS max_end_to_end_latency_seconds,
  ROUND(
    AVG(
      TIMESTAMP_DIFF(
        processing_timestamp,
        pubsub_publish_time,
        MILLISECOND
      )
    ) / 1000,
    3
  ) AS avg_processing_latency_seconds,
  CURRENT_TIMESTAMP() AS collected_at
FROM `__PROJECT_ID__.alfabetizacao_silver.streaming_eventos`
GROUP BY simulation_run_id, event_type;

CREATE OR REPLACE TABLE
  `__PROJECT_ID__.alfabetizacao_ops.bigquery_usage_daily`
PARTITION BY usage_date
CLUSTER BY user_email, statement_type
AS
SELECT
  DATE(creation_time) AS usage_date,
  user_email,
  COALESCE(statement_type, 'UNKNOWN') AS statement_type,
  COUNT(*) AS query_jobs,
  COUNTIF(error_result IS NOT NULL) AS failed_jobs,
  SUM(COALESCE(total_bytes_processed, 0)) AS total_bytes_processed,
  SUM(COALESCE(total_bytes_billed, 0)) AS total_bytes_billed,
  ROUND(
    SUM(COALESCE(total_bytes_billed, 0)) / POW(1024, 4),
    8
  ) AS total_tib_billed,
  SUM(COALESCE(total_slot_ms, 0)) AS total_slot_ms,
  COUNTIF(cache_hit) AS cache_hit_jobs,
  CURRENT_TIMESTAMP() AS collected_at
FROM `__REGION_QUALIFIER__`.INFORMATION_SCHEMA.JOBS_BY_PROJECT
WHERE
  creation_time >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 180 DAY)
  AND job_type = 'QUERY'
GROUP BY usage_date, user_email, statement_type;

CREATE OR REPLACE VIEW
  `__PROJECT_ID__.alfabetizacao_ops.vw_bigquery_usage_summary`
AS
SELECT
  MIN(usage_date) AS first_usage_date,
  MAX(usage_date) AS last_usage_date,
  SUM(query_jobs) AS query_jobs,
  SUM(failed_jobs) AS failed_jobs,
  SUM(total_bytes_processed) AS total_bytes_processed,
  SUM(total_bytes_billed) AS total_bytes_billed,
  ROUND(SUM(total_tib_billed), 8) AS total_tib_billed,
  SUM(total_slot_ms) AS total_slot_ms,
  SUM(cache_hit_jobs) AS cache_hit_jobs
FROM `__PROJECT_ID__.alfabetizacao_ops.bigquery_usage_daily`;
