# Monitoramento, governança e FinOps

## Monitoramento

### Qualidade

Cada camada possui tabela de validação mais recente e histórico.

```text
latest_silver_validation
latest_gold_validation
latest_streaming_validation
latest_ops_validation
```

### Saúde consolidada

A view `vw_pipeline_health_latest` consolida:

- execução;
- quantidade de testes;
- testes aprovados;
- testes com falha;
- status final.

### Streaming

A tabela `streaming_latency_summary` calcula:

- quantidade de eventos;
- eventos com horário de publicação;
- eventos sem horário de publicação;
- latência média ponta a ponta;
- P95;
- latência máxima;
- latência média após publicação.

### BigQuery

`bigquery_usage_daily` acompanha:

- jobs;
- falhas;
- bytes processados;
- bytes faturados;
- slot-ms;
- cache hits.

## Alertas

| Política | Sinal |
|---|---|
| Pub/Sub backlog alto | mensagens não entregues |
| Pub/Sub mensagem antiga | idade da mensagem mais antiga |
| Dataflow system lag alto | atraso do job |
| Erro no Dataflow | log com severidade de erro |

## Segurança operacional

- public access prevention;
- uniform bucket-level access;
- service accounts por workload;
- sem chaves persistentes;
- menor privilégio;
- labels;
- auditoria de papéis básicos.

## FinOps

### Controles técnicos

- Parquet e Snappy;
- partições;
- clusterização;
- limites de bytes;
- materialização de produtos;
- lifecycle em temporários;
- um worker no teste;
- drain ao final.

### Controles de gestão

- orçamento;
- alertas de faturamento;
- labels;
- visibilidade de uso;
- estimativa documentada.

### Resultado observado

```text
total_tib_billed = 0,00461102
```

Esse valor representa o uso medido no período do desenvolvimento, não um orçamento garantido para execuções futuras.

## Trade-off

A configuração acadêmica prioriza baixo custo. Um ambiente de produção precisaria balancear:

- latência desejada;
- volume;
- retenção;
- frequência batch;
- quantidade de workers;
- disponibilidade;
- custo mensal.
