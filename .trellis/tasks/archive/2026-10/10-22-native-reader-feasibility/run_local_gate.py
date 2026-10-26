"""Run the S2 local gate with bounded processes and UTF-8 evidence."""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import subprocess
import time


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("phase")
    args = parser.parse_args()
    task_dir = Path(__file__).resolve().parent
    evidence_dir = task_dir / "evidence"
    evidence_dir.mkdir(exist_ok=True)
    repo = task_dir.parents[2]
    env = dict(os.environ, PYTHONIOENCODING="utf-8")
    commands = [
        ("dart run build_runner build", 900),
        ("dart format --set-exit-if-changed lib test tool/diag", 180),
        ("flutter analyze", 180),
        ("flutter test", 900),
    ]
    records = []
    for command, timeout in commands:
        print(f"START {command} (timeout {timeout}s)", flush=True)
        started = time.monotonic()
        process = subprocess.Popen(
            ["cmd.exe", "/d", "/s", "/c", command],
            cwd=repo,
            env=env,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
        )
        timed_out = False
        try:
            output, _ = process.communicate(timeout=timeout)
        except subprocess.TimeoutExpired:
            timed_out = True
            subprocess.run(
                ["taskkill.exe", "/PID", str(process.pid), "/T", "/F"],
                capture_output=True,
                timeout=30,
                check=False,
            )
            output, _ = process.communicate(timeout=30)
        decoded = output.decode("utf-8", errors="replace")
        record = {
            "command": command,
            "timeoutSeconds": timeout,
            "exitCode": 124 if timed_out else process.returncode,
            "timedOut": timed_out,
            "durationSeconds": round(time.monotonic() - started, 3),
            "outputTail": "\n".join(line.rstrip() for line in decoded.splitlines()[-24:]),
        }
        records.append(record)
        print(json.dumps(record, ensure_ascii=False), flush=True)
        (evidence_dir / f"quality-gate-{args.phase}.json").write_text(
            json.dumps(records, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
    report = task_dir / "local-validation.md"
    existing = report.read_text(encoding="utf-8") if report.exists() else (
        "# S2 local validation\n\n"
        "Local commands only. No push, workflow trigger, signing, or device run.\n"
    )
    stamp = datetime.now(timezone.utc).isoformat()
    lines = [f"\n## Phase {args.phase} — {stamp}\n"]
    lines.append("All commands run at the repository root with explicit timeouts.\n")
    for record in records:
        lines.extend([
            f"### `{record['command']}`\n",
            f"Exit: {record['exitCode']}; timeout: {record['timeoutSeconds']} s; "
            f"duration: {record['durationSeconds']} s; timed out: {record['timedOut']}.\n",
            "```text\n" + record["outputTail"] + "\n```\n",
        ])
    report.write_text(existing + "\n".join(lines), encoding="utf-8")
    return 1 if any(record["exitCode"] for record in records) else 0


if __name__ == "__main__":
    raise SystemExit(main())
