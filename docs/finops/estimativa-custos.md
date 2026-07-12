# Estimativa e controle de custos

## BigQuery

```sql
SELECT *
FROM `PROJECT_ID.alfabetizacao_ops.vw_bigquery_usage_summary`;
```

Use:

```text
custo BigQuery = TiB faturados × preço vigente por TiB
```

A cobrança efetiva pode ser menor por franquias, cache ou créditos.

## Cloud Storage

A primeira Bronze ocupou aproximadamente 71,18 MiB. O custo deve considerar:

- armazenamento Standard;
- crescimento por snapshot;
- retenção de soft delete;
- ausência de expiração em `batch/`.

O prefixo `tmp/` é apagado após um dia.

## Pub/Sub

A demonstração publicou 15 eventos. O volume do teste é desprezível.

## Dataflow

O principal custo do teste vem do tempo em que o job ficou ativo.

Registro:

- início: July 12, 2026, 11:19:44 AM GMT-3;
- drain: July 12, 2026, 11:39:00 AM GMT-3;
- duração: 18 min 26 sec;
- custo estimado mostrado no painel Dataflow: $0.04.

## Cenário acadêmico

| Componente | Uso observado | Expectativa |
|---|---:|---|
| Cloud Storage | ~71,18 MiB | Centavos por mês |
| BigQuery | Consultas e tabelas pequenas/médias | Baixo |
| Pub/Sub | 15 mensagens | Desprezível |
| Dataflow | 1 worker por poucos minutos | Principal custo do teste |
| Monitoring | Métricas do projeto | Baixo |

## Controles

- orçamento;
- limite de bytes;
- partições;
- clustering;
- Parquet;
- labels;
- lifecycle;
- drain do Dataflow;
- `INFORMATION_SCHEMA.JOBS_BY_PROJECT`.
