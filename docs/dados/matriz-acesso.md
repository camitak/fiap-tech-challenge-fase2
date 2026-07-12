# Matriz de acesso

| Identidade | Escopo | Papel | Finalidade |
|---|---|---|---|
| `sa-batch-ingestion` | Projeto | BigQuery Job User | Executar consultas batch |
| `sa-batch-ingestion` | Projeto | BigQuery Resource Viewer | Ler metadados de jobs |
| `sa-batch-ingestion` | Bronze | BigQuery Data Viewer | Ler fontes |
| `sa-batch-ingestion` | Silver | BigQuery Data Editor | Construir Silver |
| `sa-batch-ingestion` | Gold | BigQuery Data Editor | Construir Gold |
| `sa-batch-ingestion` | Ops | BigQuery Data Editor | Gravar auditoria |
| `sa-batch-ingestion` | Quarentena | BigQuery Data Editor | Gravar rejeições |
| `sa-streaming-dataflow` | Projeto | Dataflow Worker | Executar workers |
| `sa-streaming-dataflow` | Pub/Sub | Subscriber/Publisher | Consumir e publicar DLQ |
| `sa-streaming-dataflow` | Bronze | BigQuery Data Editor | Gravar bruto |
| `sa-streaming-dataflow` | Silver | BigQuery Data Editor | Gravar válidos |
| `sa-streaming-dataflow` | Quarentena | BigQuery Data Editor | Gravar inválidos |

## Restrições

- não criar chaves JSON;
- não conceder `Owner` ou `Editor`;
- não expor microdados de alunos ao dashboard;
- preferir leitura da Gold;
- restringir concessões ao recurso necessário.
