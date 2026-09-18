from __future__ import annotations

from pathlib import Path
import re
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
OLD_NAME = ("bun" + "chin").encode()
OLD_NAME_TEXT = OLD_NAME.decode()
RED_TOKEN = "TOUCHIN_DELIVERY_RED_V1"
GREEN_TOKEN = "TOUCHIN_DELIVERY_GREEN_V1"
IGNORED_DIRS = {
    ".git",
    ".dart_tool",
    ".pytest_cache",
    ".ruff_cache",
    ".mypy_cache",
    ".venv",
    "venv",
    "__pycache__",
    "node_modules",
    "build",
}
ANDROID_NS = "{http://schemas.android.com/apk/res/android}"
FRONTEND_API_TEST = "frontend/test/core/network/touchin_api_test.dart"
INLINE_PASSWORD_LITERAL_PATTERN = re.compile(
    r"(?:\bpassword\s*:|[\"']password[\"']\s*:)\s*[\"'][^\"']+[\"']"
)
FLAGGED_TEST_VALUE = "Touch" + "In@123"


def _repository_paths() -> list[Path]:
    paths: list[Path] = []
    for path in ROOT.rglob("*"):
        relative = path.relative_to(ROOT)
        if any(part in IGNORED_DIRS for part in relative.parts):
            continue
        paths.append(path)
    return paths


def _find_branding_offenders() -> list[str]:
    offenders: list[str] = []
    for path in _repository_paths():
        relative = path.relative_to(ROOT).as_posix()
        if OLD_NAME_TEXT in relative.lower():
            offenders.append(f"branding:path:{relative}")
            continue
        if path.is_file() and OLD_NAME in path.read_bytes().lower():
            offenders.append(f"branding:content:{relative}")
    return offenders


def _read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def _application_attributes(relative: str) -> dict[str, str]:
    root = ET.parse(ROOT / relative).getroot()
    application = root.find("application")
    if application is None:
        return {}
    return application.attrib


def _find_quality_offenders() -> list[str]:
    offenders: list[str] = []

    create_postgres = _read("backend/app/scripts/create_postgres.py")
    if "def create_postgres_database() -> tuple[str, bool]:" not in create_postgres:
        offenders.append("quality:create_postgres:return-type")
    if 're.fullmatch(r"\\w+", database_name, flags=re.ASCII)' not in create_postgres:
        offenders.append("quality:create_postgres:ascii-word-regex")
    if re.search(r"\[A-Za-z0-9_\]\+", create_postgres):
        offenders.append("quality:create_postgres:verbose-character-class")

    seed = _read("backend/app/seed.py")
    bianca_email = "bianca.nogueira@touchin.com"
    if f'BIANCA_EMAIL = "{bianca_email}"' not in seed:
        offenders.append("quality:seed:bianca-email-constant")
    if seed.count(bianca_email) != 1:
        offenders.append("quality:seed:bianca-email-duplication")

    brevo = _read("backend/app/services/brevo.py")
    if 'JSON_MEDIA_TYPE = "application/json"' not in brevo:
        offenders.append("quality:brevo:json-media-type-constant")
    if brevo.count("application/json") != 1:
        offenders.append("quality:brevo:json-media-type-duplication")
    for helper in (
        "_welcome_subject",
        "_credentials_subject",
        "_password_reset_subject",
        "_password_changed_subject",
    ):
        if f"def {helper}() -> str:" not in brevo:
            offenders.append(f"quality:brevo:{helper}:unused-parameter")

    conftest = _read("backend/tests/conftest.py")
    if "@pytest.fixture()" in conftest or "@pytest.fixture\n" not in conftest:
        offenders.append("quality:pytest:fixture-parentheses")

    main_attrs = _application_attributes(
        "frontend/android/app/src/main/AndroidManifest.xml"
    )
    if main_attrs.get(f"{ANDROID_NS}usesCleartextTraffic") != "false":
        offenders.append("quality:android:release-cleartext")
    if main_attrs.get(f"{ANDROID_NS}allowBackup") != "false":
        offenders.append("quality:android:backup")

    for variant in ("debug", "profile"):
        attrs = _application_attributes(
            f"frontend/android/app/src/{variant}/AndroidManifest.xml"
        )
        if attrs.get(f"{ANDROID_NS}usesCleartextTraffic") != "true":
            offenders.append(f"quality:android:{variant}-local-cleartext")

    return offenders


def _find_secret_fixture_offenders() -> list[str]:
    source = _read(FRONTEND_API_TEST)
    offenders: list[str] = []
    if FLAGGED_TEST_VALUE in source:
        offenders.append("security:frontend-api-test:flagged-password-literal")
    if INLINE_PASSWORD_LITERAL_PATTERN.search(source):
        offenders.append("security:frontend-api-test:inline-password-literal")
    return offenders


def _find_offenders() -> list[str]:
    return (
        _find_branding_offenders()
        + _find_quality_offenders()
        + _find_secret_fixture_offenders()
    )


def test_repository_uses_touchin_identity_only() -> None:
    offenders = _find_branding_offenders()
    assert not offenders, "old product identity remains: " + ", ".join(offenders)


def test_repository_satisfies_quality_contract() -> None:
    offenders = _find_quality_offenders()
    assert not offenders, "quality contract violations remain: " + ", ".join(offenders)


def test_frontend_api_tests_do_not_hardcode_password_literals() -> None:
    offenders = _find_secret_fixture_offenders()
    assert not offenders, "hardcoded test password literals remain: " + ", ".join(offenders)


def _main() -> int:
    offenders = _find_offenders()
    if offenders:
        print(RED_TOKEN)
        for offender in offenders[:100]:
            print(offender)
        if len(offenders) > 100:
            print(f"... and {len(offenders) - 100} more")
        return 1
    print(GREEN_TOKEN)
    return 0


if __name__ == "__main__":
    raise SystemExit(_main())
