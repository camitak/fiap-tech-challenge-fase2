SELECT
  TO_JSON_STRING(d) AS registro
FROM
  `basedosdados.br_inep_avaliacao_alfabetizacao.dicionario` AS d
WHERE
  REGEXP_CONTAINS(
    LOWER(TO_JSON_STRING(d)),
    r'(rede|presenca|preenchimento_caderno|alfabetizado|serie|caderno)'
  )
ORDER BY
  registro;