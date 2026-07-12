# Checklist da entrega

## Requisitos documentais

| Requisito | Status | Local |
|---|---|---|
| Contexto do problema | Atendido | `README.md` |
| Desafio educacional | Atendido | `README.md` |
| Indicador de alfabetização | Atendido | `README.md` |
| Arquitetura proposta | Atendido | `README.md` e `docs/arquitetura/arquitetura-final.md` |
| Descrição da solução | Atendido | `README.md` e `docs/documentacao-tecnica.md` |
| Diagrama da pipeline | Atendido | Mermaid no README e arquitetura |
| Fluxo de dados | Atendido | README e runbook |
| Tecnologias e justificativas | Atendido | `README.md` |
| Batch vs streaming | Atendido | README e decisões arquiteturais |
| Data lake vs data warehouse | Atendido | README e decisões arquiteturais |
| Custo vs performance | Atendido | README e FinOps |
| Monitoramento | Atendido | README e operação |
| Controle de custos | Atendido | README e FinOps |
| Predição | Atendido | README e IA |
| Desigualdade | Atendido | README e IA |
| Políticas públicas | Atendido | README e IA |

## Estrutura mínima

| Item | Status | Evidência |
|---|---|---|
| Código-fonte dos pipelines | Atendido | `src/batch`, `src/silver`, `src/gold`, `src/streaming`, `src/ops` |
| Camadas Bronze, Silver e Gold | Atendido | datasets GCP, `sql/`, `src/` e documentação |
| Scripts de validação | Atendido | `validate_bronze.sh`, `validate_silver.sh`, `validate_gold.sh`, `validate_streaming.sh`, `validate_observability.sh` |
| Regras de qualidade | Atendido | `sql/*/validate_*.sql` e `docs/dados/regras_qualidade.md` |
| Documentação técnica | Atendido | `docs/` |
| README completo | Atendido após substituir pelo arquivo final | `README.md` |

## Antes da entrega

- [ ] substituir o README antigo;
- [ ] copiar a documentação final;
- [ ] remover arquivos `.bak`;
- [ ] confirmar que não há credenciais;
- [ ] confirmar que não há job Dataflow ativo;
- [ ] confirmar que as branches foram integradas;
- [ ] verificar Pull Requests e mensagens de commits;
- [ ] conferir links relativos do README;
- [ ] conferir renderização dos diagramas Mermaid;
- [ ] executar `git status`;
- [ ] abrir o repositório em janela anônima;
- [ ] gravar o vídeo executivo;
- [ ] inserir o link do vídeo na entrega.
