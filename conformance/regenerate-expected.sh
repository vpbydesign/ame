#!/usr/bin/env bash
# regenerate-expected.sh — regenerate every conformance/*.expected.json
# from the current state of the reference Kotlin parser.
#
# This script is the canonical mechanism described in
# specification/v1.0/regression-protocol.md §4. It MUST be re-run any
# time a fix changes parser/serializer output, and the resulting diff
# MUST be reviewed before merge.
#
# Usage:
#   ./conformance/regenerate-expected.sh
#
# Environment:
#   JAVA_HOME — required for Gradle. If unset, script tries Android Studio's bundled JBR.
#
# Behavior:
#   - Idempotent if no parser changes occurred (git diff is empty).
#   - Writes to conformance/*.expected.json in place.
#   - Does NOT commit. Author reviews `git diff conformance/` before commit.
#
# Exit codes:
#   0 — regeneration succeeded.
#   1 — Kotlin build failed or one or more cases produced no output.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
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

echo "Building reference Kotlin CLI..."
./gradlew :ame-core:installDist --no-daemon --quiet
if [[ $? -ne 0 ]]; then
    echo "ERROR: Gradle build failed. Cannot regenerate."
    exit 1
fi

CLI="./ame-core/build/install/ame-core/bin/ame-core"
if [[ ! -x "$CLI" ]]; then
    echo "ERROR: Reference CLI not found at $CLI"
    exit 1
fi

count=0
failed=0
changed=0
unchanged=0
for ame_file in conformance/*.ame; do
    expected="${ame_file%.ame}.expected.json"
    new_output=$("$CLI" "$ame_file" 2>/dev/null)
    if [[ -z "$new_output" ]]; then
        echo "  FAIL: $ame_file produced no output"
        failed=$((failed + 1))
        continue
    fi

    if [[ -f "$expected" ]]; then
        old_output=$(cat "$expected")
        if [[ "$old_output" != "$new_output" ]]; then
            echo "  CHANGED: $expected"
            changed=$((changed + 1))
        else
            unchanged=$((unchanged + 1))
        fi
    else
        echo "  NEW: $expected"
        changed=$((changed + 1))
    fi

    echo "$new_output" > "$expected"
    count=$((count + 1))
done

echo
echo "================================================================"
echo "  Regeneration complete"
echo "================================================================"
echo "  Total cases: $count"
echo "  Changed:     $changed"
echo "  Unchanged:   $unchanged"
echo "  Failed:      $failed"
echo
if [[ $failed -gt 0 ]]; then
    echo "FAIL: $failed cases produced no output. Investigate before commit."
    exit 1
fi
if [[ $changed -gt 0 ]]; then
    echo "Review with: git diff conformance/"
    echo
    echo "If any existing .expected.json changed, the PR carrying these"
    echo "regenerated files MUST include the BREAKING-CONFORMANCE label"
    echo "and document each change per regression-protocol.md §3-4."
fi
