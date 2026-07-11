SELECT
  'alunos' AS tabela,
  MIN(ano) AS primeiro_ano,
  MAX(ano) AS ultimo_ano,
  COUNT(DISTINCT ano) AS quantidade_anos
FROM
  `basedosdados.br_inep_avaliacao_alfabetizacao.alunos`

UNION ALL

SELECT
  'municipio',
  MIN(ano),
  MAX(ano),
  COUNT(DISTINCT ano)
FROM
  `basedosdados.br_inep_avaliacao_alfabetizacao.municipio`

UNION ALL

SELECT
  'uf',
  MIN(ano),
  MAX(ano),
  COUNT(DISTINCT ano)
FROM
  `basedosdados.br_inep_avaliacao_alfabetizacao.uf`

UNION ALL

SELECT
  'meta_alfabetizacao_municipio',
  MIN(ano),
  MAX(ano),
  COUNT(DISTINCT ano)
FROM
  `basedosdados.br_inep_avaliacao_alfabetizacao.meta_alfabetizacao_municipio`

UNION ALL

SELECT
  'meta_alfabetizacao_uf',
  MIN(ano),
  MAX(ano),
  COUNT(DISTINCT ano)
FROM
  `basedosdados.br_inep_avaliacao_alfabetizacao.meta_alfabetizacao_uf`

UNION ALL

SELECT
  'meta_alfabetizacao_brasil',
  MIN(ano),
  MAX(ano),
  COUNT(DISTINCT ano)
FROM
  `basedosdados.br_inep_avaliacao_alfabetizacao.meta_alfabetizacao_brasil`;