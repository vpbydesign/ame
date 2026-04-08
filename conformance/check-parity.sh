#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFORMANCE_DIR="$SCRIPT_DIR"

PASS=0
FAIL=0
ERRORS=""

echo "=== AME Conformance Parity Check ==="
echo ""

for ame_file in "$CONFORMANCE_DIR"/*.ame; do
    base="$(basename "$ame_file" .ame)"
    expected="$CONFORMANCE_DIR/${base}.expected.json"

    if [ ! -f "$expected" ]; then
        echo "SKIP $base — no .expected.json"
        continue
    fi

    echo -n "  $base ... "

    # Run Kotlin parser
    kotlin_out=$(cd "$REPO_ROOT" && ./ame-core/build/install/ame-core/bin/ame-core "$ame_file" 2>/dev/null) || {
        echo "FAIL (Kotlin parse error)"
        FAIL=$((FAIL + 1))
        ERRORS="$ERRORS\n  $base: Kotlin parse error"
        continue
    }

    # Run Swift parser
    swift_out=$(cd "$REPO_ROOT/ame-swiftui" && swift run -q ame-conformance-swift "$ame_file" 2>/dev/null) || {
        echo "FAIL (Swift parse error)"
        FAIL=$((FAIL + 1))
        ERRORS="$ERRORS\n  $base: Swift parse error"
        continue
    }

    # Normalize escaped forward slashes: kotlinx.serialization emits \/
    # while Swift JSONEncoder (macOS 13+) does not. Both are valid JSON
    # per RFC 8259. Unescape to canonical form before comparing.
    kotlin_cmp=$(echo "$kotlin_out" | sed 's|\\/|/|g')
    swift_cmp=$(echo "$swift_out" | sed 's|\\/|/|g')
    expected_cmp=$(sed 's|\\/|/|g' "$expected")

    # Compare Kotlin vs expected
    if ! diff <(echo "$kotlin_cmp") <(echo "$expected_cmp") > /dev/null 2>&1; then
        echo "FAIL (Kotlin output != expected)"
        FAIL=$((FAIL + 1))
        ERRORS="$ERRORS\n  $base: Kotlin output differs from expected"
        diff <(echo "$kotlin_cmp") <(echo "$expected_cmp") | head -20
        continue
    fi

    # Compare Swift vs expected
    if ! diff <(echo "$swift_cmp") <(echo "$expected_cmp") > /dev/null 2>&1; then
        echo "FAIL (Swift output != expected)"
        FAIL=$((FAIL + 1))
        ERRORS="$ERRORS\n  $base: Swift output differs from expected"
        diff <(echo "$swift_cmp") <(echo "$expected_cmp") | head -20
        continue
    fi

    echo "PASS"
    PASS=$((PASS + 1))
done

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="

if [ $FAIL -gt 0 ]; then
    echo -e "\nFailures:$ERRORS"
    exit 1
fi

echo "All conformance checks passed."
exit 0
