from __future__ import annotations

import contextlib
import importlib.util
import io
from pathlib import Path
import unittest
from unittest.mock import patch

MODULE_PATH = Path(__file__).with_name("test_touchin_branding.py")
SPEC = importlib.util.spec_from_file_location("touchin_branding", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
_branding = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(_branding)


class TestCodeQLLogging(unittest.TestCase):
    def test_main_does_not_log_offender_values(self) -> None:
        sentinel = "SENSITIVE-OFFENDER-SENTINEL-NOT-A-REAL-SECRET"
        output = io.StringIO()
        with patch.object(_branding, "_find_offenders", return_value=[sentinel]):
            with contextlib.redirect_stdout(output):
                result = _branding._main()
        self.assertEqual(result, 1)
        self.assertIn(_branding.RED_TOKEN, output.getvalue())
        self.assertNotIn(sentinel, output.getvalue())


if __name__ == "__main__":
    unittest.main()
