-- Etapa 07: objetos das camadas Bronze, Silver, Quarentena e Gold
-- para o fluxo de eventos em tempo quase real.

CREATE TABLE IF NOT EXISTS
  `__PROJECT_ID__.alfabetizacao_bronze.streaming_eventos_raw` (
    event_id STRING,
    simulation_run_id STRING,
    event_type STRING,
    event_time TIMESTAMP,
    schema_version STRING,
    entity_type STRING,
    entity_id STRING,
    source STRING,
    raw_message STRING,
    attributes_json STRING,
    pubsub_message_id STRING,
    pubsub_publish_time TIMESTAMP,
    ingestion_timestamp TIMESTAMP
  )
PARTITION BY DATE(ingestion_timestamp)
CLUSTER BY event_type, entity_type, simulation_run_id
OPTIONS (
  description = 'Eventos brutos recebidos pelo Pub/Sub, incluindo mensagens válidas e inválidas.'
);

CREATE TABLE IF NOT EXISTS
  `__PROJECT_ID__.alfabetizacao_silver.streaming_eventos` (
    event_id STRING,
    simulation_run_id STRING,
    event_type STRING,
    event_time TIMESTAMP,
    schema_version STRING,
    entity_type STRING,
    entity_id STRING,
    source STRING,
    ano INT64,
    ano_meta INT64,
    rede STRING,
    id_municipio STRING,
    sigla_uf STRING,
    taxa_alfabetizacao FLOAT64,
    meta_alfabetizacao FLOAT64,
    percentual_participacao FLOAT64,
    proficiencia FLOAT64,
    alfabetizado BOOL,
    payload_json STRING,
    quality_status STRING,
    processing_timestamp TIMESTAMP
  )
PARTITION BY DATE(processing_timestamp)
CLUSTER BY event_type, entity_type, entity_id, simulation_run_id
OPTIONS (
  description = 'Eventos streaming válidos, tipados e normalizados.'
);

CREATE TABLE IF NOT EXISTS
  `__PROJECT_ID__.alfabetizacao_quarantine.streaming_eventos` (
    event_id STRING,
    simulation_run_id STRING,
    event_type STRING,
    raw_message STRING,
    error_code STRING,
    error_message STRING,
    attributes_json STRING,
    pubsub_message_id STRING,
    pubsub_publish_time TIMESTAMP,
    quarantined_at TIMESTAMP
  )
PARTITION BY DATE(quarantined_at)
CLUSTER BY error_code, event_type, simulation_run_id
OPTIONS (
  description = 'Mensagens streaming rejeitadas por regra de contrato ou erro de escrita.'
);

CREATE OR REPLACE VIEW
  `__PROJECT_ID__.alfabetizacao_gold.vw_streaming_eventos_resumo` AS
SELECT
  DATE(event_time) AS data_evento,
  simulation_run_id,
  event_type,
  entity_type,
  COUNT(*) AS quantidade_eventos,
  COUNT(DISTINCT entity_id) AS quantidade_entidades,
  AVG(taxa_alfabetizacao) AS media_taxa_alfabetizacao,
  AVG(meta_alfabetizacao) AS media_meta_alfabetizacao,
  AVG(percentual_participacao) AS media_percentual_participacao,
  MAX(processing_timestamp) AS ultima_atualizacao
FROM
  `__PROJECT_ID__.alfabetizacao_silver.streaming_eventos`
GROUP BY
  data_evento,
  simulation_run_id,
  event_type,
  entity_type;

CREATE OR REPLACE VIEW
  `__PROJECT_ID__.alfabetizacao_gold.vw_streaming_ultimos_eventos` AS
SELECT * EXCEPT(row_number)
FROM (
  SELECT
    s.*,
    ROW_NUMBER() OVER (
      PARTITION BY event_type, entity_type, entity_id
      ORDER BY event_time DESC, processing_timestamp DESC
    ) AS row_number
  FROM
    `__PROJECT_ID__.alfabetizacao_silver.streaming_eventos` AS s
)
WHERE row_number = 1;
