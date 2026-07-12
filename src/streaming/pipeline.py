#!/usr/bin/env python3
"""Pipeline streaming Pub/Sub -> Bronze/Silver/Quarentena usando Apache Beam."""

from __future__ import annotations

import argparse
import json
import logging
import re
from datetime import datetime, timezone
from typing import Any, Dict, Iterable, Optional

import apache_beam as beam
from apache_beam.io.gcp.bigquery import BigQueryDisposition, WriteToBigQuery
from apache_beam.io.gcp.bigquery_tools import RetryStrategy
from apache_beam.io.gcp.pubsub import PubsubMessage, ReadFromPubSub, WriteToPubSub
from apache_beam.options.pipeline_options import PipelineOptions, SetupOptions, StandardOptions
from apache_beam.pvalue import TaggedOutput


ALLOWED_EVENT_TYPES = {
    "indicador_municipio_atualizado",
    "indicador_uf_atualizado",
    "meta_municipio_atualizada",
    "meta_uf_atualizada",
    "resultado_aluno_recebido",
}

EXPECTED_ENTITY_TYPE = {
    "indicador_municipio_atualizado": "municipio",
    "indicador_uf_atualizado": "uf",
    "meta_municipio_atualizada": "municipio",
    "meta_uf_atualizada": "uf",
    "resultado_aluno_recebido": "aluno",
}

BRONZE_SCHEMA = {
    "fields": [
        {"name": "event_id", "type": "STRING", "mode": "NULLABLE"},
        {"name": "simulation_run_id", "type": "STRING", "mode": "NULLABLE"},
        {"name": "event_type", "type": "STRING", "mode": "NULLABLE"},
        {"name": "event_time", "type": "TIMESTAMP", "mode": "NULLABLE"},
        {"name": "schema_version", "type": "STRING", "mode": "NULLABLE"},
        {"name": "entity_type", "type": "STRING", "mode": "NULLABLE"},
        {"name": "entity_id", "type": "STRING", "mode": "NULLABLE"},
        {"name": "source", "type": "STRING", "mode": "NULLABLE"},
        {"name": "raw_message", "type": "STRING", "mode": "NULLABLE"},
        {"name": "attributes_json", "type": "STRING", "mode": "NULLABLE"},
        {"name": "pubsub_message_id", "type": "STRING", "mode": "NULLABLE"},
        {"name": "pubsub_publish_time", "type": "TIMESTAMP", "mode": "NULLABLE"},
        {"name": "ingestion_timestamp", "type": "TIMESTAMP", "mode": "REQUIRED"},
    ]
}

SILVER_SCHEMA = {
    "fields": [
        {"name": "event_id", "type": "STRING", "mode": "REQUIRED"},
        {"name": "simulation_run_id", "type": "STRING", "mode": "REQUIRED"},
        {"name": "event_type", "type": "STRING", "mode": "REQUIRED"},
        {"name": "event_time", "type": "TIMESTAMP", "mode": "REQUIRED"},
        {"name": "schema_version", "type": "STRING", "mode": "REQUIRED"},
        {"name": "entity_type", "type": "STRING", "mode": "REQUIRED"},
        {"name": "entity_id", "type": "STRING", "mode": "REQUIRED"},
        {"name": "source", "type": "STRING", "mode": "REQUIRED"},
        {"name": "ano", "type": "INTEGER", "mode": "NULLABLE"},
        {"name": "ano_meta", "type": "INTEGER", "mode": "NULLABLE"},
        {"name": "rede", "type": "STRING", "mode": "NULLABLE"},
        {"name": "id_municipio", "type": "STRING", "mode": "NULLABLE"},
        {"name": "sigla_uf", "type": "STRING", "mode": "NULLABLE"},
        {"name": "taxa_alfabetizacao", "type": "FLOAT", "mode": "NULLABLE"},
        {"name": "meta_alfabetizacao", "type": "FLOAT", "mode": "NULLABLE"},
        {"name": "percentual_participacao", "type": "FLOAT", "mode": "NULLABLE"},
        {"name": "proficiencia", "type": "FLOAT", "mode": "NULLABLE"},
        {"name": "alfabetizado", "type": "BOOLEAN", "mode": "NULLABLE"},
        {"name": "payload_json", "type": "STRING", "mode": "REQUIRED"},
        {"name": "quality_status", "type": "STRING", "mode": "REQUIRED"},
        {"name": "processing_timestamp", "type": "TIMESTAMP", "mode": "REQUIRED"},
    ]
}

QUARANTINE_SCHEMA = {
    "fields": [
        {"name": "event_id", "type": "STRING", "mode": "NULLABLE"},
        {"name": "simulation_run_id", "type": "STRING", "mode": "NULLABLE"},
        {"name": "event_type", "type": "STRING", "mode": "NULLABLE"},
        {"name": "raw_message", "type": "STRING", "mode": "NULLABLE"},
        {"name": "error_code", "type": "STRING", "mode": "REQUIRED"},
        {"name": "error_message", "type": "STRING", "mode": "REQUIRED"},
        {"name": "attributes_json", "type": "STRING", "mode": "NULLABLE"},
        {"name": "pubsub_message_id", "type": "STRING", "mode": "NULLABLE"},
        {"name": "pubsub_publish_time", "type": "TIMESTAMP", "mode": "NULLABLE"},
        {"name": "quarantined_at", "type": "TIMESTAMP", "mode": "REQUIRED"},
    ]
}


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def format_datetime(value: Optional[datetime]) -> Optional[str]:
    if value is None:
        return None
    if value.tzinfo is None:
        value = value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc).isoformat().replace("+00:00", "Z")


def parse_rfc3339(value: Any) -> str:
    if not isinstance(value, str) or not value.strip():
        raise ValueError("event_time deve ser uma string RFC3339")
    parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    if parsed.tzinfo is None:
        raise ValueError("event_time precisa conter fuso horário")
    return parsed.astimezone(timezone.utc).isoformat().replace("+00:00", "Z")


def as_int(value: Any, field_name: str) -> int:
    if isinstance(value, bool):
        raise ValueError(f"{field_name} deve ser inteiro")
    try:
        return int(value)
    except (TypeError, ValueError) as exc:
        raise ValueError(f"{field_name} deve ser inteiro") from exc


def as_float(value: Any, field_name: str) -> float:
    if isinstance(value, bool):
        raise ValueError(f"{field_name} deve ser numérico")
    try:
        return float(value)
    except (TypeError, ValueError) as exc:
        raise ValueError(f"{field_name} deve ser numérico") from exc


def percentage(value: Any, field_name: str) -> float:
    parsed = as_float(value, field_name)
    if not 0 <= parsed <= 100:
        raise ValueError(f"{field_name} deve estar entre 0 e 100")
    return parsed


def required(payload: Dict[str, Any], field_name: str) -> Any:
    value = payload.get(field_name)
    if value is None or value == "":
        raise ValueError(f"payload.{field_name} é obrigatório")
    return value


def validate_entity_id(entity_type: str, entity_id: str) -> None:
    if entity_type == "municipio" and not re.fullmatch(r"\d{7}", entity_id):
        raise ValueError("entity_id de município deve ter 7 dígitos")
    if entity_type == "uf" and not re.fullmatch(r"[A-Z]{2}", entity_id):
        raise ValueError("entity_id de UF deve conter duas letras maiúsculas")
    if entity_type == "aluno" and len(entity_id) < 3:
        raise ValueError("entity_id de aluno é inválido")


def normalize_payload(event_type: str, entity_type: str, entity_id: str, payload: Dict[str, Any]) -> Dict[str, Any]:
    normalized: Dict[str, Any] = {
        "ano": None,
        "ano_meta": None,
        "rede": payload.get("rede"),
        "id_municipio": payload.get("id_municipio"),
        "sigla_uf": payload.get("sigla_uf"),
        "taxa_alfabetizacao": None,
        "meta_alfabetizacao": None,
        "percentual_participacao": None,
        "proficiencia": None,
        "alfabetizado": None,
    }

    if event_type in {"indicador_municipio_atualizado", "indicador_uf_atualizado"}:
        normalized["ano"] = as_int(required(payload, "ano"), "ano")
        normalized["taxa_alfabetizacao"] = percentage(
            required(payload, "taxa_alfabetizacao"), "taxa_alfabetizacao"
        )
        if payload.get("percentual_participacao") is not None:
            normalized["percentual_participacao"] = percentage(
                payload["percentual_participacao"], "percentual_participacao"
            )

    elif event_type in {"meta_municipio_atualizada", "meta_uf_atualizada"}:
        normalized["ano"] = as_int(required(payload, "ano"), "ano")
        normalized["ano_meta"] = as_int(required(payload, "ano_meta"), "ano_meta")
        normalized["meta_alfabetizacao"] = percentage(
            required(payload, "meta_alfabetizacao"), "meta_alfabetizacao"
        )
        if not 2024 <= normalized["ano_meta"] <= 2030:
            raise ValueError("ano_meta deve estar entre 2024 e 2030")

    elif event_type == "resultado_aluno_recebido":
        normalized["ano"] = as_int(required(payload, "ano"), "ano")
        normalized["id_municipio"] = str(required(payload, "id_municipio"))
        if not re.fullmatch(r"\d{7}", normalized["id_municipio"]):
            raise ValueError("payload.id_municipio deve ter 7 dígitos")
        normalized["proficiencia"] = as_float(required(payload, "proficiencia"), "proficiencia")
        if normalized["proficiencia"] < 0:
            raise ValueError("proficiencia não pode ser negativa")
        alfabetizado = required(payload, "alfabetizado")
        if not isinstance(alfabetizado, bool):
            raise ValueError("alfabetizado deve ser booleano")
        normalized["alfabetizado"] = alfabetizado

    if normalized["ano"] is not None and not 2023 <= normalized["ano"] <= 2035:
        raise ValueError("ano está fora do intervalo esperado")

    if entity_type == "municipio":
        normalized["id_municipio"] = entity_id
    elif entity_type == "uf":
        normalized["sigla_uf"] = entity_id

    return normalized


class ParseAndValidateEvent(beam.DoFn):
    """Preserva todo evento na Bronze e separa válido/inválido."""

    def process(self, message: PubsubMessage) -> Iterable[Dict[str, Any]]:
        received_at = utc_now()
        raw_message = (message.data or b"").decode("utf-8", errors="replace")
        attributes = dict(message.attributes or {})
        attributes_json = json.dumps(attributes, ensure_ascii=False, sort_keys=True)
        pubsub_publish_time = format_datetime(message.publish_time)
        fallback_event_id = attributes.get("event_id")
        fallback_run_id = attributes.get("simulation_run_id")

        parsed: Dict[str, Any] = {}
        parse_error: Optional[Exception] = None
        try:
            candidate = json.loads(raw_message)
            if not isinstance(candidate, dict):
                raise ValueError("a mensagem JSON deve ser um objeto")
            parsed = candidate
        except (json.JSONDecodeError, ValueError) as exc:
            parse_error = exc

        bronze_row = {
            "event_id": parsed.get("event_id") or fallback_event_id,
            "simulation_run_id": parsed.get("simulation_run_id") or fallback_run_id,
            "event_type": parsed.get("event_type"),
            "event_time": parsed.get("event_time") if isinstance(parsed.get("event_time"), str) else None,
            "schema_version": parsed.get("schema_version"),
            "entity_type": parsed.get("entity_type"),
            "entity_id": parsed.get("entity_id"),
            "source": parsed.get("source"),
            "raw_message": raw_message,
            "attributes_json": attributes_json,
            "pubsub_message_id": message.message_id,
            "pubsub_publish_time": pubsub_publish_time,
            "ingestion_timestamp": received_at,
        }
        yield bronze_row

        if parse_error is not None:
            yield TaggedOutput(
                "invalid",
                self._quarantine_row(
                    bronze_row,
                    "INVALID_JSON",
                    str(parse_error),
                    received_at,
                ),
            )
            return

        try:
            event_id = str(parsed.get("event_id") or fallback_event_id or "").strip()
            simulation_run_id = str(parsed.get("simulation_run_id") or fallback_run_id or "").strip()
            event_type = str(parsed.get("event_type") or "").strip()
            schema_version = str(parsed.get("schema_version") or "").strip()
            entity_type = str(parsed.get("entity_type") or "").strip().lower()
            entity_id = str(parsed.get("entity_id") or "").strip().upper() if entity_type == "uf" else str(parsed.get("entity_id") or "").strip()
            source = str(parsed.get("source") or "").strip()
            payload = parsed.get("payload")

            if not event_id:
                raise ValueError("event_id é obrigatório")
            if not simulation_run_id:
                raise ValueError("simulation_run_id é obrigatório")
            if event_type not in ALLOWED_EVENT_TYPES:
                raise ValueError("event_type não reconhecido")
            if schema_version != "1.0":
                raise ValueError("schema_version deve ser 1.0")
            if entity_type != EXPECTED_ENTITY_TYPE[event_type]:
                raise ValueError("entity_type incompatível com event_type")
            if not entity_id:
                raise ValueError("entity_id é obrigatório")
            validate_entity_id(entity_type, entity_id)
            if not source:
                raise ValueError("source é obrigatório")
            if not isinstance(payload, dict):
                raise ValueError("payload deve ser um objeto JSON")

            event_time = parse_rfc3339(parsed.get("event_time"))
            normalized = normalize_payload(event_type, entity_type, entity_id, payload)

            silver_row = {
                "event_id": event_id,
                "simulation_run_id": simulation_run_id,
                "event_type": event_type,
                "event_time": event_time,
                "schema_version": schema_version,
                "entity_type": entity_type,
                "entity_id": entity_id,
                "source": source,
                **normalized,
                "payload_json": json.dumps(payload, ensure_ascii=False, sort_keys=True),
                "quality_status": "VALID",
                "processing_timestamp": received_at,
            }
            yield TaggedOutput("silver", silver_row)

        except (ValueError, TypeError) as exc:
            yield TaggedOutput(
                "invalid",
                self._quarantine_row(
                    bronze_row,
                    "CONTRACT_VALIDATION_ERROR",
                    str(exc),
                    received_at,
                ),
            )

    @staticmethod
    def _quarantine_row(
        bronze_row: Dict[str, Any],
        error_code: str,
        error_message: str,
        quarantined_at: str,
    ) -> Dict[str, Any]:
        return {
            "event_id": bronze_row.get("event_id"),
            "simulation_run_id": bronze_row.get("simulation_run_id"),
            "event_type": bronze_row.get("event_type"),
            "raw_message": bronze_row.get("raw_message"),
            "error_code": error_code,
            "error_message": error_message[:1024],
            "attributes_json": bronze_row.get("attributes_json"),
            "pubsub_message_id": bronze_row.get("pubsub_message_id"),
            "pubsub_publish_time": bronze_row.get("pubsub_publish_time"),
            "quarantined_at": quarantined_at,
        }


def bq_failure_to_quarantine(element: Any, error_code: str) -> Dict[str, Any]:
    destination, row, errors = element
    error_message = json.dumps(errors, ensure_ascii=False, default=str)
    return {
        "event_id": row.get("event_id"),
        "simulation_run_id": row.get("simulation_run_id"),
        "event_type": row.get("event_type"),
        "raw_message": row.get("raw_message") or json.dumps(row, ensure_ascii=False, default=str),
        "error_code": error_code,
        "error_message": f"Destino {destination}: {error_message}"[:1024],
        "attributes_json": row.get("attributes_json"),
        "pubsub_message_id": row.get("pubsub_message_id"),
        "pubsub_publish_time": row.get("pubsub_publish_time"),
        "quarantined_at": utc_now(),
    }


def quarantine_to_dlq_bytes(row: Dict[str, Any]) -> bytes:
    return json.dumps(row, ensure_ascii=False, default=str).encode("utf-8")


def build_pipeline(options: PipelineOptions, args: argparse.Namespace) -> beam.Pipeline:
    pipeline = beam.Pipeline(options=options)

    messages = pipeline | "Ler PubSub" >> ReadFromPubSub(
        subscription=args.subscription,
        with_attributes=True,
        id_label="event_id",
    )

    parsed = (
        messages
        | "Preservar validar e normalizar"
        >> beam.ParDo(ParseAndValidateEvent()).with_outputs(
            "silver", "invalid", main="bronze"
        )
    )

    bronze_result = (
        parsed.bronze
        | "Gravar Bronze"
        >> WriteToBigQuery(
            table=args.bronze_table,
            schema=BRONZE_SCHEMA,
            create_disposition=BigQueryDisposition.CREATE_NEVER,
            write_disposition=BigQueryDisposition.WRITE_APPEND,
            method=WriteToBigQuery.Method.STREAMING_INSERTS,
            insert_retry_strategy=RetryStrategy.RETRY_NEVER,
        )
    )

    silver_result = (
        parsed.silver
        | "Gravar Silver"
        >> WriteToBigQuery(
            table=args.silver_table,
            schema=SILVER_SCHEMA,
            create_disposition=BigQueryDisposition.CREATE_NEVER,
            write_disposition=BigQueryDisposition.WRITE_APPEND,
            method=WriteToBigQuery.Method.STREAMING_INSERTS,
            insert_retry_strategy=RetryStrategy.RETRY_NEVER,
        )
    )

    bronze_write_errors = (
        bronze_result.failed_rows_with_errors
        | "Formatar falhas Bronze"
        >> beam.Map(bq_failure_to_quarantine, error_code="BRONZE_BQ_WRITE_ERROR")
    )

    silver_write_errors = (
        silver_result.failed_rows_with_errors
        | "Formatar falhas Silver"
        >> beam.Map(bq_failure_to_quarantine, error_code="SILVER_BQ_WRITE_ERROR")
    )

    quarantine_rows = (
        [parsed.invalid, bronze_write_errors, silver_write_errors]
        | "Unificar quarentena" >> beam.Flatten()
    )

    _ = (
        quarantine_rows
        | "Gravar Quarentena"
        >> WriteToBigQuery(
            table=args.quarantine_table,
            schema=QUARANTINE_SCHEMA,
            create_disposition=BigQueryDisposition.CREATE_NEVER,
            write_disposition=BigQueryDisposition.WRITE_APPEND,
            method=WriteToBigQuery.Method.STREAMING_INSERTS,
        )
    )

    _ = (
        quarantine_rows
        | "Serializar DLQ" >> beam.Map(quarantine_to_dlq_bytes)
        | "Publicar DLQ" >> WriteToPubSub(args.dlq_topic)
    )

    return pipeline


def parse_args() -> tuple[argparse.Namespace, list[str]]:
    parser = argparse.ArgumentParser()
    parser.add_argument("--subscription", required=True)
    parser.add_argument("--dlq_topic", required=True)
    parser.add_argument("--bronze_table", required=True)
    parser.add_argument("--silver_table", required=True)
    parser.add_argument("--quarantine_table", required=True)
    return parser.parse_known_args()


def main() -> None:
    logging.getLogger().setLevel(logging.INFO)
    known_args, pipeline_args = parse_args()
    options = PipelineOptions(pipeline_args)
    options.view_as(StandardOptions).streaming = True
    options.view_as(SetupOptions).save_main_session = True

    pipeline = build_pipeline(options, known_args)
    result = pipeline.run()
    logging.info("Pipeline submetida. Resultado: %s", result)


if __name__ == "__main__":
    main()
