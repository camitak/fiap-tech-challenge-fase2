SELECT
  ordinal_position,
  column_name,
  data_type,
  is_nullable
FROM
  `basedosdados.br_inep_avaliacao_alfabetizacao.INFORMATION_SCHEMA.COLUMNS`
WHERE
  table_name = 'dicionario'
ORDER BY
  ordinal_position;