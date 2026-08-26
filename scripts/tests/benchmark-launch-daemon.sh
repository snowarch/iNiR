#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"

ITERATIONS="${1:-100}"
UNIT="inir-bench-test"

cleanup() {
    systemctl --user stop "${UNIT}.service" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

# Ensure clean slate
cleanup

# Start active dummy service
if ! systemd-run --user --quiet --unit="$UNIT" --description="Benchmark Unit" sleep 3600; then
    echo "Failed to launch benchmark test unit" >&2
    exit 1
fi

# Wait until unit is confirmed active
for _ in $(seq 1 20); do
    if systemctl --user is-active --quiet "$UNIT" 2>/dev/null; then
        break
    fi
    sleep 0.1
done

if ! systemctl --user is-active --quiet "$UNIT" 2>/dev/null; then
    echo "Benchmark unit failed to transition to active state" >&2
    exit 1
fi

python3 - "$REPO_ROOT" "$UNIT" "$ITERATIONS" <<'PY'
import importlib.util
import sys
import time
import statistics
import subprocess
from pathlib import Path

repo_root = Path(sys.argv[1])
unit = sys.argv[2]
iterations = int(sys.argv[3])

extractor_path = repo_root / "scripts" / "lib" / "extract-launch-daemon.py"
spec = importlib.util.spec_from_file_location("extract_launch_daemon", extractor_path)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

qml_file = repo_root / "modules/common/functions/ShellExec.qml"
try:
    script = module.extract_launch_daemon_script(qml_file)
except (OSError, ValueError) as exc:
    print(f"Error: {exc}", file=sys.stderr)
    sys.exit(1)

print(f"Running {iterations} iterations on active unit '{unit}'...")
latencies = []
for i in range(iterations):
    t0 = time.perf_counter()
    res = subprocess.run(
        ["/usr/bin/bash", "-c", script, "inir-daemon", "/usr/bin/systemd-run", "Benchmark Unit", unit, "", "reuse", "true"],
        capture_output=True
    )
    t1 = time.perf_counter()
    if res.returncode != 0:
        print(f"Iteration {i+1} failed with code {res.returncode}: {res.stderr.decode()}", file=sys.stderr)
        sys.exit(res.returncode)
    latencies.append((t1 - t0) * 1000.0)

latencies.sort()
mean_val = statistics.mean(latencies)
stdev_val = statistics.stdev(latencies) if len(latencies) > 1 else 0.0
p95_val = latencies[int(len(latencies) * 0.95)]
p50_val = statistics.median(latencies)
min_val = min(latencies)
max_val = max(latencies)
total_val = sum(latencies)

print("\n--- Latency Benchmark Results ---")
print(f"Iterations: {len(latencies)}")
print(f"Total time: {total_val:.2f} ms")
print(f"Mean:       {mean_val:.2f} ms")
print(f"Median:     {p50_val:.2f} ms")
print(f"Min:        {min_val:.2f} ms")
print(f"Max:        {max_val:.2f} ms")
print(f"p95:        {p95_val:.2f} ms")
print(f"StdDev:     {stdev_val:.2f} ms")
print("---------------------------------")
PY
