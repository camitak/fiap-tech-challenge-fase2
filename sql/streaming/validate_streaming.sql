-- Os placeholders são substituídos pelo script validate_streaming.sh.

CREATE OR REPLACE TABLE
  `__PROJECT_ID__.alfabetizacao_ops.latest_streaming_validation` AS
WITH
bronze AS (
  SELECT *
  FROM `__PROJECT_ID__.alfabetizacao_bronze.streaming_eventos_raw`
  WHERE simulation_run_id = '__SIMULATION_RUN_ID__'
),
silver AS (
  SELECT *
  FROM `__PROJECT_ID__.alfabetizacao_silver.streaming_eventos`
  WHERE simulation_run_id = '__SIMULATION_RUN_ID__'
),
quarantine AS (
  SELECT *
  FROM `__PROJECT_ID__.alfabetizacao_quarantine.streaming_eventos`
  WHERE simulation_run_id = '__SIMULATION_RUN_ID__'
),
checks AS (
  SELECT
    'RECONCILIATION' AS check_type,
    'bronze_total_eventos' AS object_name,
    CAST(__EXPECTED_TOTAL__ AS INT64) AS expected_value,
    COUNT(*) AS actual_value
  FROM bronze

  UNION ALL

  SELECT
    'RECONCILIATION',
    'silver_eventos_validos',
    CAST(__EXPECTED_VALID__ AS INT64),
    COUNT(DISTINCT event_id)
  FROM silver

  UNION ALL

  SELECT
    'RECONCILIATION',
    'quarentena_eventos_invalidos',
    CAST(__EXPECTED_INVALID__ AS INT64),
    COUNT(DISTINCT event_id)
  FROM quarantine

  UNION ALL

  SELECT
    'UNIQUENESS',
    'silver_event_id',
    0,
    COUNT(*) - COUNT(DISTINCT event_id)
  FROM silver

  UNION ALL

  SELECT
    'VALIDITY',
    'silver_campos_obrigatorios',
    0,
    COUNTIF(
      event_id IS NULL OR
      event_type IS NULL OR
      event_time IS NULL OR
      entity_type IS NULL OR
      entity_id IS NULL OR
      source IS NULL
    )
  FROM silver

  UNION ALL

  SELECT
    'VALIDITY',
    'silver_tipos_evento',
    0,
    COUNTIF(event_type NOT IN (
      'indicador_municipio_atualizado',
      'indicador_uf_atualizado',
      'meta_municipio_atualizada',
      'meta_uf_atualizada',
      'resultado_aluno_recebido'
    ))
  FROM silver

  UNION ALL

  SELECT
    'VALIDITY',
    'silver_percentuais',
    0,
    COUNTIF(
      (taxa_alfabetizacao IS NOT NULL AND taxa_alfabetizacao NOT BETWEEN 0 AND 100) OR
      (meta_alfabetizacao IS NOT NULL AND meta_alfabetizacao NOT BETWEEN 0 AND 100) OR
      (percentual_participacao IS NOT NULL AND percentual_participacao NOT BETWEEN 0 AND 100)
    )
  FROM silver

  UNION ALL

  SELECT
    'CONSISTENCY',
    'quarentena_com_motivo',
    0,
    COUNTIF(error_code IS NULL OR error_message IS NULL)
  FROM quarantine
)
SELECT
  check_type,
  object_name,
  expected_value,
  actual_value,
  IF(expected_value = actual_value, 'OK', 'FAIL') AS status,
  '__SIMULATION_RUN_ID__' AS simulation_run_id,
  CURRENT_TIMESTAMP() AS executed_at
FROM checks;

SELECT *
FROM `__PROJECT_ID__.alfabetizacao_ops.latest_streaming_validation`
ORDER BY check_type, object_name;
