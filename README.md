# Tech Challenge — Fase 2

## Pipeline híbrido para análise da alfabetização no Brasil

Este projeto implementa uma pipeline de dados Batch e Streaming utilizando
dados públicos do Indicador Criança Alfabetizada.

## Objetivo

Integrar dados de alunos, municípios, UFs e metas de alfabetização em uma
arquitetura medalhão, garantindo:

- qualidade;
- rastreabilidade;
- escalabilidade;
- monitoramento;
- controle de custos;
- consumo analítico.

## Fontes

Projeto público:

`basedosdados.br_inep_avaliacao_alfabetizacao`

Tabelas principais:

- alunos;
- municipio;
- uf;
- meta_alfabetizacao_brasil;
- meta_alfabetizacao_uf;
- meta_alfabetizacao_municipio.

Fonte auxiliar:

- dicionario.

## Arquitetura

- Google Cloud Storage: Bronze;
- BigQuery: Silver e Gold;
- Pub/Sub: entrada streaming;
- Dataflow: processamento streaming;
- Cloud Monitoring: observabilidade;
- Looker Studio: visualização.

Consulte [a documentação da arquitetura](docs/arquitetura/arquitetura.md).

## Estrutura do projeto

```text
docs/       Documentação e evidências
sql/        Consultas e transformações SQL
src/        Código batch e streaming
infra/      Infraestrutura como código
tests/      Testes automatizados
dashboard/  Evidências e documentação do painel