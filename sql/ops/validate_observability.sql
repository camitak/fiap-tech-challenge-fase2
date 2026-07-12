CREATE OR REPLACE TABLE
  `__PROJECT_ID__.alfabetizacao_ops.latest_ops_validation`
AS
WITH checks AS (
  SELECT
    'RECONCILIATION' AS check_type,
    'silver_validation_history' AS object_name,
    1 AS expected_value,
    IF(COUNT(*) > 0, 1, 0) AS actual_value
  FROM `__PROJECT_ID__.alfabetizacao_ops.silver_validation_history`

  UNION ALL
  SELECT 'RECONCILIATION', 'gold_validation_history', 1, IF(COUNT(*) > 0, 1, 0)
  FROM `__PROJECT_ID__.alfabetizacao_ops.gold_validation_history`

  UNION ALL
  SELECT 'RECONCILIATION', 'streaming_validation_history', 1, IF(COUNT(*) > 0, 1, 0)
  FROM `__PROJECT_ID__.alfabetizacao_ops.streaming_validation_history`

  UNION ALL
  SELECT 'RECONCILIATION', 'pipeline_health_latest', 3, COUNT(*)
  FROM `__PROJECT_ID__.alfabetizacao_ops.vw_pipeline_health_latest`

  UNION ALL
  SELECT
    'CONSISTENCY',
    'latest_pipeline_failures',
    0,
    COUNTIF(pipeline_status != 'SUCCEEDED')
  FROM `__PROJECT_ID__.alfabetizacao_ops.vw_pipeline_health_latest`

  UNION ALL
  SELECT 'CONSISTENCY', 'quality_failures', 0, COUNT(*)
  FROM `__PROJECT_ID__.alfabetizacao_ops.vw_quality_failures`

  UNION ALL
  SELECT
    'VALIDITY',
    'negative_streaming_latency',
    0,
    COUNTIF(
      avg_end_to_end_latency_seconds < 0
      OR p95_end_to_end_latency_seconds < 0
      OR max_end_to_end_latency_seconds < 0
      OR avg_processing_latency_seconds < 0
    )
  FROM `__PROJECT_ID__.alfabetizacao_ops.streaming_latency_summary`

  UNION ALL
  SELECT 'RECONCILIATION', 'bigquery_usage_daily', 1, IF(COUNT(*) > 0, 1, 0)
  FROM `__PROJECT_ID__.alfabetizacao_ops.bigquery_usage_daily`

  UNION ALL
  SELECT
    'VALIDITY',
    'bigquery_negative_usage',
    0,
    COUNTIF(
      query_jobs < 0
      OR failed_jobs < 0
      OR total_bytes_processed < 0
      OR total_bytes_billed < 0
      OR total_slot_ms < 0
      OR cache_hit_jobs < 0
    )
  FROM `__PROJECT_ID__.alfabetizacao_ops.bigquery_usage_daily`
)
SELECT
  check_type,
  object_name,
  expected_value,
  actual_value,
  IF(expected_value = actual_value, 'OK', 'ERROR') AS status,
  CURRENT_TIMESTAMP() AS executed_at
FROM checks;
