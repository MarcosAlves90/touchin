"""Regression tests for CI's adapter to the checked-in POLIS gate policy."""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

from scripts import run_polis_gates as runner


class PolicyGateRunnerTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)

    def gate(self, argv, timeout=5, passed=None):
        return {
            "id": "example",
            "mode": "command",
            "command": {
                "argv": argv,
                "cwd": ".",
                "timeout_seconds": timeout,
                "environment": {"mode": "clean", "pass": passed or ["PATH"]},
            },
        }

    def run_gate(self, gate):
        with patch.object(runner, "ROOT", self.root), patch.object(
            runner, "GATES", {"example": gate}
        ):
            runner.run_gate("example")

    def test_passes_configured_working_directory_and_clean_environment(self):
        destination = self.root / "result.json"
        code = (
            "import json,os,sys,pathlib;"
            "pathlib.Path(sys.argv[1]).write_text(json.dumps({"
            "'cwd':os.getcwd(),'allowed':os.getenv('GATE_ALLOWED'),"
            "'blocked':os.getenv('GATE_BLOCKED')}))"
        )
        with patch.dict(os.environ, {"GATE_ALLOWED": "yes", "GATE_BLOCKED": "secret"}):
            self.run_gate(self.gate(
                [sys.executable, "-c", code, str(destination)],
                passed=["PATH", "GATE_ALLOWED"],
            ))
        result = json.loads(destination.read_text())
        self.assertEqual(result, {"cwd": str(self.root.resolve()), "allowed": "yes", "blocked": None})

    def test_propagates_nonzero_exit(self):
        with self.assertRaises(SystemExit) as caught:
            self.run_gate(self.gate([sys.executable, "-c", "raise SystemExit(17)"]))
        self.assertEqual(caught.exception.code, 17)

    def test_rejects_invalid_timeout_before_starting_a_gate(self):
        for value in (0, -1, "30", True):
            with self.subTest(timeout=value):
                with self.assertRaisesRegex(ValueError, "invalid timeout_seconds"):
                    self.run_gate(self.gate([sys.executable, "-c", "pass"], timeout=value))

    def test_timeout_returns_124(self):
        with self.assertRaises(SystemExit) as caught:
            self.run_gate(self.gate(
                [sys.executable, "-c", "import time; time.sleep(20)"],
                timeout=1,
            ))
        self.assertEqual(caught.exception.code, 124)

    @unittest.skipUnless(os.name == "posix", "requires POSIX process groups")
    def test_timeout_kills_descendant_processes(self):
        child_ran = self.root / "child-ran.txt"
        child_started = self.root / "child-started.txt"
        child_code = (
            "import pathlib,sys,time;"
            "time.sleep(1.5);pathlib.Path(sys.argv[1]).write_text('still alive')"
        )
        parent_code = (
            "import pathlib,subprocess,sys,time;"
            "child=subprocess.Popen([sys.executable,'-c',sys.argv[2],sys.argv[1]]);"
            "pathlib.Path(sys.argv[3]).write_text(str(child.pid));"
            "time.sleep(20)"
        )
        with self.assertRaises(SystemExit) as caught:
            self.run_gate(self.gate([
                sys.executable, "-c", parent_code,
                str(child_ran), child_code, str(child_started),
            ], timeout=1))
        self.assertEqual(caught.exception.code, 124)
        self.assertTrue(child_started.is_file(), "test must actually launch a descendant")
        time.sleep(0.8)
        self.assertFalse(child_ran.exists(), "timed-out gate left a child running")


if __name__ == "__main__":
    unittest.main()
