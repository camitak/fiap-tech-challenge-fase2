# Dicionário da camada Gold

## kpi_brasil

Grão: uma linha por ano e rede nacional.

Principais campos:

- `taxa_alfabetizacao_resultado`: indicador publicado para o ano;
- `meta_alfabetizacao`: meta correspondente ao mesmo ano;
- `gap_meta_pontos_percentuais`: resultado menos meta;
- `variacao_pp_ano_anterior`: evolução em pontos percentuais;
- `status_meta`: situação da comparação;
- `percentual_participacao`: participação na avaliação.

## kpi_uf

Grão: uma linha por ano e UF.

Inclui:

- comparação com a meta estadual;
- comparação com o indicador nacional;
- ranking e quartil entre UFs com resultado;
- evolução em relação ao ano anterior;
- status de cobertura da integração.

## kpi_municipio

Grão: uma linha por ano e município para a rede municipal.

Inclui:

- resultado publicado;
- meta do mesmo ano;
- gap da meta;
- média de português;
- microdados agregados;
- taxa de presença;
- proficiência média;
- ranking e quartil;
- divergência entre cálculo dos microdados e indicador publicado.

As faixas de gap e participação são classificações analíticas do projeto. Não
representam categorias oficiais do INEP ou do MEC.

## cobertura_integracao

Resume `MATCH`, `SOMENTE_RESULTADO` e `SOMENTE_META` por ano e nível
territorial. Essa tabela evita ocultar lacunas de cobertura.

## distribuicao_niveis_uf

Transforma as nove colunas de proporção por nível em linhas, facilitando o
uso em gráficos e análises estatísticas.

## resumo_executivo

Tabela anual pronta para cartões e indicadores de dashboard.

## features_modelo_municipio

Tabela preparada para futuros experimentos de machine learning. O alvo é a
taxa de alfabetização do ano seguinte, quando existe uma observação consecutiva.
A base atual possui poucos anos e, isoladamente, não é suficiente para afirmar que
um modelo preditivo terá boa generalização.
