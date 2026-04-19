#!/usr/bin/env bash
# AME conformance parity check (multi-runtime).
#
# Adding a new runtime port: append a "name|command-template" entry to the
# RUNTIMES array below. The token {{ame_file}} is replaced per-fixture with
# the path to the .ame source. The runtime's CLI MUST print the canonical
# JSON serialization of the parsed tree to stdout (see conformance.md §5).
#
# Each runtime is invoked independently per fixture, so a failure in one
# runtime does NOT prevent the others from running for that case (Bug 16
# fix). The script prints a per-fixture matrix of PASS/FAIL per runtime
# and exits non-zero if ANY runtime has ANY failure.
#
# Note: `set -e` is intentionally NOT enabled. Per-runtime invocations
# MAY fail (the script captures the failure and reports it); the loop
# must continue regardless.
#
# Compatibility: bash 3.2+ (macOS default ships bash 3.2, which lacks
# associative arrays; we use parallel indexed arrays instead).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"
# Use a relative conformance dir from REPO_ROOT so per-fixture paths stay
# relative ("conformance/01-basic-col.ame"). This avoids two pitfalls when
# expanding the runtime command templates: (1) absolute paths containing
# spaces (e.g., "Dev Work/") would break re-tokenization, and (2) prepending
# "../" to an absolute path yields nonsense like "..//Users/...".
CONFORMANCE_DIR="conformance"

# Multi-runtime configuration. Declaration order is preserved in the matrix
# output. Kotlin first per regression-protocol.md §7 reference-implementation
# rule; additional ports append below.
RUNTIMES=(
    "kotlin|./ame-core/build/install/ame-core/bin/ame-core {{ame_file}}"
    "swift|(cd ame-swiftui && swift run -q ame-conformance-swift ../{{ame_file}})"
    "flutter|(cd ame-flutter && dart run bin/ame_conformance_cli.dart ../{{ame_file}})"
    # Future runtime ports register here, e.g.:
    # "react-native|node ./ame-react-native/dist/cli.js {{ame_file}}"
)

NUM_RUNTIMES=${#RUNTIMES[@]}

echo "=== AME Conformance Parity Check ==="
echo ""

# Header row
printf "%-40s" "Case"
for entry in "${RUNTIMES[@]}"; do
    printf " %-10s" "${entry%%|*}"
done
printf "\n"

printf "%-40s" "----"
for ((i = 0; i < NUM_RUNTIMES; i++)); do
    printf " %-10s" "------"
done
printf "\n"

# Per-runtime failure counters and error trail (parallel indexed arrays).
RUNTIME_FAILURES=()
RUNTIME_ERRORS=()
for ((i = 0; i < NUM_RUNTIMES; i++)); do
    RUNTIME_FAILURES[$i]=0
    RUNTIME_ERRORS[$i]=""
done

total=0

for ame_file in "$CONFORMANCE_DIR"/*.ame; do
    base="$(basename "$ame_file" .ame)"
    expected="$CONFORMANCE_DIR/${base}.expected.json"
    [[ -f "$expected" ]] || continue
    total=$((total + 1))

    printf "%-40s" "$base"

    for ((i = 0; i < NUM_RUNTIMES; i++)); do
        entry="${RUNTIMES[$i]}"
        cmd_template="${entry#*|}"
        cmd="${cmd_template//\{\{ame_file\}\}/$ame_file}"

        # Invoke the runtime; capture stdout, suppress stderr.
        # `|| true` ensures a non-zero exit doesn't trip the trap.
        out=$(eval "$cmd" 2>/dev/null) || true

        status="FAIL"
        reason=""
        if [[ -z "$out" ]]; then
            reason="no output (parse error or missing CLI)"
        else
            # Normalize escaped forward slashes: kotlinx.serialization emits \/
            # while Swift JSONEncoder (macOS 13+) does not. Both are valid JSON
            # per RFC 8259. Unescape to canonical form before comparing.
            out_norm=$(printf "%s" "$out" | sed 's|\\/|/|g')
            expected_norm=$(sed 's|\\/|/|g' "$expected")
            if [[ "$out_norm" == "$expected_norm" ]]; then
                status="PASS"
            else
                reason="output differs from expected"
            fi
        fi

        if [[ "$status" == "FAIL" ]]; then
            RUNTIME_FAILURES[$i]=$((${RUNTIME_FAILURES[$i]} + 1))
            RUNTIME_ERRORS[$i]="${RUNTIME_ERRORS[$i]}\n  $base: $reason"
        fi

        printf " %-10s" "$status"
    done
    printf "\n"
done

echo
echo "=== Results ==="
echo "Total cases: $total"
overall_failed=0
for ((i = 0; i < NUM_RUNTIMES; i++)); do
    rt="${RUNTIMES[$i]%%|*}"
    n=${RUNTIME_FAILURES[$i]}
    echo "  ${rt}: ${n} failure(s)"
    overall_failed=$((overall_failed + n))
done

if [[ $overall_failed -gt 0 ]]; then
    echo
    echo "=== Failures ==="
    for ((i = 0; i < NUM_RUNTIMES; i++)); do
        rt="${RUNTIMES[$i]%%|*}"
        if [[ ${RUNTIME_FAILURES[$i]} -gt 0 ]]; then
            echo "${rt}:"
            echo -e "${RUNTIME_ERRORS[$i]}"
        fi
    done
    exit 1
fi

echo
echo "All conformance checks passed."
exit 0
