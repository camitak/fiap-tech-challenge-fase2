# Etapa 07 — Pipeline streaming

## Arquitetura

```text
Simulador Python
      |
      v
Pub/Sub: alfabetizacao-eventos
      |
      v
Dataflow / Apache Beam
      |-----------------------> Bronze.streaming_eventos_raw
      |-----------------------> Silver.streaming_eventos
      |-----------------------> Quarantine.streaming_eventos
      |                               |
      |                               v
      +--------------------------> Pub/Sub DLQ
                                      |
                                      v
                         alfabetizacao-eventos-dlq-sub

Silver.streaming_eventos
      |
      v
Gold views de resumo e últimos eventos
```

## Tópicos e assinaturas

- tópico principal: `alfabetizacao-eventos`;
- assinatura do Dataflow: `alfabetizacao-eventos-dataflow`;
- tópico DLQ: `alfabetizacao-eventos-dlq`;
- assinatura DLQ: `alfabetizacao-eventos-dlq-sub`.

A política nativa de dead-letter protege contra falhas repetidas de entrega. Além
disso, mensagens que violam o contrato são publicadas na DLQ pela própria pipeline.

## Camadas

### Bronze

Preserva todas as mensagens, válidas e inválidas, junto com atributos técnicos do
Pub/Sub e timestamps de ingestão.

### Silver

Contém somente eventos válidos, com tipos normalizados e campos do payload
convertidos para tipos analíticos.

### Quarentena

Registra mensagens inválidas e falhas de escrita, com código e descrição do erro.

### Gold

Views atualizadas automaticamente apresentam resumo dos eventos e o último evento
por entidade.

## FinOps

- um único worker;
- `e2-standard-2`;
- autoscaling desabilitado para a demonstração;
- job drenado logo após os testes;
- diretórios temporários removidos após o encerramento;
- tabelas particionadas e clusterizadas.

## Segurança

O worker utiliza a conta `sa-streaming-dataflow`. Nenhuma chave JSON persistente é
criada.
