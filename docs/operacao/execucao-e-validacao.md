# Runbook de execução e validação

## Pré-requisitos

- projeto GCP ativo;
- faturamento habilitado;
- APIs habilitadas;
- datasets criados;
- bucket criado;
- contas de serviço configuradas;
- `gcloud`, `bq`, Python 3 e Git;
- usuário autorizado a impersonar as contas de serviço.

## Variáveis

```bash
export PROJECT_ID="fiap-tc-f2-camila-takemoto"
export LOCATION="US"
export DATAFLOW_REGION="us-central1"
export BUCKET="fiap-tc-f2-camila-takemoto-alfabetizacao-bronze"

export SA_BATCH="sa-batch-ingestion@${PROJECT_ID}.iam.gserviceaccount.com"
export SA_STREAMING="sa-streaming-dataflow@${PROJECT_ID}.iam.gserviceaccount.com"
```

## 1. Infraestrutura base

```bash
./infra/gcp/bootstrap.sh
```

O script não deve criar chaves de conta de serviço.

## 2. Bronze batch

```bash
./src/batch/export_bronze.sh
source /tmp/fiap_last_batch.env
./src/batch/create_external_tables.sh
./src/batch/validate_bronze.sh
```

Critério de aceite: todas as contagens `ORIGEM = BRONZE`.

## 3. Silver

```bash
export INGESTION_DATE="2026-07-12"
export BATCH_ID="batch_20260712T011134Z"

./src/silver/run_silver.sh
./src/silver/validate_silver.sh
```

Critério de aceite: todos os testes de `latest_silver_validation` em `OK`.

## 4. Gold

```bash
./src/gold/run_gold.sh
./src/gold/validate_gold.sh
```

Critério de aceite: todos os testes de `latest_gold_validation` em `OK`.

## 5. Streaming

### Configuração

```bash
./infra/gcp/setup_streaming.sh
```

### Início

```bash
./src/streaming/run_streaming.sh
```

Aguardar `JOB_STATE_RUNNING`.

### Simulação

```bash
./src/streaming/run_simulator.sh
source /tmp/fiap_simulation.env
```

### Validação

```bash
./src/streaming/validate_streaming.sh
```

Critério de aceite:

```text
Bronze = 15
Silver = 12
Quarentena = 3
```

### Encerramento

```bash
./src/streaming/stop_streaming.sh
```

Critério de aceite: nenhum job em `JOB_STATE_RUNNING`.

## 6. Observabilidade e governança

```bash
./infra/gcp/setup_ops_governance.sh
./src/ops/run_observability.sh
./src/ops/validate_observability.sh
./infra/gcp/validate_ops_governance.sh
```

Critério de aceite:

- `latest_ops_validation` sem falhas;
- três pipelines `SUCCEEDED`;
- bucket protegido;
- políticas de monitoramento presentes;
- nenhum papel básico amplo nas contas de serviço.

## 7. Consultas operacionais

### Saúde

```sql
SELECT *
FROM `fiap-tc-f2-camila-takemoto.alfabetizacao_ops.vw_pipeline_health_latest`
ORDER BY pipeline_name;
```

### Falhas de qualidade

```sql
SELECT *
FROM `fiap-tc-f2-camila-takemoto.alfabetizacao_ops.vw_quality_failures`;
```

### Uso

```sql
SELECT *
FROM `fiap-tc-f2-camila-takemoto.alfabetizacao_ops.vw_bigquery_usage_summary`;
```

### Latência

```sql
SELECT *
FROM `fiap-tc-f2-camila-takemoto.alfabetizacao_ops.streaming_latency_summary`
ORDER BY simulation_run_id, event_type;
```

## 8. Recuperação

### Falha batch

- consultar a mensagem do `bq`;
- verificar localização;
- verificar partição e lote;
- não excluir a Bronze;
- corrigir o script;
- reexecutar Silver ou Gold, que usam substituição controlada.

### Falha streaming

- verificar estado do Dataflow;
- consultar Cloud Logging;
- verificar backlog da assinatura;
- verificar DLQ;
- drenar o job antes de nova implantação.

### Falha de custo

- drenar Dataflow;
- revisar jobs BigQuery;
- verificar bytes faturados;
- validar filtros e partições;
- revisar orçamento e alertas.
