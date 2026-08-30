#!/usr/bin/env python3
"""Write a GitHub Actions job summary table for Terraform plan/apply.

Also ANSI-colorizes terraform plan/apply logs (green add, red destroy) so the
Terraform plan / Terraform apply steps show color in the Actions log.
"""

from __future__ import annotations

import argparse
import html
import json
import os
import re
import subprocess
import sys
from pathlib import Path

ACTION_LABEL = {
    "create": "add",
    "update": "change",
    "delete": "destroy",
    "replace": "replace",
    "read": "read",
    "no-op": "no-op",
}

ACTION_EMOJI = {
    "create": "🟢",
    "update": "🟡",
    "delete": "🔴",
    "replace": "🟠",
}

# GitHub-like greens/reds so add vs destroy is obvious in the job summary.
ACTION_FG = {
    "create": "#1a7f37",
    "delete": "#cf222e",
    "replace": "#cf222e",
    "update": "#9a6700",
}

ACTION_BG = {
    "create": "#dafbe1",
    "delete": "#ffebe9",
    "replace": "#ffebe9",
    "update": "#fff8c5",
}

ADD_COUNT_RE = re.compile(r"(\d+)\s+(to add|added)", re.I)
DESTROY_COUNT_RE = re.compile(r"(\d+)\s+(to destroy|destroyed)", re.I)

ANSI = {
    "create": "\033[1;32m",
    "delete": "\033[1;31m",
    "replace": "\033[1;31m",
    "update": "\033[1;33m",
}
ANSI_RESET = "\033[0m"


def append_summary(text: str) -> None:
    path = os.environ.get("GITHUB_STEP_SUMMARY")
    if not path:
        sys.stdout.write(text + "\n")
        return
    with open(path, "a", encoding="utf-8") as handle:
        handle.write(text)
        if not text.endswith("\n"):
            handle.write("\n")


def tail_text(path: Path, limit: int = 8000) -> str:
    if not path.is_file():
        return ""
    data = path.read_text(encoding="utf-8", errors="replace")
    if len(data) <= limit:
        return data
    return data[-limit:]


def colored(text: str, action: str, *, bold: bool = True) -> str:
    fg = ACTION_FG.get(action)
    if not fg:
        return html.escape(text)
    weight = "font-weight:700;" if bold else ""
    return f'<span style="color:{fg};{weight}">{html.escape(text)}</span>'


def resource_action(actions: list[str]) -> str:
    if actions == ["create", "delete"] or actions == ["delete", "create"]:
        return "replace"
    if len(actions) == 1:
        return actions[0]
    return "+".join(actions)


def plan_resources(plan_json: dict) -> list[tuple[str, str]]:
    rows: list[tuple[str, str]] = []
    for change in plan_json.get("resource_changes") or []:
        actions = (change.get("change") or {}).get("actions") or []
        if not actions or actions == ["no-op"] or actions == ["read"]:
            continue
        rows.append((change.get("address") or "(unknown)", resource_action(actions)))
    return rows


def load_plan_json(workdir: Path, plan_file: Path) -> dict | None:
    if not plan_file.is_file():
        return None
    try:
        result = subprocess.run(
            ["terraform", "show", "-json", str(plan_file)],
            cwd=workdir,
            check=False,
            capture_output=True,
            text=True,
        )
    except OSError:
        return None
    if result.returncode != 0:
        return None
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError:
        return None


def count_phrase(n: int, label: str, action: str) -> str:
    text = f"{n} {label}"
    if n <= 0:
        return text
    return colored(text, action)


def write_resource_table(resources: list[tuple[str, str]]) -> None:
    append_summary("<table>")
    append_summary("<tr><th>Status</th><th>Action</th><th>Resource</th></tr>")
    for address, action in resources:
        emoji = ACTION_EMOJI.get(action, "⚪")
        label = ACTION_LABEL.get(action, action)
        bg = ACTION_BG.get(action, "#ffffff")
        fg = ACTION_FG.get(action, "#1f2328")
        append_summary(
            f'<tr style="background-color:{bg};color:{fg}">'
            f"<td>{emoji}</td>"
            f"<td><strong>{html.escape(label)}</strong></td>"
            f"<td><code>{html.escape(address)}</code></td>"
            f"</tr>"
        )
    append_summary("</table>")
    append_summary("")
    append_summary(
        f"{colored('add', 'create')} &nbsp; "
        f"{colored('destroy', 'delete')} &nbsp; "
        "🟠 replace &nbsp; 🟡 change"
    )
    append_summary("")


def cli_line_action(line: str) -> str | None:
    """Classify a terraform plan/apply log line as add, destroy, replace, or change."""
    lower = line.lower()
    core = line.lstrip()
    if "must be replaced" in lower or core.startswith("-/+"):
        return "replace"
    if "will be destroyed" in lower or ": destroying" in lower or "destruction complete" in lower:
        return "delete"
    if "will be created" in lower or ": creating" in lower or "creation complete" in lower:
        return "create"
    if "will be updated" in lower:
        return "update"
    if core.startswith("+"):
        return "create"
    if core.startswith("-"):
        return "delete"
    if core.startswith("~"):
        return "update"
    return None


def ansi_paint_counts(line: str) -> str:
    def paint(match: re.Match[str], action: str) -> str:
        if int(match.group(1)) <= 0:
            return match.group(0)
        return f"{ANSI[action]}{match.group(0)}{ANSI_RESET}"

    out = ADD_COUNT_RE.sub(lambda m: paint(m, "create"), line)
    return DESTROY_COUNT_RE.sub(lambda m: paint(m, "delete"), out)


def ansi_colorize_line(line: str) -> str:
    if ADD_COUNT_RE.search(line) or DESTROY_COUNT_RE.search(line):
        return ansi_paint_counts(line)
    action = cli_line_action(line)
    if not action:
        return line
    return f"{ANSI[action]}{line}{ANSI_RESET}"


def colorize_stream() -> None:
    for line in sys.stdin:
        body = line[:-1] if line.endswith("\n") else line
        sys.stdout.write(ansi_colorize_line(body))
        if line.endswith("\n"):
            sys.stdout.write("\n")
        sys.stdout.flush()


def colorize_count_line(line: str) -> str:
    def paint(match: re.Match[str], action: str) -> str:
        if int(match.group(1)) <= 0:
            return html.escape(match.group(0))
        return colored(match.group(0), action)

    escaped = html.escape(line)
    escaped = ADD_COUNT_RE.sub(lambda m: paint(m, "create"), escaped)
    escaped = DESTROY_COUNT_RE.sub(lambda m: paint(m, "delete"), escaped)
    return escaped


def html_colorize_log(log_text: str) -> str:
    blocks: list[str] = []
    for raw in log_text.splitlines():
        line = raw.rstrip("\n")
        if ADD_COUNT_RE.search(line) or DESTROY_COUNT_RE.search(line):
            blocks.append(colorize_count_line(line))
            continue
        action = cli_line_action(line)
        if action:
            bg = ACTION_BG[action]
            fg = ACTION_FG[action]
            blocks.append(
                f'<span style="display:block;background-color:{bg};color:{fg};'
                f'font-weight:700">{html.escape(line)}</span>'
            )
            continue
        blocks.append(html.escape(line))
    return "\n".join(blocks)


def write_plan_summary(exitcode: int, log: Path, workdir: Path, plan_file: Path) -> None:
    log_text = tail_text(log)
    if exitcode == 1:
        append_summary("> [!CAUTION]")
        append_summary("> **Terraform plan failed**")
        append_summary("")
        append_summary("```diff")
        append_summary("- PLAN FAILED")
        for line in log_text.splitlines()[-80:]:
            append_summary(line)
        append_summary("```")
        append_summary("")
        print("::error::Terraform plan failed. See the job summary and plan log.")
        return

    resources = []
    plan_json = load_plan_json(workdir, plan_file)
    if plan_json:
        resources = plan_resources(plan_json)

    if exitcode == 0:
        append_summary("> [!TIP]")
        append_summary("> **Terraform plan succeeded** — no changes")
    else:
        counts = {"create": 0, "update": 0, "delete": 0, "replace": 0}
        for _, action in resources:
            if action in counts:
                counts[action] += 1
        append_summary("> [!WARNING]")
        append_summary(
            "> **Terraform plan succeeded** — "
            f"{count_phrase(counts['create'], 'add', 'create')}, "
            f"{counts['update']} change, "
            f"{count_phrase(counts['delete'], 'destroy', 'delete')}, "
            f"{counts['replace']} replace"
        )
    append_summary("")

    if resources:
        write_resource_table(resources)
    elif exitcode == 2:
        append_summary("_Could not parse a resource table from the remote plan JSON._")
        append_summary("")

    if log_text:
        append_summary(
            '<pre style="white-space:pre-wrap;font-size:12px">'
            + html_colorize_log(log_text[-4000:])
            + "</pre>"
        )
        append_summary("")


def write_apply_summary(
    exitcode: int, log: Path, workdir: Path, plan_file: Path | None
) -> None:
    log_text = tail_text(log)
    if exitcode != 0:
        append_summary("> [!CAUTION]")
        append_summary("> **Terraform apply failed**")
        append_summary("")
        append_summary("```diff")
        append_summary("- APPLY FAILED")
        for line in log_text.splitlines()[-80:]:
            append_summary(line)
        append_summary("```")
        append_summary("")
        print("::error::Terraform apply failed. See the job summary and apply log.")
        return

    append_summary("> [!TIP]")
    append_summary("> **Terraform apply succeeded**")
    append_summary("")

    resources: list[tuple[str, str]] = []
    if plan_file:
        plan_json = load_plan_json(workdir, plan_file)
        if plan_json:
            resources = plan_resources(plan_json)
    if resources:
        write_resource_table(resources)

    append_summary(
        '<pre style="white-space:pre-wrap;font-size:12px">'
        + html_colorize_log(log_text[-4000:])
        + "</pre>"
    )
    append_summary("")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--phase",
        choices=["plan", "apply", "colorize-stream"],
        required=True,
    )
    parser.add_argument("--exitcode", type=int, default=0)
    parser.add_argument("--log", type=Path, default=None)
    parser.add_argument("--workdir", type=Path, default=Path.cwd())
    parser.add_argument("--plan-file", type=Path, default=None)
    args = parser.parse_args()

    if args.phase == "colorize-stream":
        colorize_stream()
        return 0
    if not args.log:
        parser.error("--log is required for plan and apply")
    if args.phase == "plan":
        plan_file = args.plan_file or (args.workdir / "tfplan")
        write_plan_summary(args.exitcode, args.log, args.workdir, plan_file)
    else:
        write_apply_summary(args.exitcode, args.log, args.workdir, args.plan_file)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
