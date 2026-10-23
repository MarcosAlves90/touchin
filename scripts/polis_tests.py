"""Run the existing backend and Flutter test suites without a shell command string."""

from pathlib import Path
import shutil
import subprocess
import sys


ROOT = Path(__file__).resolve().parent.parent
BACKEND = ROOT / "backend"
FRONTEND = ROOT / "frontend"

virtual_env_python = BACKEND / ".venv" / (
    "Scripts/python.exe" if sys.platform == "win32" else "bin/python"
)
backend_python = str(virtual_env_python) if virtual_env_python.is_file() else sys.executable
flutter_executable = shutil.which("flutter.bat") or shutil.which("flutter") or "flutter"

for name, command, directory in (
    (
        "POLIS CI adapter",
        [sys.executable, "-B", "-m", "unittest", "discover", "-s", "scripts/tests", "-v"],
        ROOT,
    ),
    ("backend", [backend_python, "-m", "pytest"], BACKEND),
    ("frontend", [flutter_executable, "test"], FRONTEND),
):
    print(f"POLIS tests: {name}", flush=True)
    result = subprocess.run(command, cwd=directory, check=False)
    if result.returncode != 0:
        sys.exit(result.returncode)
