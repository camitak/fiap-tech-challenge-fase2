-- Etapa 09: validação das views de consumo do dashboard.

CREATE OR REPLACE TABLE
  `__PROJECT_ID__.alfabetizacao_ops.latest_dashboard_validation`
AS
WITH checks AS (
  SELECT
    'RECONCILIATION' AS check_type,
    'dashboard_views' AS object_name,
    6 AS expected_value,
    (
      SELECT COUNT(*)
      FROM `__PROJECT_ID__.alfabetizacao_gold.INFORMATION_SCHEMA.TABLES`
      WHERE table_name IN (
        'vw_dashboard_resumo_nacional',
        'vw_dashboard_uf',
        'vw_dashboard_municipio',
        'vw_dashboard_streaming',
        'vw_dashboard_operacao',
        'vw_dashboard_bigquery_uso_diario'
      )
      AND table_type = 'VIEW'
    ) AS actual_value

  UNION ALL

  SELECT
    'RECONCILIATION',
    'vw_dashboard_resumo_nacional',
    (SELECT COUNT(*) FROM `__PROJECT_ID__.alfabetizacao_gold.resumo_executivo`),
    (SELECT COUNT(*) FROM `__PROJECT_ID__.alfabetizacao_gold.vw_dashboard_resumo_nacional`)

  UNION ALL

  SELECT
    'RECONCILIATION',
    'vw_dashboard_uf',
    (SELECT COUNT(*) FROM `__PROJECT_ID__.alfabetizacao_gold.kpi_uf`),
    (SELECT COUNT(*) FROM `__PROJECT_ID__.alfabetizacao_gold.vw_dashboard_uf`)

  UNION ALL

  SELECT
    'RECONCILIATION',
    'vw_dashboard_municipio',
    (SELECT COUNT(*) FROM `__PROJECT_ID__.alfabetizacao_gold.kpi_municipio`),
    (SELECT COUNT(*) FROM `__PROJECT_ID__.alfabetizacao_gold.vw_dashboard_municipio`)

  UNION ALL

  SELECT
    'RECONCILIATION',
    'vw_dashboard_operacao',
    3,
    (SELECT COUNT(*) FROM `__PROJECT_ID__.alfabetizacao_gold.vw_dashboard_operacao`)

  UNION ALL

  SELECT
    'CONSISTENCY',
    'dashboard_operacao_sem_falhas',
    0,
    (
      SELECT COUNTIF(pipeline_status != 'SUCCEEDED' OR checks_failed != 0)
      FROM `__PROJECT_ID__.alfabetizacao_gold.vw_dashboard_operacao`
    )

  UNION ALL

  SELECT
    'VALIDITY',
    'dashboard_resumo_chaves',
    0,
    (
      SELECT COUNTIF(ano IS NULL OR ano_referencia IS NULL)
      FROM `__PROJECT_ID__.alfabetizacao_gold.vw_dashboard_resumo_nacional`
    )

  UNION ALL

  SELECT
    'VALIDITY',
    'dashboard_uf_chaves',
    0,
    (
      SELECT COUNTIF(ano IS NULL OR sigla_uf IS NULL)
      FROM `__PROJECT_ID__.alfabetizacao_gold.vw_dashboard_uf`
    )

  UNION ALL

  SELECT
    'VALIDITY',
    'dashboard_municipio_chaves',
    0,
    (
      SELECT COUNTIF(ano IS NULL OR id_municipio IS NULL)
      FROM `__PROJECT_ID__.alfabetizacao_gold.vw_dashboard_municipio`
    )

  UNION ALL

  SELECT
    'VALIDITY',
    'dashboard_streaming_disponivel',
    1,
    IF(
      (
        SELECT COUNT(*)
        FROM `__PROJECT_ID__.alfabetizacao_gold.vw_dashboard_streaming`
      ) > 0,
      1,
      0
    )

  UNION ALL

  SELECT
    'VALIDITY',
    'dashboard_bigquery_uso_disponivel',
    1,
    IF(
      (
        SELECT COUNT(*)
        FROM `__PROJECT_ID__.alfabetizacao_gold.vw_dashboard_bigquery_uso_diario`
      ) > 0,
      1,
      0
    )

  UNION ALL

  SELECT
    'VALIDITY',
    'dashboard_metricas_nao_negativas',
    0,
    (
      SELECT COUNTIF(
        total_bytes_processed < 0
        OR total_bytes_billed < 0
        OR total_tib_billed < 0
        OR query_jobs < 0
        OR failed_jobs < 0
      )
      FROM `__PROJECT_ID__.alfabetizacao_gold.vw_dashboard_bigquery_uso_diario`
    )
)
SELECT
  check_type,
  object_name,
  expected_value,
  actual_value,
  IF(expected_value = actual_value, 'OK', 'ERROR') AS status,
  CURRENT_TIMESTAMP() AS executed_at
FROM checks;
