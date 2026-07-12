# Catálogo de campos do dashboard

## Resumo nacional

| Campo | Significado |
|---|---|
| `taxa_alfabetizacao_brasil` | Resultado nacional publicado |
| `meta_brasil` | Meta correspondente ao ano |
| `gap_meta_brasil_pp` | Resultado menos meta, em pontos percentuais |
| `participacao_brasil` | Percentual de participação |
| `percentual_ufs_atingiram_meta` | UFs comparáveis que atingiram ou superaram a meta |
| `percentual_municipios_atingiram_meta` | Municípios comparáveis que atingiram ou superaram a meta |

## UF

| Campo | Significado |
|---|---|
| `sigla_uf` | Unidade da Federação |
| `taxa_alfabetizacao_resultado` | Resultado da UF |
| `meta_alfabetizacao` | Meta da UF para o ano |
| `gap_meta_pontos_percentuais` | Resultado menos meta |
| `gap_brasil_pontos_percentuais` | Resultado da UF menos resultado nacional |
| `posicao_uf` | Ranking da UF dentro do ano |
| `status_meta` | Situação em relação à meta |
| `integration_status` | Cobertura do cruzamento entre resultado e meta |

## Município

| Campo | Significado |
|---|---|
| `id_municipio` | Código oficial do município |
| `taxa_alfabetizacao_resultado` | Resultado municipal publicado |
| `taxa_alfabetizacao_calculada` | Taxa calculada com os microdados disponíveis |
| `divergencia_microdados_publicado_pp` | Diferença entre taxa calculada e publicada |
| `taxa_presenca` | Presença calculada nos microdados |
| `proficiencia_media` | Proficiência média |
| `faixa_gap_meta` | Classificação da distância da meta |
| `faixa_participacao` | Classificação da participação |
| `posicao_nacional_municipio` | Ranking municipal no ano |

## Streaming

| Campo | Significado |
|---|---|
| `quantidade_eventos` | Eventos válidos do tipo |
| `eventos_bronze_total_run` | Total bruto recebido na simulação |
| `eventos_validos_total_run` | Total aprovado na Silver |
| `eventos_invalidos_total_run` | Total enviado à quarentena |
| `avg_end_to_end_latency_seconds` | Média entre o horário do evento e o processamento |
| `p95_end_to_end_latency_seconds` | Percentil 95 da latência ponta a ponta |
| `avg_processing_latency_seconds` | Média entre publicação no Pub/Sub e processamento |

## Operação e custos

| Campo | Significado |
|---|---|
| `checks_total` | Quantidade de testes da pipeline |
| `checks_failed` | Testes que falharam |
| `pipeline_status` | Saúde consolidada da pipeline |
| `query_jobs` | Jobs de consulta concluídos |
| `failed_jobs` | Jobs com erro |
| `total_tib_billed` | Volume faturável em TiB |
| `cache_hit_jobs` | Consultas atendidas pelo cache |
