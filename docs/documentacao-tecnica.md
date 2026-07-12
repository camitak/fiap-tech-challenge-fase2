# Documentação técnica da solução

## 1. Visão geral

A solução integra dados públicos do Indicador Criança Alfabetizada em uma arquitetura híbrida batch e streaming na Google Cloud Platform.

O desenho separa armazenamento bruto, tratamento, consumo analítico e operação. Essa separação reduz acoplamento, facilita reprocessamento e permite identificar em qual etapa uma inconsistência surgiu.

## 2. Escopo implementado

- ingestão batch de seis fontes obrigatórias;
- ingestão do dicionário auxiliar;
- armazenamento Bronze em Parquet;
- catálogo Bronze por tabelas externas;
- tratamento e integração Silver;
- quarentena de dados inválidos;
- produtos analíticos Gold;
- simulador de eventos;
- Pub/Sub, Dataflow e DLQ;
- qualidade automatizada;
- histórico de validações;
- métricas de latência;
- métricas de uso do BigQuery;
- alertas de Pub/Sub e Dataflow;
- controles IAM, Cloud Storage e FinOps.

## 3. Componentes GCP

### Projeto

```text
fiap-tc-f2-camila-takemoto
```

### Localizações

```text
BigQuery e Cloud Storage: US
Dataflow: us-central1
```

### Datasets

```text
alfabetizacao_bronze
alfabetizacao_silver
alfabetizacao_gold
alfabetizacao_quarantine
alfabetizacao_ops
```

### Bucket

```text
gs://fiap-tc-f2-camila-takemoto-alfabetizacao-bronze
```

### Contas de serviço

```text
sa-batch-ingestion@fiap-tc-f2-camila-takemoto.iam.gserviceaccount.com
sa-streaming-dataflow@fiap-tc-f2-camila-takemoto.iam.gserviceaccount.com
```

### Pub/Sub

```text
alfabetizacao-eventos
alfabetizacao-eventos-dataflow
alfabetizacao-eventos-dlq
alfabetizacao-eventos-dlq-sub
```

## 4. Granularidades

| Entidade | Grão |
|---|---|
| aluno | ano e aluno |
| resultado municipal | ano, município, série e rede |
| resultado UF | ano, UF, série e rede |
| meta municipal | ano de observação, município, rede e ano da meta |
| meta UF | ano de observação, UF, rede e ano da meta |
| meta Brasil | ano de observação, rede e ano da meta |
| KPI municipal | ano, município e rede comparável |
| KPI UF | ano, UF e rede comparável |
| KPI Brasil | ano e rede |
| evento streaming | event_id |

## 5. Metadados e rastreabilidade

Batch:

- `ingestion_date`;
- `_ingestion_timestamp`;
- `batch_id`;
- `_batch_id`;
- `_source_table`.

Streaming:

- `event_id`;
- `simulation_run_id`;
- `event_type`;
- `schema_version`;
- `event_time`;
- `pubsub_publish_time`;
- `processing_timestamp`;
- `source`.

Operação:

- `executed_at`;
- `collected_at`;
- `pipeline_name`;
- `run_id`;
- `check_type`;
- `expected_value`;
- `actual_value`;
- `status`.

## 6. Estratégia de idempotência

- Bronze batch usa novo `batch_id` a cada snapshot.
- Tabelas externas leem histórico particionado.
- Silver e Gold usam `CREATE OR REPLACE` para reconstrução controlada.
- Históricos de observabilidade usam `MERGE`.
- Eventos possuem `event_id`.
- Validações detectam duplicidade de `event_id`.
- Scripts preservam SQL renderizado quando ocorre falha.

## 7. Estratégia de erros

### Batch

- erros críticos seguem para `alfabetizacao_quarantine.records`;
- alertas permanecem na Silver;
- reconciliação exige Bronze = Silver + Quarentena.

### Streaming

- toda mensagem chega à Bronze;
- JSON inválido e contrato inválido seguem para quarentena;
- eventos inválidos são publicados na DLQ;
- o motivo técnico é armazenado;
- os válidos são gravados na Silver.

## 8. Qualidade

Dimensões verificadas:

- completude;
- validade;
- unicidade;
- consistência;
- integridade referencial;
- cobertura;
- reconciliação;
- atualidade e latência.

## 9. Desempenho

- Parquet;
- Snappy;
- particionamento Hive;
- tabelas BigQuery particionadas;
- clusterização por município, UF e rede;
- agregação de alunos antes de joins analíticos;
- materialização de KPIs;
- limites de bytes faturados.

## 10. Segurança

- impersonação;
- ausência de chaves persistentes;
- papéis por workload;
- acesso por dataset;
- bucket com acesso uniforme;
- prevenção de acesso público;
- microdados individuais fora da Gold;
- segredos excluídos pelo `.gitignore`.

## 11. Operação

A solução foi executada por scripts no Cloud Shell. Não há agendamento automático no escopo atual.

Para produção, a recomendação é:

- Cloud Scheduler para gatilhos;
- Workflows para dependências;
- CI/CD para validação e implantação;
- ambientes separados;
- SLOs formais;
- alertas com canal de plantão.
