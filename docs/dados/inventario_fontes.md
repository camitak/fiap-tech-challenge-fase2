# Inventário das fontes de dados

## Origem

Os dados são provenientes do projeto público `basedosdados`, dataset
`br_inep_avaliacao_alfabetizacao`, disponível no Google BigQuery.

Data da análise inicial: preencher com a data da execução.

## Tabelas obrigatórias

| Tabela | Linhas | Tamanho aproximado | Cobertura |
|---|---:|---:|---|
| alunos | 3.867.999 | 256,10 MB | 2023–2024 |
| meta_alfabetizacao_brasil | 3 | menor que 0,01 MB | 2023–2025 |
| meta_alfabetizacao_municipio | 10.704 | 1,10 MB | 2023–2024 |
| meta_alfabetizacao_uf | 81 | 0,01 MB | 2023–2025 |
| municipio | 23.995 | 1,75 MB | 2023–2024 |
| uf | 145 | 0,01 MB | 2023–2024 |

## Fonte auxiliar

A tabela `dicionario` será utilizada para interpretar códigos e categorias,
como rede de ensino, presença, preenchimento do caderno e alfabetização.

A tabela de dicionário é uma fonte de metadados e não substitui nenhuma
das seis entidades obrigatórias do desafio.

## Granularidade preliminar

### alunos

Um registro representa o resultado de um aluno em determinado ano de
avaliação.

Chave candidata:

- ano
- id_aluno

### municipio

Um registro representa um indicador agregado por:

- ano
- município
- série
- rede

Chave candidata:

- ano
- id_municipio
- serie
- rede

### uf

Um registro representa um indicador agregado por:

- ano
- UF
- série
- rede

Chave candidata:

- ano
- sigla_uf
- serie
- rede

### meta_alfabetizacao_municipio

Um registro representa o indicador e as metas de um município, rede e ano.

Chave candidata:

- ano
- id_municipio
- rede

### meta_alfabetizacao_uf

Um registro representa o indicador e as metas de uma UF, rede e ano.

Chave candidata:

- ano
- sigla_uf
- rede

### meta_alfabetizacao_brasil

Um registro representa o indicador e as metas nacionais de uma rede e ano.

Chave candidata:

- ano
- rede

## Pontos de atenção

1. As tabelas de resultado utilizam códigos de rede, enquanto as tabelas
   de metas utilizam valores textuais.
2. Todos os campos das tabelas de origem estão definidos como anuláveis.
3. Os dados municipais detalhados ainda não cobrem 2025.
4. A tabela de alunos representa a maior parte do volume do projeto.
5. Valores nulos não devem ser automaticamente substituídos por zero.
6. As colunas de metas estão em formato largo e deverão ser transformadas
   em linhas na camada Silver.