# Evidências de execução

## Identificação

- Project ID: `fiap-tc-f2-camila-takemoto`
- Região BigQuery: `US`
- Região Dataflow: `us-central1`
- Batch ID: `batch_20260712T011134Z`
- Simulation Run ID: `sim_20260712T142039Z`

## Resultado consolidado

| Etapa | Resultado | Evidência |
|---|---|---|
| Bronze | 7 fontes reconciliadas | [Validação batch](etapa-04/validacao_batch_20260712T011134Z.txt) |
| Silver | 13 testes aprovados | [Validação Silver](etapa-05/validacao_silver_batch_20260712T011134Z.txt) |
| Gold | 19 testes aprovados | [Validação Gold](etapa-06/validacao_gold.txt) |
| Streaming | 15 recebidos, 12 válidos e 3 inválidos | [Validação streaming](etapa-07/validacao_streaming_sim_20260712T142039Z.txt) |
| Dataflow | Job encerrado por drain | [Encerramento](etapa-07/dataflow_stop_alfabetizacao-stream-20260712-141823.txt) |
| Observabilidade | 11 testes aprovados | [Validação Ops](etapa-08/validacao_observabilidade.txt) |
| Governança | IAM, bucket e alertas verificados | [Evidências da Etapa 8](etapa-08/) |

## Resumo

- Alunos processados: 3.867.999
- Produtos Gold: 7
- Pipelines saudáveis: 3 de 3
- Eventos válidos: 12
- Eventos em quarentena: 3
- TiB faturados no BigQuery: 0,00461102
- Custo Dataflow observado: US$ 0,04