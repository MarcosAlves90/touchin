"""Test that the CI workaround retains every Flutter test and its coverage."""

import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest


MODULE_PATH = Path(__file__).resolve().parents[1] / "run_frontend_coverage.py"
SPEC = importlib.util.spec_from_file_location("run_frontend_coverage", MODULE_PATH)
assert SPEC and SPEC.loader
coverage_runner = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(coverage_runner)


class FrontendCoverageTests(unittest.TestCase):
    def test_batches_contain_each_file_once_and_reject_invalid_sizes(self):
        files = [Path(f"test/{i:02d}_test.dart") for i in range(23)]
        groups = coverage_runner.batches(files)
        self.assertEqual([10, 10, 3], [len(group) for group in groups])
        self.assertEqual(files, [item for group in groups for item in group])
        with self.assertRaises(ValueError):
            coverage_runner.batches(files, size=0)

    def test_all_batches_preserve_coverage_flags_and_merge_every_trace(self):
        files = [Path(f"test/{i:02d}_test.dart") for i in range(23)]
        commands = []

        def fake_run(args, *, check):
            self.assertTrue(check)
            commands.append(args)
            if args[0] == "timeout":
                self.assertIn("--coverage", args)
                self.assertIn("--concurrency=1", args)
                self.assertIn("canonical-golden", args)
                self.assertIn("--no-pub", args)
                trace = next(arg.partition("=")[2] for arg in args
                             if arg.startswith("--coverage-path="))
                Path(trace).write_text("TN:\nSF:lib/a.dart\nLF:1\nLH:1\nend_of_record\n")
            else:
                self.assertEqual("lcov", args[0])
                self.assertEqual(3, args.count("--add-tracefile"))
                destination = args[args.index("--output-file") + 1]
                Path(destination).write_text("TN:\nSF:lib/a.dart\nLF:1\nLH:1\nend_of_record\n")

        with tempfile.TemporaryDirectory() as directory:
            destination = Path(directory) / "coverage" / "lcov.info"
            coverage_runner.run_coverage(files, destination, invoke=fake_run)
            self.assertTrue(destination.is_file())
        self.assertEqual(4, len(commands))
        self.assertEqual(
            files,
            [Path(arg) for command in commands[:3] for arg in command
             if arg.endswith("_test.dart")],
        )

    def test_failed_flutter_batch_never_merges_partial_coverage(self):
        calls = []

        def fail(args, *, check):
            calls.append(args)
            raise subprocess.CalledProcessError(139, args)

        with tempfile.TemporaryDirectory() as directory:
            destination = Path(directory) / "coverage" / "lcov.info"
            with self.assertRaises(subprocess.CalledProcessError):
                coverage_runner.run_coverage([Path("test/a_test.dart")],
                                             destination, invoke=fail)
            self.assertFalse(destination.exists())
        self.assertEqual(1, len(calls))


if __name__ == "__main__":
    unittest.main()
