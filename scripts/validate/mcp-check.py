#!/usr/bin/env python3
"""Validate the checked-in MCP config and exercise each server over stdio."""

from __future__ import annotations

import argparse
import collections
import json
import os
import queue
import re
import shutil
import subprocess
import sys
import threading
import time
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
CONFIG = ROOT / ".mcp.json"
CLAUDE_SETTINGS = ROOT / ".claude" / "settings.json"
VARIABLE = re.compile(r"\$\{([A-Za-z_][A-Za-z0-9_]*)(?::-([^}]*))?}")
EXPECTED_SERVERS = {"grafana", "playwright", "chrome-devtools"}
GRAFANA_IMAGE = (
    "grafana/mcp-grafana:1.5.1@"
    "sha256:07c6614a8f8b6477e572444874c8c07baf145473977f014497cb59262af1944c"
)
EXPECTED_ARGS = {
    "grafana": [
        "run", "-i", "--rm", "--network", "host",
        "--add-host=grafana.localhost:127.0.0.1",
        "-v", "${PWD}/.local/dev-root-ca.crt:/ca/dev-root-ca.crt:ro",
        "-e", "GRAFANA_URL", "-e", "GRAFANA_USERNAME", "-e", "GRAFANA_PASSWORD",
        "--entrypoint", "/app/mcp-grafana", GRAFANA_IMAGE,
        "--transport", "stdio", "--tls-ca-file", "/ca/dev-root-ca.crt",
        "--disable-write", "--enabled-tools",
        "search,datasource,prometheus,loki,dashboard,navigation,tempo",
        "--max-loki-log-limit", "20", "--usage-stats", "disabled",
    ],
    "playwright": [
        "-y", "@playwright/mcp@0.0.80", "--browser", "chrome", "--isolated",
        "--block-service-workers",
        "--allowed-origins",
        (
            "https://hello.localhost;https://hello.localhost:8443;"
            "https://kiali.localhost;https://kiali.localhost:8443;"
            "wss://kiali.localhost;wss://kiali.localhost:8443;"
            "http://crl.localhost;http://crl.localhost:8080"
        ),
        "--output-dir", "${PWD}/.local/mcp-artifacts/playwright",
    ],
    "chrome-devtools": [
        "-y", "chrome-devtools-mcp@1.9.0", "--isolated",
        "--no-usage-statistics", "--no-performance-crux",
        "--no-javascript-evaluation", "--no-category-emulation",
        "--redact-network-headers",
        "--allowed-url-pattern=https://hello.localhost/*",
        "--allowed-url-pattern=https://hello.localhost:8443/*",
        "--allowed-url-pattern=https://kiali.localhost/*",
        "--allowed-url-pattern=https://kiali.localhost:8443/*",
        "--allowed-url-pattern=wss://kiali.localhost/*",
        "--allowed-url-pattern=wss://kiali.localhost:8443/*",
        "--allowed-url-pattern=http://crl.localhost/*",
        "--allowed-url-pattern=http://crl.localhost:8080/*",
    ],
}
EXPECTED_ENVS = {
    "grafana": {
        "GRAFANA_URL": "https://grafana.localhost",
        "GRAFANA_USERNAME": "admin",
        "GRAFANA_PASSWORD": "admin",
    },
    "playwright": {"NPM_CONFIG_CACHE": "${PWD}/.local/npm-cache"},
    "chrome-devtools": {
        "NPM_CONFIG_CACHE": "${PWD}/.local/npm-cache",
        "CHROME_DEVTOOLS_MCP_NO_UPDATE_CHECKS": "1",
    },
}
WRITE_TOOL_NAMES = {
    "add_activity_to_incident",
    "alerting_manage_rules",
    "alerting_manage_silences",
    "create_annotation",
    "create_folder",
    "create_incident",
    "create_snapshot",
    "delete_annotation",
    "delete_snapshot",
    "find_error_pattern_logs",
    "find_slow_requests",
    "grafana_api_request",
    "query_influxdb",
    "query_sql",
    "update_alert_group",
    "update_annotation",
    "update_dashboard",
    "update_incident",
}
BROWSER_DENIES = {
    "mcp__playwright__browser_close",
    "mcp__playwright__browser_click",
    "mcp__playwright__browser_drag",
    "mcp__playwright__browser_drop",
    "mcp__playwright__browser_evaluate",
    "mcp__playwright__browser_file_upload",
    "mcp__playwright__browser_fill_form",
    "mcp__playwright__browser_handle_dialog",
    "mcp__playwright__browser_hover",
    "mcp__playwright__browser_navigate_back",
    "mcp__playwright__browser_press_key",
    "mcp__playwright__browser_resize",
    "mcp__playwright__browser_run_code_unsafe",
    "mcp__playwright__browser_select_option",
    "mcp__playwright__browser_tabs",
    "mcp__playwright__browser_type",
    "mcp__chrome-devtools__click",
    "mcp__chrome-devtools__close_page",
    "mcp__chrome-devtools__drag",
    "mcp__chrome-devtools__fill",
    "mcp__chrome-devtools__fill_form",
    "mcp__chrome-devtools__handle_dialog",
    "mcp__chrome-devtools__hover",
    "mcp__chrome-devtools__lighthouse_audit",
    "mcp__chrome-devtools__press_key",
    "mcp__chrome-devtools__take_screenshot",
    "mcp__chrome-devtools__take_heapsnapshot",
    "mcp__chrome-devtools__type_text",
    "mcp__chrome-devtools__upload_file",
}
BROWSER_ALLOWED_NON_READ_ONLY = {
    "playwright": {"browser_navigate"},
    "chrome-devtools": {
        "get_network_request",
        "navigate_page",
        "new_page",
        "performance_start_trace",
        "performance_stop_trace",
        "take_snapshot",
    },
}


def expand(value: str, env: dict[str, str]) -> str:
    def replace(match: re.Match[str]) -> str:
        name, default = match.group(1), match.group(2)
        current = env.get(name)
        if current:
            return current
        if default is not None:
            return default
        raise ValueError(f"environment variable {name} is not set")

    return VARIABLE.sub(replace, value)


def load_config() -> dict[str, Any]:
    with CONFIG.open(encoding="utf-8") as stream:
        config = json.load(stream)
    servers = config.get("mcpServers")
    if not isinstance(servers, dict):
        raise ValueError(".mcp.json has no mcpServers object")
    return servers


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def validate_config(servers: dict[str, Any]) -> None:
    require(set(servers) == EXPECTED_SERVERS, "expected exactly grafana, playwright and chrome-devtools")

    for name, command in (("grafana", "docker"), ("playwright", "npx"), ("chrome-devtools", "npx")):
        server = servers[name]
        require(server.get("command") == command, f"{name} must run through {command}")
        require(server.get("args") == EXPECTED_ARGS[name],
                f"{name} arguments differ from the reviewed fail-closed configuration")
        require(server.get("env") == EXPECTED_ENVS[name],
                f"{name} environment differs from the reviewed fail-closed configuration")

    grafana = servers["grafana"]
    grafana_args = grafana.get("args", [])
    require("--entrypoint" in grafana_args and "/app/mcp-grafana" in grafana_args,
            "grafana must override the image's SSE entrypoint")
    require("--disable-write" in grafana_args, "grafana must disable write tools")
    require("--enabled-tools" in grafana_args, "grafana must use a narrow enabled-tools list")
    require(GRAFANA_IMAGE in grafana_args, "grafana image must be pinned by version and digest")
    require(grafana.get("env", {}).get("GRAFANA_URL") == "https://grafana.localhost",
            "grafana URL must be passed through the server environment")
    require("--usage-stats" in grafana_args and "disabled" in grafana_args,
            "grafana usage statistics must be disabled")

    for name in ("playwright", "chrome-devtools"):
        server = servers[name]
        args = server.get("args", [])
        require(not any("@latest" in arg for arg in args), f"{name} package must be pinned")
        require(server.get("env", {}).get("NPM_CONFIG_CACHE") == "${PWD}/.local/npm-cache",
                f"{name} must use the repo-local npm cache")

    playwright_args = servers["playwright"].get("args", [])
    require("@playwright/mcp@0.0.80" in playwright_args,
            "Playwright must use the newest release admitted by the 14-day package-age policy")
    require("--isolated" in playwright_args, "Playwright must use an isolated browser profile")
    require("--block-service-workers" in playwright_args,
            "Playwright must block service workers so they cannot bypass request filtering")
    require("--allowed-origins" in playwright_args, "Playwright must limit requested origins")
    require("--ignore-https-errors" not in playwright_args,
            "Playwright must validate the platform certificate")

    devtools_args = servers["chrome-devtools"].get("args", [])
    require("chrome-devtools-mcp@1.9.0" in devtools_args, "Chrome DevTools MCP must be pinned")
    require("--isolated" in devtools_args, "Chrome DevTools must use an isolated browser profile")
    require("--no-usage-statistics" in devtools_args, "Chrome DevTools usage statistics must be off")
    require("--no-performance-crux" in devtools_args, "Chrome DevTools CrUX lookups must be off")
    require("--no-javascript-evaluation" in devtools_args, "Chrome DevTools JavaScript evaluation must be off")
    require("--no-category-emulation" in devtools_args, "Chrome DevTools emulation tools must be off")
    require("--redact-network-headers" in devtools_args, "Chrome DevTools must redact network headers")
    require(servers["chrome-devtools"].get("env", {}).get("CHROME_DEVTOOLS_MCP_NO_UPDATE_CHECKS") == "1",
            "Chrome DevTools update checks must be disabled")
    require(any(arg.startswith("--allowed-url-pattern=") for arg in devtools_args),
            "Chrome DevTools must limit requested URLs")
    require(not any("accept-insecure-certs" in arg.lower() or "ignore-certificate-errors" in arg.lower()
                    for arg in devtools_args),
            "Chrome DevTools must validate the platform certificate")

    with CLAUDE_SETTINGS.open(encoding="utf-8") as stream:
        settings = json.load(stream)
    denied = set(settings.get("permissions", {}).get("deny", []))
    missing_denies = sorted(BROWSER_DENIES - denied)
    require(not missing_denies,
            "Claude settings do not deny browser mutation tools: " + ", ".join(missing_denies))


def require_command(name: str) -> str:
    command = shutil.which(name)
    require(command is not None, f"{name} not on PATH")
    return command


def preflight_grafana() -> None:
    docker = require_command("docker")
    ca = ROOT / ".local" / "dev-root-ca.crt"
    if ca.is_dir():
        raise ValueError(
            ".local/dev-root-ca.crt is a DIRECTORY; remove that empty mount-point directory "
            "and run ./scripts/platform.sh up"
        )
    if not ca.is_file() or ca.stat().st_size == 0:
        raise ValueError(
            "missing .local/dev-root-ca.crt; refusing to start Docker because its bind mount "
            "would create a directory there; run ./scripts/platform.sh up"
        )
    print("  ok    platform CA exported to .local/dev-root-ca.crt")

    result = subprocess.run(
        [docker, "info"], capture_output=True, text=True, timeout=30, check=False
    )
    require(result.returncode == 0, "docker daemon not responding")
    print("  ok    docker daemon responding")


def preflight_browsers() -> None:
    node = require_command("node")
    require_command("npx")
    result = subprocess.run(
        [node, "--version"], capture_output=True, text=True, timeout=10, check=False
    )
    require(result.returncode == 0, "could not determine the Node.js version")
    version = result.stdout.strip()
    match = re.fullmatch(r"v?(\d+)\.(\d+)\.(\d+)", version)
    require(match is not None, f"could not parse Node.js version: {version!r}")
    major, minor, _patch = (int(part) for part in match.groups())
    supported = (
        (major == 20 and minor >= 19)
        or (major == 22 and minor >= 12)
        or major >= 23
    )
    require(
        supported,
        f"Node.js {version} does not satisfy the Chrome DevTools MCP engine "
        "^20.19 || ^22.12 || >=23",
    )
    print(f"  ok    Node.js {version} satisfies ^20.19 || ^22.12 || >=23")


class McpProcess:
    def __init__(self, name: str, config: dict[str, Any]) -> None:
        self.name = name
        env = os.environ.copy()
        env["PWD"] = str(ROOT)
        env["MSYS_NO_PATHCONV"] = "1"
        for key, value in config.get("env", {}).items():
            env[key] = expand(str(value), env)
        command = expand(str(config["command"]), env)
        args = [expand(str(arg), env) for arg in config.get("args", [])]
        self.process = subprocess.Popen(
            [command, *args],
            cwd=ROOT,
            env=env,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            bufsize=1,
        )
        self.messages: queue.Queue[dict[str, Any]] = queue.Queue()
        self.stderr: collections.deque[str] = collections.deque(maxlen=40)
        self.next_id = 1
        threading.Thread(target=self._read_stdout, daemon=True).start()
        threading.Thread(target=self._read_stderr, daemon=True).start()

    def _read_stdout(self) -> None:
        assert self.process.stdout is not None
        for raw in self.process.stdout:
            line = raw.strip()
            if not line.startswith("{"):
                continue
            try:
                self.messages.put(json.loads(line))
            except json.JSONDecodeError:
                self.stderr.append(f"unparseable stdout: {line}")

    def _read_stderr(self) -> None:
        assert self.process.stderr is not None
        for raw in self.process.stderr:
            self.stderr.append(raw.rstrip())

    def send(self, message: dict[str, Any]) -> None:
        assert self.process.stdin is not None
        self.process.stdin.write(json.dumps(message, separators=(",", ":")) + "\n")
        self.process.stdin.flush()

    def request(self, method: str, params: dict[str, Any] | None = None, timeout: int = 90) -> dict[str, Any]:
        request_id = self.next_id
        self.next_id += 1
        self.send({"jsonrpc": "2.0", "id": request_id, "method": method, "params": params or {}})
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            if self.process.poll() is not None and self.messages.empty():
                raise RuntimeError(self._failure(f"exited with status {self.process.returncode}"))
            try:
                message = self.messages.get(timeout=min(0.25, max(0.01, deadline - time.monotonic())))
            except queue.Empty:
                continue
            if message.get("id") != request_id:
                continue
            if "error" in message:
                raise RuntimeError(self._failure(f"JSON-RPC error: {message['error']}"))
            return message.get("result", {})
        raise TimeoutError(self._failure(f"timed out after {timeout}s waiting for {method}"))

    def initialize(self) -> list[dict[str, Any]]:
        result = self.request(
            "initialize",
            {
                "protocolVersion": "2024-11-05",
                "capabilities": {"roots": {"listChanged": False}},
                "clientInfo": {"name": "tilt-training-check", "version": "1"},
            },
        )
        require(bool(result.get("serverInfo")), f"{self.name}: initialize returned no serverInfo")
        self.send({"jsonrpc": "2.0", "method": "notifications/initialized"})
        tools = self.request("tools/list").get("tools", [])
        require(bool(tools), f"{self.name}: tools/list returned no tools")
        return tools

    def call_tool(self, name: str, arguments: dict[str, Any]) -> str:
        result = self.request("tools/call", {"name": name, "arguments": arguments}, timeout=120)
        output = "\n".join(
            str(item.get("text", ""))
            for item in result.get("content", [])
            if isinstance(item, dict) and item.get("type") == "text"
        )
        if result.get("isError"):
            detail = output.strip() or "no error detail returned"
            raise RuntimeError(self._failure(f"tool {name} failed: {detail}"))
        return output

    def _failure(self, message: str) -> str:
        tail = "\n".join(self.stderr)
        return f"{self.name}: {message}" + (f"\nserver stderr:\n{tail}" if tail else "")

    def close(self) -> None:
        if self.process.poll() is not None:
            return
        try:
            if self.process.stdin:
                self.process.stdin.close()
            self.process.terminate()
            self.process.wait(timeout=5)
        except (OSError, subprocess.TimeoutExpired):
            self.process.kill()
            self.process.wait(timeout=5)


def check_server(name: str, config: dict[str, Any], handshake_only: bool) -> None:
    client = McpProcess(name, config)
    try:
        tools = client.initialize()
        tool_names = {str(tool.get("name")) for tool in tools}
        print(f"  ok    {name}: MCP handshake and tools/list ({len(tool_names)} tools)")
        if name == "grafana":
            unsafe = sorted(tool_names & WRITE_TOOL_NAMES)
            require(not unsafe, f"grafana exposed write-capable tools: {', '.join(unsafe)}")
            require(not any(item.startswith(("create_", "update_", "delete_")) for item in tool_names),
                    "grafana exposed a create/update/delete tool")
            not_read_only = sorted(
                str(tool.get("name"))
                for tool in tools
                if (tool.get("annotations") or {}).get("readOnlyHint") is not True
            )
            require(not not_read_only,
                    "grafana exposed tools without readOnlyHint=true: " + ", ".join(not_read_only))
            if not handshake_only:
                output = client.call_tool("list_datasources", {})
                require("Prometheus" in output and "Loki" in output, "grafana returned no live Prometheus/Loki data")
                prometheus = client.call_tool(
                    "query_prometheus",
                    {"datasourceUid": "prometheus", "expr": "sum(up)", "queryType": "instant", "endTime": "now"},
                )
                require('"value"' in prometheus, "Prometheus sum(up) returned no value")
                loki = client.call_tool(
                    "query_loki_logs",
                    {
                        "datasourceUid": "loki",
                        "logql": '{namespace="hello"}',
                        "limit": 1,
                        "startRfc3339": "now-1h",
                        "endRfc3339": "now",
                        "format": "compact",
                    },
                )
                require('"data"' in loki or '"streams"' in loki, "Loki query returned no structured result")
                tempo = client.call_tool(
                    "search_tempo_traces", {"datasourceUid": "tempo", "query": "{ true }"}
                )
                require('"traces"' in tempo, "Tempo search returned no structured result")
                print("  ok    grafana: live read-only Prometheus, Loki and Tempo queries")
        elif name == "playwright" and not handshake_only:
            client.call_tool("browser_navigate", {"url": "https://hello.localhost"})
            snapshot = client.call_tool("browser_snapshot", {})
            require("Hello from the platform" in snapshot,
                    "Playwright snapshot did not contain the expected hello page")
            print("  ok    playwright: snapshot contains 'Hello from the platform'")
        elif name == "chrome-devtools" and not handshake_only:
            output = client.call_tool("new_page", {"url": "https://hello.localhost"})
            require("hello.localhost" in output, "Chrome DevTools did not open hello.localhost")
            snapshot = client.call_tool("take_snapshot", {})
            require("Hello from the platform" in snapshot,
                    "Chrome DevTools snapshot did not contain the expected hello page")
            network = client.call_tool("list_network_requests", {})
            hello_requests = [
                line for line in network.splitlines() if "hello.localhost" in line
            ]
            require(hello_requests, "Chrome DevTools listed no request to hello.localhost")
            require(any(re.search(r"\b200\b", line) for line in hello_requests),
                    "Chrome DevTools did not report HTTP 200 for hello.localhost")
            print("  ok    chrome-devtools: snapshot text and document HTTP 200")
        if name in BROWSER_ALLOWED_NON_READ_ONLY:
            uncovered = sorted(
                tool_name
                for tool_name in tool_names
                if next(
                    tool for tool in tools if str(tool.get("name")) == tool_name
                ).get("annotations", {}).get("readOnlyHint") is not True
                and f"mcp__{name}__{tool_name}" not in BROWSER_DENIES
                and tool_name not in BROWSER_ALLOWED_NON_READ_ONLY[name]
            )
            require(not uncovered,
                    f"{name} exposes unreviewed non-read-only tools: {', '.join(uncovered)}")
    finally:
        client.close()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--server", action="append", choices=sorted(EXPECTED_SERVERS),
                        help="check only this server (repeatable)")
    parser.add_argument("--config-only", action="store_true", help="validate .mcp.json without starting servers")
    parser.add_argument("--handshake-only", action="store_true", help="skip live tool calls")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        servers = load_config()
        validate_config(servers)
        print("  ok    .mcp.json safety and version pins")
        if args.config_only:
            return 0
        selected = args.server or ["grafana", "playwright", "chrome-devtools"]
        if "grafana" in selected:
            preflight_grafana()
        if {"playwright", "chrome-devtools"} & set(selected):
            preflight_browsers()
        for name in selected:
            check_server(name, servers[name], args.handshake_only)
        return 0
    except (OSError, RuntimeError, TimeoutError, ValueError) as error:
        print(f"  FAIL  {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
