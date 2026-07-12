# Etapa 08 — Monitoramento, governança e FinOps

## Objetivo

Consolidar mecanismos de observabilidade, histórico de validações, controle
de acesso e eficiência de custos da pipeline híbrida.

## Observabilidade em BigQuery

O dataset `alfabetizacao_ops` recebe:

- `silver_validation_history`;
- `gold_validation_history`;
- `streaming_validation_history`;
- `pipeline_health_history`;
- `streaming_latency_summary`;
- `bigquery_usage_daily`;
- `vw_pipeline_health_latest`;
- `vw_quality_failures`;
- `vw_bigquery_usage_summary`;
- `latest_ops_validation`.

As tabelas históricas são append-only por execução. O script utiliza `MERGE`
para impedir duplicidade quando a mesma etapa é coletada novamente.

## Métricas

### Batch e qualidade

- verificações executadas, aprovadas e reprovadas;
- estado consolidado de cada pipeline;
- histórico de reconciliação, validade, consistência e unicidade.

### Streaming

- volume por tipo de evento;
- latência ponta a ponta;
- latência entre Pub/Sub e processamento;
- média, percentil 95 e máximo;
- backlog;
- idade da mensagem mais antiga;
- system lag do Dataflow.

### BigQuery

- jobs de consulta;
- jobs com falha;
- bytes processados e faturados;
- TiB faturados;
- slot-milliseconds;
- uso do cache.

## Alertas

São criadas três políticas:

- backlog Pub/Sub acima de 100 mensagens por cinco minutos;
- mensagem não confirmada acima de 300 segundos por cinco minutos;
- system lag do Dataflow acima de 300 segundos por cinco minutos.

Também deve ser configurado um alerta baseado em logs para erros do Dataflow.

## Governança

- acesso uniforme no bucket;
- prevenção de acesso público;
- contas de serviço separadas por workload;
- ausência de `Owner` e `Editor` nas contas de serviço;
- labels por projeto, ambiente e camada;
- microdados restritos à Silver;
- consumo analítico preferencialmente pela Gold;
- contrato de eventos;
- quarentena com motivo técnico.

## Lifecycle

Somente o prefixo `tmp/` é removido após um dia.

O histórico em `batch/` não recebe expiração, porque a Bronze precisa preservar
snapshots completos.

## FinOps

- Parquet e Snappy;
- particionamento Hive;
- particionamento e clustering no BigQuery;
- limite de bytes por consulta;
- Dataflow com um worker no teste;
- encerramento por drain;
- orçamento com alertas;
- lifecycle de temporários;
- monitoramento de bytes faturados.
