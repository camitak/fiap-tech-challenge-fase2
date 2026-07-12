-- Tech Challenge Fase 2
-- Etapa 09: views de consumo para o Looker Studio.
-- O placeholder __PROJECT_ID__ é substituído por src/dashboard/run_dashboard_views.sh.

-- ================================================================
-- 1. VISÃO EXECUTIVA NACIONAL
-- ================================================================

CREATE OR REPLACE VIEW
  `__PROJECT_ID__.alfabetizacao_gold.vw_dashboard_resumo_nacional`
AS
SELECT
  ano,
  ano_referencia,
  ROUND(taxa_alfabetizacao_brasil, 2) AS taxa_alfabetizacao_brasil,
  ROUND(meta_brasil, 2) AS meta_brasil,
  ROUND(gap_meta_brasil_pp, 2) AS gap_meta_brasil_pp,
  ROUND(participacao_brasil, 2) AS participacao_brasil,
  ufs_com_resultado,
  ufs_comparaveis,
  ufs_atingiram_meta,
  ROUND(percentual_ufs_atingiram_meta, 2) AS percentual_ufs_atingiram_meta,
  ROUND(media_taxa_ufs, 2) AS media_taxa_ufs,
  ROUND(menor_taxa_uf, 2) AS menor_taxa_uf,
  ROUND(maior_taxa_uf, 2) AS maior_taxa_uf,
  municipios_com_resultado,
  municipios_comparaveis,
  municipios_atingiram_meta,
  ROUND(
    percentual_municipios_atingiram_meta,
    2
  ) AS percentual_municipios_atingiram_meta,
  ROUND(media_taxa_municipios, 2) AS media_taxa_municipios,
  ROUND(menor_taxa_municipio, 2) AS menor_taxa_municipio,
  ROUND(maior_taxa_municipio, 2) AS maior_taxa_municipio,
  ROUND(media_taxa_presenca_alunos, 2) AS media_taxa_presenca_alunos,
  CASE
    WHEN meta_brasil IS NULL THEN 'SEM_META_DO_ANO'
    WHEN gap_meta_brasil_pp >= 0 THEN 'ATINGIU_OU_SUPEROU'
    ELSE 'ABAIXO_DA_META'
  END AS status_meta_brasil,
  gold_processed_at
FROM
  `__PROJECT_ID__.alfabetizacao_gold.resumo_executivo`;

-- ================================================================
-- 2. VISÃO POR UF
-- ================================================================

CREATE OR REPLACE VIEW
  `__PROJECT_ID__.alfabetizacao_gold.vw_dashboard_uf`
AS
SELECT
  ano,
  ano_referencia,
  sigla_uf,
  ROUND(taxa_alfabetizacao_resultado, 2) AS taxa_alfabetizacao_resultado,
  ROUND(media_portugues, 2) AS media_portugues,
  ROUND(meta_alfabetizacao, 2) AS meta_alfabetizacao,
  ROUND(gap_meta_pontos_percentuais, 2) AS gap_meta_pontos_percentuais,
  ROUND(variacao_pp_ano_anterior, 2) AS variacao_pp_ano_anterior,
  ROUND(percentual_participacao, 2) AS percentual_participacao,
  ROUND(taxa_alfabetizacao_brasil, 2) AS taxa_alfabetizacao_brasil,
  ROUND(gap_brasil_pontos_percentuais, 2) AS gap_brasil_pontos_percentuais,
  posicao_uf,
  ROUND(percentil_desempenho * 100, 2) AS percentil_desempenho,
  quartil_desempenho,
  faixa_desempenho,
  status_meta,
  integration_status,
  gold_processed_at
FROM
  `__PROJECT_ID__.alfabetizacao_gold.kpi_uf`;

-- ================================================================
-- 3. VISÃO MUNICIPAL
-- ================================================================

CREATE OR REPLACE VIEW
  `__PROJECT_ID__.alfabetizacao_gold.vw_dashboard_municipio`
AS
SELECT
  ano,
  ano_referencia,
  id_municipio,
  ROUND(taxa_alfabetizacao_resultado, 2) AS taxa_alfabetizacao_resultado,
  ROUND(media_portugues, 2) AS media_portugues,
  ROUND(meta_alfabetizacao, 2) AS meta_alfabetizacao,
  ROUND(percentual_participacao, 2) AS percentual_participacao,
  nivel_alfabetizacao,
  ROUND(gap_meta_pontos_percentuais, 2) AS gap_meta_pontos_percentuais,
  integration_status,
  ROUND(variacao_pp_ano_anterior, 2) AS variacao_pp_ano_anterior,
  quantidade_alunos,
  quantidade_presentes,
  quantidade_provas_preenchidas,
  quantidade_alfabetizados,
  ROUND(taxa_presenca, 2) AS taxa_presenca,
  ROUND(taxa_preenchimento, 2) AS taxa_preenchimento,
  ROUND(taxa_alfabetizacao_calculada, 2) AS taxa_alfabetizacao_calculada,
  ROUND(proficiencia_media, 2) AS proficiencia_media,
  ROUND(proficiencia_media_ponderada, 2) AS proficiencia_media_ponderada,
  quantidade_registros_com_alerta,
  ROUND(
    divergencia_microdados_publicado_pp,
    2
  ) AS divergencia_microdados_publicado_pp,
  posicao_nacional_municipio,
  ROUND(percentil_desempenho * 100, 2) AS percentil_desempenho,
  quartil_desempenho,
  faixa_desempenho,
  status_meta,
  faixa_gap_meta,
  faixa_participacao,
  gold_processed_at
FROM
  `__PROJECT_ID__.alfabetizacao_gold.kpi_municipio`;

-- ================================================================
-- 4. VISÃO STREAMING
-- ================================================================

CREATE OR REPLACE VIEW
  `__PROJECT_ID__.alfabetizacao_gold.vw_dashboard_streaming`
AS
WITH validos_por_tipo AS (
  SELECT
    data_evento,
    simulation_run_id,
    event_type,
    entity_type,
    quantidade_eventos,
    quantidade_entidades,
    ROUND(media_taxa_alfabetizacao, 2) AS media_taxa_alfabetizacao,
    ROUND(media_meta_alfabetizacao, 2) AS media_meta_alfabetizacao,
    ROUND(
      media_percentual_participacao,
      2
    ) AS media_percentual_participacao,
    ultima_atualizacao
  FROM
    `__PROJECT_ID__.alfabetizacao_gold.vw_streaming_eventos_resumo`
),
latencia AS (
  SELECT
    simulation_run_id,
    event_type,
    event_count,
    events_with_publish_time,
    events_without_publish_time,
    avg_end_to_end_latency_seconds,
    p95_end_to_end_latency_seconds,
    max_end_to_end_latency_seconds,
    avg_processing_latency_seconds
  FROM
    `__PROJECT_ID__.alfabetizacao_ops.streaming_latency_summary`
),
bronze AS (
  SELECT
    simulation_run_id,
    COUNT(*) AS eventos_bronze_total_run
  FROM
    `__PROJECT_ID__.alfabetizacao_bronze.streaming_eventos_raw`
  WHERE simulation_run_id IS NOT NULL
  GROUP BY simulation_run_id
),
silver AS (
  SELECT
    simulation_run_id,
    COUNT(*) AS eventos_validos_total_run
  FROM
    `__PROJECT_ID__.alfabetizacao_silver.streaming_eventos`
  WHERE simulation_run_id IS NOT NULL
  GROUP BY simulation_run_id
),
quarentena AS (
  SELECT
    simulation_run_id,
    COUNT(*) AS eventos_invalidos_total_run
  FROM
    `__PROJECT_ID__.alfabetizacao_quarantine.streaming_eventos`
  WHERE simulation_run_id IS NOT NULL
  GROUP BY simulation_run_id
)
SELECT
  v.*,
  l.event_count,
  l.events_with_publish_time,
  l.events_without_publish_time,
  l.avg_end_to_end_latency_seconds,
  l.p95_end_to_end_latency_seconds,
  l.max_end_to_end_latency_seconds,
  l.avg_processing_latency_seconds,
  b.eventos_bronze_total_run,
  s.eventos_validos_total_run,
  COALESCE(q.eventos_invalidos_total_run, 0) AS eventos_invalidos_total_run
FROM validos_por_tipo AS v
LEFT JOIN latencia AS l
  USING (simulation_run_id, event_type)
LEFT JOIN bronze AS b
  USING (simulation_run_id)
LEFT JOIN silver AS s
  USING (simulation_run_id)
LEFT JOIN quarentena AS q
  USING (simulation_run_id);

-- ================================================================
-- 5. VISÃO OPERACIONAL
-- ================================================================

CREATE OR REPLACE VIEW
  `__PROJECT_ID__.alfabetizacao_gold.vw_dashboard_operacao`
AS
SELECT
  pipeline_name,
  CASE pipeline_name
    WHEN 'silver_batch' THEN 'Batch — Silver'
    WHEN 'gold_batch' THEN 'Batch — Gold'
    WHEN 'streaming' THEN 'Streaming'
    ELSE pipeline_name
  END AS pipeline_nome_exibicao,
  run_id,
  executed_at,
  checks_total,
  checks_ok,
  checks_failed,
  pipeline_status,
  collected_at
FROM
  `__PROJECT_ID__.alfabetizacao_ops.vw_pipeline_health_latest`;

-- ================================================================
-- 6. VISÃO FINOPS — USO DIÁRIO DO BIGQUERY
-- ================================================================

CREATE OR REPLACE VIEW
  `__PROJECT_ID__.alfabetizacao_gold.vw_dashboard_bigquery_uso_diario`
AS
SELECT
  usage_date,
  SUM(query_jobs) AS query_jobs,
  SUM(failed_jobs) AS failed_jobs,
  SUM(total_bytes_processed) AS total_bytes_processed,
  SUM(total_bytes_billed) AS total_bytes_billed,
  ROUND(SUM(total_bytes_billed) / POW(1024, 3), 4) AS total_gib_billed,
  ROUND(SUM(total_bytes_billed) / POW(1024, 4), 8) AS total_tib_billed,
  SUM(total_slot_ms) AS total_slot_ms,
  SUM(cache_hit_jobs) AS cache_hit_jobs
FROM
  `__PROJECT_ID__.alfabetizacao_ops.bigquery_usage_daily`
GROUP BY usage_date;
