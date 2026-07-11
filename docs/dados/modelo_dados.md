# Modelo de dados

## Modelo das fontes

```mermaid
erDiagram
    ALUNOS {
        int ano
        string id_municipio
        string id_escola
        string id_aluno
        string serie
        string rede
        string presenca
        string alfabetizado
        float proficiencia
        float peso_aluno
    }

    RESULTADO_MUNICIPIO {
        int ano
        string id_municipio
        string serie
        string rede
        float taxa_alfabetizacao
        float media_portugues
    }

    RESULTADO_UF {
        int ano
        string sigla_uf
        string serie
        string rede
        float taxa_alfabetizacao
        float media_portugues
    }

    META_MUNICIPIO {
        int ano
        string id_municipio
        string rede
        float taxa_alfabetizacao
        int nivel_alfabetizacao
        float percentual_participacao
    }

    META_UF {
        int ano
        string sigla_uf
        string rede
        float taxa_alfabetizacao
        float percentual_participacao
    }

    META_BRASIL {
        int ano
        string rede
        float taxa_alfabetizacao
        float percentual_participacao
    }

    DICIONARIO {
        string coluna
        string chave
        string valor
    }

    RESULTADO_MUNICIPIO }o--o| META_MUNICIPIO : "ano, município e rede normalizada"
    RESULTADO_UF }o--o| META_UF : "ano, UF e rede normalizada"
    ALUNOS }o--o{ RESULTADO_MUNICIPIO : "agregação por ano e município"
    DICIONARIO ||--o{ ALUNOS : "decodifica categorias"
    DICIONARIO ||--o{ RESULTADO_MUNICIPIO : "decodifica categorias"
    DICIONARIO ||--o{ RESULTADO_UF : "decodifica categorias"
```

## Modelo analítico proposto

A camada Gold será organizada por nível territorial.

### Gold Brasil

Grão:

- ano
- rede

Principais métricas:

- taxa de alfabetização;
- meta correspondente ao ano;
- diferença entre resultado e meta;
- percentual de participação;
- variação anual;
- situação da meta.

### Gold UF

Grão:

- ano
- sigla_uf
- rede

Principais métricas:

- taxa de alfabetização;
- meta correspondente ao ano;
- diferença entre resultado e meta;
- média de português;
- participação;
- distribuição por nível;
- posição da UF;
- diferença em relação ao Brasil.

### Gold Município

Grão:

- ano
- id_municipio
- rede

Principais métricas:

- taxa de alfabetização;
- meta correspondente ao ano;
- diferença entre resultado e meta;
- média de português;
- participação;
- nível de alfabetização;
- distribuição dos estudantes por nível.

### Gold Alunos Agregados

Os microdados não serão disponibilizados individualmente para consumo
analítico aberto. Eles serão agregados por município, ano e rede.

Métricas:

- total de alunos;
- total de presentes;
- total com caderno preenchido;
- total alfabetizado;
- taxa de presença;
- taxa de preenchimento;
- taxa de alfabetização calculada;
- proficiência média;
- proficiência ponderada.