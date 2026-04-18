#!/usr/bin/env bash
# verify-bugs.sh — run every audit regression test suite and produce a results summary.
#
# This script does NOT exit on first failure. Each suite is run independently
# so the verdict report (AUDIT_VERDICTS.md) is comprehensive.
#
# Usage:
#   ./verify-bugs.sh
#
# Environment:
#   JAVA_HOME      — required for Gradle. If unset, script tries to use Android
#                    Studio's bundled JBR.
#   GRADLE_USER_HOME — optional override for Gradle's cache directory.
#
# Exit codes:
#   0 — all audit regression tests are in their expected state (REAL bugs fail,
#       NOT REAL bugs pass). After Phase 2 fixes, all tests must pass for exit 0.
#   1 — at least one suite produced unexpected results.
#
# See specification/v1.0/regression-protocol.md for the discipline rules.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_ROOT"

# Detect JAVA_HOME if not set.
if [[ -z "${JAVA_HOME:-}" ]]; then
    if [[ -d "/Applications/Android Studio Preview.app/Contents/jbr/Contents/Home" ]]; then
        export JAVA_HOME="/Applications/Android Studio Preview.app/Contents/jbr/Contents/Home"
    elif [[ -d "/Applications/Android Studio.app/Contents/jbr/Contents/Home" ]]; then
        export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
    fi
fi
if [[ -n "${JAVA_HOME:-}" ]]; then
    export PATH="$JAVA_HOME/bin:$PATH"
fi

results=()
overall_status=0

run_suite() {
    local label="$1"
    shift
    echo
    echo "================================================================"
    echo "  $label"
    echo "================================================================"
    if "$@"; then
        results+=("$label : PASS")
    else
        results+=("$label : FAIL")
        overall_status=1
    fi
}

run_suite "Kotlin parser audit (ame-core)" \
    ./gradlew :ame-core:test --tests AuditedBugRegressionTest --no-daemon

run_suite "Kotlin Compose audit (ame-compose)" \
    ./gradlew :ame-compose:testDebugUnitTest --no-daemon

run_suite "Swift parser audit (ame-swiftui)" \
    bash -c 'cd ame-swiftui && swift test --filter AuditedBugRegressionTests'

run_suite "SwiftUI render audit (ame-swiftui)" \
    bash -c 'cd ame-swiftui && swift test --filter AuditedSwiftUIBugTests'

echo
echo "================================================================"
echo "  Audit Regression Verification Summary"
echo "================================================================"
for r in "${results[@]}"; do
    echo "  $r"
done
echo
if [[ $overall_status -eq 0 ]]; then
    echo "All suites in expected state. See AUDIT_VERDICTS.md for per-bug verdicts."
else
    echo "One or more suites failed. Review test output above and AUDIT_VERDICTS.md."
fi
exit $overall_status
