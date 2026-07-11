# ADR-003 — BigQuery em vez de cluster Spark permanente

## Status

Aceita.

## Contexto

A maior tabela possui aproximadamente 3,87 milhões de registros e 256 MB.
Os dados são estruturados e já estão no BigQuery.

## Decisão

Utilizar BigQuery SQL para a maior parte das transformações batch.

Dataflow será usado no fluxo streaming. Não será mantido um cluster Spark
permanente.

## Justificativa

Um cluster permanente adicionaria custo e complexidade sem benefício
proporcional para o volume atual.

## Consequências positivas

- menor custo operacional;
- menos infraestrutura;
- transformações próximas aos dados;
- SQL mais acessível para o projeto.

## Consequências negativas

- maior dependência do BigQuery;
- menor demonstração prática de Spark;
- necessidade de controlar os bytes processados pelas consultas.