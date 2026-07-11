SELECT
  'alunos' AS tabela,
  CAST(rede AS STRING) AS rede,
  COUNT(*) AS quantidade
FROM
  `basedosdados.br_inep_avaliacao_alfabetizacao.alunos`
GROUP BY
  rede

UNION ALL

SELECT
  'municipio',
  CAST(rede AS STRING),
  COUNT(*)
FROM
  `basedosdados.br_inep_avaliacao_alfabetizacao.municipio`
GROUP BY
  rede

UNION ALL

SELECT
  'uf',
  CAST(rede AS STRING),
  COUNT(*)
FROM
  `basedosdados.br_inep_avaliacao_alfabetizacao.uf`
GROUP BY
  rede

UNION ALL

SELECT
  'meta_municipio',
  rede,
  COUNT(*)
FROM
  `basedosdados.br_inep_avaliacao_alfabetizacao.meta_alfabetizacao_municipio`
GROUP BY
  rede

UNION ALL

SELECT
  'meta_uf',
  rede,
  COUNT(*)
FROM
  `basedosdados.br_inep_avaliacao_alfabetizacao.meta_alfabetizacao_uf`
GROUP BY
  rede

UNION ALL

SELECT
  'meta_brasil',
  rede,
  COUNT(*)
FROM
  `basedosdados.br_inep_avaliacao_alfabetizacao.meta_alfabetizacao_brasil`
GROUP BY
  rede

ORDER BY
  tabela,
  rede;