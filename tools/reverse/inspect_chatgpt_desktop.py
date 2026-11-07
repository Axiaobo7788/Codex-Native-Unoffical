#!/usr/bin/env python3
# Copyright 2026 Codex-Native-Unoffical Contributors
# SPDX-License-Identifier: Apache-2.0
"""Clean-room static & local-persistence inspector for ChatGPT Desktop.

Inspects an installed ChatGPT Desktop bundle (`app.asar` + `plugins/openai-bundled`)
and local `~/.codex` SQLite schemas without dumping proprietary source code,
assets, or user credentials/conversations.

Usage:
  python3 tools/reverse/inspect_chatgpt_desktop.py --summary
  python3 tools/reverse/inspect_chatgpt_desktop.py --ipc
  python3 tools/reverse/inspect_chatgpt_desktop.py --endpoints
  python3 tools/reverse/inspect_chatgpt_desktop.py --sqlite-schemas
  python3 tools/reverse/inspect_chatgpt_desktop.py --css-tokens
  python3 tools/reverse/inspect_chatgpt_desktop.py --plugins
  python3 tools/reverse/inspect_chatgpt_desktop.py --evidence-report
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import sqlite3
import struct
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any


DEFAULT_ASAR_CANDIDATES = (
    Path("/opt/codex-desktop/resources/app.asar"),
    Path("/Applications/ChatGPT.app/Contents/Resources/app.asar"),
    Path("/Applications/Codex.app/Contents/Resources/app.asar"),
)


def find_asar(explicit: str | None) -> Path:
    if explicit:
        path = Path(explicit).expanduser().resolve()
        if not path.is_file():
            raise FileNotFoundError(f"app.asar not found at {path}")
        return path
    for candidate in DEFAULT_ASAR_CANDIDATES:
        if candidate.is_file():
            return candidate
    raise FileNotFoundError(
        "Could not locate app.asar automatically. Pass --asar /path/to/app.asar"
    )


class AsarArchive:
    """Minimal read-only Chromium/Electron ASAR reader."""

    def __init__(self, path: Path) -> None:
        self.path = path
        with path.open("rb") as f:
            header_data = f.read(16)
            if len(header_data) < 16:
                raise ValueError(f"Invalid ASAR header in {path}")
            _, header_size, _, json_size = struct.unpack("<IIII", header_data)
            self.data_offset = 8 + header_size
            header_bytes = f.read(json_size)
        self.header: dict[str, Any] = json.loads(header_bytes.decode("utf-8"))

    def iter_entries(
        self, node: dict[str, Any] | None = None, prefix: str = ""
    ):
        if node is None:
            node = self.header
        for name, meta in node.get("files", {}).items():
            rel = f"{prefix}/{name}" if prefix else name
            if "files" in meta:
                yield from self.iter_entries(meta, rel)
            else:
                yield rel, meta

    def read_text(self, rel_path: str) -> str:
        parts = [p for p in rel_path.split("/") if p]
        node = self.header
        for part in parts:
            node = node.get("files", {}).get(part)
            if node is None:
                raise KeyError(f"Entry not found in ASAR: {rel_path}")
        if node.get("unpacked"):
            unpacked_path = self.path.with_name(f"{self.path.name}.unpacked") / rel_path
            return unpacked_path.read_text(encoding="utf-8", errors="replace")
        offset = int(node["offset"])
        size = int(node["size"])
        with self.path.open("rb") as f:
            f.seek(self.data_offset + offset)
            return f.read(size).decode("utf-8", errors="replace")


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        while chunk := f.read(1024 * 1024):
            h.update(chunk)
    return h.hexdigest()


def cmd_summary(archive: AsarArchive) -> dict[str, Any]:
    pkg = json.loads(archive.read_text("package.json"))
    entries = list(archive.iter_entries())
    unpacked_dir = archive.path.with_name(f"{archive.path.name}.unpacked")
    sidecars = []
    if unpacked_dir.is_dir():
        for p in sorted(unpacked_dir.rglob("*")):
            if p.is_file():
                sidecars.append(
                    {
                        "path": str(p.relative_to(unpacked_dir)),
                        "size_bytes": p.stat().st_size,
                    }
                )
    return {
        "asar_path": str(archive.path),
        "asar_size_bytes": archive.path.stat().st_size,
        "asar_sha256": sha256_file(archive.path),
        "name": pkg.get("name"),
        "productName": pkg.get("productName"),
        "version": pkg.get("version"),
        "codexBuildNumber": pkg.get("codexBuildNumber"),
        "codexBuildFlavor": pkg.get("codexBuildFlavor"),
        "main": pkg.get("main"),
        "devDependencies": pkg.get("devDependencies", {}),
        "total_asar_files": len(entries),
        "unpacked_sidecars": sidecars,
    }


def iter_main_js(archive: AsarArchive):
    for rel, _ in archive.iter_entries():
        if rel.startswith(".vite/build/") and rel.endswith(".js"):
            yield rel, archive.read_text(rel)


def iter_renderer_js(archive: AsarArchive):
    for rel, _ in archive.iter_entries():
        if rel.startswith("webview/") and rel.endswith(".js"):
            yield rel, archive.read_text(rel)


RPC_METHOD_REGEX = re.compile(
    r'"((?:thread|turn|item|skills|plugin|mcpServer|mcpServerStatus|account|config|configRequirements|fuzzyFileSearch|command|review|experimentalFeature|externalAgentConfig|windowsSandbox|remoteControl|model|collaborationMode|apps|fs|marketplace)/[A-Za-z0-9_/]+)"'
)


def cmd_ipc(archive: AsarArchive) -> dict[str, Any]:
    channels: set[str] = set()
    rpc_methods: set[str] = set()
    for _, text in iter_main_js(archive):
        channels.update(re.findall(r'"(codex_desktop:[^"]+)"', text))
        rpc_methods.update(RPC_METHOD_REGEX.findall(text))
    preload_text = archive.read_text(".vite/build/preload.js")
    preload_channels = sorted(set(re.findall(r'"(codex_desktop:[^"]+)"', preload_text)))
    return {
        "preload_channels": preload_channels,
        "all_ipc_channels": sorted(channels),
        "app_server_rpc_methods": sorted(rpc_methods),
    }


def cmd_endpoints(archive: AsarArchive) -> dict[str, Any]:
    backend_api: set[str] = set()
    wham_paths: set[str] = set()
    routes: set[str] = set()
    for _, text in list(iter_main_js(archive)) + list(iter_renderer_js(archive)):
        for m in re.findall(r'["\'](/backend-api/[A-Za-z0-9_./${}:?=&-]+)["\']', text):
            backend_api.add(re.sub(r"\$\{[^}]+\}", ":param", m))
        for m in re.findall(r'["\'](/wham/[A-Za-z0-9_./${}:?=&-]+)["\']', text):
            wham_paths.add(re.sub(r"\$\{[^}]+\}", ":param", m))
        for m in re.findall(
            r'path:\s*"(/[A-Za-z0-9_/:*-]+)"',
            text,
        ):
            routes.add(m)
    return {
        "backend_api_paths": sorted(backend_api),
        "wham_paths": sorted(wham_paths),
        "router_paths": sorted(routes),
    }


def load_stock_app_server_schema(archive: AsarArchive) -> dict[str, Any]:
    candidates = [
        archive.path.parent / "codex",
        Path("/opt/codex-desktop/resources/codex"),
    ]
    which_codex = shutil.which("codex")
    if which_codex:
        candidates.append(Path(which_codex))

    codex_bin = next((c for c in candidates if c.is_file() and os.access(c, os.X_OK)), None)
    if codex_bin is None:
        return {"available": False}

    def extract_methods(schema_file: Path) -> set[str]:
        if not schema_file.is_file():
            return set()
        data = json.loads(schema_file.read_text(encoding="utf-8"))
        out: set[str] = set()
        for variant in data.get("oneOf", []):
            props = variant.get("properties", {})
            method_prop = props.get("method", {})
            for val in method_prop.get("enum", []):
                out.add(val)
            if "const" in method_prop:
                out.add(method_prop["const"])
        return out

    with tempfile.TemporaryDirectory(prefix="codex_schema_ro_") as tmp:
        stable_dir = Path(tmp) / "stable"
        exp_dir = Path(tmp) / "exp"
        subprocess.run(
            [str(codex_bin), "app-server", "generate-json-schema", "--out", str(stable_dir)],
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        subprocess.run(
            [
                str(codex_bin),
                "app-server",
                "generate-json-schema",
                "--experimental",
                "--out",
                str(exp_dir),
            ],
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        ver_proc = subprocess.run(
            [str(codex_bin), "--version"],
            check=False,
            capture_output=True,
            text=True,
        )
        stable_client = extract_methods(stable_dir / "ClientRequest.json")
        exp_client = extract_methods(exp_dir / "ClientRequest.json")
        stable_server_req = extract_methods(stable_dir / "ServerRequest.json")
        exp_server_req = extract_methods(exp_dir / "ServerRequest.json")
        stable_notif = extract_methods(stable_dir / "ServerNotification.json")
        exp_notif = extract_methods(exp_dir / "ServerNotification.json")
        client_notif = extract_methods(exp_dir / "ClientNotification.json")

    return {
        "available": True,
        "codex_binary": str(codex_bin),
        "codex_version": ver_proc.stdout.strip(),
        "counts": {
            "client_request_stable": len(stable_client),
            "client_request_experimental_only": len(exp_client - stable_client),
            "client_request_total": len(exp_client),
            "server_request_stable": len(stable_server_req),
            "server_request_experimental_only": len(exp_server_req - stable_server_req),
            "server_request_total": len(exp_server_req),
            "server_notification_stable": len(stable_notif),
            "server_notification_experimental_only": len(exp_notif - stable_notif),
            "server_notification_total": len(exp_notif),
            "client_notification_total": len(client_notif),
        },
        "sets": {
            "stable_client": stable_client,
            "exp_only_client": exp_client - stable_client,
            "stable_server_req": stable_server_req,
            "exp_only_server_req": exp_server_req - stable_server_req,
            "stable_notif": stable_notif,
            "exp_only_notif": exp_notif - stable_notif,
        },
    }


def cmd_evidence_report(archive: AsarArchive) -> dict[str, Any]:
    preload_text = archive.read_text(".vite/build/preload.js")
    preload_channels = set(re.findall(r'"(codex_desktop:[^"]+)"', preload_text))

    bundle_texts: list[tuple[str, str]] = (
        list(iter_main_js(archive)) + list(iter_renderer_js(archive))
    )

    schema_info = load_stock_app_server_schema(archive)
    sets = schema_info.get("sets", {})
    stable_client: set[str] = sets.get("stable_client", set())
    exp_only_client: set[str] = sets.get("exp_only_client", set())
    stable_server_req: set[str] = sets.get("stable_server_req", set())
    exp_only_server_req: set[str] = sets.get("exp_only_server_req", set())
    stable_notif: set[str] = sets.get("stable_notif", set())
    exp_only_notif: set[str] = sets.get("exp_only_notif", set())

    # 1. IPC channel provenance
    ipc_stats: dict[str, dict[str, Any]] = {}
    for rel, text in bundle_texts:
        for ch in re.findall(r'"(codex_desktop:[^"]+)"', text):
            entry = ipc_stats.setdefault(
                ch,
                {
                    "bundles": [],
                    "static_occurrences": 0,
                    "in_preload_bridge": ch in preload_channels,
                    "evidence_tags": ["STATIC_BUNDLE"],
                    "support_classification": "INTERNAL_ELECTRON_IPC",
                },
            )
            entry["static_occurrences"] += 1
            if rel not in entry["bundles"]:
                entry["bundles"].append(rel)

    # 2. App-server RPC method provenance & schema cross-reference
    rpc_stats: dict[str, dict[str, Any]] = {}
    for rel, text in bundle_texts:
        for m in RPC_METHOD_REGEX.findall(text):
            entry = rpc_stats.setdefault(
                m,
                {
                    "bundles": [],
                    "static_occurrences": 0,
                    "in_preload_bridge": m in preload_text,
                },
            )
            entry["static_occurrences"] += 1
            if rel not in entry["bundles"]:
                entry["bundles"].append(rel)

    for m, entry in rpc_stats.items():
        if m in stable_client:
            schema_status = "client_request_stable"
            tags = ["PUBLIC_SOURCE", "STATIC_BUNDLE"]
            support = "PUBLIC_SUPPORTED"
        elif m in exp_only_client:
            schema_status = "client_request_experimental_only"
            tags = ["PUBLIC_SOURCE", "STATIC_BUNDLE"]
            support = "EXPERIMENTAL_STOCK_SCHEMA"
        elif m in stable_server_req:
            schema_status = "server_request_stable"
            tags = ["PUBLIC_SOURCE", "STATIC_BUNDLE"]
            support = "PUBLIC_SUPPORTED"
        elif m in exp_only_server_req:
            schema_status = "server_request_experimental_only"
            tags = ["PUBLIC_SOURCE", "STATIC_BUNDLE"]
            support = "EXPERIMENTAL_STOCK_SCHEMA"
        elif m in stable_notif or m in exp_only_notif:
            schema_status = "server_notification"
            tags = ["PUBLIC_SOURCE", "STATIC_BUNDLE"]
            support = "PUBLIC_SUPPORTED"
        else:
            schema_status = "not_in_local_stock_schema"
            tags = ["STATIC_BUNDLE"]
            support = "PRIVATE_INTERNAL_SERVICE"
        entry["in_stock_app_server_schema"] = schema_status
        entry["evidence_tags"] = tags
        entry["support_classification"] = support

    # 3. Key architectural symbol provenance
    tracked_symbols = (
        "STEPS_PROSE",
        "STEPS_COMMANDS",
        "STEPS_EXECUTION",
        "includeProseDetailLevelInstructions",
        "writing_blocks",
        "thread/startAeon",
        "thread/environmentReady",
        "tpp-local-executor",
        "CODEX_TPP_LOCAL_EXECUTOR_ENABLED",
        "submitChatGPTLocalFunctionResult",
        "remoteControl/enable",
        "remote-control-device-key.node",
        "codex_app_active_history_eviction_v1",
        "codex-app-thread-timeline-history",
        "codex-app-bounded-cloud-history",
    )
    symbol_report: dict[str, dict[str, Any]] = {}
    for sym in tracked_symbols:
        bundles: list[str] = []
        count = 0
        for rel, text in bundle_texts:
            c = text.count(sym)
            if c > 0:
                count += c
                bundles.append(rel)
        in_schema = (
            sym in stable_client
            or sym in exp_only_client
            or sym in stable_server_req
            or sym in exp_only_server_req
            or sym in stable_notif
        )
        symbol_report[sym] = {
            "bundles": bundles,
            "static_occurrences": count,
            "in_preload_bridge": sym in preload_text,
            "in_stock_app_server_schema": in_schema,
            "evidence_tags": (
                ["PUBLIC_SOURCE", "STATIC_BUNDLE"] if in_schema else ["STATIC_BUNDLE"]
            ),
        }

    # 4. Network endpoint provenance (/backend-api/* and /wham/*)
    endpoint_stats: dict[str, dict[str, Any]] = {}
    for rel, text in bundle_texts:
        for pat in (
            r'["\'](/backend-api/[A-Za-z0-9_./${}:?=&-]+)["\']',
            r'["\'](/wham/[A-Za-z0-9_./${}:?=&-]+)["\']',
        ):
            for raw in re.findall(pat, text):
                ep = re.sub(r"\$\{[^}]+\}", ":param", raw)
                is_wham = ep.startswith("/wham/") or "/wham/" in ep or "/codex/remote/" in ep
                entry = endpoint_stats.setdefault(
                    ep,
                    {
                        "bundles": [],
                        "static_occurrences": 0,
                        "in_preload_bridge": ep in preload_text,
                        "in_stock_app_server_schema": False,
                        "evidence_tags": ["STATIC_BUNDLE"],
                        "support_classification": (
                            "PRIVATE_INTERNAL_SERVICE"
                            if is_wham
                            else "PRIVATE_WEB_SESSION"
                        ),
                    },
                )
                entry["static_occurrences"] += 1
                if rel not in entry["bundles"]:
                    entry["bundles"].append(rel)

    schema_summary = {
        k: v for k, v in schema_info.items() if k != "sets"
    }
    not_in_stock_schema = sorted(
        m
        for m, e in rpc_stats.items()
        if e["in_stock_app_server_schema"] == "not_in_local_stock_schema"
    )
    return {
        "stock_app_server_schema": schema_summary,
        "ipc_channel_counts": {
            "preload_exposed": len(preload_channels),
            "total_static_ipc_channels": len(ipc_stats),
        },
        "rpc_method_summary": {
            "total_asar_matched_rpc_strings": len(rpc_stats),
            "in_stock_stable_client_request": sorted(
                m
                for m, e in rpc_stats.items()
                if e["in_stock_app_server_schema"] == "client_request_stable"
            ),
            "in_stock_experimental_client_request": sorted(
                m
                for m, e in rpc_stats.items()
                if e["in_stock_app_server_schema"] == "client_request_experimental_only"
            ),
            "in_stock_server_request": sorted(
                m
                for m, e in rpc_stats.items()
                if e["in_stock_app_server_schema"].startswith("server_request_")
            ),
            "in_stock_server_notification": sorted(
                m
                for m, e in rpc_stats.items()
                if e["in_stock_app_server_schema"] == "server_notification"
            ),
            "not_in_local_stock_schema": not_in_stock_schema,
        },
        "endpoint_counts": {
            "total_discovered_endpoints": len(endpoint_stats),
        },
        "key_symbols": symbol_report,
        "ipc_channels": dict(sorted(ipc_stats.items())),
        "rpc_methods": dict(sorted(rpc_stats.items())),
        "endpoints": dict(sorted(endpoint_stats.items())),
    }


def cmd_css_tokens(archive: AsarArchive) -> dict[str, Any]:
    layers: set[str] = set()
    tokens: dict[str, str] = {}
    for rel, _ in archive.iter_entries():
        if rel.startswith("webview/") and rel.endswith(".css"):
            css = archive.read_text(rel)
            for layer_match in re.findall(r"@layer\s+([a-zA-Z0-9_,\s-]+?)[;{]", css):
                for part in layer_match.split(","):
                    part = part.strip()
                    if part:
                        layers.add(part)
            for k, v in re.findall(r"(--[a-zA-Z0-9_-]+)\s*:\s*([^;}{]+)", css):
                tokens.setdefault(k, v.strip())
    key_prefixes = (
        "--app-shell-",
        "--sidebar-",
        "--thread-",
        "--composer-",
        "--user-message-",
        "--codex-",
        "--font-",
        "--text-",
        "--radius-",
        "--spacing",
        "--elevation-",
    )
    filtered = {
        k: tokens[k]
        for k in sorted(tokens)
        if k.startswith(key_prefixes)
    }
    return {
        "css_layers": sorted(layers),
        "total_custom_properties": len(tokens),
        "selected_design_tokens": filtered,
    }


def cmd_plugins(archive: AsarArchive) -> dict[str, Any]:
    plugins_root = archive.path.parent / "plugins" / "openai-bundled"
    if not plugins_root.is_dir():
        return {"plugins_root": str(plugins_root), "present": False}
    marketplace_file = plugins_root / ".agents" / "plugins" / "marketplace.json"
    marketplace = (
        json.loads(marketplace_file.read_text(encoding="utf-8"))
        if marketplace_file.is_file()
        else {}
    )
    manifests = []
    for p in sorted(plugins_root.glob("plugins/*/.codex-plugin/plugin.json")):
        data = json.loads(p.read_text(encoding="utf-8"))
        mcp_file = p.parent.parent / ".mcp.json"
        mcp_data = (
            json.loads(mcp_file.read_text(encoding="utf-8"))
            if mcp_file.is_file()
            else None
        )
        skills = [
            str(s.relative_to(p.parent.parent))
            for s in sorted(p.parent.parent.glob("skills/*/SKILL.md"))
        ]
        manifests.append(
            {
                "plugin": data.get("name"),
                "version": data.get("version"),
                "description": data.get("description"),
                "mcp": mcp_data,
                "skills": skills,
            }
        )
    return {
        "plugins_root": str(plugins_root),
        "present": True,
        "marketplace": marketplace,
        "plugins": manifests,
    }


def cmd_sqlite_schemas(codex_home: Path) -> dict[str, Any]:
    result: dict[str, Any] = {"codex_home": str(codex_home), "databases": {}}
    if not codex_home.is_dir():
        return result
    db_files = sorted(
        list(codex_home.glob("*.sqlite"))
        + list(codex_home.glob("*.db"))
        + list((codex_home / "sqlite").glob("*.db"))
    )
    for db_path in db_files:
        rel = str(db_path.relative_to(codex_home))
        try:
            conn = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
            cur = conn.cursor()
            rows = cur.execute(
                "SELECT type, name, sql FROM sqlite_master WHERE sql IS NOT NULL ORDER BY type, name"
            ).fetchall()
            conn.close()
            result["databases"][rel] = [
                {"type": r[0], "name": r[1], "sql": r[2]} for r in rows
            ]
        except Exception as exc:  # noqa: BLE001
            result["databases"][rel] = {"error": str(exc)}
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--asar", help="Path to ChatGPT Desktop app.asar")
    parser.add_argument(
        "--codex-home",
        default=os.environ.get("CODEX_HOME", str(Path.home() / ".codex")),
        help="Path to ~/.codex directory for schema-only SQLite inspection",
    )
    parser.add_argument("--summary", action="store_true", help="Print bundle summary")
    parser.add_argument("--ipc", action="store_true", help="Print IPC & RPC inventory")
    parser.add_argument(
        "--endpoints", action="store_true", help="Print network & router surfaces"
    )
    parser.add_argument(
        "--css-tokens", action="store_true", help="Print CSS layers & design tokens"
    )
    parser.add_argument(
        "--plugins", action="store_true", help="Print bundled plugins & skills metadata"
    )
    parser.add_argument(
        "--sqlite-schemas",
        action="store_true",
        help="Print ~/.codex SQLite DDL schemas (no row data)",
    )
    parser.add_argument(
        "--evidence-report",
        action="store_true",
        help="Print provenance, static counts, preload exposure, stock app-server schema cross-check, and evidence tags",
    )
    args = parser.parse_args()

    run_all = not any(
        [
            args.summary,
            args.ipc,
            args.endpoints,
            args.css_tokens,
            args.plugins,
            args.sqlite_schemas,
            args.evidence_report,
        ]
    )

    output: dict[str, Any] = {}
    if run_all or any(
        [
            args.summary,
            args.ipc,
            args.endpoints,
            args.css_tokens,
            args.plugins,
            args.evidence_report,
        ]
    ):
        archive = AsarArchive(find_asar(args.asar))
        if run_all or args.summary:
            output["summary"] = cmd_summary(archive)
        if run_all or args.ipc:
            output["ipc"] = cmd_ipc(archive)
        if run_all or args.endpoints:
            output["endpoints"] = cmd_endpoints(archive)
        if run_all or args.css_tokens:
            output["css_tokens"] = cmd_css_tokens(archive)
        if run_all or args.plugins:
            output["plugins"] = cmd_plugins(archive)
        if run_all or args.evidence_report:
            output["evidence_report"] = cmd_evidence_report(archive)

    if run_all or args.sqlite_schemas:
        output["sqlite_schemas"] = cmd_sqlite_schemas(
            Path(args.codex_home).expanduser().resolve()
        )

    json.dump(output, sys.stdout, indent=2, ensure_ascii=False)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

