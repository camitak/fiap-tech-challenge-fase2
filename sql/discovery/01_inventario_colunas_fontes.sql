SELECT
  table_name,
  ordinal_position,
  column_name,
  data_type,
  is_nullable
FROM
  `basedosdados.br_inep_avaliacao_alfabetizacao.INFORMATION_SCHEMA.COLUMNS`
WHERE
  table_name IN (
    'alunos',
    'meta_alfabetizacao_brasil',
    'meta_alfabetizacao_municipio',
    'meta_alfabetizacao_uf',
    'municipio',
    'uf'
  )
ORDER BY
  table_name,
  ordinal_position;