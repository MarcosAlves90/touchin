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

    def test_windows_gate_environment_keeps_required_system_variables_and_utf8(self):
        """Clean gates still need Windows process-launch variables and UTF-8."""
        captured = {}

        class Process:
            def wait(self, timeout=None):
                return 0

        def popen(argv, **kwargs):
            captured.update(argv=argv, **kwargs)
            return Process()

        required = {
            "SystemRoot": "C:\\Windows",
            "COMSPEC": "C:\\Windows\\System32\\cmd.exe",
            "PATHEXT": ".COM;.EXE;.BAT;.CMD",
        }
        with patch.dict(os.environ, required, clear=False), patch.dict(
            os.environ, {"PYTHONUTF8": "0", "PYTHONIOENCODING": "latin-1"}, clear=False
        ), patch.object(runner.subprocess, "Popen", side_effect=popen):
            self.run_gate(self.gate([sys.executable, "-c", "pass"]))

        for key, value in required.items():
            with self.subTest(variable=key):
                self.assertEqual(captured["env"].get(key), value)
        self.assertEqual(captured["env"].get("PYTHONUTF8"), "1")
        self.assertEqual(captured["env"].get("PYTHONIOENCODING"), "utf-8")

    def test_batch_gate_command_is_dispatched_through_comspec_on_windows(self):
        captured = {}

        class Process:
            def wait(self, timeout=None):
                return 0

        def popen(argv, **kwargs):
            captured.update(argv=argv, **kwargs)
            return Process()

        batch_file = self.root / "flutter.BAT"
        batch_file.write_text("@echo off\r\n")
        gate = self.gate(
            ["flutter", "test"], passed=["PATH", "PATHEXT", "COMSPEC"]
        )
        with patch.object(runner.os, "name", "nt"), patch.object(
            runner.subprocess, "CREATE_NEW_PROCESS_GROUP", 512, create=True
        ), patch.dict(os.environ, {
            "PATH": str(self.root),
            "PATHEXT": ".COM;.EXE;.BAT;.CMD",
            "COMSPEC": "C:\\Windows\\cmd.exe",
        }), patch.object(runner.subprocess, "Popen", side_effect=popen):
            self.run_gate(gate)

        self.assertEqual(
            captured["argv"], [
                "C:\\Windows\\cmd.exe", "/d", "/s", "/c",
                f'"{batch_file} test"',
            ]
        )


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


class WindowsPolicyTests(unittest.TestCase):
    def test_every_command_gate_passes_windows_launch_variables(self):
        policy_path = Path(runner.ROOT) / ".polis" / "policy.json"
        policy = json.loads(policy_path.read_text())
        required = {"SystemRoot", "COMSPEC", "PATHEXT"}

        for gate in policy["gates"]:
            if gate["mode"] != "command":
                continue
            with self.subTest(gate=gate["id"]):
                passed = set(gate["command"]["environment"]["pass"])
                self.assertTrue(required <= passed, f"missing {sorted(required - passed)}")


if __name__ == "__main__":
    unittest.main()
