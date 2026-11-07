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
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sqlite3
import struct
import sys
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


def cmd_ipc(archive: AsarArchive) -> dict[str, Any]:
    channels: set[str] = set()
    rpc_methods: set[str] = set()
    for _, text in iter_main_js(archive):
        channels.update(re.findall(r'"(codex_desktop:[^"]+)"', text))
        rpc_methods.update(
            re.findall(
                r'"((?:thread|turn|item|skills|plugin|mcpServer|account|config|fuzzyFileSearch|command|review|experimentalFeature|externalAgentConfig|windowsSandbox)/[A-Za-z0-9_/]+)"',
                text,
            )
        )
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
        for m in re.findall(r'["\'](/backend-api/[A-Za-z0-9_./-${}:?=&]+)["\']', text):
            backend_api.add(re.sub(r"\$\{[^}]+\}", ":param", m))
        for m in re.findall(r'["\'](/wham/[A-Za-z0-9_./-${}:?=&]+)["\']', text):
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
    args = parser.parse_args()

    run_all = not any(
        [
            args.summary,
            args.ipc,
            args.endpoints,
            args.css_tokens,
            args.plugins,
            args.sqlite_schemas,
        ]
    )

    output: dict[str, Any] = {}
    if run_all or any(
        [args.summary, args.ipc, args.endpoints, args.css_tokens, args.plugins]
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

    if run_all or args.sqlite_schemas:
        output["sqlite_schemas"] = cmd_sqlite_schemas(
            Path(args.codex_home).expanduser().resolve()
        )

    json.dump(output, sys.stdout, indent=2, ensure_ascii=False)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
