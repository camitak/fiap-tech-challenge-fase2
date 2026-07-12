# Aplicações da Gold em inteligência artificial

## Objetivo

A Gold organiza atributos territoriais e temporais que podem alimentar análises avançadas. Ela não representa, por si só, um modelo treinado ou uma decisão automatizada.

## 1. Predição da alfabetização

### Perguntas

- qual a taxa esperada no próximo ano?
- qual município possui risco de não alcançar a meta?
- quais territórios apresentam tendência de queda?
- qual intervalo provável do indicador?

### Unidade de análise

Município e ano.

### Features candidatas

- taxa atual;
- taxa anterior;
- variação anual;
- gap da meta;
- participação;
- presença;
- proficiência;
- taxa calculada nos microdados;
- distribuição por níveis;
- divergência entre indicador publicado e cálculo;
- quartil de desempenho.

### Alvo

```text
taxa_alfabetizacao_ano_seguinte
```

### Modelos possíveis

- regressão linear regularizada;
- random forest;
- gradient boosting;
- modelos hierárquicos;
- modelos temporais, após ampliação da série.

## 2. Desigualdade educacional

### Métricas

- diferença para a média nacional;
- dispersão entre UFs;
- distância entre quartis;
- persistência abaixo da meta;
- cobertura de participação;
- clusters territoriais.

### Enriquecimento recomendado

- Censo Escolar;
- Censo e PNAD;
- Atlas do Desenvolvimento Humano;
- CadÚnico;
- FUNDEB;
- território e ruralidade.

## 3. Políticas públicas

### Possíveis produtos

- mapa de risco;
- lista de territórios prioritários;
- alerta de deterioração;
- monitor de metas;
- avaliação antes/depois de intervenções;
- segmentação de municípios com necessidades semelhantes.

## 4. Riscos e controles

### Vazamento temporal

Features do futuro não podem ser usadas para prever o passado.

### Viés

Cobertura, participação e ausência de dados podem variar territorialmente.

### Explicabilidade

Órgãos públicos precisam compreender quais fatores influenciam a previsão.

### Causalidade

Correlação não prova que uma variável causou o resultado.

### Supervisão humana

O modelo deve apoiar, e não substituir, decisões de política pública.

### Monitoramento

Modelos futuros precisam acompanhar drift, erro por grupo, cobertura e custo.

## 5. Limitações atuais

A maior parte das fontes detalhadas cobre apenas 2023 e 2024. Esse histórico é insuficiente para afirmar robustez preditiva. A tabela de features demonstra preparação técnica, mas o treinamento definitivo exige mais anos e enriquecimento.
