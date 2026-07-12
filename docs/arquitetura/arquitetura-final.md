# Arquitetura final

## Princípios

1. preservar o dado antes de transformá-lo;
2. processar próximo ao armazenamento;
3. separar dados inválidos de dados confiáveis;
4. manter rastreabilidade por lote e evento;
5. desacoplar produtores e consumidores;
6. aplicar custo como requisito arquitetural;
7. disponibilizar produtos analíticos, não apenas tabelas técnicas.

## Diagrama

```mermaid
flowchart TB
    subgraph S1["Fontes"]
        BQ0["Base dos Dados<br/>BigQuery público"]
        CSV0["Arquivos CSV<br/>apoio e desenvolvimento"]
        SIM0["Simulador Python<br/>eventos JSON"]
    end

    subgraph S2["Ingestão batch"]
        EX0["export_bronze.sh<br/>BigQuery EXPORT DATA"]
        GCS0["Cloud Storage<br/>Parquet + Snappy"]
        EXT0["Tabelas externas<br/>Bronze BigQuery"]
    end

    subgraph S3["Ingestão streaming"]
        PS0["Pub/Sub<br/>alfabetizacao-eventos"]
        DF0["Dataflow<br/>Apache Beam"]
        DLQ0["DLQ<br/>mensagens rejeitadas"]
    end

    subgraph S4["Arquitetura medalhão"]
        BR0["Bronze<br/>raw e histórico"]
        SI0["Silver<br/>padronização e integração"]
        QU0["Quarentena<br/>regra + payload"]
        GO0["Gold<br/>KPIs e features"]
    end

    subgraph S5["Operação"]
        OP0["BigQuery Ops"]
        CM0["Cloud Monitoring"]
        CL0["Cloud Logging"]
        IAM0["IAM e contas de serviço"]
        FI0["Budgets, labels,<br/>limits e lifecycle"]
    end

    BQ0 --> EX0
    CSV0 -. comparação .-> EX0
    EX0 --> GCS0 --> EXT0 --> BR0

    SIM0 --> PS0 --> DF0
    DF0 --> BR0
    DF0 --> SI0
    DF0 --> QU0
    DF0 --> DLQ0

    BR0 --> SI0
    SI0 --> QU0
    SI0 --> GO0

    BR0 -. volume .-> OP0
    SI0 -. qualidade .-> OP0
    GO0 -. validação .-> OP0
    PS0 -. backlog .-> CM0
    DF0 -. lag .-> CM0
    DF0 -. erro .-> CL0
    OP0 --> CM0

    IAM0 -. acesso .-> EX0
    IAM0 -. acesso .-> DF0
    FI0 -. custo .-> GCS0
    FI0 -. custo .-> GO0
    FI0 -. custo .-> DF0
```

## Fluxo batch

```mermaid
sequenceDiagram
    participant SRC as BigQuery público
    participant JOB as Script batch
    participant GCS as Cloud Storage Bronze
    participant BQ as BigQuery
    participant Q as Quarentena
    participant OPS as Ops

    JOB->>SRC: consulta as sete fontes
    SRC-->>JOB: dados estruturados
    JOB->>GCS: EXPORT DATA Parquet
    JOB->>BQ: cria tabelas externas
    JOB->>OPS: reconcilia origem x Bronze
    BQ->>BQ: constrói Silver
    BQ->>Q: grava erros críticos
    BQ->>BQ: integra dados válidos
    BQ->>BQ: constrói Gold
    BQ->>OPS: grava validações
```

## Fluxo streaming

```mermaid
sequenceDiagram
    participant SIM as Simulador
    participant PS as Pub/Sub
    participant DF as Dataflow
    participant BR as Bronze
    participant SI as Silver
    participant Q as Quarentena
    participant DLQ as DLQ
    participant OPS as Ops

    SIM->>PS: publica evento JSON
    PS->>DF: entrega mensagem
    DF->>BR: preserva raw_message
    alt evento válido
        DF->>SI: grava evento tipado
    else evento inválido
        DF->>Q: grava erro e payload
        DF->>DLQ: publica rejeição
    end
    SI->>OPS: volume e latência
```

## Topologia dos dados

```text
Fonte pública
  └── snapshot batch
      └── Cloud Storage Bronze
          └── tabela externa Bronze
              └── Silver tipada e integrada
                  ├── Quarentena
                  └── Gold analítica

Simulador
  └── Pub/Sub
      └── Dataflow
          ├── Bronze raw
          ├── Silver válida
          ├── Quarentena
          └── DLQ
```

## Escalabilidade

O projeto usa serviços serverless ou gerenciados. BigQuery escala o processamento analítico sem cluster dedicado. Pub/Sub desacopla produtor e consumidor. Dataflow pode aumentar workers quando houver necessidade real.

No ambiente acadêmico, o autoscaling foi restringido para reduzir custo. Em produção, quantidade mínima, máxima e política de autoscaling devem ser definidas com base em backlog, latência e SLA.
