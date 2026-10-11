"""Run selected command gates from the versioned POLIS policy in CI.

The POLIS CLI itself lives outside this repository. This small adapter reuses
the policy's argv, cwd, and environment instead of maintaining duplicate
Flutter build and browser-smoke commands in the GitHub Actions workflow.
It does not replace POLIS's policy validation, evidence or provenance gates.
"""

import json
import os
from pathlib import Path
import subprocess
import sys


ROOT = Path(__file__).resolve().parent.parent
POLICY = json.loads((ROOT / ".polis" / "policy.json").read_text())
GATES = {gate["id"]: gate for gate in POLICY["gates"]}


def run_gate(name: str) -> None:
    gate = GATES.get(name)
    if gate is None or gate.get("mode") != "command":
        raise ValueError(f"POLIS gate {name!r} is missing or disabled")

    command = gate["command"]
    argv = command["argv"]
    if not isinstance(argv, list) or not argv or not all(
        isinstance(item, str) and item for item in argv
    ):
        raise ValueError(f"POLIS gate {name!r} has invalid argv")

    cwd = (ROOT / command["cwd"]).resolve()
    if not cwd.is_relative_to(ROOT) or not cwd.is_dir():
        raise ValueError(f"POLIS gate {name!r} has an invalid working directory")

    environment = command["environment"]
    if environment["mode"] != "clean":
        raise ValueError(f"POLIS gate {name!r} requires an unsupported environment")
    env = {key: os.environ[key] for key in environment["pass"] if key in os.environ}

    print(f"Running POLIS policy gate {name}: {argv!r}", flush=True)
    result = subprocess.run(argv, cwd=cwd, env=env, check=False)
    if result.returncode:
        raise SystemExit(result.returncode)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        raise SystemExit("Specify one or more POLIS command gate IDs")
    for gate_id in sys.argv[1:]:
        run_gate(gate_id)
