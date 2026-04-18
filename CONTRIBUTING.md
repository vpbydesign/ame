# Contributing to AME

AME is an open-source specification for LLM-generated native mobile UI.
Contributions are welcome: bug fixes, new renderers, benchmark data, and
spec improvements.

## How to Propose a Spec Change

1. Open an issue with the prefix **"RFC:"** in the title.
2. Include: what you want to change, why, one or more examples showing
   the current and proposed behavior.
3. Spec changes require discussion before implementation. Do not open a
   PR that modifies `specification/` without a corresponding RFC issue.

## How to Add a New Primitive

New primitives are significant spec changes. The process:

1. Open an RFC issue describing the primitive: name, arguments, rendering
   behavior, accessibility, and at least two realistic usage examples.
2. After approval, implement in this order:
   - `specification/v1.0/primitives.md` — add the primitive definition
   - `ame-core/.../AmeNode.kt` — add the sealed subtype
   - `ame-core/.../AmeParser.kt` — add the builder function
   - `ame-core/.../AmeParserTest.kt` — add parse tests
   - `ame-compose/.../AmeRenderer.kt` — add Compose rendering
   - `ame-compose/.../AuditedBugRegressionTest.kt` — add regression coverage if any prior bug applies
   - `ame-swiftui/.../AmeNode.swift` — add the enum case
   - `ame-swiftui/.../AmeParser.swift` — add the builder function
   - `ame-swiftui/.../AmeParserTests.swift` — add parse tests
   - `ame-swiftui/.../AmeRenderer.swift` — add SwiftUI rendering
   - `conformance/` — add at least one conformance test input + expected output
3. Run `./conformance/check-parity.sh` and verify zero diffs.
4. Run `./verify-bugs.sh` and verify all audit regression tests still pass.
5. Open a PR referencing the RFC issue.

## How to Contribute a Renderer for a New Platform

AME is platform-neutral. Renderers for Flutter, React Native, Kotlin/XML,
or any other framework are welcome as separate repositories or as
subdirectories in this repo.

A conformant renderer must:

1. Handle all 24 `AmeNode` types (21 visual + Ref + Each + TimelineItem)
2. Pass the conformance test suite (parse + render equivalence)
3. Follow the accessibility guidance in `specification/v1.0/primitives.md`
4. Document the implementation's claimed conformance level per
   [`specification/v1.0/conformance.md`](specification/v1.0/conformance.md)

## Reporting a Bug

When reporting a bug, include:

- **Input** — the minimal `.ame` source (or AmeNode tree) that triggers the bug
- **Expected** — what the parser/renderer SHOULD produce, with reference to
  the relevant section of `specification/v1.0/`
- **Actual** — what it actually produces (JSON output, screenshot, error
  message, or stack trace)
- **Platform** — which runtime (`ame-core`, `ame-compose`, `ame-swiftui`,
  or a third-party implementation) and version
- **Severity hypothesis** — your initial guess (CRITICAL / HIGH / MEDIUM / LOW)

Do NOT include speculation about the root cause unless you have read the
relevant source code. Speculative diagnostics waste reviewer time and risk
chasing phantom bugs (see the WP#6 phantom-bug incident documented in
[`AUDIT_VERDICTS.md`](AUDIT_VERDICTS.md) Bug 19).

## Verifying a Claimed Defect

The AME project follows a strict discipline rule: **no defect is acted on
without a failing test**. This applies to bugs you report, bugs you read
about in audits, and bugs surfaced by code review.

The full procedure is in
[`specification/v1.0/regression-protocol.md`](specification/v1.0/regression-protocol.md).
Summary:

1. Add a test to the appropriate `Audited*` regression file:
   - `ame-core/src/test/kotlin/com/agenticmobile/ame/AuditedBugRegressionTest.kt`
   - `ame-compose/src/test/kotlin/com/agenticmobile/ame/compose/AuditedBugRegressionTest.kt`
   - `ame-swiftui/Tests/AMESwiftUITests/AuditedBugRegressionTests.swift`
   - `ame-swiftui/Tests/AMESwiftUITests/AuditedSwiftUIBugTests.swift`
2. Use the standard docstring template (see "Adding a Regression Test" below).
3. Run the suite. The test MUST fail today if the bug is REAL, or pass if
   the claim is NOT REAL.
4. Add a row to [`AUDIT_VERDICTS.md`](AUDIT_VERDICTS.md) with status
   `REAL` or `NOT REAL` and a citation to the test method.
5. Only after the verdict is recorded do you scope the fix.

## Adding a Regression Test

Standard docstring template (Kotlin):

```kotlin
/**
 * Audit Bug #N: <one-line description>.
 *
 * Spec section: specification/v1.0/<file>.md (<section>)
 * Audit reference: AUDIT_VERDICTS.md#bug-N
 * Pre-fix expected: <FAIL or PASS> — <why>
 * Post-fix expected: <FAIL or PASS> — <correct behavior>
 */
@Test
fun testDescriptiveBehaviorThatBugViolated() { ... }
```

Standard docstring template (Swift):

```swift
/// Audit Bug #N: <one-line description>.
///
/// Spec section: specification/v1.0/<file>.md (<section>)
/// Audit reference: AUDIT_VERDICTS.md#bug-N
/// Pre-fix expected: <FAIL or PASS> — <why>
/// Post-fix expected: <FAIL or PASS> — <correct behavior>
func testDescriptiveBehaviorThatBugViolated() { ... }
```

Naming convention: prefer `testDescriptiveBehaviorThatBugViolated`
(positive assertion of correct behavior) over `testBugNDescription`
(negative; loses meaning after the fix). The test name should still make
sense after the bug is fixed.

## Running the Full Test Suite

Before submitting a PR:

```bash
# Standard tests (existing)
./gradlew :ame-core:test
./gradlew :ame-compose:testDebugUnitTest
cd ame-swiftui && swift test

# Conformance parity check
./conformance/check-parity.sh

# Audit regression suite (Strict Conformance)
./verify-bugs.sh
```

If any audit regression test that was previously passing now fails, your
PR introduced a regression. Either fix the regression or escalate via PR
discussion.

If your fix changes parser/serializer output, you MUST regenerate the
conformance goldens:

```bash
./conformance/regenerate-expected.sh
git diff conformance/
```

If the diff modifies any existing `.expected.json` file, your PR MUST
carry the `BREAKING-CONFORMANCE` label and document each change per
[`specification/v1.0/regression-protocol.md`](specification/v1.0/regression-protocol.md) §4.

## Code Style

- Kotlin: follow the existing code style in `ame-core/`
- Swift: follow the existing code style in `ame-swiftui/`
- Spec documents: use RFC 2119 normative language (MUST/SHOULD/MAY)
- Test files: docstrings on every audit regression test per the template above

## License

By contributing, you agree that your contributions will be licensed under
the Apache 2.0 license.
