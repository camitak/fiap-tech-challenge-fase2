# Contrato dos eventos streaming

## Envelope comum

```json
{
  "event_id": "UUID",
  "simulation_run_id": "sim_YYYYMMDDTHHMMSSZ",
  "event_type": "indicador_municipio_atualizado",
  "event_time": "2026-07-12T14:00:00Z",
  "schema_version": "1.0",
  "entity_type": "municipio",
  "entity_id": "3550308",
  "source": "simulador-tech-challenge",
  "payload": {}
}
```

## Tipos aceitos

| event_type | entity_type | Campos principais do payload |
|---|---|---|
| indicador_municipio_atualizado | municipio | ano, taxa_alfabetizacao, percentual_participacao, rede |
| indicador_uf_atualizado | uf | ano, taxa_alfabetizacao, percentual_participacao, rede |
| meta_municipio_atualizada | municipio | ano, ano_meta, meta_alfabetizacao, rede |
| meta_uf_atualizada | uf | ano, ano_meta, meta_alfabetizacao, rede |
| resultado_aluno_recebido | aluno | ano, id_municipio, proficiencia, alfabetizado, rede |

## Regras principais

- `event_id` é obrigatório e utilizado para deduplicação.
- `event_time` deve seguir RFC3339 e conter fuso horário.
- `schema_version` deve ser `1.0`.
- percentuais devem ficar entre 0 e 100.
- código de município deve conter sete dígitos.
- sigla de UF deve conter duas letras maiúsculas.
- `ano_meta` deve ficar entre 2024 e 2030.
- proficiência não pode ser negativa.

## Semântica temporal

`event_time` representa quando o evento ocorreu no domínio. O horário de
publicação no Pub/Sub e o horário de processamento são preservados separadamente.

## Semântica de entrega

O fluxo utiliza `event_id` como identificador estável. Como sistemas de streaming
podem reenviar mensagens, consumidores analíticos devem deduplicar pelo evento
mais recente quando necessário.
