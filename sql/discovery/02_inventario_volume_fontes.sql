SELECT
  table_id AS tabela,
  row_count AS quantidade_linhas,
  ROUND(size_bytes / POW(1024, 2), 2) AS tamanho_mb
FROM
  `basedosdados.br_inep_avaliacao_alfabetizacao.__TABLES__`
WHERE
  table_id IN (
    'alunos',
    'meta_alfabetizacao_brasil',
    'meta_alfabetizacao_municipio',
    'meta_alfabetizacao_uf',
    'municipio',
    'uf'
  )
ORDER BY
  table_id;