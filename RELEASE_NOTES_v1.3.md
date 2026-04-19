# AME v1.3.0: Flutter Joins as Third Reference Runtime

Release date: 2026-04-XX

## Summary

v1.3 ships the Flutter port (`ame-flutter` parser + `ame-flutter-ui`
renderer) as a first-class reference runtime. The Flutter packages match
v1.2 behavior across the parser, AST, serializer, renderer, theme, and
form-state layers, and pass all 57 conformance fixtures byte-equal with
the Kotlin canonical and SwiftUI runtimes.

There are no `BREAKING-CONFORMANCE` changes. The 57 conformance
`.expected.json` files are byte-identical to v1.2. Implementations
producing v1.2-compatible JSON continue to be v1.3-compatible without
modification.

## What's New

- **`ame-flutter`** (Dart 3.0+). Parser, AST, serializer, conformance CLI.
  Pure Dart, no Flutter SDK dependency. Distributed as the `ame_flutter`
  pub package. Mirrors `ame-core` (Kotlin) and `AMESwiftUI` (Swift)
  surfaces verbatim.
- **`ame-flutter-ui`** (Flutter 3.19+). Renderer, theme, form state,
  icons, chart painter. Material 3-aware with system-brightness
  adaptation. Distributed as the `ame_flutter_ui` pub package. Mirrors
  `ame-compose` (Kotlin Compose) and `AMESwiftUI` SwiftUI surfaces.
- **Multi-runtime conformance gate.**
  [`conformance/check-parity.sh`](conformance/check-parity.sh) now
  exercises three runtimes (kotlin, swift, flutter) per fixture and
  exits non-zero on any failure. Adding a new runtime is a one-line
  append to the `RUNTIMES` array.
- **CI workflow.**
  [`.github/workflows/audit-regression.yml`](.github/workflows/audit-regression.yml)
  runs Flutter tests on every PR alongside the Kotlin and Swift suites.
  The conformance-parity job sets up the Flutter SDK and runs the
  three-runtime parity check on macOS-14.
- **Six audit suites in `verify-bugs.sh`.** The audit verification
  script now runs four Kotlin/Swift suites plus two new Flutter suites
  (`Flutter parser audit (ame-flutter)`,
  `Flutter UI audit (ame-flutter-ui)`). The script is the single source
  of truth for which audit suites the project considers normative.
- **`ChartMath` extracted as a public testable utility.**
  `ame-flutter-ui` exposes a top-level `@visibleForTesting` `ChartMath`
  class with `computeRange`, `computeBar`, `computeLineY`, and
  `computeSharedStepX` static methods. Mirrors Compose
  `internal object ChartMath` so the audit tests call production math
  directly instead of mirroring formulas.
- **`AmeDecodeResult` sealed class for diagnostic JSON decoding.** The
  Flutter `AmeSerializer.fromJsonOrError` returns a sealed
  `AmeDecodeSuccess(node)` / `AmeDecodeFailure(message, cause)` so hosts
  can distinguish invalid JSON, schema mismatch, missing root, and
  unexpected runtime failures. Symmetric `AmeActionDecodeResult` for
  action payloads. Legacy nullable APIs delegate to the diagnostic
  versions for back-compat. Mirrors v1.2 Bug 15 fix in Kotlin and Swift.

## Audit Alignment

Every Flutter fix has a permanent regression test in the new audit
suites:

- [`ame-flutter/test/audited_bug_regression_test.dart`](ame-flutter/test/audited_bug_regression_test.dart)
  (15 tests covering Bugs 26, 27, 29, 30, 31, 32, 35)
- [`ame-flutter-ui/test/audited_ui_bug_regression_test.dart`](ame-flutter-ui/test/audited_ui_bug_regression_test.dart)
  (7 tests covering Bug 28 sentinel, Bug 33 sentinel, 34, 36, 37, 38)
- [`ame-flutter-ui/test/audited_chart_math_test.dart`](ame-flutter-ui/test/audited_chart_math_test.dart)
  (6 behavioral ChartMath tests)
- [`ame-flutter-ui/test/audited_form_state_test.dart`](ame-flutter-ui/test/audited_form_state_test.dart)
  (3 collision-warning behavioral tests)

Total: 30 new Flutter audit tests across 4 files. See
[`AUDIT_VERDICTS.md`](AUDIT_VERDICTS.md) for the per-bug evidence trail
and the WP#7 completion report for the full pre/post-fix delta.

## Discovered During Fix Work

- **Bug 38 (MEDIUM-architectural)**. WP#7 Phase D discovery.
  `_AmeInputDatePicker` and `_AmeInputTimePicker` previously constructed
  a fresh `TextEditingController` inside `build()` on every rebuild,
  losing cursor/selection state on every `formState.notifyListeners()`,
  causing GC churn, and breaking IME composition on Android. Fixed in
  v1.3 by converting both subwidgets to `StatefulWidget`s with paired
  `State` classes that allocate the controller in `initState`, dispose
  in `dispose`, and synchronize via a `formState` listener plus
  `didUpdateWidget` for the rare host-swap case. Pattern mirrors
  `_AmeInputTextField` which already followed the correct lifecycle.
  No Kotlin or Swift analog (Compose `OutlinedTextField` and SwiftUI
  `TextField` manage their own controller equivalents). No additional
  Flutter-only bugs surfaced beyond Bug 38.

## Still Queued for v1.4

The three v1.2-deferred bugs remain queued for v1.4 with their full
evidence trails in [`AUDIT_VERDICTS.md`](AUDIT_VERDICTS.md):

- **Bug 23 (LOW)**. Pie chart label visual divergence between Compose
  (on-segment text) and SwiftUI (legend chip). Pixel-level parity is
  not part of conformance; both runtimes surface the labels. True 1:1
  parity in SwiftUI requires a custom Canvas-style pie with on-arc
  text, which needs proper design time and a visual-regression harness.
- **Bug 24 (MEDIUM-perf)**. `AmeFormState` whole-map `@Published`
  causes unrelated-field re-renders per keystroke in SwiftUI. The
  Combine-harness test required to lock the invariant ("observers of
  field A do not fire when field B is edited") is WP-sized on its own,
  and per-key publishers via `CurrentValueSubject` or a wrapper type is
  real architectural work.
- **Bug 25 (MEDIUM-arch)**. `AmeThemeConfig` lacks an explicit
  success/warning role family. v1.2 Path D ships
  `isSystemInDarkTheme()`-branched defaults that preserve recognizable
  green/orange in both modes without introducing new public API
  surface. The proper redesign (explicit `successColor`,
  `warningColor`, plus the full Material 3 role family
  `successContainer` / `onSuccess` / `successContrast`; same for
  warning) needs proper design time and is queued for v1.4.

The v1.3 Flutter alignment did not introduce any new deferrals beyond
these three.

## Conformance

All 57 conformance fixtures pass byte-equal across kotlin, swift, AND
flutter. Verify with:

```bash
./conformance/check-parity.sh
```

Strict Conformance implementations now have three reference runtimes to
match against. See
[specification/v1.0/conformance.md](specification/v1.0/conformance.md)
for the full conformance methodology and the
[`AmeNode.dart`](ame-flutter/lib/src/ame_node.dart) /
[`AmeParser.dart`](ame-flutter/lib/src/ame_parser.dart) /
[`AmeSerializer.dart`](ame-flutter/lib/src/ame_serializer.dart)
sources for the canonical Dart shape.

## Quality and Testing

AME maintains a three-tier test discipline:

1. **Unit tests** in each module (parser, serializer, renderer logic).
   Run all six audit suites via [`./verify-bugs.sh`](verify-bugs.sh).
2. **Conformance suite**. 57 canonical `.ame` to JSON cases verified
   via the multi-runtime [`conformance/check-parity.sh`](conformance/check-parity.sh).
3. **Audit regression suite**. One test per known historical defect,
   listed in [`AUDIT_VERDICTS.md`](AUDIT_VERDICTS.md). Now includes
   30 Flutter audit tests across 4 files.

Cross-runtime parity at the JSON serialization level is enforced by
the 57-case conformance suite. Individual runtime implementations may
add internal property-based or fuzz testing as their own quality
concern; this is not an AME standard requirement.

## Compatibility

- **Spec compatibility:** v1.2 documents continue to parse and
  serialize identically under v1.3.
- **JSON compatibility:** v1.2 JSON decodes correctly in v1.3.
- **Runtime requirements:** unchanged for Kotlin/Swift. Flutter
  packages require Dart SDK >= 3.0.0 and Flutter SDK >= 3.19.0 (for
  `ame-flutter-ui` only; `ame-flutter` is pure Dart).
- **Capability declaration:** hosts may declare
  `AME_SUPPORT: v1.3` per
  [integration.md](specification/v1.0/integration.md). Hosts still
  declaring `AME_SUPPORT: v1.2` continue to work; v1.3 adds no new
  primitives or actions, only a new reference runtime.

## Repository Changes

- `ame-flutter/` and `ame-flutter-ui/` directories now contain
  reference Flutter implementations (previously parallel work, now
  committed alongside the rest of v1.3).
- `flutter-check-parity.sh` deleted (replaced by the Flutter row in
  `conformance/check-parity.sh`'s `RUNTIMES` array).
- [`verify-bugs.sh`](verify-bugs.sh) now runs 6 audit suites
  (4 Kotlin/Swift + 2 Flutter) and surfaces a clear warning when
  `flutter` is not on PATH.
- [`.github/workflows/audit-regression.yml`](.github/workflows/audit-regression.yml)
  has a new `flutter-tests` job and the `conformance-parity` job sets
  up the Flutter SDK before running the parity script.
- [`README.md`](README.md), [`CONTRIBUTING.md`](CONTRIBUTING.md),
  [`RELEASE.md`](RELEASE.md),
  [`specification/v1.0/README.md`](specification/v1.0/README.md), and
  [`specification/v1.0/conformance.md`](specification/v1.0/conformance.md)
  updated to reflect three reference runtimes.
- New 4-file audit test suite under `ame-flutter/test/` and
  `ame-flutter-ui/test/` (30 tests total).


