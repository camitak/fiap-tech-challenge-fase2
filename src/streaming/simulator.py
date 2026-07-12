#!/usr/bin/env python3
"""Publica eventos válidos e inválidos para demonstrar o fluxo streaming."""

from __future__ import annotations

import argparse
import json
import random
import time
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Tuple

from google.cloud import pubsub_v1


MUNICIPIOS = ["3550308", "3304557", "5300108", "2927408"]
UFS = ["SP", "RJ", "DF", "BA"]


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def new_event_id() -> str:
    return str(uuid.uuid4())


def base_event(run_id: str, event_type: str, entity_type: str, entity_id: str, payload: Dict[str, Any]) -> Dict[str, Any]:
    return {
        "event_id": new_event_id(),
        "simulation_run_id": run_id,
        "event_type": event_type,
        "event_time": utc_now(),
        "schema_version": "1.0",
        "entity_type": entity_type,
        "entity_id": entity_id,
        "source": "simulador-tech-challenge",
        "payload": payload,
    }


def build_valid_event(run_id: str, index: int) -> Dict[str, Any]:
    event_kind = index % 5
    municipio = MUNICIPIOS[index % len(MUNICIPIOS)]
    uf = UFS[index % len(UFS)]

    if event_kind == 0:
        return base_event(
            run_id,
            "indicador_municipio_atualizado",
            "municipio",
            municipio,
            {
                "ano": 2025,
                "rede": "Municipal",
                "taxa_alfabetizacao": round(random.uniform(48, 82), 2),
                "percentual_participacao": round(random.uniform(82, 97), 2),
            },
        )
    if event_kind == 1:
        return base_event(
            run_id,
            "indicador_uf_atualizado",
            "uf",
            uf,
            {
                "ano": 2025,
                "rede": "Pública",
                "taxa_alfabetizacao": round(random.uniform(50, 78), 2),
                "percentual_participacao": round(random.uniform(84, 98), 2),
            },
        )
    if event_kind == 2:
        return base_event(
            run_id,
            "meta_municipio_atualizada",
            "municipio",
            municipio,
            {
                "ano": 2025,
                "ano_meta": 2026,
                "rede": "Municipal",
                "meta_alfabetizacao": round(random.uniform(65, 78), 2),
            },
        )
    if event_kind == 3:
        return base_event(
            run_id,
            "meta_uf_atualizada",
            "uf",
            uf,
            {
                "ano": 2025,
                "ano_meta": 2026,
                "rede": "Pública",
                "meta_alfabetizacao": round(random.uniform(66, 77), 2),
            },
        )

    proficiencia = round(random.uniform(650, 850), 2)
    return base_event(
        run_id,
        "resultado_aluno_recebido",
        "aluno",
        f"ALUNO-{index:06d}",
        {
            "ano": 2025,
            "id_municipio": municipio,
            "rede": "Municipal",
            "proficiencia": proficiencia,
            "alfabetizado": proficiencia >= 743,
        },
    )


def build_invalid_messages(run_id: str) -> List[Tuple[str, bytes, Dict[str, str]]]:
    malformed_id = new_event_id()
    malformed = b'{"event_id": "quebrado", "event_type": '

    missing_entity = base_event(
        run_id,
        "indicador_uf_atualizado",
        "uf",
        "SP",
        {"ano": 2025, "taxa_alfabetizacao": 62.5},
    )
    missing_entity["event_id"] = new_event_id()
    missing_entity.pop("entity_id")

    invalid_percentage = base_event(
        run_id,
        "indicador_municipio_atualizado",
        "municipio",
        "3550308",
        {"ano": 2025, "taxa_alfabetizacao": 130.0},
    )

    return [
        (
            malformed_id,
            malformed,
            {"event_id": malformed_id, "simulation_run_id": run_id, "message_kind": "invalid"},
        ),
        (
            missing_entity["event_id"],
            json.dumps(missing_entity, ensure_ascii=False).encode("utf-8"),
            {"event_id": missing_entity["event_id"], "simulation_run_id": run_id, "message_kind": "invalid"},
        ),
        (
            invalid_percentage["event_id"],
            json.dumps(invalid_percentage, ensure_ascii=False).encode("utf-8"),
            {"event_id": invalid_percentage["event_id"], "simulation_run_id": run_id, "message_kind": "invalid"},
        ),
    ]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project-id", required=True)
    parser.add_argument("--topic-id", default="alfabetizacao-eventos")
    parser.add_argument("--count-valid", type=int, default=12)
    parser.add_argument("--interval-seconds", type=float, default=0.4)
    parser.add_argument("--simulation-run-id")
    parser.add_argument("--manifest-path", required=True)
    parser.add_argument("--env-path", default="/tmp/fiap_simulation.env")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    run_id = args.simulation_run_id or datetime.now(timezone.utc).strftime("sim_%Y%m%dT%H%M%SZ")
    publisher = pubsub_v1.PublisherClient()
    topic_path = publisher.topic_path(args.project_id, args.topic_id)

    published_valid: List[str] = []
    published_invalid: List[str] = []

    for index in range(args.count_valid):
        event = build_valid_event(run_id, index)
        data = json.dumps(event, ensure_ascii=False).encode("utf-8")
        future = publisher.publish(
            topic_path,
            data,
            event_id=event["event_id"],
            simulation_run_id=run_id,
            message_kind="valid",
        )
        future.result(timeout=60)
        published_valid.append(event["event_id"])
        print(f"VALID {index + 1:02d}: {event['event_type']} {event['event_id']}")
        time.sleep(args.interval_seconds)

    for event_id, data, attributes in build_invalid_messages(run_id):
        future = publisher.publish(topic_path, data, **attributes)
        future.result(timeout=60)
        published_invalid.append(event_id)
        print(f"INVALID: {event_id}")
        time.sleep(args.interval_seconds)

    manifest = {
        "simulation_run_id": run_id,
        "published_at": utc_now(),
        "topic": topic_path,
        "expected_valid": len(published_valid),
        "expected_invalid": len(published_invalid),
        "expected_total": len(published_valid) + len(published_invalid),
        "valid_event_ids": published_valid,
        "invalid_event_ids": published_invalid,
    }

    manifest_path = Path(args.manifest_path)
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")

    Path(args.env_path).write_text(
        "\n".join(
            [
                f'export SIMULATION_RUN_ID="{run_id}"',
                f'export EXPECTED_VALID="{manifest["expected_valid"]}"',
                f'export EXPECTED_INVALID="{manifest["expected_invalid"]}"',
                f'export EXPECTED_TOTAL="{manifest["expected_total"]}"',
                f'export SIMULATION_MANIFEST="{manifest_path}"',
            ]
        )
        + "\n",
        encoding="utf-8",
    )

    print("============================================================")
    print(f"SIMULATION_RUN_ID={run_id}")
    print(f"EXPECTED_VALID={manifest['expected_valid']}")
    print(f"EXPECTED_INVALID={manifest['expected_invalid']}")
    print(f"EXPECTED_TOTAL={manifest['expected_total']}")
    print(f"Manifesto: {manifest_path}")
    print(f"Variáveis: {args.env_path}")
    print("============================================================")


if __name__ == "__main__":
    main()
