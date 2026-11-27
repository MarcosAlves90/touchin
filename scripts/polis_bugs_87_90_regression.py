"""Focused multi-language RED/GREEN command for issues #87-#90."""

from pathlib import Path
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[1]
CHECKS = [
    (
        [sys.executable, "-m", "pytest", "-q", "tests/test_seed_settings.py", "tests/test_db_schema.py"],
        ROOT / "backend",
    ),
    (
        [
            "flutter", "test",
            "test/core/forms/br_input_masks_test.dart",
            "test/features/projects/presentation/project_tasks_controller_test.dart",
        ],
        ROOT / "frontend",
    ),
]


def main() -> int:
    failures = 0
    for argv, cwd in CHECKS:
        print(f"Checking {cwd.name}: {' '.join(argv)}", flush=True)
        outcome = subprocess.run(argv, cwd=cwd, check=False)
        if outcome.returncode != 0:
            failures += 1
    if failures:
        print("BUGS_87_90_REGRESSION_FAILED")
        return 1
    print("BUGS_87_90_REGRESSION_PASSED")
    return 0


if __name__ == "__main__":
    sys.exit(main())
