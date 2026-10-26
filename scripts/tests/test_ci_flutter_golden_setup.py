import re
import unittest
from pathlib import Path


WORKFLOW = Path(".github/workflows/ci.yml").read_text(encoding="utf-8")
POLIS_TESTS = Path("scripts/polis_tests.py").read_text(encoding="utf-8")


def _named_block(pattern: str, source: str) -> str:
    match = re.search(pattern, source, flags=re.MULTILINE | re.DOTALL)
    if match is None:
        return ""
    return match.group("body")


def _canonical_golden_job() -> str:
    return _named_block(
        r"^  frontend-golden-ubuntu:\n(?P<body>.*?)(?=^  [A-Za-z0-9_-]+:\n|\Z)",
        WORKFLOW,
    )


def _job_step(job: str, name: str) -> str:
    return _named_block(
        rf"^      - name: {re.escape(name)}\n(?P<body>.*?)(?=^      - name:|^  [A-Za-z0-9_-]+:|\Z)",
        job,
    )


class FlutterGoldenCiContractTest(unittest.TestCase):
    def test_canonical_golden_job_pins_flutter_and_records_installed_version(self):
        self.assertRegex(WORKFLOW, r"(?m)^\s*flutter-version:\s*['\"]?3\.47\.2['\"]?\s*$")
        self.assertIn("flutter --version", WORKFLOW)

    def test_golden_case_is_tagged_for_isolated_canonical_execution(self):
        test_source = Path(
            "frontend/test/features/shared/presentation/widgets/workspace_shell_test.dart"
        ).read_text(encoding="utf-8")
        self.assertRegex(test_source, r"(?s)tags:\s*<String>\s*\{[^}]*canonical-golden")
        self.assertRegex(WORKFLOW, r"flutter test[^\n]*--tags\s+canonical-golden")

    def test_functional_suites_exclude_only_the_golden_tag(self):
        self.assertRegex(POLIS_TESTS, r"flutter test[^\n]*--exclude-tags\s+canonical-golden")
        self.assertRegex(WORKFLOW, r"flutter test[^\n]*--exclude-tags\s+canonical-golden")

    def test_canonical_job_binds_runtime_golden_and_failure_artifact_steps(self):
        job = _canonical_golden_job()
        setup = _job_step(job, "Set up Flutter 3.47.2 for canonical goldens")
        runtime = _job_step(job, "Confirm canonical Flutter runtime")
        golden = _job_step(job, "Compare canonical navigation goldens")
        upload = _job_step(job, "Upload canonical golden failure images")

        self.assertIn("runs-on: ubuntu-latest", job, "issue123_golden_job_contract_missing")
        self.assertIn("uses: subosito/flutter-action@v2", setup, "issue123_golden_job_contract_missing")
        self.assertRegex(setup, r"(?m)^\s*flutter-version:\s*['\"]?3\.47\.2['\"]?\s*$", "issue123_golden_job_contract_missing")
        self.assertRegex(runtime, r"(?m)^\s*run:\s*flutter --version\s*$", "issue123_golden_job_contract_missing")
        self.assertRegex(golden, r"(?m)^\s*run:\s*flutter test --tags canonical-golden\s*$", "issue123_golden_job_contract_missing")
        self.assertRegex(upload, r"(?m)^\s*if:\s*failure\(\)\s*$", "issue123_golden_failure_artifact_missing")
        self.assertIn("uses: actions/upload-artifact@v4", upload, "issue123_golden_failure_artifact_missing")
        self.assertRegex(upload, r"(?m)^\s*path:\s*frontend/test/failures/?\s*$", "issue123_golden_failure_artifact_missing")


if __name__ == "__main__":
    unittest.main()
