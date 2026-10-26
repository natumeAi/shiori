"""Run two clean oracle generations across timezones and compare every byte."""
from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys


def main() -> int:
    task_dir = Path(__file__).resolve().parent
    evidence_dir = task_dir / "evidence"
    evidence_dir.mkdir(exist_ok=True)
    repo = task_dir.parents[2]
    # Git's eol filter can normalize the index without rewriting the worktree.
    # Refuse to build from bytes that differ after the committed path's filters.
    tracked = subprocess.run(["git", "ls-files", "-z", "tool/oracle"], cwd=repo,
                             capture_output=True, timeout=30, check=True).stdout.decode("utf-8")
    filtered_mismatches = []
    for name in filter(None, tracked.split("\0")):
        source = (repo / name).read_bytes()
        raw_hash = subprocess.run(["git", "hash-object", "--no-filters", "--stdin"],
                                  input=source, cwd=repo, capture_output=True, timeout=30, check=True).stdout
        filtered_hash = subprocess.run(["git", "hash-object", f"--path={name}", "--stdin"],
                                       input=source, cwd=repo, capture_output=True, timeout=30, check=True).stdout
        if raw_hash != filtered_hash:
            filtered_mismatches.append(name)
    if filtered_mismatches:
        raise RuntimeError(f"Source worktree bytes differ from Git-filtered bytes: {filtered_mismatches}")
    directories = [repo / "assets/reader_fixtures", repo / "test/fixtures/reader/oracle"]
    snapshots = []
    for run, timezone in enumerate(["UTC", "Asia/Hong_Kong"], start=1):
        for directory in directories:
            resolved = directory.resolve()
            if not resolved.is_relative_to(repo.resolve()):
                raise RuntimeError("Generated path outside intended repository")
            for entry in resolved.iterdir():
                if not entry.is_file() or entry.parent.resolve() != resolved:
                    raise RuntimeError("Unexpected generated output entry")
                if entry.name != ".gitattributes":
                    entry.unlink()
        for name in ["build-fixtures", "vectors", "verify-vectors"]:
            result = subprocess.run(
                [sys.executable, str(task_dir / "run_oracle_command.py"),
                 f"final-clean-{run}-{name}", "--", "npm.cmd", "run", name],
                cwd=repo, env=dict(os.environ, TZ=timezone, PYTHONIOENCODING="utf-8"),
                timeout=240, check=False,
            )
            if result.returncode:
                return result.returncode
        snapshots.append({
            str(file.relative_to(repo)).replace("\\", "/"): hashlib.sha256(file.read_bytes()).hexdigest()
            for directory in directories for file in directory.iterdir() if file.is_file()
        })
    changed = [key for key in sorted(set(snapshots[0]) | set(snapshots[1]))
               if snapshots[0].get(key) != snapshots[1].get(key)]
    report = {"timezones": ["UTC", "Asia/Hong_Kong"], "files": len(snapshots[0]),
              "sourceFilterMismatches": filtered_mismatches,
              "byteIdentical": not changed, "changed": changed, "sha256": snapshots[1]}
    (evidence_dir / "oracle-final-reproducibility.json").write_text(
        json.dumps(report, indent=2) + "\n", encoding="utf-8")
    with (task_dir / "local-validation.md").open("a", encoding="utf-8") as stream:
        stream.write(f"\n## Phase A final clean reproducibility\n\n"
                     f"Two clean builds/extractions under UTC and Asia/Hong_Kong: "
                     f"{len(snapshots[0])} generated/attribute files, "
                     f"{len(changed)} SHA-256 differences; exit {int(bool(changed))}. "
                     "Scoped .gitattributes were preserved during cleanup. "
                     "Every generation command had a 180 s process timeout and a 240 s wrapper bound. "
                     "See evidence/oracle-final-reproducibility.json for final hashes.\n")
    print(f"Reproducibility: {len(snapshots[0])} files; {len(changed)} differences", flush=True)
    return int(bool(changed))


if __name__ == "__main__":
    raise SystemExit(main())
