#!/usr/bin/env python3
"""Write a GitHub Actions job summary table for Terraform plan/apply."""

from __future__ import annotations

import argparse
import json
import os
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
            f"{counts['create']} add, {counts['update']} change, "
            f"{counts['delete']} destroy, {counts['replace']} replace"
        )
    append_summary("")

    if resources:
        append_summary("| Status | Action | Resource |")
        append_summary("| --- | --- | --- |")
        for address, action in resources:
            emoji = ACTION_EMOJI.get(action, "⚪")
            label = ACTION_LABEL.get(action, action)
            if action == "delete":
                label = f"<strong>{label}</strong>"
            append_summary(f"| {emoji} | {label} | `{address}` |")
        append_summary("")
        append_summary("🔴 destroy &nbsp; 🟠 replace &nbsp; 🟡 change &nbsp; 🟢 add")
        append_summary("")
    elif exitcode == 2:
        append_summary("_Could not parse a resource table from the remote plan JSON._")
        append_summary("")
        append_summary("```")
        append_summary(log_text[-4000:])
        append_summary("```")
        append_summary("")


def write_apply_summary(exitcode: int, log: Path) -> None:
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
    append_summary("```")
    append_summary(log_text[-4000:])
    append_summary("```")
    append_summary("")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--phase", choices=["plan", "apply"], required=True)
    parser.add_argument("--exitcode", type=int, required=True)
    parser.add_argument("--log", type=Path, required=True)
    parser.add_argument("--workdir", type=Path, default=Path.cwd())
    parser.add_argument("--plan-file", type=Path, default=None)
    args = parser.parse_args()

    if args.phase == "plan":
        plan_file = args.plan_file or (args.workdir / "tfplan")
        write_plan_summary(args.exitcode, args.log, args.workdir, plan_file)
    else:
        write_apply_summary(args.exitcode, args.log)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
