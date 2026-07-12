-- Valida reconciliação Bronze -> Silver + Quarentena e regras estruturais.
DECLARE v_ingestion_date DATE DEFAULT DATE '__INGESTION_DATE__';
DECLARE v_batch_id STRING DEFAULT '__BATCH_ID__';

CREATE OR REPLACE TABLE `__PROJECT_ID__.alfabetizacao_ops.latest_silver_validation`
OPTIONS(description='Último resultado das validações automatizadas da camada Silver.') AS
WITH reconciliation AS (
  SELECT 'RECONCILIATION' AS check_type, 'dicionario' AS object_name,
    (SELECT COUNT(*) FROM `__PROJECT_ID__.alfabetizacao_bronze.ext_dicionario`
      WHERE ingestion_date=v_ingestion_date AND batch_id=v_batch_id) AS expected_value,
    (SELECT COUNT(*) FROM `__PROJECT_ID__.alfabetizacao_silver.dim_dicionario`) +
    (SELECT COUNT(*) FROM `__PROJECT_ID__.alfabetizacao_quarantine.records`
      WHERE source_table='dicionario' AND ingestion_date=v_ingestion_date AND batch_id=v_batch_id) AS actual_value
  UNION ALL
  SELECT 'RECONCILIATION', 'alunos',
    (SELECT COUNT(*) FROM `__PROJECT_ID__.alfabetizacao_bronze.ext_alunos`
      WHERE ingestion_date=v_ingestion_date AND batch_id=v_batch_id),
    (SELECT COUNT(*) FROM `__PROJECT_ID__.alfabetizacao_silver.alunos`) +
    (SELECT COUNT(*) FROM `__PROJECT_ID__.alfabetizacao_quarantine.records`
      WHERE source_table='alunos' AND ingestion_date=v_ingestion_date AND batch_id=v_batch_id)
  UNION ALL
  SELECT 'RECONCILIATION', 'municipio',
    (SELECT COUNT(*) FROM `__PROJECT_ID__.alfabetizacao_bronze.ext_municipio`
      WHERE ingestion_date=v_ingestion_date AND batch_id=v_batch_id),
    (SELECT COUNT(*) FROM `__PROJECT_ID__.alfabetizacao_silver.resultado_municipio`) +
    (SELECT COUNT(*) FROM `__PROJECT_ID__.alfabetizacao_quarantine.records`
      WHERE source_table='municipio' AND ingestion_date=v_ingestion_date AND batch_id=v_batch_id)
  UNION ALL
  SELECT 'RECONCILIATION', 'uf',
    (SELECT COUNT(*) FROM `__PROJECT_ID__.alfabetizacao_bronze.ext_uf`
      WHERE ingestion_date=v_ingestion_date AND batch_id=v_batch_id),
    (SELECT COUNT(*) FROM `__PROJECT_ID__.alfabetizacao_silver.resultado_uf`) +
    (SELECT COUNT(*) FROM `__PROJECT_ID__.alfabetizacao_quarantine.records`
      WHERE source_table='uf' AND ingestion_date=v_ingestion_date AND batch_id=v_batch_id)
  UNION ALL
  SELECT 'RECONCILIATION', 'meta_alfabetizacao_brasil',
    7 * (SELECT COUNT(*) FROM `__PROJECT_ID__.alfabetizacao_bronze.ext_meta_alfabetizacao_brasil`
      WHERE ingestion_date=v_ingestion_date AND batch_id=v_batch_id),
    (SELECT COUNT(*) FROM `__PROJECT_ID__.alfabetizacao_silver.meta_brasil`) +
    (SELECT COUNT(*) FROM `__PROJECT_ID__.alfabetizacao_quarantine.records`
      WHERE source_table='meta_alfabetizacao_brasil' AND ingestion_date=v_ingestion_date AND batch_id=v_batch_id)
  UNION ALL
  SELECT 'RECONCILIATION', 'meta_alfabetizacao_uf',
    7 * (SELECT COUNT(*) FROM `__PROJECT_ID__.alfabetizacao_bronze.ext_meta_alfabetizacao_uf`
      WHERE ingestion_date=v_ingestion_date AND batch_id=v_batch_id),
    (SELECT COUNT(*) FROM `__PROJECT_ID__.alfabetizacao_silver.meta_uf`) +
    (SELECT COUNT(*) FROM `__PROJECT_ID__.alfabetizacao_quarantine.records`
      WHERE source_table='meta_alfabetizacao_uf' AND ingestion_date=v_ingestion_date AND batch_id=v_batch_id)
  UNION ALL
  SELECT 'RECONCILIATION', 'meta_alfabetizacao_municipio',
    7 * (SELECT COUNT(*) FROM `__PROJECT_ID__.alfabetizacao_bronze.ext_meta_alfabetizacao_municipio`
      WHERE ingestion_date=v_ingestion_date AND batch_id=v_batch_id),
    (SELECT COUNT(*) FROM `__PROJECT_ID__.alfabetizacao_silver.meta_municipio`) +
    (SELECT COUNT(*) FROM `__PROJECT_ID__.alfabetizacao_quarantine.records`
      WHERE source_table='meta_alfabetizacao_municipio' AND ingestion_date=v_ingestion_date AND batch_id=v_batch_id)
), structural AS (
  SELECT 'UNIQUENESS' AS check_type, 'alunos' AS object_name, 0 AS expected_value,
    (SELECT COUNT(*) FROM (
      SELECT ano, id_aluno FROM `__PROJECT_ID__.alfabetizacao_silver.alunos`
      GROUP BY ano, id_aluno HAVING COUNT(*) > 1)) AS actual_value
  UNION ALL
  SELECT 'UNIQUENESS', 'resultado_municipio', 0,
    (SELECT COUNT(*) FROM (
      SELECT ano, id_municipio, serie_codigo, rede_codigo
      FROM `__PROJECT_ID__.alfabetizacao_silver.resultado_municipio`
      GROUP BY ano, id_municipio, serie_codigo, rede_codigo HAVING COUNT(*) > 1))
  UNION ALL
  SELECT 'UNIQUENESS', 'resultado_uf', 0,
    (SELECT COUNT(*) FROM (
      SELECT ano, sigla_uf, serie_codigo, rede_codigo
      FROM `__PROJECT_ID__.alfabetizacao_silver.resultado_uf`
      GROUP BY ano, sigla_uf, serie_codigo, rede_codigo HAVING COUNT(*) > 1))
  UNION ALL
  SELECT 'VALIDITY', 'taxas_resultado_municipio', 0,
    (SELECT COUNT(*) FROM `__PROJECT_ID__.alfabetizacao_silver.resultado_municipio`
      WHERE taxa_alfabetizacao IS NOT NULL AND (taxa_alfabetizacao < 0 OR taxa_alfabetizacao > 100))
  UNION ALL
  SELECT 'VALIDITY', 'taxas_resultado_uf', 0,
    (SELECT COUNT(*) FROM `__PROJECT_ID__.alfabetizacao_silver.resultado_uf`
      WHERE taxa_alfabetizacao IS NOT NULL AND (taxa_alfabetizacao < 0 OR taxa_alfabetizacao > 100))
  UNION ALL
  SELECT 'VALIDITY', 'metas', 0,
    (SELECT COUNT(*) FROM (
      SELECT meta_alfabetizacao FROM `__PROJECT_ID__.alfabetizacao_silver.meta_brasil`
      UNION ALL SELECT meta_alfabetizacao FROM `__PROJECT_ID__.alfabetizacao_silver.meta_uf`
      UNION ALL SELECT meta_alfabetizacao FROM `__PROJECT_ID__.alfabetizacao_silver.meta_municipio`
    ) WHERE meta_alfabetizacao IS NOT NULL AND (meta_alfabetizacao < 0 OR meta_alfabetizacao > 100))
)
SELECT
  check_type,
  object_name,
  expected_value,
  actual_value,
  IF(expected_value = actual_value, 'OK', 'FAIL') AS status,
  v_ingestion_date AS ingestion_date,
  v_batch_id AS batch_id,
  CURRENT_TIMESTAMP() AS executed_at
FROM reconciliation
UNION ALL
SELECT
  check_type,
  object_name,
  expected_value,
  actual_value,
  IF(expected_value = actual_value, 'OK', 'FAIL') AS status,
  v_ingestion_date,
  v_batch_id,
  CURRENT_TIMESTAMP()
FROM structural;

SELECT *
FROM `__PROJECT_ID__.alfabetizacao_ops.latest_silver_validation`
ORDER BY check_type, object_name;
