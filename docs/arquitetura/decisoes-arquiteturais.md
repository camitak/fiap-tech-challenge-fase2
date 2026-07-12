# Decisões arquiteturais e trade-offs

## GCP como provedor

**Decisão:** usar Google Cloud Platform.

**Motivos:**

- fontes já disponíveis no BigQuery;
- integração entre BigQuery, Cloud Storage, Pub/Sub e Dataflow;
- serviços gerenciados;
- menor movimentação de dados;
- menor esforço operacional.

**Trade-off:** maior dependência do ecossistema GCP.

## Arquitetura híbrida

**Decisão:** combinar batch e streaming.

**Batch:** metas e histórico.

**Streaming:** atualizações simuladas.

**Trade-off:** o streaming entrega menor latência, mas exige mensageria, worker contínuo, contrato, DLQ e monitoramento.

## Arquitetura medalhão

**Decisão:** separar Bronze, Silver e Gold.

**Benefício:** rastreabilidade, reprocessamento, isolamento da qualidade e consumo confiável.

**Custo:** maior quantidade de objetos e necessidade de governança.

## Data lake + data warehouse

**Decisão:** Bronze em Cloud Storage e camadas analíticas em BigQuery.

**Benefício:** histórico econômico e flexível no lake; esquema e performance no warehouse.

**Trade-off:** dados existem em mecanismos diferentes e precisam de catálogo consistente.

## BigQuery no batch

**Decisão:** transformar com GoogleSQL.

**Motivo:** dados estruturados, volume compatível e origem já no BigQuery.

**Alternativa rejeitada:** cluster Spark permanente.

**Trade-off:** SQL reduz complexidade, mas aumenta dependência do mecanismo analítico.

## Dataflow no streaming

**Decisão:** Apache Beam executado no Dataflow.

**Benefício:** integração gerenciada e processamento distribuído.

**Trade-off:** custo enquanto o job está ativo e maior tempo de inicialização.

## Materialização na Gold

**Decisão:** materializar KPIs e usar poucas views.

**Benefício:** consultas de consumo mais simples e previsíveis.

**Trade-off:** armazenamento adicional e necessidade de reconstrução.

## Quarentena

**Decisão:** não corrigir silenciosamente registros críticos.

**Benefício:** transparência e auditabilidade.

**Trade-off:** consumidores precisam compreender cobertura e alertas.

## Valores nulos

**Decisão:** não substituir `NULL` por zero sem regra de negócio.

**Benefício:** ausência de informação não é confundida com valor conhecido igual a zero.

**Trade-off:** métricas e dashboards precisam tratar `NULL` explicitamente.

## Segurança sem chaves

**Decisão:** usar impersonação e contas anexadas aos workloads.

**Benefício:** reduz risco de vazamento de credenciais.

**Trade-off:** configuração inicial de IAM é mais detalhada.

## Custo vs latência

**Decisão:** um worker Dataflow no teste.

**Resultado:** custo reduzido, com latência média próxima de 144 segundos.

**Implicação:** a solução é apresentada como tempo quase real. Um SLA menor exigiria mais recursos e testes de capacidade.
