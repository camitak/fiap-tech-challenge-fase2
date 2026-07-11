# ADR-002 — Arquitetura Medalhão

## Status

Aceita.

## Contexto

A solução precisa preservar o dado original, aplicar regras de qualidade e
disponibilizar produtos analíticos confiáveis.

## Decisão

Separar o pipeline em Bronze, Silver e Gold.

## Bronze

Preserva os dados brutos e adiciona somente metadados técnicos.

## Silver

Aplica:

- tipagem;
- padronização;
- deduplicação;
- decodificação;
- validação;
- quarentena;
- integração.

## Gold

Disponibiliza produtos analíticos agregados por Brasil, UF e município.

## Consequências

A separação aumenta a rastreabilidade e facilita reprocessamentos, mas exige
mais objetos, documentação e governança.