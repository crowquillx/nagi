"""Copy org.freedesktop.secrets items between providers.

Never prints secret values. Used by nagi-migrate-secrets-to-kwallet.
"""

from __future__ import annotations

import argparse
import base64
import json
import sys
from typing import Any

import secretstorage


def _collection_label(collection: Any) -> str:
    try:
        return collection.get_label() or ""
    except Exception:
        return ""


def dump_items() -> list[dict[str, Any]]:
    conn = secretstorage.dbus_init()
    items: list[dict[str, Any]] = []
    for collection in secretstorage.get_all_collections(conn):
        if collection.is_locked():
            collection.unlock()
        label = _collection_label(collection)
        for item in collection.get_all_items():
            if item.is_locked():
                item.unlock()
            secret = item.get_secret()
            items.append(
                {
                    "collection": label,
                    "label": item.get_label() or "",
                    "attributes": dict(item.get_attributes() or {}),
                    "secret_b64": base64.b64encode(secret).decode("ascii"),
                }
            )
    return items


def summarize(items: list[dict[str, Any]]) -> list[str]:
    lines = []
    for item in items:
        attrs = item.get("attributes") or {}
        schema = attrs.get("xdg:schema") or attrs.get("application") or attrs.get("service") or ""
        label = item.get("label") or "(no label)"
        lines.append(f"{label} [{schema}]")
    return lines


def _content_type(secret: bytes) -> str:
    try:
        secret.decode("utf-8")
    except UnicodeDecodeError:
        return "application/octet-stream"
    return "text/plain"


def import_items(items: list[dict[str, Any]]) -> tuple[int, int, int]:
    conn = secretstorage.dbus_init()
    collection = secretstorage.get_default_collection(conn)
    if collection.is_locked():
        collection.unlock()
    created = 0
    replaced = 0
    failed = 0
    for spec in items:
        attrs = dict(spec.get("attributes") or {})
        secret = base64.b64decode(spec["secret_b64"])
        label = spec.get("label") or "migrated"
        try:
            existing = list(collection.search_items(attrs)) if attrs else []
            collection.create_item(
                label,
                attrs,
                secret,
                replace=True,
                content_type=_content_type(secret),
            )
        except Exception as exc:
            failed += 1
            print(f"failed {label!r}: {type(exc).__name__}", file=sys.stderr)
            continue
        if existing:
            replaced += 1
        else:
            created += 1
    return created, replaced, failed


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="cmd", required=True)
    dump_p = sub.add_parser("dump", help="dump items from the current Secret Service")
    dump_p.add_argument("--output", required=True)
    dump_p.add_argument("--summary", action="store_true")
    imp = sub.add_parser("import", help="import items into the current Secret Service")
    imp.add_argument("--input", required=True)
    args = parser.parse_args()

    if args.cmd == "dump":
        items = dump_items()
        payload = {"items": items}
        with open(args.output, "w", encoding="utf-8") as fh:
            json.dump(payload, fh, indent=2, sort_keys=True)
            fh.write("\n")
        print(f"dumped {len(items)} items", file=sys.stderr)
        if args.summary:
            for line in summarize(items):
                print(line)
        return 0

    with open(args.input, encoding="utf-8") as fh:
        payload = json.load(fh)
    created, replaced, failed = import_items(payload.get("items") or [])
    print(
        f"imported created={created} replaced={replaced} failed={failed}",
        file=sys.stderr,
    )
    return 1 if failed and created + replaced == 0 else 0


if __name__ == "__main__":
    raise SystemExit(main())
