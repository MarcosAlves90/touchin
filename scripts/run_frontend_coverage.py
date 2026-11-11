"""Run every Flutter test with coverage in bounded runner sessions.

On hosted Ubuntu/Flutter 3.47.9, a single serial coverage run consistently
segfaults inside flutter_tester after ~280 passing tests. The same Kanban file
passes when run alone, with and without coverage. Fresh CLI sessions keep the
native runner's lifetime bounded without disabling any tests or coverage.
"""

from pathlib import Path
import subprocess
import tempfile


BATCH_SIZE = 10


def test_files(directory: Path) -> list[Path]:
    return sorted(directory.rglob("*_test.dart"))


def batches(files: list[Path], size: int = BATCH_SIZE) -> list[list[Path]]:
    if size < 1:
        raise ValueError("Batch size must be positive")
    return [files[index : index + size] for index in range(0, len(files), size)]


def run_coverage(
    files: list[Path],
    destination: Path,
    *,
    invoke=subprocess.run,
) -> None:
    if not files:
        raise ValueError("No Flutter test files found")

    with tempfile.TemporaryDirectory(prefix="touchin_flutter_coverage_") as work:
        traces: list[Path] = []
        for index, group in enumerate(batches(files), start=1):
            trace = Path(work) / f"batch-{index}.info"
            print(
                f"Flutter coverage batch {index}: {len(group)} test files",
                flush=True,
            )
            invoke(
                [
                    "timeout", "--signal=TERM", "--kill-after=30s", "15m",
                    "flutter", "test", "--no-pub", "--coverage",
                    f"--coverage-path={trace}",
                    "--exclude-tags", "canonical-golden",
                    "--concurrency=1", "--reporter", "expanded",
                    *(str(path) for path in group),
                ],
                check=True,
            )
            if not trace.is_file() or trace.stat().st_size == 0:
                raise RuntimeError(f"Flutter did not produce coverage for batch {index}")
            traces.append(trace)

        destination.parent.mkdir(parents=True, exist_ok=True)
        merge = ["lcov"]
        for trace in traces:
            merge.extend(("--add-tracefile", str(trace)))
        merge.extend(("--output-file", str(destination)))
        invoke(merge, check=True)
        if not destination.is_file() or destination.stat().st_size == 0:
            raise RuntimeError("LCOV merge did not produce a coverage report")
        print(f"Merged {len(traces)} LCOV reports to {destination}", flush=True)


if __name__ == "__main__":
    run_coverage(test_files(Path("test")), Path("coverage/lcov.info"))
