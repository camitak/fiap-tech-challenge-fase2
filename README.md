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

## Monitoramento e observabilidade

A solução monitora:

- falhas de qualidade nas camadas Silver e Gold;
- reconciliação entre origem e destino;
- volume de eventos streaming;
- latência média, percentil 95 e latência máxima;
- backlog do Pub/Sub;
- idade da mensagem não confirmada mais antiga;
- system lag do Dataflow;
- erros do Dataflow por meio do Cloud Logging;
- uso e bytes faturados pelo BigQuery.

Os resultados operacionais são armazenados no dataset `alfabetizacao_ops`.

## Governança

A arquitetura aplica:

- contas de serviço separadas por workload;
- princípio do menor privilégio;
- ausência de chaves persistentes;
- acesso uniforme ao Cloud Storage;
- prevenção de acesso público;
- labels por projeto, ambiente e camada;
- contratos versionados para eventos;
- quarentena com motivo técnico;
- restrição de microdados à camada Silver;
- consumo analítico preferencialmente pela Gold.

## FinOps

Os principais controles de custo são:

- Bronze em Parquet com compressão Snappy;
- particionamento por data e lote;
- tabelas BigQuery particionadas e clusterizadas;
- limites máximos de bytes por consulta;
- Dataflow limitado a um worker durante a demonstração;
- encerramento do streaming por drain;
- lifecycle de um dia somente para arquivos temporários;
- orçamento e alertas de faturamento;
- acompanhamento de bytes processados e faturados.