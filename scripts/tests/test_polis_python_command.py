"""The committed POLIS entrypoint must work on Windows and Linux."""

import json
from pathlib import Path
import shutil
import subprocess
import unittest


ROOT = Path(__file__).resolve().parents[2]


class PolisPythonCommandTest(unittest.TestCase):
    def test_gate_uses_cross_platform_python_not_windows_store_python3_alias(self):
        policy = json.loads((ROOT / ".polis" / "policy.json").read_text(encoding="utf-8"))
        command = next(gate["command"]["argv"] for gate in policy["gates"]
                       if gate["id"] == "test.complete")
        self.assertEqual(command, ["python", "scripts/polis_tests.py"])
        executable = shutil.which(command[0])
        self.assertIsNotNone(executable)
        result = subprocess.run([executable, "--version"], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Python 3", result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
