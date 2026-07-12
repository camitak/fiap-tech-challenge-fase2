-- Tech Challenge Fase 2
-- Etapa 06: construção da camada Gold.
-- O placeholder __PROJECT_ID__ é substituído por src/gold/run_gold.sh.

-- ================================================================
-- 1. KPI NACIONAL: EVOLUÇÃO, META E PARTICIPAÇÃO
-- ================================================================

CREATE OR REPLACE TABLE `__PROJECT_ID__.alfabetizacao_gold.kpi_brasil`
PARTITION BY ano_referencia
CLUSTER BY rede_normalizada
OPTIONS(description='Indicadores nacionais de alfabetização, evolução temporal e comparação com a meta do mesmo ano.') AS
WITH resultados AS (
  SELECT DISTINCT
    ano,
    ano_referencia,
    rede_normalizada,
    taxa_alfabetizacao AS taxa_alfabetizacao_resultado,
    percentual_participacao,
    source_batch_id
  FROM `__PROJECT_ID__.alfabetizacao_silver.meta_brasil`
), metas_mesmo_ano AS (
  SELECT
    ano,
    rede_normalizada,
    meta_alfabetizacao
  FROM `__PROJECT_ID__.alfabetizacao_silver.meta_brasil`
  WHERE ano_meta = ano
  QUALIFY ROW_NUMBER() OVER (
    PARTITION BY ano, rede_normalizada
    ORDER BY silver_processed_at DESC
  ) = 1
), base AS (
  SELECT
    r.*,
    m.meta_alfabetizacao,
    r.taxa_alfabetizacao_resultado - m.meta_alfabetizacao AS gap_meta_pontos_percentuais,
    r.taxa_alfabetizacao_resultado
      - LAG(r.taxa_alfabetizacao_resultado) OVER (
          PARTITION BY r.rede_normalizada ORDER BY r.ano
        ) AS variacao_pp_ano_anterior
  FROM resultados AS r
  LEFT JOIN metas_mesmo_ano AS m
    USING (ano, rede_normalizada)
)
SELECT
  ano,
  ano_referencia,
  rede_normalizada,
  taxa_alfabetizacao_resultado,
  meta_alfabetizacao,
  gap_meta_pontos_percentuais,
  variacao_pp_ano_anterior,
  percentual_participacao,
  CASE
    WHEN taxa_alfabetizacao_resultado IS NULL THEN 'SEM_RESULTADO'
    WHEN meta_alfabetizacao IS NULL THEN 'SEM_META_DO_ANO'
    WHEN gap_meta_pontos_percentuais >= 0 THEN 'ATINGIU_OU_SUPEROU'
    ELSE 'ABAIXO_DA_META'
  END AS status_meta,
  CASE
    WHEN percentual_participacao IS NULL THEN 'SEM_DADO'
    WHEN percentual_participacao < 80 THEN 'ABAIXO_DE_80'
    WHEN percentual_participacao < 90 THEN 'DE_80_A_89_99'
    ELSE '90_OU_MAIS'
  END AS faixa_participacao,
  source_batch_id,
  CURRENT_TIMESTAMP() AS gold_processed_at
FROM base;

-- ================================================================
-- 2. KPI POR UF: META, BRASIL, RANKING E EVOLUÇÃO
-- ================================================================

CREATE OR REPLACE TABLE `__PROJECT_ID__.alfabetizacao_gold.kpi_uf`
PARTITION BY ano_referencia
CLUSTER BY sigla_uf, integration_status
OPTIONS(description='Indicadores por UF com comparação à meta, ao Brasil, ranking, quartil e evolução temporal.') AS
WITH historico_resultado AS (
  SELECT
    ano,
    sigla_uf,
    taxa_alfabetizacao,
    taxa_alfabetizacao
      - LAG(taxa_alfabetizacao) OVER (
          PARTITION BY sigla_uf ORDER BY ano
        ) AS variacao_pp_ano_anterior
  FROM `__PROJECT_ID__.alfabetizacao_silver.resultado_uf`
  WHERE serie_codigo = '2'
    AND rede_codigo = '5'
), base AS (
  SELECT
    i.ano,
    i.ano_referencia,
    i.sigla_uf,
    i.taxa_alfabetizacao_resultado,
    i.media_portugues,
    i.meta_alfabetizacao,
    i.percentual_participacao,
    i.gap_meta_pontos_percentuais,
    i.integration_status,
    h.variacao_pp_ano_anterior,
    b.taxa_alfabetizacao_resultado AS taxa_alfabetizacao_brasil,
    i.taxa_alfabetizacao_resultado
      - b.taxa_alfabetizacao_resultado AS gap_brasil_pontos_percentuais
  FROM `__PROJECT_ID__.alfabetizacao_silver.int_uf_meta` AS i
  LEFT JOIN historico_resultado AS h
    ON i.ano = h.ano
   AND i.sigla_uf = h.sigla_uf
  LEFT JOIN `__PROJECT_ID__.alfabetizacao_gold.kpi_brasil` AS b
    ON i.ano = b.ano
   AND b.rede_normalizada = 'Pública'
), ranking AS (
  SELECT
    ano,
    sigla_uf,
    RANK() OVER (
      PARTITION BY ano
      ORDER BY taxa_alfabetizacao_resultado DESC
    ) AS posicao_uf,
    PERCENT_RANK() OVER (
      PARTITION BY ano
      ORDER BY taxa_alfabetizacao_resultado
    ) AS percentil_desempenho,
    NTILE(4) OVER (
      PARTITION BY ano
      ORDER BY taxa_alfabetizacao_resultado DESC
    ) AS quartil_desempenho
  FROM base
  WHERE taxa_alfabetizacao_resultado IS NOT NULL
)
SELECT
  b.ano,
  b.ano_referencia,
  b.sigla_uf,
  b.taxa_alfabetizacao_resultado,
  b.media_portugues,
  b.meta_alfabetizacao,
  b.gap_meta_pontos_percentuais,
  b.variacao_pp_ano_anterior,
  b.percentual_participacao,
  b.taxa_alfabetizacao_brasil,
  b.gap_brasil_pontos_percentuais,
  r.posicao_uf,
  r.percentil_desempenho,
  r.quartil_desempenho,
  CASE r.quartil_desempenho
    WHEN 1 THEN 'Q1_MAIS_ALTO'
    WHEN 2 THEN 'Q2'
    WHEN 3 THEN 'Q3'
    WHEN 4 THEN 'Q4_MAIS_BAIXO'
    ELSE 'SEM_RANKING'
  END AS faixa_desempenho,
  CASE
    WHEN b.taxa_alfabetizacao_resultado IS NULL THEN 'SEM_RESULTADO'
    WHEN b.meta_alfabetizacao IS NULL THEN 'SEM_META_DO_ANO'
    WHEN b.gap_meta_pontos_percentuais >= 0 THEN 'ATINGIU_OU_SUPEROU'
    ELSE 'ABAIXO_DA_META'
  END AS status_meta,
  b.integration_status,
  CURRENT_TIMESTAMP() AS gold_processed_at
FROM base AS b
LEFT JOIN ranking AS r
  USING (ano, sigla_uf);

-- ================================================================
-- 3. KPI MUNICIPAL: META, MICRODADOS, RANKING E EVOLUÇÃO
-- ================================================================

CREATE OR REPLACE TABLE `__PROJECT_ID__.alfabetizacao_gold.kpi_municipio`
PARTITION BY ano_referencia
CLUSTER BY id_municipio, integration_status
OPTIONS(description='Indicadores municipais integrando resultado publicado, meta e microdados agregados.') AS
WITH historico_resultado AS (
  SELECT
    ano,
    id_municipio,
    taxa_alfabetizacao,
    taxa_alfabetizacao
      - LAG(taxa_alfabetizacao) OVER (
          PARTITION BY id_municipio ORDER BY ano
        ) AS variacao_pp_ano_anterior
  FROM `__PROJECT_ID__.alfabetizacao_silver.resultado_municipio`
  WHERE serie_codigo = '2'
    AND rede_nome = 'Municipal'
), alunos AS (
  SELECT
    ano,
    id_municipio,
    quantidade_alunos,
    quantidade_presentes,
    quantidade_provas_preenchidas,
    quantidade_alfabetizados,
    taxa_presenca,
    taxa_preenchimento,
    taxa_alfabetizacao_calculada,
    proficiencia_media,
    proficiencia_media_ponderada,
    quantidade_registros_com_alerta
  FROM `__PROJECT_ID__.alfabetizacao_silver.agg_alunos_municipio`
  WHERE rede_nome = 'Municipal'
), base AS (
  SELECT
    i.ano,
    i.ano_referencia,
    i.id_municipio,
    i.taxa_alfabetizacao_resultado,
    i.media_portugues,
    i.meta_alfabetizacao,
    i.percentual_participacao,
    i.nivel_alfabetizacao,
    i.gap_meta_pontos_percentuais,
    i.integration_status,
    h.variacao_pp_ano_anterior,
    a.quantidade_alunos,
    a.quantidade_presentes,
    a.quantidade_provas_preenchidas,
    a.quantidade_alfabetizados,
    a.taxa_presenca,
    a.taxa_preenchimento,
    a.taxa_alfabetizacao_calculada,
    a.proficiencia_media,
    a.proficiencia_media_ponderada,
    a.quantidade_registros_com_alerta,
    a.taxa_alfabetizacao_calculada
      - i.taxa_alfabetizacao_resultado AS divergencia_microdados_publicado_pp
  FROM `__PROJECT_ID__.alfabetizacao_silver.int_municipio_meta` AS i
  LEFT JOIN historico_resultado AS h
    ON i.ano = h.ano
   AND i.id_municipio = h.id_municipio
  LEFT JOIN alunos AS a
    ON i.ano = a.ano
   AND i.id_municipio = a.id_municipio
), ranking AS (
  SELECT
    ano,
    id_municipio,
    RANK() OVER (
      PARTITION BY ano
      ORDER BY taxa_alfabetizacao_resultado DESC
    ) AS posicao_nacional_municipio,
    PERCENT_RANK() OVER (
      PARTITION BY ano
      ORDER BY taxa_alfabetizacao_resultado
    ) AS percentil_desempenho,
    NTILE(4) OVER (
      PARTITION BY ano
      ORDER BY taxa_alfabetizacao_resultado DESC
    ) AS quartil_desempenho
  FROM base
  WHERE taxa_alfabetizacao_resultado IS NOT NULL
)
SELECT
  b.*,
  r.posicao_nacional_municipio,
  r.percentil_desempenho,
  r.quartil_desempenho,
  CASE r.quartil_desempenho
    WHEN 1 THEN 'Q1_MAIS_ALTO'
    WHEN 2 THEN 'Q2'
    WHEN 3 THEN 'Q3'
    WHEN 4 THEN 'Q4_MAIS_BAIXO'
    ELSE 'SEM_RANKING'
  END AS faixa_desempenho,
  CASE
    WHEN b.taxa_alfabetizacao_resultado IS NULL THEN 'SEM_RESULTADO'
    WHEN b.meta_alfabetizacao IS NULL THEN 'SEM_META_DO_ANO'
    WHEN b.gap_meta_pontos_percentuais >= 0 THEN 'ATINGIU_OU_SUPEROU'
    ELSE 'ABAIXO_DA_META'
  END AS status_meta,
  CASE
    WHEN b.gap_meta_pontos_percentuais IS NULL THEN 'SEM_COMPARACAO'
    WHEN b.gap_meta_pontos_percentuais < -10 THEN 'ABAIXO_MAIS_DE_10_PP'
    WHEN b.gap_meta_pontos_percentuais < -5 THEN 'ABAIXO_DE_5_A_10_PP'
    WHEN b.gap_meta_pontos_percentuais < 0 THEN 'ABAIXO_ATE_5_PP'
    ELSE 'META_ATINGIDA_OU_SUPERADA'
  END AS faixa_gap_meta,
  CASE
    WHEN b.percentual_participacao IS NULL THEN 'SEM_DADO'
    WHEN b.percentual_participacao < 80 THEN 'ABAIXO_DE_80'
    WHEN b.percentual_participacao < 90 THEN 'DE_80_A_89_99'
    ELSE '90_OU_MAIS'
  END AS faixa_participacao,
  CURRENT_TIMESTAMP() AS gold_processed_at
FROM base AS b
LEFT JOIN ranking AS r
  USING (ano, id_municipio);

-- ================================================================
-- 4. COBERTURA DAS INTEGRAÇÕES
-- ================================================================

CREATE OR REPLACE TABLE `__PROJECT_ID__.alfabetizacao_gold.cobertura_integracao`
PARTITION BY ano_referencia
CLUSTER BY nivel_territorial, integration_status
OPTIONS(description='Cobertura das integrações entre resultados e metas, sem ocultar ausências de correspondência.') AS
WITH dados AS (
  SELECT
    'MUNICIPIO' AS nivel_territorial,
    ano,
    ano_referencia,
    integration_status,
    COUNT(*) AS quantidade
  FROM `__PROJECT_ID__.alfabetizacao_silver.int_municipio_meta`
  GROUP BY 1, 2, 3, 4

  UNION ALL

  SELECT
    'UF' AS nivel_territorial,
    ano,
    ano_referencia,
    integration_status,
    COUNT(*) AS quantidade
  FROM `__PROJECT_ID__.alfabetizacao_silver.int_uf_meta`
  GROUP BY 1, 2, 3, 4
)
SELECT
  nivel_territorial,
  ano,
  ano_referencia,
  integration_status,
  quantidade,
  SAFE_DIVIDE(
    quantidade,
    SUM(quantidade) OVER (PARTITION BY nivel_territorial, ano)
  ) * 100 AS percentual_cobertura,
  CURRENT_TIMESTAMP() AS gold_processed_at
FROM dados;

-- ================================================================
-- 5. DISTRIBUIÇÃO DE ESTUDANTES POR NÍVEL DE PROFICIÊNCIA — UF
-- ================================================================

CREATE OR REPLACE TABLE `__PROJECT_ID__.alfabetizacao_gold.distribuicao_niveis_uf`
PARTITION BY ano_referencia
CLUSTER BY sigla_uf, nivel_proficiencia
OPTIONS(description='Distribuição dos estudantes por nível de proficiência para análise estadual.') AS
SELECT
  r.ano,
  r.ano_referencia,
  r.sigla_uf,
  r.rede_nome,
  n.nivel_proficiencia,
  n.proporcao_alunos,
  n.proporcao_alunos IS NOT NULL AS dado_disponivel,
  r.source_batch_id,
  CURRENT_TIMESTAMP() AS gold_processed_at
FROM `__PROJECT_ID__.alfabetizacao_silver.resultado_uf` AS r
CROSS JOIN UNNEST([
  STRUCT(0 AS nivel_proficiencia, r.proporcao_aluno_nivel_0 AS proporcao_alunos),
  STRUCT(1 AS nivel_proficiencia, r.proporcao_aluno_nivel_1 AS proporcao_alunos),
  STRUCT(2 AS nivel_proficiencia, r.proporcao_aluno_nivel_2 AS proporcao_alunos),
  STRUCT(3 AS nivel_proficiencia, r.proporcao_aluno_nivel_3 AS proporcao_alunos),
  STRUCT(4 AS nivel_proficiencia, r.proporcao_aluno_nivel_4 AS proporcao_alunos),
  STRUCT(5 AS nivel_proficiencia, r.proporcao_aluno_nivel_5 AS proporcao_alunos),
  STRUCT(6 AS nivel_proficiencia, r.proporcao_aluno_nivel_6 AS proporcao_alunos),
  STRUCT(7 AS nivel_proficiencia, r.proporcao_aluno_nivel_7 AS proporcao_alunos),
  STRUCT(8 AS nivel_proficiencia, r.proporcao_aluno_nivel_8 AS proporcao_alunos)
]) AS n
WHERE r.serie_codigo = '2'
  AND r.rede_codigo = '5';

-- ================================================================
-- 6. RESUMO EXECUTIVO PARA DASHBOARD
-- ================================================================

CREATE OR REPLACE TABLE `__PROJECT_ID__.alfabetizacao_gold.resumo_executivo`
PARTITION BY ano_referencia
OPTIONS(description='Resumo anual para dashboard executivo com indicadores nacionais, estaduais e municipais.') AS
WITH anos AS (
  SELECT ano, ano_referencia FROM `__PROJECT_ID__.alfabetizacao_gold.kpi_brasil`
  UNION DISTINCT
  SELECT ano, ano_referencia FROM `__PROJECT_ID__.alfabetizacao_gold.kpi_uf`
  UNION DISTINCT
  SELECT ano, ano_referencia FROM `__PROJECT_ID__.alfabetizacao_gold.kpi_municipio`
), brasil AS (
  SELECT
    ano,
    ANY_VALUE(taxa_alfabetizacao_resultado) AS taxa_alfabetizacao_brasil,
    ANY_VALUE(meta_alfabetizacao) AS meta_brasil,
    ANY_VALUE(gap_meta_pontos_percentuais) AS gap_meta_brasil_pp,
    ANY_VALUE(percentual_participacao) AS participacao_brasil
  FROM `__PROJECT_ID__.alfabetizacao_gold.kpi_brasil`
  WHERE rede_normalizada = 'Pública'
  GROUP BY ano
), uf AS (
  SELECT
    ano,
    COUNTIF(taxa_alfabetizacao_resultado IS NOT NULL) AS ufs_com_resultado,
    COUNTIF(meta_alfabetizacao IS NOT NULL AND taxa_alfabetizacao_resultado IS NOT NULL) AS ufs_comparaveis,
    COUNTIF(status_meta = 'ATINGIU_OU_SUPEROU') AS ufs_atingiram_meta,
    AVG(taxa_alfabetizacao_resultado) AS media_taxa_ufs,
    MIN(taxa_alfabetizacao_resultado) AS menor_taxa_uf,
    MAX(taxa_alfabetizacao_resultado) AS maior_taxa_uf
  FROM `__PROJECT_ID__.alfabetizacao_gold.kpi_uf`
  GROUP BY ano
), municipio AS (
  SELECT
    ano,
    COUNTIF(taxa_alfabetizacao_resultado IS NOT NULL) AS municipios_com_resultado,
    COUNTIF(meta_alfabetizacao IS NOT NULL AND taxa_alfabetizacao_resultado IS NOT NULL) AS municipios_comparaveis,
    COUNTIF(status_meta = 'ATINGIU_OU_SUPEROU') AS municipios_atingiram_meta,
    AVG(taxa_alfabetizacao_resultado) AS media_taxa_municipios,
    MIN(taxa_alfabetizacao_resultado) AS menor_taxa_municipio,
    MAX(taxa_alfabetizacao_resultado) AS maior_taxa_municipio,
    AVG(taxa_presenca) AS media_taxa_presenca_alunos
  FROM `__PROJECT_ID__.alfabetizacao_gold.kpi_municipio`
  GROUP BY ano
)
SELECT
  a.ano,
  a.ano_referencia,
  b.taxa_alfabetizacao_brasil,
  b.meta_brasil,
  b.gap_meta_brasil_pp,
  b.participacao_brasil,
  u.ufs_com_resultado,
  u.ufs_comparaveis,
  u.ufs_atingiram_meta,
  SAFE_DIVIDE(u.ufs_atingiram_meta, u.ufs_comparaveis) * 100 AS percentual_ufs_atingiram_meta,
  u.media_taxa_ufs,
  u.menor_taxa_uf,
  u.maior_taxa_uf,
  m.municipios_com_resultado,
  m.municipios_comparaveis,
  m.municipios_atingiram_meta,
  SAFE_DIVIDE(m.municipios_atingiram_meta, m.municipios_comparaveis) * 100 AS percentual_municipios_atingiram_meta,
  m.media_taxa_municipios,
  m.menor_taxa_municipio,
  m.maior_taxa_municipio,
  m.media_taxa_presenca_alunos,
  CURRENT_TIMESTAMP() AS gold_processed_at
FROM anos AS a
LEFT JOIN brasil AS b USING (ano)
LEFT JOIN uf AS u USING (ano)
LEFT JOIN municipio AS m USING (ano);

-- ================================================================
-- 7. DATASET DE FEATURES PARA FUTUROS MODELOS
-- ================================================================

CREATE OR REPLACE TABLE `__PROJECT_ID__.alfabetizacao_gold.features_modelo_municipio`
PARTITION BY ano_referencia
CLUSTER BY id_municipio
OPTIONS(description='Features municipais e alvo do ano seguinte para experimentos futuros de machine learning.') AS
WITH base AS (
  SELECT
    ano,
    ano_referencia,
    id_municipio,
    taxa_alfabetizacao_resultado,
    media_portugues,
    meta_alfabetizacao,
    gap_meta_pontos_percentuais,
    percentual_participacao,
    nivel_alfabetizacao,
    variacao_pp_ano_anterior,
    quantidade_alunos,
    quantidade_presentes,
    quantidade_alfabetizados,
    taxa_presenca,
    taxa_preenchimento,
    taxa_alfabetizacao_calculada,
    proficiencia_media,
    proficiencia_media_ponderada,
    integration_status,
    status_meta,
    LEAD(ano) OVER (
      PARTITION BY id_municipio ORDER BY ano
    ) AS target_ano,
    LEAD(taxa_alfabetizacao_resultado) OVER (
      PARTITION BY id_municipio ORDER BY ano
    ) AS target_taxa_alfabetizacao_proximo_ano,
    LEAD(status_meta) OVER (
      PARTITION BY id_municipio ORDER BY ano
    ) AS target_status_meta_proximo_ano
  FROM `__PROJECT_ID__.alfabetizacao_gold.kpi_municipio`
)
SELECT
  *,
  target_ano = ano + 1
    AND target_taxa_alfabetizacao_proximo_ano IS NOT NULL AS possui_target_ano_seguinte,
  CURRENT_TIMESTAMP() AS gold_processed_at
FROM base;
