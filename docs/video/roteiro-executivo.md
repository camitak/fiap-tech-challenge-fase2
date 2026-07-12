# Roteiro executivo — vídeo de até 5 minutos

## 0:00–0:35 — Problema

A alfabetização na infância influencia toda a trajetória educacional. O
problema não é somente calcular um indicador, mas integrar microdados, resultados,
metas municipais, estaduais e nacionais com qualidade, rastreabilidade e baixo
custo.

## 0:35–1:25 — Arquitetura

A solução foi construída na Google Cloud usando uma arquitetura híbrida.

No fluxo batch, as fontes públicas do BigQuery são exportadas para o Cloud
Storage em Parquet e preservadas na Bronze. O BigQuery realiza as transformações
Silver e Gold.

No fluxo streaming, um simulador publica eventos no Pub/Sub. O Dataflow
processa os eventos, preserva o bruto, envia eventos válidos para a Silver e eventos
inválidos para quarentena e dead-letter queue.

## 1:25–2:10 — Qualidade e governança

A pipeline aplica reconciliação, unicidade, validade, consistência e cobertura.

No lote utilizado:

- 3.867.999 registros de alunos foram reconciliados;
- as seis fontes obrigatórias e o dicionário foram integrados;
- todos os testes Silver, Gold e Streaming terminaram com sucesso;
- contas de serviço separadas foram utilizadas sem chaves persistentes;
- o bucket possui prevenção de acesso público.

## 2:10–3:05 — Resultados educacionais

Em 2024, o resultado nacional foi 59,2%, frente a uma meta de 59,9%, um gap
de aproximadamente -0,7 ponto percentual.

Entre as UFs comparáveis, 45,83% atingiram ou superaram a meta. Entre os
municípios comparáveis, o percentual foi 53,29%.

Em 2025, o resultado nacional chegou a 66%, acima da meta nacional de 64%.
Os resultados detalhados por UF e município da fonte utilizada ainda terminam em
2024, e essa ausência foi preservada como informação de cobertura.

## 3:05–3:50 — Streaming e monitoramento

O teste de streaming publicou 15 eventos:

- 12 eventos válidos foram processados;
- 3 eventos inválidos foram enviados à quarentena;
- nenhuma duplicidade foi encontrada.

A latência média observada ficou em torno de 144 segundos no ambiente de
demonstração com um único worker. Por isso, a solução é apresentada como tempo
quase real e não como processamento instantâneo.

A saúde do batch, da Gold e do streaming é consolidada em tabelas de
observabilidade e alertas do Cloud Monitoring.

## 3:50–4:30 — FinOps

A Bronze usa Parquet com compressão Snappy e particionamento por data e lote.
As tabelas analíticas são particionadas e clusterizadas.

O Dataflow foi limitado a um worker e drenado imediatamente após o teste. O
uso observado do BigQuery foi de aproximadamente 0,0046 TiB faturáveis no
período analisado, demonstrando baixo consumo no cenário acadêmico.

## 4:30–4:55 — Potencial para IA

A Gold disponibiliza features municipais, participação, proficiência, taxa,
distância da meta e evolução temporal. Com mais anos e enriquecimento
socioeconômico, essa base poderá apoiar modelos de previsão, identificação de
municípios vulneráveis e priorização de políticas públicas.

## 4:55–5:00 — Encerramento

O resultado é uma plataforma confiável, monitorada e preparada para transformar
dados educacionais em decisões baseadas em evidências.
