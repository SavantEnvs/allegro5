#!/usr/bin/env bash
#
# Runs upstream's test driver (tests/test_driver.c, built by mayhem/build.sh) over its .ini test
# lists. Each test renders software bitmaps/primitives or loads image fixtures and compares the
# result with a reference, so the pass count asserts real output.
set -uo pipefail
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH
: "${SRC:=/mayhem}"
cd "$SRC"

emit_ctrf() {
  local tool="$1" passed="$2" failed="$3" skipped="${4:-0}" pending="${5:-0}" other="${6:-0}"
  local tests=$(( passed + failed + skipped + pending + other ))
  cat > "${CTRF_REPORT:-$SRC/ctrf-report.json}" <<JSON
{
  "results": {
    "tool": { "name": "$tool" },
    "summary": {
      "tests": $tests,
      "passed": $passed,
      "failed": $failed,
      "pending": $pending,
      "skipped": $skipped,
      "other": $other
    }
  }
}
JSON
  printf 'CTRF {"results":{"tool":{"name":"%s"},"summary":{"tests":%d,"passed":%d,"failed":%d,"pending":%d,"skipped":%d,"other":%d}}}\n' \
    "$tool" "$tests" "$passed" "$failed" "$pending" "$skipped" "$other"
  [ "$failed" -eq 0 ]
}

DRIVER="$SRC/build/test/tests/test_driver"
if [ ! -x "$DRIVER" ]; then
  echo "test.sh: $DRIVER missing; mayhem/build.sh should have built it" >&2
  emit_ctrf "allegro-test-driver" 0 1 0
  exit 1
fi

# The driver loads fixtures from ../examples/data and writes tmp.* files into its cwd, so run it
# from a scratch directory that sits next to a link to the examples.
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir "$WORK/tests"
ln -s "$SRC/examples" "$WORK/examples"
cd "$WORK/tests"

OUT="$WORK/out.txt"
timeout 900 "$DRIVER" -n "$SRC"/tests/test_*.ini > "$OUT" 2>&1
RC=$?
tail -n 12 "$OUT"

# Parse the driver's own summary; a program that exits early prints none of it.
total=$(sed -n 's/^total tests: *//p' "$OUT" | tail -n1)
passed=$(sed -n 's/^passed tests: *//p' "$OUT" | tail -n1)
failed=$(sed -n 's/^failed tests: *//p' "$OUT" | tail -n1)
skipped=$(sed -n 's/^skipped tests: *//p' "$OUT" | tail -n1)

if [ -z "$total" ] || [ -z "$passed" ] || [ -z "$failed" ]; then
  echo "test.sh: no test summary in the driver output (exit code $RC)" >&2
  emit_ctrf "allegro-test-driver" 0 1 0
  exit 1
fi

# A driver that skipped or lost tests must not pass: the suite has hundreds of assertions.
if [ "$passed" -lt 300 ]; then
  echo "test.sh: only $passed tests passed (expected at least 300)" >&2
  failed=$(( failed + 1 ))
fi
[ "$RC" -eq 0 ] || failed=$(( failed > 0 ? failed : 1 ))

emit_ctrf "allegro-test-driver" "$passed" "$failed" "${skipped:-0}"
