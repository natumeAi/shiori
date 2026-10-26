"""Run one oracle command with an explicit timeout and retain S2 evidence."""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import subprocess
import time


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("label")
    parser.add_argument("--timeout", type=int, default=180)
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command[1:] if args.command[:1] == ["--"] else args.command
    if not command:
        parser.error("a command is required")
    task_dir = Path(__file__).resolve().parent
    evidence_dir = task_dir / "evidence"
    evidence_dir.mkdir(exist_ok=True)
    repo = task_dir.parents[2]
    start = time.monotonic()
    process = subprocess.Popen(
        command, cwd=repo / "tool/oracle", env=dict(os.environ, PYTHONIOENCODING="utf-8"),
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
    )
    timed_out = False
    try:
        output, _ = process.communicate(timeout=args.timeout)
    except subprocess.TimeoutExpired:
        timed_out = True
        subprocess.run(["taskkill.exe", "/PID", str(process.pid), "/T", "/F"],
                       capture_output=True, timeout=30, check=False)
        output, _ = process.communicate(timeout=30)
    record = {"command": subprocess.list2cmdline(command), "cwd": "tool/oracle",
              "timeoutSeconds": args.timeout, "exitCode": 124 if timed_out else process.returncode,
              "timedOut": timed_out, "durationSeconds": round(time.monotonic() - start, 3),
              "outputTail": "\n".join(line.rstrip() for line in output.decode("utf-8", errors="replace").splitlines()[-60:])}
    (evidence_dir / f"oracle-{args.label}.json").write_text(
        json.dumps(record, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    with (task_dir / "local-validation.md").open("a", encoding="utf-8") as stream:
        stream.write(f"\n## Phase A — {args.label}\n\n`{record['command']}` in tool/oracle.\n\n"
                     f"Exit {record['exitCode']}; timeout {args.timeout} s; duration {record['durationSeconds']} s.\n\n"
                     f"```text\n{record['outputTail']}\n```\n")
    print(json.dumps(record, ensure_ascii=False), flush=True)
    return record["exitCode"]


if __name__ == "__main__":
    raise SystemExit(main())
