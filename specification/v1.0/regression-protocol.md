# Defect and Regression Protocol

Rules for finding, verifying, and fixing defects in the AME project.

## Verification

Every defect claim MUST have an executable failing test before any fix
work is scoped. A claim that cannot be reproduced with a failing test
is classified as NOT REAL and recorded with a permanent guard test.

Tests live in the per-module `Audited*` test classes:

- `AuditedBugRegressionTest.kt` (Kotlin)
- `AuditedBugRegressionTests.swift` / `AuditedSwiftUIBugTests.swift` (Swift)
- `audited_bug_regression_test.dart` and related files (Flutter)

Each test carries the bug number, spec section reference, and expected
outcome.

## Conformance Impact

Every verified defect is classified by its effect on serializer output:

- **none.** Parser and serializer JSON unchanged. Renderer-only bugs,
  theme bugs, form state bugs.
- **regeneration required.** Serializer JSON changes. One or more
  `conformance/*.expected.json` files must be regenerated from the
  Kotlin parser before the PR merges.
- **breaking.** Regeneration changes existing `.expected.json` files
  in ways that third-party implementations must also update for. PR
  MUST carry the `BREAKING-CONFORMANCE` label and list every affected
  case.

## Regeneration Procedure

1. Apply the Kotlin fix. Verify the audit regression test passes.
2. Run `conformance/regenerate-expected.sh`.
3. Inspect every changed file in `git diff conformance/`.
4. Confirm the new output matches corrected behavior.
5. If any existing `.expected.json` changed, apply
   `BREAKING-CONFORMANCE` and document each change in the PR.
6. Other runtimes re-test against the new goldens in a follow-up PR.

## Cross-Platform Order

Kotlin owns the conformance goldens. Fix Kotlin first, regenerate,
then mirror to Swift and Flutter. Both platforms' audit regression
tests must pass before either fix merges.

## Lock-in

A fix is not complete until:

1. The verifying test passes.
2. The test is permanent (not deleted after the fix).
3. Any required `.expected.json` regeneration is done.

Audit regression tests run on every PR. A previously passing test that
fails is a merge blocker.
