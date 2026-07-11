# Arquitetura da solução

## Visão geral

A solução utiliza arquitetura medalhão e combina ingestão batch e streaming.

```mermaid
flowchart LR
    subgraph FONTES["Fontes públicas"]
        BQ["BigQuery público\nBase dos Dados"]
        CSV["CSV de desenvolvimento"]
        DIC["Tabela dicionário"]
    end

    subgraph BATCH["Fluxo Batch"]
        EXT["Extração periódica"]
        GCS["Cloud Storage\nBronze Parquet"]
    end

    subgraph STREAMING["Fluxo Streaming"]
        PROD["Simulador Python"]
        PUB["Pub/Sub"]
        DF["Dataflow / Apache Beam"]
        DLQ["Dead-letter queue"]
    end

    subgraph MEDALHAO["Camadas analíticas"]
        BRONZE["Bronze\nDados brutos + metadados"]
        SILVER["Silver\nLimpeza, tipagem e qualidade"]
        QUA["Quarentena"]
        GOLD["Gold\nProdutos analíticos"]
    end

    subgraph CONSUMO["Consumo"]
        BI["Looker Studio"]
        SQL["Consultas SQL"]
        ML["Modelos de IA"]
    end

    subgraph OPERACAO["Operação"]
        MON["Cloud Monitoring"]
        FIN["Budgets e FinOps"]
        OPS["Tabelas de auditoria"]
    end

    BQ --> EXT
    CSV --> EXT
    DIC --> EXT
    EXT --> GCS
    GCS --> BRONZE

    PROD --> PUB
    PUB --> DF
    DF --> BRONZE
    DF --> DLQ

    BRONZE --> SILVER
    SILVER --> QUA
    SILVER --> GOLD

    GOLD --> BI
    GOLD --> SQL
    GOLD --> ML

    BRONZE -. métricas .-> MON
    SILVER -. métricas .-> MON
    GOLD -. métricas .-> MON
    MON --> OPS
    FIN -. controle de custos .-> BATCH
    FIN -. controle de custos .-> STREAMING
```

## Componentes

### BigQuery público

Origem principal dos dados históricos disponibilizados pela Base dos Dados.

### Cloud Storage

Armazena snapshots históricos da camada Bronze em formato Parquet,
preservando os dados como foram recebidos.

### BigQuery

Armazena e processa as camadas Silver e Gold.

### Pub/Sub

Recebe os eventos publicados pelo simulador de streaming.

### Dataflow

Valida, transforma e direciona eventos para a Bronze ou para a fila de erros.

### Looker Studio

Consome os produtos analíticos da camada Gold.

### Cloud Monitoring

Acompanha execução, falhas, latência, backlog e registros em quarentena.

## Estratégia de processamento

- Batch para dados históricos e metas.
- Streaming simulado para eventos de atualização.
- ELT para as transformações analíticas dentro do BigQuery.
- Dados inválidos enviados para quarentena.
- Camada Gold composta por produtos de dados agregados.