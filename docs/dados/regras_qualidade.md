# Regras de qualidade — Camada Silver

As regras são divididas em duas severidades:

- **Crítica:** o registro é enviado à quarentena e não avança para a Silver.
- **Alerta:** o registro avança, mas recebe `quality_status = ALERT` e a lista `quality_alerts`.

## Regras críticas principais

- chaves obrigatórias ausentes;
- códigos territoriais inválidos;
- códigos categóricos não encontrados no dicionário;
- chaves candidatas duplicadas;
- taxas, metas, participação ou proporções fora de 0 a 100;
- proficiência negativa;
- peso do aluno não positivo;
- UF inválida.

## Alertas principais

- taxa, média, participação ou meta ausente;
- proporções por nível ausentes ou parcialmente preenchidas;
- soma dos nove níveis fora da tolerância de 99,9 a 100,1;
- aluno presente com prova preenchida, mas sem proficiência;
- inconsistência entre proficiência e corte de 743 pontos;
- cobertura incompleta nos relacionamentos entre metas e resultados.

## Quarentena

A tabela `alfabetizacao_quarantine.records` contém:

- fonte;
- data e lote de ingestão;
- chave do registro;
- severidade;
- lista das regras violadas;
- mensagem explicativa;
- payload original em JSON;
- data da detecção.
