"""Run selected command gates from the versioned POLIS policy in CI.

The POLIS CLI itself lives outside this repository. This small adapter reuses
the policy's argv, cwd, and environment instead of maintaining duplicate
Flutter build and browser-smoke commands in the GitHub Actions workflow.
It does not replace POLIS's policy validation, evidence or provenance gates.
"""

import json
import os
from pathlib import Path
import signal
import subprocess
import sys


ROOT = Path(__file__).resolve().parent.parent
POLICY = json.loads((ROOT / ".polis" / "policy.json").read_text())
GATES = {gate["id"]: gate for gate in POLICY["gates"]}


def _stop_process_tree(process: subprocess.Popen) -> None:
    if os.name == "nt":
        # The Windows process-tree equivalent of killing a POSIX process group.
        try:
            subprocess.run(
                ["taskkill", "/PID", str(process.pid), "/T", "/F"],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                timeout=10,
                check=False,
            )
        except (OSError, subprocess.TimeoutExpired):
            pass
        if process.poll() is None:
            process.kill()
    else:
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
    process.wait()


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

    root = ROOT.resolve()
    cwd = (root / command["cwd"]).resolve()
    if not cwd.is_relative_to(root) or not cwd.is_dir():
        raise ValueError(f"POLIS gate {name!r} has an invalid working directory")

    environment = command["environment"]
    if environment["mode"] != "clean":
        raise ValueError(f"POLIS gate {name!r} requires an unsupported environment")
    env = {key: os.environ[key] for key in environment["pass"] if key in os.environ}
    timeout = command["timeout_seconds"]
    if type(timeout) is not int or timeout <= 0:
        raise ValueError(f"POLIS gate {name!r} has invalid timeout_seconds")

    print(f"Running POLIS policy gate {name}: {argv!r}", flush=True)
    process = subprocess.Popen(
        argv, cwd=cwd, env=env,
        start_new_session=os.name != "nt",
        creationflags=subprocess.CREATE_NEW_PROCESS_GROUP if os.name == "nt" else 0,
    )
    try:
        returncode = process.wait(timeout=timeout)
    except subprocess.TimeoutExpired:
        _stop_process_tree(process)
        print(f"POLIS gate {name!r} exceeded timeout_seconds={timeout}; process tree stopped.", file=sys.stderr)
        raise SystemExit(124) from None
    except KeyboardInterrupt:
        _stop_process_tree(process)
        raise
    if returncode:
        raise SystemExit(returncode)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        raise SystemExit("Specify one or more POLIS command gate IDs")
    for gate_id in sys.argv[1:]:
        run_gate(gate_id)
