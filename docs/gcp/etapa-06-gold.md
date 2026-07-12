# Etapa 06 — Camada Gold

## Objetivo

Disponibilizar datasets analíticos prontos para dashboards, análises
estatísticas e futuros modelos de machine learning.

## Produtos criados

- `kpi_brasil`;
- `kpi_uf`;
- `kpi_municipio`;
- `cobertura_integracao`;
- `distribuicao_niveis_uf`;
- `resumo_executivo`;
- `features_modelo_municipio`.

## Regras analíticas

A comparação entre resultado e meta ocorre somente quando existe uma meta
correspondente ao mesmo ano. A ausência de meta ou resultado permanece explícita
nos campos de status.

Os rankings consideram apenas entidades com resultado publicado. Valores
nulos não recebem posição nem quartil.

## Aplicação em IA

A tabela `features_modelo_municipio` organiza atributos municipais e um alvo
do ano seguinte. Ela pode apoiar provas de conceito de regressão ou classificação,
mas o histórico atual é curto. Para um modelo robusto, recomenda-se enriquecer a
base com mais anos e variáveis socioeconômicas e escolares.

## FinOps

- tabelas particionadas por ano;
- clusterização pelas chaves mais consultadas;
- materialização de produtos reutilizáveis;
- limite de bytes por execução;
- cálculos pesados centralizados na criação da Gold, reduzindo repetição em BI.

## Qualidade

A validação verifica:

- reconciliação com as integrações da Silver;
- unicidade dos grãos analíticos;
- validade de taxas e percentuais;
- consistência dos status de meta;
- integridade dos alvos de machine learning.
