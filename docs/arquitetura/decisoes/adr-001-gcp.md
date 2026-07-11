# ADR-001 — Uso da Google Cloud Platform

## Status

Aceita.

## Contexto

As fontes oficiais do projeto já estão disponíveis no BigQuery público da
Base dos Dados. A solução precisa implementar armazenamento, processamento
batch, streaming, monitoramento e controle de custos.

## Decisão

Utilizar a Google Cloud Platform como ambiente principal.

Serviços previstos:

- BigQuery;
- Cloud Storage;
- Pub/Sub;
- Dataflow;
- Cloud Monitoring;
- Cloud Billing;
- Looker Studio.

## Justificativa

A escolha evita movimentação desnecessária de dados entre provedores e
permite utilizar serviços gerenciados e serverless.

## Consequências positivas

- integração nativa com as fontes;
- menor esforço operacional;
- escalabilidade;
- pagamento conforme uso;
- facilidade de monitoramento.

## Consequências negativas

- dependência dos serviços da GCP;
- necessidade de controle rigoroso de custos;
- necessidade de aprender IAM e permissões;
- risco de custos em consultas ou pipelines mal configurados.