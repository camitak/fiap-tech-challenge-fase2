-- Tech Challenge Fase 2
-- Etapa 05: construção da camada Silver, quarentena e integrações.

DECLARE v_ingestion_date DATE DEFAULT DATE '__INGESTION_DATE__';
DECLARE v_batch_id STRING DEFAULT '__BATCH_ID__';

-- ================================================================
-- 1. DICIONÁRIO
-- ================================================================

CREATE TEMP TABLE stg_dicionario AS
WITH ranked AS (
  SELECT
    TRIM(id_tabela) AS id_tabela,
    TRIM(nome_coluna) AS nome_coluna,
    TRIM(chave) AS chave,
    TRIM(cobertura_temporal) AS cobertura_temporal,
    TRIM(valor) AS valor,
    _ingestion_timestamp AS source_ingestion_timestamp,
    _batch_id AS source_batch_id,
    _source_table AS source_table,
    ingestion_date,
    batch_id,
    ROW_NUMBER() OVER (
      PARTITION BY TRIM(id_tabela), TRIM(nome_coluna), TRIM(chave)
      ORDER BY _ingestion_timestamp DESC
    ) AS rn
  FROM `__PROJECT_ID__.alfabetizacao_bronze.ext_dicionario`
  WHERE ingestion_date = v_ingestion_date
    AND batch_id = v_batch_id
)
SELECT
  *,
  ARRAY(
    SELECT rule
    FROM UNNEST([
      IF(id_tabela IS NULL OR id_tabela = '', 'DQ001_ID_TABELA_AUSENTE', NULL),
      IF(nome_coluna IS NULL OR nome_coluna = '', 'DQ002_NOME_COLUNA_AUSENTE', NULL),
      IF(chave IS NULL OR chave = '', 'DQ003_CHAVE_DICIONARIO_AUSENTE', NULL),
      IF(valor IS NULL OR valor = '', 'DQ004_VALOR_DICIONARIO_AUSENTE', NULL),
      IF(rn > 1, 'DQ005_DICIONARIO_DUPLICADO', NULL)
    ]) AS rule
    WHERE rule IS NOT NULL
  ) AS critical_rules,
  CAST([] AS ARRAY<STRING>) AS alert_rules
FROM ranked;

CREATE OR REPLACE TABLE `__PROJECT_ID__.alfabetizacao_silver.dim_dicionario`
OPTIONS(description='Dicionário oficial de códigos da Base dos Dados, deduplicado.') AS
SELECT
  id_tabela,
  nome_coluna,
  chave,
  cobertura_temporal,
  valor,
  source_ingestion_timestamp,
  source_batch_id,
  source_table,
  ingestion_date,
  CURRENT_TIMESTAMP() AS silver_processed_at
FROM stg_dicionario
WHERE ARRAY_LENGTH(critical_rules) = 0;

-- ================================================================
-- 2. ALUNOS
-- ================================================================

CREATE TEMP TABLE stg_alunos AS
WITH base AS (
  SELECT
    a.ano,
    DATE(a.ano, 1, 1) AS ano_referencia,
    TRIM(a.id_municipio) AS id_municipio,
    TRIM(a.id_escola) AS id_escola,
    TRIM(a.id_aluno) AS id_aluno,
    TRIM(a.caderno) AS caderno_codigo,
    TRIM(a.serie) AS serie_codigo,
    d_serie.valor AS serie_nome,
    TRIM(a.rede) AS rede_codigo,
    d_rede.valor AS rede_nome,
    CASE
      WHEN d_rede.valor IN ('Federal', 'Estadual', 'Municipal') THEN 'Pública'
      WHEN d_rede.valor = 'Privada' THEN 'Privada'
      ELSE d_rede.valor
    END AS rede_agrupada,
    TRIM(a.presenca) AS presenca_codigo,
    d_presenca.valor AS presenca_nome,
    TRIM(a.preenchimento_caderno) AS preenchimento_caderno_codigo,
    d_preenchimento.valor AS preenchimento_caderno_nome,
    TRIM(a.alfabetizado) AS alfabetizado_codigo,
    d_alfabetizado.valor AS alfabetizado_nome,
    a.proficiencia,
    a.peso_aluno,
    a._ingestion_timestamp AS source_ingestion_timestamp,
    a._batch_id AS source_batch_id,
    a._source_table AS source_table,
    a.ingestion_date,
    a.batch_id
  FROM `__PROJECT_ID__.alfabetizacao_bronze.ext_alunos` AS a
  LEFT JOIN `__PROJECT_ID__.alfabetizacao_silver.dim_dicionario` AS d_serie
    ON d_serie.id_tabela = 'alunos'
   AND d_serie.nome_coluna = 'serie'
   AND d_serie.chave = TRIM(a.serie)
  LEFT JOIN `__PROJECT_ID__.alfabetizacao_silver.dim_dicionario` AS d_rede
    ON d_rede.id_tabela = 'alunos'
   AND d_rede.nome_coluna = 'rede'
   AND d_rede.chave = TRIM(a.rede)
  LEFT JOIN `__PROJECT_ID__.alfabetizacao_silver.dim_dicionario` AS d_presenca
    ON d_presenca.id_tabela = 'alunos'
   AND d_presenca.nome_coluna = 'presenca'
   AND d_presenca.chave = TRIM(a.presenca)
  LEFT JOIN `__PROJECT_ID__.alfabetizacao_silver.dim_dicionario` AS d_preenchimento
    ON d_preenchimento.id_tabela = 'alunos'
   AND d_preenchimento.nome_coluna = 'preenchimento_caderno'
   AND d_preenchimento.chave = TRIM(a.preenchimento_caderno)
  LEFT JOIN `__PROJECT_ID__.alfabetizacao_silver.dim_dicionario` AS d_alfabetizado
    ON d_alfabetizado.id_tabela = 'alunos'
   AND d_alfabetizado.nome_coluna = 'alfabetizado'
   AND d_alfabetizado.chave = TRIM(a.alfabetizado)
  WHERE a.ingestion_date = v_ingestion_date
    AND a.batch_id = v_batch_id
), ranked AS (
  SELECT
    *,
    ROW_NUMBER() OVER (
      PARTITION BY ano, id_aluno
      ORDER BY source_ingestion_timestamp DESC, id_escola
    ) AS rn
  FROM base
)
SELECT
  *,
  ARRAY(
    SELECT rule
    FROM UNNEST([
      IF(ano IS NULL, 'DQ001_ANO_AUSENTE', NULL),
      IF(ano IS NOT NULL AND (ano < 2020 OR ano > 2035), 'DQ002_ANO_FORA_INTERVALO', NULL),
      IF(id_municipio IS NULL OR id_municipio = '', 'DQ003_ID_MUNICIPIO_AUSENTE', NULL),
      IF(id_municipio IS NOT NULL AND NOT REGEXP_CONTAINS(id_municipio, r'^\d{7}$'), 'DQ004_ID_MUNICIPIO_INVALIDO', NULL),
      IF(id_escola IS NULL OR id_escola = '', 'DQ005_ID_ESCOLA_AUSENTE', NULL),
      IF(id_aluno IS NULL OR id_aluno = '', 'DQ006_ID_ALUNO_AUSENTE', NULL),
      IF(caderno_codigo IS NULL OR caderno_codigo = '', 'DQ007_CADERNO_AUSENTE', NULL),
      IF(serie_nome IS NULL, 'DQ008_SERIE_NAO_MAPEADA', NULL),
      IF(rede_nome IS NULL, 'DQ009_REDE_NAO_MAPEADA', NULL),
      IF(presenca_nome IS NULL, 'DQ010_PRESENCA_NAO_MAPEADA', NULL),
      IF(preenchimento_caderno_nome IS NULL, 'DQ011_PREENCHIMENTO_NAO_MAPEADO', NULL),
      IF(alfabetizado_nome IS NULL, 'DQ012_ALFABETIZADO_NAO_MAPEADO', NULL),
      IF(proficiencia IS NOT NULL AND proficiencia < 0, 'DQ013_PROFICIENCIA_NEGATIVA', NULL),
      IF(peso_aluno IS NOT NULL AND peso_aluno <= 0, 'DQ014_PESO_ALUNO_NAO_POSITIVO', NULL),
      IF(rn > 1, 'DQ015_CHAVE_ALUNO_DUPLICADA', NULL)
    ]) AS rule
    WHERE rule IS NOT NULL
  ) AS critical_rules,
  ARRAY(
    SELECT rule
    FROM UNNEST([
      IF(presenca_codigo = '1' AND preenchimento_caderno_codigo = '1' AND proficiencia IS NULL,
         'DQ101_PRESENTE_COM_PROVA_SEM_PROFICIENCIA', NULL),
      IF(presenca_codigo = '0' AND proficiencia IS NOT NULL,
         'DQ102_AUSENTE_COM_PROFICIENCIA', NULL),
      IF(presenca_codigo = '0' AND alfabetizado_codigo = '1',
         'DQ103_AUSENTE_MARCADO_ALFABETIZADO', NULL),
      IF(proficiencia IS NOT NULL AND proficiencia >= 743 AND alfabetizado_codigo = '0',
         'DQ104_PROFICIENCIA_ACIMA_CORTE_NAO_ALFABETIZADO', NULL),
      IF(proficiencia IS NOT NULL AND proficiencia < 743 AND alfabetizado_codigo = '1',
         'DQ105_PROFICIENCIA_ABAIXO_CORTE_ALFABETIZADO', NULL),
      IF(presenca_codigo = '1' AND peso_aluno IS NULL,
         'DQ106_PRESENTE_SEM_PESO_ALUNO', NULL)
    ]) AS rule
    WHERE rule IS NOT NULL
  ) AS alert_rules
FROM ranked;

CREATE OR REPLACE TABLE `__PROJECT_ID__.alfabetizacao_silver.alunos`
PARTITION BY ano_referencia
CLUSTER BY id_municipio, rede_nome, id_escola
OPTIONS(description='Microdados de alunos tratados, tipados, decodificados e deduplicados.') AS
SELECT
  * EXCEPT(critical_rules, alert_rules, rn),
  IF(ARRAY_LENGTH(alert_rules) = 0, 'VALID', 'ALERT') AS quality_status,
  alert_rules AS quality_alerts,
  CURRENT_TIMESTAMP() AS silver_processed_at
FROM stg_alunos
WHERE ARRAY_LENGTH(critical_rules) = 0;

-- ================================================================
-- 3. RESULTADOS POR MUNICÍPIO
-- ================================================================

CREATE TEMP TABLE stg_resultado_municipio AS
WITH base AS (
  SELECT
    m.ano,
    DATE(m.ano, 1, 1) AS ano_referencia,
    TRIM(m.id_municipio) AS id_municipio,
    TRIM(m.serie) AS serie_codigo,
    d_serie.valor AS serie_nome,
    TRIM(m.rede) AS rede_codigo,
    d_rede.valor AS rede_nome,
    CASE
      WHEN d_rede.valor IN ('Federal', 'Estadual', 'Municipal',
                            'Pública (Estadual e Municipal)',
                            'Pública (Federal, Estadual e Municipal)') THEN 'Pública'
      WHEN d_rede.valor = 'Privada' THEN 'Privada'
      WHEN STARTS_WITH(d_rede.valor, 'Total') THEN 'Total'
      ELSE d_rede.valor
    END AS rede_agrupada,
    m.taxa_alfabetizacao,
    m.media_portugues,
    m.proporcao_aluno_nivel_0,
    m.proporcao_aluno_nivel_1,
    m.proporcao_aluno_nivel_2,
    m.proporcao_aluno_nivel_3,
    m.proporcao_aluno_nivel_4,
    m.proporcao_aluno_nivel_5,
    m.proporcao_aluno_nivel_6,
    m.proporcao_aluno_nivel_7,
    m.proporcao_aluno_nivel_8,
    (SELECT COUNTIF(x IS NOT NULL)
       FROM UNNEST([
         m.proporcao_aluno_nivel_0, m.proporcao_aluno_nivel_1,
         m.proporcao_aluno_nivel_2, m.proporcao_aluno_nivel_3,
         m.proporcao_aluno_nivel_4, m.proporcao_aluno_nivel_5,
         m.proporcao_aluno_nivel_6, m.proporcao_aluno_nivel_7,
         m.proporcao_aluno_nivel_8
       ]) AS x) AS quantidade_niveis_preenchidos,
    (SELECT SUM(COALESCE(x, 0))
       FROM UNNEST([
         m.proporcao_aluno_nivel_0, m.proporcao_aluno_nivel_1,
         m.proporcao_aluno_nivel_2, m.proporcao_aluno_nivel_3,
         m.proporcao_aluno_nivel_4, m.proporcao_aluno_nivel_5,
         m.proporcao_aluno_nivel_6, m.proporcao_aluno_nivel_7,
         m.proporcao_aluno_nivel_8
       ]) AS x) AS soma_proporcoes_niveis,
    m._ingestion_timestamp AS source_ingestion_timestamp,
    m._batch_id AS source_batch_id,
    m._source_table AS source_table,
    m.ingestion_date,
    m.batch_id
  FROM `__PROJECT_ID__.alfabetizacao_bronze.ext_municipio` AS m
  LEFT JOIN `__PROJECT_ID__.alfabetizacao_silver.dim_dicionario` AS d_serie
    ON d_serie.id_tabela = 'municipio'
   AND d_serie.nome_coluna = 'serie'
   AND d_serie.chave = TRIM(m.serie)
  LEFT JOIN `__PROJECT_ID__.alfabetizacao_silver.dim_dicionario` AS d_rede
    ON d_rede.id_tabela = 'municipio'
   AND d_rede.nome_coluna = 'rede'
   AND d_rede.chave = TRIM(m.rede)
  WHERE m.ingestion_date = v_ingestion_date
    AND m.batch_id = v_batch_id
), ranked AS (
  SELECT
    *,
    ROW_NUMBER() OVER (
      PARTITION BY ano, id_municipio, serie_codigo, rede_codigo
      ORDER BY source_ingestion_timestamp DESC
    ) AS rn
  FROM base
)
SELECT
  *,
  ARRAY(
    SELECT rule
    FROM UNNEST([
      IF(ano IS NULL, 'DQ001_ANO_AUSENTE', NULL),
      IF(id_municipio IS NULL OR id_municipio = '', 'DQ003_ID_MUNICIPIO_AUSENTE', NULL),
      IF(id_municipio IS NOT NULL AND NOT REGEXP_CONTAINS(id_municipio, r'^\d{7}$'), 'DQ004_ID_MUNICIPIO_INVALIDO', NULL),
      IF(serie_nome IS NULL, 'DQ008_SERIE_NAO_MAPEADA', NULL),
      IF(rede_nome IS NULL, 'DQ009_REDE_NAO_MAPEADA', NULL),
      IF(taxa_alfabetizacao IS NOT NULL AND (taxa_alfabetizacao < 0 OR taxa_alfabetizacao > 100), 'DQ020_TAXA_FORA_INTERVALO', NULL),
      IF(media_portugues IS NOT NULL AND media_portugues < 0, 'DQ021_MEDIA_PORTUGUES_NEGATIVA', NULL),
      IF(EXISTS(
           SELECT 1 FROM UNNEST([
             proporcao_aluno_nivel_0, proporcao_aluno_nivel_1,
             proporcao_aluno_nivel_2, proporcao_aluno_nivel_3,
             proporcao_aluno_nivel_4, proporcao_aluno_nivel_5,
             proporcao_aluno_nivel_6, proporcao_aluno_nivel_7,
             proporcao_aluno_nivel_8
           ]) x WHERE x IS NOT NULL AND (x < 0 OR x > 100)
         ), 'DQ022_PROPORCAO_NIVEL_FORA_INTERVALO', NULL),
      IF(rn > 1, 'DQ023_CHAVE_RESULTADO_MUNICIPIO_DUPLICADA', NULL)
    ]) AS rule
    WHERE rule IS NOT NULL
  ) AS critical_rules,
  ARRAY(
    SELECT rule
    FROM UNNEST([
      IF(taxa_alfabetizacao IS NULL, 'DQ110_TAXA_ALFABETIZACAO_AUSENTE', NULL),
      IF(media_portugues IS NULL, 'DQ111_MEDIA_PORTUGUES_AUSENTE', NULL),
      IF(quantidade_niveis_preenchidos = 0, 'DQ112_NIVEIS_NAO_INFORMADOS', NULL),
      IF(quantidade_niveis_preenchidos BETWEEN 1 AND 8, 'DQ113_NIVEIS_PARCIALMENTE_INFORMADOS', NULL),
      IF(quantidade_niveis_preenchidos = 9
         AND (soma_proporcoes_niveis < 99.9 OR soma_proporcoes_niveis > 100.1),
         'DQ114_SOMA_NIVEIS_FORA_TOLERANCIA', NULL)
    ]) AS rule
    WHERE rule IS NOT NULL
  ) AS alert_rules
FROM ranked;

CREATE OR REPLACE TABLE `__PROJECT_ID__.alfabetizacao_silver.resultado_municipio`
PARTITION BY ano_referencia
CLUSTER BY id_municipio, rede_codigo
OPTIONS(description='Indicadores municipais tratados, decodificados e validados.') AS
SELECT
  * EXCEPT(critical_rules, alert_rules, rn),
  IF(ARRAY_LENGTH(alert_rules) = 0, 'VALID', 'ALERT') AS quality_status,
  alert_rules AS quality_alerts,
  CURRENT_TIMESTAMP() AS silver_processed_at
FROM stg_resultado_municipio
WHERE ARRAY_LENGTH(critical_rules) = 0;

-- ================================================================
-- 4. RESULTADOS POR UF
-- ================================================================

CREATE TEMP TABLE stg_resultado_uf AS
WITH base AS (
  SELECT
    u.ano,
    DATE(u.ano, 1, 1) AS ano_referencia,
    UPPER(TRIM(u.sigla_uf)) AS sigla_uf,
    TRIM(u.serie) AS serie_codigo,
    d_serie.valor AS serie_nome,
    TRIM(u.rede) AS rede_codigo,
    d_rede.valor AS rede_nome,
    CASE
      WHEN d_rede.valor IN ('Federal', 'Estadual', 'Municipal',
                            'Pública (Estadual e Municipal)',
                            'Pública (Federal, Estadual e Municipal)') THEN 'Pública'
      WHEN d_rede.valor = 'Privada' THEN 'Privada'
      WHEN STARTS_WITH(d_rede.valor, 'Total') THEN 'Total'
      ELSE d_rede.valor
    END AS rede_agrupada,
    u.taxa_alfabetizacao,
    u.media_portugues,
    u.proporcao_aluno_nivel_0,
    u.proporcao_aluno_nivel_1,
    u.proporcao_aluno_nivel_2,
    u.proporcao_aluno_nivel_3,
    u.proporcao_aluno_nivel_4,
    u.proporcao_aluno_nivel_5,
    u.proporcao_aluno_nivel_6,
    u.proporcao_aluno_nivel_7,
    u.proporcao_aluno_nivel_8,
    (SELECT COUNTIF(x IS NOT NULL)
       FROM UNNEST([
         u.proporcao_aluno_nivel_0, u.proporcao_aluno_nivel_1,
         u.proporcao_aluno_nivel_2, u.proporcao_aluno_nivel_3,
         u.proporcao_aluno_nivel_4, u.proporcao_aluno_nivel_5,
         u.proporcao_aluno_nivel_6, u.proporcao_aluno_nivel_7,
         u.proporcao_aluno_nivel_8
       ]) AS x) AS quantidade_niveis_preenchidos,
    (SELECT SUM(COALESCE(x, 0))
       FROM UNNEST([
         u.proporcao_aluno_nivel_0, u.proporcao_aluno_nivel_1,
         u.proporcao_aluno_nivel_2, u.proporcao_aluno_nivel_3,
         u.proporcao_aluno_nivel_4, u.proporcao_aluno_nivel_5,
         u.proporcao_aluno_nivel_6, u.proporcao_aluno_nivel_7,
         u.proporcao_aluno_nivel_8
       ]) AS x) AS soma_proporcoes_niveis,
    u._ingestion_timestamp AS source_ingestion_timestamp,
    u._batch_id AS source_batch_id,
    u._source_table AS source_table,
    u.ingestion_date,
    u.batch_id
  FROM `__PROJECT_ID__.alfabetizacao_bronze.ext_uf` AS u
  LEFT JOIN `__PROJECT_ID__.alfabetizacao_silver.dim_dicionario` AS d_serie
    ON d_serie.id_tabela = 'uf'
   AND d_serie.nome_coluna = 'serie'
   AND d_serie.chave = TRIM(u.serie)
  LEFT JOIN `__PROJECT_ID__.alfabetizacao_silver.dim_dicionario` AS d_rede
    ON d_rede.id_tabela = 'uf'
   AND d_rede.nome_coluna = 'rede'
   AND d_rede.chave = TRIM(u.rede)
  WHERE u.ingestion_date = v_ingestion_date
    AND u.batch_id = v_batch_id
), ranked AS (
  SELECT
    *,
    ROW_NUMBER() OVER (
      PARTITION BY ano, sigla_uf, serie_codigo, rede_codigo
      ORDER BY source_ingestion_timestamp DESC
    ) AS rn
  FROM base
)
SELECT
  *,
  ARRAY(
    SELECT rule
    FROM UNNEST([
      IF(ano IS NULL, 'DQ001_ANO_AUSENTE', NULL),
      IF(sigla_uf IS NULL OR sigla_uf = '', 'DQ030_SIGLA_UF_AUSENTE', NULL),
      IF(sigla_uf IS NOT NULL AND sigla_uf NOT IN
         ('AC','AL','AP','AM','BA','CE','DF','ES','GO','MA','MT','MS','MG','PA','PB','PR','PE','PI','RJ','RN','RS','RO','RR','SC','SP','SE','TO'),
         'DQ031_SIGLA_UF_INVALIDA', NULL),
      IF(serie_nome IS NULL, 'DQ008_SERIE_NAO_MAPEADA', NULL),
      IF(rede_nome IS NULL, 'DQ009_REDE_NAO_MAPEADA', NULL),
      IF(taxa_alfabetizacao IS NOT NULL AND (taxa_alfabetizacao < 0 OR taxa_alfabetizacao > 100), 'DQ020_TAXA_FORA_INTERVALO', NULL),
      IF(media_portugues IS NOT NULL AND media_portugues < 0, 'DQ021_MEDIA_PORTUGUES_NEGATIVA', NULL),
      IF(EXISTS(
           SELECT 1 FROM UNNEST([
             proporcao_aluno_nivel_0, proporcao_aluno_nivel_1,
             proporcao_aluno_nivel_2, proporcao_aluno_nivel_3,
             proporcao_aluno_nivel_4, proporcao_aluno_nivel_5,
             proporcao_aluno_nivel_6, proporcao_aluno_nivel_7,
             proporcao_aluno_nivel_8
           ]) x WHERE x IS NOT NULL AND (x < 0 OR x > 100)
         ), 'DQ022_PROPORCAO_NIVEL_FORA_INTERVALO', NULL),
      IF(rn > 1, 'DQ032_CHAVE_RESULTADO_UF_DUPLICADA', NULL)
    ]) AS rule
    WHERE rule IS NOT NULL
  ) AS critical_rules,
  ARRAY(
    SELECT rule
    FROM UNNEST([
      IF(taxa_alfabetizacao IS NULL, 'DQ110_TAXA_ALFABETIZACAO_AUSENTE', NULL),
      IF(media_portugues IS NULL, 'DQ111_MEDIA_PORTUGUES_AUSENTE', NULL),
      IF(quantidade_niveis_preenchidos = 0, 'DQ112_NIVEIS_NAO_INFORMADOS', NULL),
      IF(quantidade_niveis_preenchidos BETWEEN 1 AND 8, 'DQ113_NIVEIS_PARCIALMENTE_INFORMADOS', NULL),
      IF(quantidade_niveis_preenchidos = 9
         AND (soma_proporcoes_niveis < 99.9 OR soma_proporcoes_niveis > 100.1),
         'DQ114_SOMA_NIVEIS_FORA_TOLERANCIA', NULL)
    ]) AS rule
    WHERE rule IS NOT NULL
  ) AS alert_rules
FROM ranked;

CREATE OR REPLACE TABLE `__PROJECT_ID__.alfabetizacao_silver.resultado_uf`
PARTITION BY ano_referencia
CLUSTER BY sigla_uf, rede_codigo
OPTIONS(description='Indicadores estaduais tratados, decodificados e validados.') AS
SELECT
  * EXCEPT(critical_rules, alert_rules, rn),
  IF(ARRAY_LENGTH(alert_rules) = 0, 'VALID', 'ALERT') AS quality_status,
  alert_rules AS quality_alerts,
  CURRENT_TIMESTAMP() AS silver_processed_at
FROM stg_resultado_uf
WHERE ARRAY_LENGTH(critical_rules) = 0;

-- ================================================================
-- 5. METAS EM FORMATO LONGO
-- ================================================================

CREATE TEMP TABLE stg_meta_brasil AS
WITH expanded AS (
  SELECT
    b.ano,
    DATE(b.ano, 1, 1) AS ano_referencia,
    CASE LOWER(TRIM(b.rede))
      WHEN 'pública' THEN 'Pública'
      WHEN 'municipal' THEN 'Municipal'
      ELSE TRIM(b.rede)
    END AS rede_normalizada,
    b.taxa_alfabetizacao,
    meta.ano_meta,
    meta.meta_alfabetizacao,
    b.percentual_participacao,
    b._ingestion_timestamp AS source_ingestion_timestamp,
    b._batch_id AS source_batch_id,
    b._source_table AS source_table,
    b.ingestion_date,
    b.batch_id
  FROM `__PROJECT_ID__.alfabetizacao_bronze.ext_meta_alfabetizacao_brasil` AS b
  CROSS JOIN UNNEST([
    STRUCT(2024 AS ano_meta, b.meta_alfabetizacao_2024 AS meta_alfabetizacao),
    STRUCT(2025 AS ano_meta, b.meta_alfabetizacao_2025 AS meta_alfabetizacao),
    STRUCT(2026 AS ano_meta, b.meta_alfabetizacao_2026 AS meta_alfabetizacao),
    STRUCT(2027 AS ano_meta, b.meta_alfabetizacao_2027 AS meta_alfabetizacao),
    STRUCT(2028 AS ano_meta, b.meta_alfabetizacao_2028 AS meta_alfabetizacao),
    STRUCT(2029 AS ano_meta, b.meta_alfabetizacao_2029 AS meta_alfabetizacao),
    STRUCT(2030 AS ano_meta, b.meta_alfabetizacao_2030 AS meta_alfabetizacao)
  ]) AS meta
  WHERE b.ingestion_date = v_ingestion_date
    AND b.batch_id = v_batch_id
), ranked AS (
  SELECT *, ROW_NUMBER() OVER (
    PARTITION BY ano, rede_normalizada, ano_meta
    ORDER BY source_ingestion_timestamp DESC
  ) AS rn
  FROM expanded
)
SELECT
  *,
  ARRAY(
    SELECT rule FROM UNNEST([
      IF(ano IS NULL, 'DQ001_ANO_AUSENTE', NULL),
      IF(rede_normalizada IS NULL OR rede_normalizada = '', 'DQ040_REDE_META_AUSENTE', NULL),
      IF(taxa_alfabetizacao IS NOT NULL AND (taxa_alfabetizacao < 0 OR taxa_alfabetizacao > 100), 'DQ020_TAXA_FORA_INTERVALO', NULL),
      IF(meta_alfabetizacao IS NOT NULL AND (meta_alfabetizacao < 0 OR meta_alfabetizacao > 100), 'DQ041_META_FORA_INTERVALO', NULL),
      IF(percentual_participacao IS NOT NULL AND (percentual_participacao < 0 OR percentual_participacao > 100), 'DQ042_PARTICIPACAO_FORA_INTERVALO', NULL),
      IF(rn > 1, 'DQ043_CHAVE_META_BRASIL_DUPLICADA', NULL)
    ]) rule WHERE rule IS NOT NULL
  ) AS critical_rules,
  ARRAY(
    SELECT rule FROM UNNEST([
      IF(rede_normalizada != 'Pública', 'DQ120_REDE_META_BRASIL_INESPERADA', NULL),
      IF(taxa_alfabetizacao IS NULL, 'DQ110_TAXA_ALFABETIZACAO_AUSENTE', NULL),
      IF(meta_alfabetizacao IS NULL, 'DQ121_META_ALFABETIZACAO_AUSENTE', NULL),
      IF(percentual_participacao IS NULL, 'DQ122_PARTICIPACAO_AUSENTE', NULL)
    ]) rule WHERE rule IS NOT NULL
  ) AS alert_rules
FROM ranked;

CREATE TEMP TABLE stg_meta_uf AS
WITH expanded AS (
  SELECT
    u.ano,
    DATE(u.ano, 1, 1) AS ano_referencia,
    UPPER(TRIM(u.sigla_uf)) AS sigla_uf,
    CASE LOWER(TRIM(u.rede))
      WHEN 'pública' THEN 'Pública'
      WHEN 'municipal' THEN 'Municipal'
      ELSE TRIM(u.rede)
    END AS rede_normalizada,
    u.taxa_alfabetizacao,
    meta.ano_meta,
    meta.meta_alfabetizacao,
    u.percentual_participacao,
    u._ingestion_timestamp AS source_ingestion_timestamp,
    u._batch_id AS source_batch_id,
    u._source_table AS source_table,
    u.ingestion_date,
    u.batch_id
  FROM `__PROJECT_ID__.alfabetizacao_bronze.ext_meta_alfabetizacao_uf` AS u
  CROSS JOIN UNNEST([
    STRUCT(2024 AS ano_meta, u.meta_alfabetizacao_2024 AS meta_alfabetizacao),
    STRUCT(2025 AS ano_meta, u.meta_alfabetizacao_2025 AS meta_alfabetizacao),
    STRUCT(2026 AS ano_meta, u.meta_alfabetizacao_2026 AS meta_alfabetizacao),
    STRUCT(2027 AS ano_meta, u.meta_alfabetizacao_2027 AS meta_alfabetizacao),
    STRUCT(2028 AS ano_meta, u.meta_alfabetizacao_2028 AS meta_alfabetizacao),
    STRUCT(2029 AS ano_meta, u.meta_alfabetizacao_2029 AS meta_alfabetizacao),
    STRUCT(2030 AS ano_meta, u.meta_alfabetizacao_2030 AS meta_alfabetizacao)
  ]) AS meta
  WHERE u.ingestion_date = v_ingestion_date
    AND u.batch_id = v_batch_id
), ranked AS (
  SELECT *, ROW_NUMBER() OVER (
    PARTITION BY ano, sigla_uf, rede_normalizada, ano_meta
    ORDER BY source_ingestion_timestamp DESC
  ) AS rn
  FROM expanded
)
SELECT
  *,
  ARRAY(
    SELECT rule FROM UNNEST([
      IF(ano IS NULL, 'DQ001_ANO_AUSENTE', NULL),
      IF(sigla_uf IS NULL OR sigla_uf = '', 'DQ030_SIGLA_UF_AUSENTE', NULL),
      IF(sigla_uf IS NOT NULL AND sigla_uf NOT IN
         ('AC','AL','AP','AM','BA','CE','DF','ES','GO','MA','MT','MS','MG','PA','PB','PR','PE','PI','RJ','RN','RS','RO','RR','SC','SP','SE','TO'),
         'DQ031_SIGLA_UF_INVALIDA', NULL),
      IF(rede_normalizada IS NULL OR rede_normalizada = '', 'DQ040_REDE_META_AUSENTE', NULL),
      IF(taxa_alfabetizacao IS NOT NULL AND (taxa_alfabetizacao < 0 OR taxa_alfabetizacao > 100), 'DQ020_TAXA_FORA_INTERVALO', NULL),
      IF(meta_alfabetizacao IS NOT NULL AND (meta_alfabetizacao < 0 OR meta_alfabetizacao > 100), 'DQ041_META_FORA_INTERVALO', NULL),
      IF(percentual_participacao IS NOT NULL AND (percentual_participacao < 0 OR percentual_participacao > 100), 'DQ042_PARTICIPACAO_FORA_INTERVALO', NULL),
      IF(rn > 1, 'DQ044_CHAVE_META_UF_DUPLICADA', NULL)
    ]) rule WHERE rule IS NOT NULL
  ) AS critical_rules,
  ARRAY(
    SELECT rule FROM UNNEST([
      IF(rede_normalizada != 'Pública', 'DQ123_REDE_META_UF_INESPERADA', NULL),
      IF(taxa_alfabetizacao IS NULL, 'DQ110_TAXA_ALFABETIZACAO_AUSENTE', NULL),
      IF(meta_alfabetizacao IS NULL, 'DQ121_META_ALFABETIZACAO_AUSENTE', NULL),
      IF(percentual_participacao IS NULL, 'DQ122_PARTICIPACAO_AUSENTE', NULL)
    ]) rule WHERE rule IS NOT NULL
  ) AS alert_rules
FROM ranked;

CREATE TEMP TABLE stg_meta_municipio AS
WITH expanded AS (
  SELECT
    m.ano,
    DATE(m.ano, 1, 1) AS ano_referencia,
    TRIM(m.id_municipio) AS id_municipio,
    CASE LOWER(TRIM(m.rede))
      WHEN 'pública' THEN 'Pública'
      WHEN 'municipal' THEN 'Municipal'
      ELSE TRIM(m.rede)
    END AS rede_normalizada,
    m.taxa_alfabetizacao,
    meta.ano_meta,
    meta.meta_alfabetizacao,
    m.nivel_alfabetizacao,
    m.percentual_participacao,
    m._ingestion_timestamp AS source_ingestion_timestamp,
    m._batch_id AS source_batch_id,
    m._source_table AS source_table,
    m.ingestion_date,
    m.batch_id
  FROM `__PROJECT_ID__.alfabetizacao_bronze.ext_meta_alfabetizacao_municipio` AS m
  CROSS JOIN UNNEST([
    STRUCT(2024 AS ano_meta, m.meta_alfabetizacao_2024 AS meta_alfabetizacao),
    STRUCT(2025 AS ano_meta, m.meta_alfabetizacao_2025 AS meta_alfabetizacao),
    STRUCT(2026 AS ano_meta, m.meta_alfabetizacao_2026 AS meta_alfabetizacao),
    STRUCT(2027 AS ano_meta, m.meta_alfabetizacao_2027 AS meta_alfabetizacao),
    STRUCT(2028 AS ano_meta, m.meta_alfabetizacao_2028 AS meta_alfabetizacao),
    STRUCT(2029 AS ano_meta, m.meta_alfabetizacao_2029 AS meta_alfabetizacao),
    STRUCT(2030 AS ano_meta, m.meta_alfabetizacao_2030 AS meta_alfabetizacao)
  ]) AS meta
  WHERE m.ingestion_date = v_ingestion_date
    AND m.batch_id = v_batch_id
), ranked AS (
  SELECT *, ROW_NUMBER() OVER (
    PARTITION BY ano, id_municipio, rede_normalizada, ano_meta
    ORDER BY source_ingestion_timestamp DESC
  ) AS rn
  FROM expanded
)
SELECT
  *,
  ARRAY(
    SELECT rule FROM UNNEST([
      IF(ano IS NULL, 'DQ001_ANO_AUSENTE', NULL),
      IF(id_municipio IS NULL OR id_municipio = '', 'DQ003_ID_MUNICIPIO_AUSENTE', NULL),
      IF(id_municipio IS NOT NULL AND NOT REGEXP_CONTAINS(id_municipio, r'^\d{7}$'), 'DQ004_ID_MUNICIPIO_INVALIDO', NULL),
      IF(rede_normalizada IS NULL OR rede_normalizada = '', 'DQ040_REDE_META_AUSENTE', NULL),
      IF(taxa_alfabetizacao IS NOT NULL AND (taxa_alfabetizacao < 0 OR taxa_alfabetizacao > 100), 'DQ020_TAXA_FORA_INTERVALO', NULL),
      IF(meta_alfabetizacao IS NOT NULL AND (meta_alfabetizacao < 0 OR meta_alfabetizacao > 100), 'DQ041_META_FORA_INTERVALO', NULL),
      IF(nivel_alfabetizacao IS NOT NULL AND nivel_alfabetizacao < 0, 'DQ045_NIVEL_ALFABETIZACAO_NEGATIVO', NULL),
      IF(percentual_participacao IS NOT NULL AND (percentual_participacao < 0 OR percentual_participacao > 100), 'DQ042_PARTICIPACAO_FORA_INTERVALO', NULL),
      IF(rn > 1, 'DQ046_CHAVE_META_MUNICIPIO_DUPLICADA', NULL)
    ]) rule WHERE rule IS NOT NULL
  ) AS critical_rules,
  ARRAY(
    SELECT rule FROM UNNEST([
      IF(rede_normalizada != 'Municipal', 'DQ124_REDE_META_MUNICIPIO_INESPERADA', NULL),
      IF(taxa_alfabetizacao IS NULL, 'DQ110_TAXA_ALFABETIZACAO_AUSENTE', NULL),
      IF(meta_alfabetizacao IS NULL, 'DQ121_META_ALFABETIZACAO_AUSENTE', NULL),
      IF(nivel_alfabetizacao IS NULL, 'DQ125_NIVEL_ALFABETIZACAO_AUSENTE', NULL),
      IF(percentual_participacao IS NULL, 'DQ122_PARTICIPACAO_AUSENTE', NULL)
    ]) rule WHERE rule IS NOT NULL
  ) AS alert_rules
FROM ranked;

CREATE OR REPLACE TABLE `__PROJECT_ID__.alfabetizacao_silver.meta_brasil`
PARTITION BY ano_referencia
CLUSTER BY rede_normalizada, ano_meta
OPTIONS(description='Metas nacionais em formato longo, com uma linha por ano da meta.') AS
SELECT
  * EXCEPT(critical_rules, alert_rules, rn),
  IF(ARRAY_LENGTH(alert_rules) = 0, 'VALID', 'ALERT') AS quality_status,
  alert_rules AS quality_alerts,
  CURRENT_TIMESTAMP() AS silver_processed_at
FROM stg_meta_brasil
WHERE ARRAY_LENGTH(critical_rules) = 0;

CREATE OR REPLACE TABLE `__PROJECT_ID__.alfabetizacao_silver.meta_uf`
PARTITION BY ano_referencia
CLUSTER BY sigla_uf, rede_normalizada, ano_meta
OPTIONS(description='Metas estaduais em formato longo, com uma linha por UF e ano da meta.') AS
SELECT
  * EXCEPT(critical_rules, alert_rules, rn),
  IF(ARRAY_LENGTH(alert_rules) = 0, 'VALID', 'ALERT') AS quality_status,
  alert_rules AS quality_alerts,
  CURRENT_TIMESTAMP() AS silver_processed_at
FROM stg_meta_uf
WHERE ARRAY_LENGTH(critical_rules) = 0;

CREATE OR REPLACE TABLE `__PROJECT_ID__.alfabetizacao_silver.meta_municipio`
PARTITION BY ano_referencia
CLUSTER BY id_municipio, rede_normalizada, ano_meta
OPTIONS(description='Metas municipais em formato longo, com uma linha por município e ano da meta.') AS
SELECT
  * EXCEPT(critical_rules, alert_rules, rn),
  IF(ARRAY_LENGTH(alert_rules) = 0, 'VALID', 'ALERT') AS quality_status,
  alert_rules AS quality_alerts,
  CURRENT_TIMESTAMP() AS silver_processed_at
FROM stg_meta_municipio
WHERE ARRAY_LENGTH(critical_rules) = 0;

-- ================================================================
-- 6. QUARENTENA UNIFICADA
-- ================================================================

CREATE OR REPLACE TABLE `__PROJECT_ID__.alfabetizacao_quarantine.records`
PARTITION BY ingestion_date
CLUSTER BY source_table, batch_id
OPTIONS(description='Registros rejeitados por regras críticas de qualidade.') AS
SELECT
  'dicionario' AS source_table,
  ingestion_date,
  batch_id,
  CONCAT(COALESCE(id_tabela, ''), '|', COALESCE(nome_coluna, ''), '|', COALESCE(chave, '')) AS record_key,
  'CRITICAL' AS quality_severity,
  critical_rules AS quality_rules,
  CONCAT('Registro rejeitado pelas regras: ', ARRAY_TO_STRING(critical_rules, '; ')) AS quality_message,
  TO_JSON_STRING((SELECT AS STRUCT s.* EXCEPT(critical_rules, alert_rules, rn))) AS payload_json,
  CURRENT_TIMESTAMP() AS detected_at
FROM stg_dicionario AS s
WHERE ARRAY_LENGTH(critical_rules) > 0

UNION ALL

SELECT
  'alunos', ingestion_date, batch_id,
  CONCAT(CAST(ano AS STRING), '|', COALESCE(id_aluno, '')),
  'CRITICAL', critical_rules,
  CONCAT('Registro rejeitado pelas regras: ', ARRAY_TO_STRING(critical_rules, '; ')),
  TO_JSON_STRING((SELECT AS STRUCT s.* EXCEPT(critical_rules, alert_rules, rn))),
  CURRENT_TIMESTAMP()
FROM stg_alunos AS s
WHERE ARRAY_LENGTH(critical_rules) > 0

UNION ALL

SELECT
  'municipio', ingestion_date, batch_id,
  CONCAT(CAST(ano AS STRING), '|', COALESCE(id_municipio, ''), '|', COALESCE(serie_codigo, ''), '|', COALESCE(rede_codigo, '')),
  'CRITICAL', critical_rules,
  CONCAT('Registro rejeitado pelas regras: ', ARRAY_TO_STRING(critical_rules, '; ')),
  TO_JSON_STRING((SELECT AS STRUCT s.* EXCEPT(critical_rules, alert_rules, rn))),
  CURRENT_TIMESTAMP()
FROM stg_resultado_municipio AS s
WHERE ARRAY_LENGTH(critical_rules) > 0

UNION ALL

SELECT
  'uf', ingestion_date, batch_id,
  CONCAT(CAST(ano AS STRING), '|', COALESCE(sigla_uf, ''), '|', COALESCE(serie_codigo, ''), '|', COALESCE(rede_codigo, '')),
  'CRITICAL', critical_rules,
  CONCAT('Registro rejeitado pelas regras: ', ARRAY_TO_STRING(critical_rules, '; ')),
  TO_JSON_STRING((SELECT AS STRUCT s.* EXCEPT(critical_rules, alert_rules, rn))),
  CURRENT_TIMESTAMP()
FROM stg_resultado_uf AS s
WHERE ARRAY_LENGTH(critical_rules) > 0

UNION ALL

SELECT
  'meta_alfabetizacao_brasil', ingestion_date, batch_id,
  CONCAT(CAST(ano AS STRING), '|', COALESCE(rede_normalizada, ''), '|', CAST(ano_meta AS STRING)),
  'CRITICAL', critical_rules,
  CONCAT('Registro rejeitado pelas regras: ', ARRAY_TO_STRING(critical_rules, '; ')),
  TO_JSON_STRING((SELECT AS STRUCT s.* EXCEPT(critical_rules, alert_rules, rn))),
  CURRENT_TIMESTAMP()
FROM stg_meta_brasil AS s
WHERE ARRAY_LENGTH(critical_rules) > 0

UNION ALL

SELECT
  'meta_alfabetizacao_uf', ingestion_date, batch_id,
  CONCAT(CAST(ano AS STRING), '|', COALESCE(sigla_uf, ''), '|', COALESCE(rede_normalizada, ''), '|', CAST(ano_meta AS STRING)),
  'CRITICAL', critical_rules,
  CONCAT('Registro rejeitado pelas regras: ', ARRAY_TO_STRING(critical_rules, '; ')),
  TO_JSON_STRING((SELECT AS STRUCT s.* EXCEPT(critical_rules, alert_rules, rn))),
  CURRENT_TIMESTAMP()
FROM stg_meta_uf AS s
WHERE ARRAY_LENGTH(critical_rules) > 0

UNION ALL

SELECT
  'meta_alfabetizacao_municipio', ingestion_date, batch_id,
  CONCAT(CAST(ano AS STRING), '|', COALESCE(id_municipio, ''), '|', COALESCE(rede_normalizada, ''), '|', CAST(ano_meta AS STRING)),
  'CRITICAL', critical_rules,
  CONCAT('Registro rejeitado pelas regras: ', ARRAY_TO_STRING(critical_rules, '; ')),
  TO_JSON_STRING((SELECT AS STRUCT s.* EXCEPT(critical_rules, alert_rules, rn))),
  CURRENT_TIMESTAMP()
FROM stg_meta_municipio AS s
WHERE ARRAY_LENGTH(critical_rules) > 0;

-- ================================================================
-- 7. AGREGAÇÃO DOS MICRODADOS E INTEGRAÇÕES SILVER
-- ================================================================

CREATE OR REPLACE TABLE `__PROJECT_ID__.alfabetizacao_silver.agg_alunos_municipio`
PARTITION BY ano_referencia
CLUSTER BY id_municipio, rede_nome
OPTIONS(description='Microdados agregados por ano, município e rede para integração analítica.') AS
SELECT
  ano,
  ano_referencia,
  id_municipio,
  rede_codigo,
  rede_nome,
  rede_agrupada,
  COUNT(*) AS quantidade_alunos,
  COUNTIF(presenca_codigo = '1') AS quantidade_presentes,
  COUNTIF(preenchimento_caderno_codigo = '1') AS quantidade_provas_preenchidas,
  COUNTIF(alfabetizado_codigo = '1') AS quantidade_alfabetizados,
  SAFE_DIVIDE(COUNTIF(presenca_codigo = '1'), COUNT(*)) * 100 AS taxa_presenca,
  SAFE_DIVIDE(COUNTIF(preenchimento_caderno_codigo = '1'), COUNT(*)) * 100 AS taxa_preenchimento,
  SAFE_DIVIDE(COUNTIF(alfabetizado_codigo = '1'), COUNT(*)) * 100 AS taxa_alfabetizacao_calculada,
  AVG(IF(presenca_codigo = '1', proficiencia, NULL)) AS proficiencia_media,
  SAFE_DIVIDE(
    SUM(IF(presenca_codigo = '1', proficiencia * peso_aluno, NULL)),
    SUM(IF(presenca_codigo = '1', peso_aluno, NULL))
  ) AS proficiencia_media_ponderada,
  COUNTIF(quality_status = 'ALERT') AS quantidade_registros_com_alerta,
  ANY_VALUE(source_batch_id) AS source_batch_id,
  CURRENT_TIMESTAMP() AS silver_processed_at
FROM `__PROJECT_ID__.alfabetizacao_silver.alunos`
GROUP BY ano, ano_referencia, id_municipio, rede_codigo, rede_nome, rede_agrupada;

CREATE OR REPLACE TABLE `__PROJECT_ID__.alfabetizacao_silver.int_alunos_resultado_municipio`
PARTITION BY ano_referencia
CLUSTER BY id_municipio, rede_nome
OPTIONS(description='Integração entre microdados agregados e indicadores municipais publicados.') AS
SELECT
  COALESCE(a.ano, r.ano) AS ano,
  COALESCE(a.ano_referencia, r.ano_referencia) AS ano_referencia,
  COALESCE(a.id_municipio, r.id_municipio) AS id_municipio,
  COALESCE(a.rede_nome, r.rede_nome) AS rede_nome,
  a.quantidade_alunos,
  a.quantidade_presentes,
  a.quantidade_alfabetizados,
  a.taxa_presenca,
  a.taxa_alfabetizacao_calculada,
  a.proficiencia_media,
  a.proficiencia_media_ponderada,
  r.taxa_alfabetizacao AS taxa_alfabetizacao_publicada,
  r.media_portugues,
  CASE
    WHEN a.id_municipio IS NOT NULL AND r.id_municipio IS NOT NULL THEN 'MATCH'
    WHEN a.id_municipio IS NOT NULL THEN 'SOMENTE_ALUNOS'
    ELSE 'SOMENTE_RESULTADO'
  END AS integration_status,
  CURRENT_TIMESTAMP() AS silver_processed_at
FROM `__PROJECT_ID__.alfabetizacao_silver.agg_alunos_municipio` AS a
FULL OUTER JOIN `__PROJECT_ID__.alfabetizacao_silver.resultado_municipio` AS r
  ON a.ano = r.ano
 AND a.id_municipio = r.id_municipio
 AND a.rede_nome = r.rede_nome
 AND r.serie_codigo = '2';

CREATE OR REPLACE TABLE `__PROJECT_ID__.alfabetizacao_silver.int_municipio_meta`
PARTITION BY ano_referencia
CLUSTER BY id_municipio
OPTIONS(description='Integração municipal entre resultado publicado e meta do mesmo ano.') AS
WITH resultado AS (
  SELECT *
  FROM `__PROJECT_ID__.alfabetizacao_silver.resultado_municipio`
  WHERE serie_codigo = '2' AND rede_nome = 'Municipal'
), meta AS (
  SELECT *
  FROM `__PROJECT_ID__.alfabetizacao_silver.meta_municipio`
  WHERE rede_normalizada = 'Municipal'
    AND ano_meta = ano
)
SELECT
  COALESCE(r.ano, m.ano) AS ano,
  COALESCE(r.ano_referencia, m.ano_referencia) AS ano_referencia,
  COALESCE(r.id_municipio, m.id_municipio) AS id_municipio,
  r.taxa_alfabetizacao AS taxa_alfabetizacao_resultado,
  r.media_portugues,
  m.meta_alfabetizacao,
  m.percentual_participacao,
  m.nivel_alfabetizacao,
  r.taxa_alfabetizacao - m.meta_alfabetizacao AS gap_meta_pontos_percentuais,
  CASE
    WHEN r.id_municipio IS NOT NULL AND m.id_municipio IS NOT NULL THEN 'MATCH'
    WHEN r.id_municipio IS NOT NULL THEN 'SOMENTE_RESULTADO'
    ELSE 'SOMENTE_META'
  END AS integration_status,
  CURRENT_TIMESTAMP() AS silver_processed_at
FROM resultado AS r
FULL OUTER JOIN meta AS m
  ON r.ano = m.ano
 AND r.id_municipio = m.id_municipio;

CREATE OR REPLACE TABLE `__PROJECT_ID__.alfabetizacao_silver.int_uf_meta`
PARTITION BY ano_referencia
CLUSTER BY sigla_uf
OPTIONS(description='Integração estadual entre resultado da rede pública e meta do mesmo ano.') AS
WITH resultado AS (
  SELECT *
  FROM `__PROJECT_ID__.alfabetizacao_silver.resultado_uf`
  WHERE serie_codigo = '2' AND rede_codigo = '5'
), meta AS (
  SELECT *
  FROM `__PROJECT_ID__.alfabetizacao_silver.meta_uf`
  WHERE rede_normalizada = 'Pública'
    AND ano_meta = ano
)
SELECT
  COALESCE(r.ano, m.ano) AS ano,
  COALESCE(r.ano_referencia, m.ano_referencia) AS ano_referencia,
  COALESCE(r.sigla_uf, m.sigla_uf) AS sigla_uf,
  r.taxa_alfabetizacao AS taxa_alfabetizacao_resultado,
  r.media_portugues,
  m.meta_alfabetizacao,
  m.percentual_participacao,
  r.taxa_alfabetizacao - m.meta_alfabetizacao AS gap_meta_pontos_percentuais,
  CASE
    WHEN r.sigla_uf IS NOT NULL AND m.sigla_uf IS NOT NULL THEN 'MATCH'
    WHEN r.sigla_uf IS NOT NULL THEN 'SOMENTE_RESULTADO'
    ELSE 'SOMENTE_META'
  END AS integration_status,
  CURRENT_TIMESTAMP() AS silver_processed_at
FROM resultado AS r
FULL OUTER JOIN meta AS m
  ON r.ano = m.ano
 AND r.sigla_uf = m.sigla_uf;

CREATE OR REPLACE TABLE `__PROJECT_ID__.alfabetizacao_silver.int_brasil_meta`
PARTITION BY ano_referencia
CLUSTER BY rede_normalizada
OPTIONS(description='Resultado nacional integrado à meta correspondente ao mesmo ano.') AS
SELECT
  ano,
  ano_referencia,
  rede_normalizada,
  taxa_alfabetizacao AS taxa_alfabetizacao_resultado,
  meta_alfabetizacao,
  percentual_participacao,
  taxa_alfabetizacao - meta_alfabetizacao AS gap_meta_pontos_percentuais,
  CURRENT_TIMESTAMP() AS silver_processed_at
FROM `__PROJECT_ID__.alfabetizacao_silver.meta_brasil`
WHERE ano_meta = ano;
