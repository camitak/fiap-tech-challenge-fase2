# Etapa 03 — Configuração base da GCP

## Projeto

- Project ID: fiap-tc-f2-camila-takemoto
- Faturamento habilitado: sim
- Localização dos dados: US
- Ambiente: desenvolvimento

## BigQuery

Datasets criados:

- alfabetizacao_bronze
- alfabetizacao_silver
- alfabetizacao_gold
- alfabetizacao_quarantine
- alfabetizacao_ops

## Cloud Storage

Bucket Bronze:

- Nome: fiap-tc-f2-camila-takemoto-alfabetizacao-bronze
- Localização: US
- Classe: Standard
- Acesso uniforme: habilitado

## Contas de serviço

- sa-batch-ingestion
- sa-streaming-dataflow

Nenhuma chave persistente foi criada.

## FinOps

- Orçamento configurado: sim
- Alertas: 50%, 80% e 100%
- Máximo inicial de bytes por consulta: 1 GiB
- Recursos identificados com labels
- Serviços serverless adotados sempre que adequados

## Segurança

- Sem credenciais no repositório
- Sem chaves de conta de serviço
- Separação de identidades por workload
- Princípio do menor privilégio