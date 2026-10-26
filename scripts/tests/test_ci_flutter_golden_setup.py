import re
import unittest
from pathlib import Path


WORKFLOW = Path(".github/workflows/ci.yml").read_text(encoding="utf-8")
POLIS_TESTS = Path("scripts/polis_tests.py").read_text(encoding="utf-8")


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


if __name__ == "__main__":
    unittest.main()
