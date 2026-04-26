# AME v1.2.0: Quality Release with Conformance Methodology

Release date: 2026-04-18

## Summary

v1.2 is a quality-focused release. We audited v1.1, verified every claim
with executable tests, fixed 17 real defects across the parser, renderer,
theme, and serializer layers in both Kotlin Compose and SwiftUI runtimes,
and formalized the conformance methodology and defect lifecycle that
prevents this class of issue from recurring.

There are no `BREAKING-CONFORMANCE` changes. All 57 conformance
`.expected.json` files are byte-identical to v1.1. Implementations
producing v1.1-compatible JSON continue to be v1.2-compatible without
modification.

## What's Fixed

17 audit bugs resolved across WP#1-6, plus 1 cross-runtime serialization
bug (Bug 21) that was discovered during the fix work and fixed inside the
same release. Every entry below has a permanent regression test in the
audit suite (`./verify-bugs.sh`) and a row in
[AUDIT_VERDICTS.md](AUDIT_VERDICTS.md) with full evidence trail.

### Critical

- **Bug 3**. Parser corruption when string literals contain `)` or `]`.
  Strings like `txt("Storage: 500 GB)", body)` no longer drop the trailing
  segment. WP#1.

### High

- **Bug 1**. SwiftUI renderer now displays `chart()` labels (previously
  wildcarded in the renderer's chart case). WP#4.
- **Bug 2**. SwiftUI carousel now applies the `peek` parameter as
  trailing padding, matching Compose. WP#4.
- **Bug 4**. Compose chart math correctly handles all-negative data,
  mixed-sign data with cross-zero baseline, single-point line series
  (now show "No chart data"), and multi-series x-axis alignment (now
  share a stride based on the longest series). All four sub-bugs covered
  by direct calls to a new `internal object ChartMath`. WP#5.
- **Bug 5**. SwiftUI `AmeFormState` no longer mutates `@Published`
  state during view body composition (no more "Modifying state during
  view update" warning). Defaults live in non-published companion maps
  and `collectValues()` falls through them. WP#4.
- **Bug 6**. `callout(... color=...)` parameter is now honored by the
  AST. New optional `color: SemanticColor?` field defaults to null and is
  omitted from JSON when unset (additive, non-breaking). WP#2.
- **Bug 7**. `chart(line, series=[$a, $b])` array-of-paths syntax now
  resolves end-to-end. New `seriesPaths: List<String>?` field stores the
  unresolved paths; `resolveTree` produces the resolved `series` from the
  per-path data. WP#2.
- **Bug 8**. Streaming `parseLine()` + `---` + JSON data section now
  works in both runtimes. Completes the v1.1 streaming.md promise. WP#3.
- **Bug 11**. Ref cycle chains no longer stack-overflow the parser.
  Both direct cycles and diamond patterns are covered by regression
  tests. WP#3.
- **Bug 21** (discovered during WP#2 Bug 7 work). Cross-runtime Double
  serialization parity. Swift's Foundation `JSONEncoder` previously
  stripped trailing `.0` from whole-number Doubles
  (`Double(1.0) -> "1"`); Kotlin's kotlinx.serialization writes `"1.0"`.
  Wrapped affected fields (`Chart.values`, `Chart.series`,
  `Progress.value`) in `PreservedDouble` / `PreservedFloat` types that
  round-trip canonical numeric strings through a sentinel-bracketed
  encoding pass. WP#2.

### Medium

- **Bug 9**. Spec retracts the over-aggressive enum-keyword reservation
  rule. Common identifiers like `title` and `label` are now permitted as
  user-defined names. The parser already disambiguated by argument
  position; the rule was aspirational and was rejecting common LLM-emitted
  identifiers. WP#3 chose the spec-retraction path with reviewer
  sign-off; the test was inverted to
  `testEnumValueTokensAreNotReserved`. WP#3.
- **Bug 10**. Spec table for `chart(... color=...)` aligned to the
  AST: default is `null` (renderer falls back to platform primary), not
  `primary`. Documentation drift, no JSON change. WP#2.
- **Bug 12**. Input/toggle id collisions surface via a new
  `state.warnings` diagnostic surface in both runtimes. The merge order
  (toggle wins) is preserved per WP#4 Bug 5 contract; the principle-correct
  minimal fix is visibility, not behavior change. WP#5.
- **Bug 13**. Hyphenated input IDs in `${input.field-name}` now
  substitute correctly. Regex broadened from `\w+` to `[a-zA-Z0-9_-]+`
  in both runtimes. New Q4 guard test in both runtimes asserts that
  `${input.user.name}` (with literal `.`) still does NOT match,
  defending against future over-permissive expansion. WP#5.
- **Bug 14**. Theme tokens adapt to dark mode in both runtimes via
  Path D: Compose branches `defaultBadgeColor`, `defaultCalloutStyle`
  (WARNING/SUCCESS/TIP), and `defaultSemanticColor` on
  `isSystemInDarkTheme()` using documented Material 3 700 (light) and
  300 (dark) tints; SwiftUI replaces bare `.green/.orange/.red/.blue`
  literals with adaptive `Color(.systemGreen/.systemOrange/.systemRed/
  .systemBlue)` per Apple HIG. Zero new `AmeThemeConfig` API surface in
  v1.2. The proper role-family extension (Bug 25) is queued for v1.3
  with full design time. WP#5.
- **Bug 15**. Diagnostic serializer API: `fromJsonOrError` returning
  `Result<AmeNode>` (Kotlin) and `Result<AmeNode, Error>` (Swift) so
  hosts can distinguish invalid JSON, schema mismatch, and other failure
  modes. Symmetric `actionFromJsonOrError` for action payloads. Legacy
  nullable APIs unchanged for backward compatibility. WP#5.
- **Bug 16**. `conformance/check-parity.sh` rewritten around a
  declarative `RUNTIMES` configuration array. Each runtime is invoked
  independently per fixture (Bug 16 fix is implicit in the rewrite). The
  per-runtime PASS/FAIL matrix and final summary make Swift-only
  regressions visible even when Kotlin also fails. The same refactor
  delivers the multi-runtime extensibility groundwork (see "What's New"
  below). WP#6.
- **Bug 18**. Accordion `expanded` parameter is now reactive in both
  runtimes. Compose `AmeAccordion` adds `LaunchedEffect(node.expanded)`
  that syncs the local snapshot to external prop updates; SwiftUI
  `AmeAccordionView` adds a `let nodeExpanded` field tracked by
  `.onChange(of: nodeExpanded)`. Local user toggles still flip
  immediately and persist until the next external change. The pattern
  mirrors WP#4 Bug 5's separate-state architecture. The spec's
  accordion `expanded` row in `primitives.md` documents the contract.
  WP#5.

## What's New

- **AME Strict Conformance level**. Third compliance tier requiring the
  audit regression suite. See
  [specification/v1.0/conformance.md](specification/v1.0/conformance.md)
  §1.3.
- **Audit regression suite**. One test per known historical defect, runs
  in CI on every PR via `./verify-bugs.sh` (53 tests across both
  runtimes). Implementations claiming AME Strict Conformance must
  include analogous tests in their own runtime.
- **Multi-runtime conformance tooling**.
  [`conformance/check-parity.sh`](conformance/check-parity.sh) now
  supports N runtimes via a configuration array. Adding a new runtime
  port is a one-line append; the script invokes each runtime
  independently per fixture and reports a per-runtime PASS/FAIL matrix.
- **`fromJsonOrError` diagnostic serializer API**. Both runtimes now
  expose a `Result`-returning entry point on `AmeSerializer` that
  surfaces the failure cause instead of swallowing it into `null`.
  Existing nullable APIs preserved.
- **Optional `Callout.color` field**. Completes v1.1's primitives.md
  promise. Additive; defaults to null; omitted from JSON when unset.
- **`Chart.series=[$a, $b]` array-of-paths resolution**. Completes
  v1.1's primitives.md promise.
- **Streaming `parseLine() + --- + JSON` data section**. Completes
  v1.1's streaming.md promise. Both runtimes implement the
  state-machine flow.
- **Two new conformance fixtures**: `56-callout-with-color` and
  `57-chart-series-array-of-paths` exercise the Bug 6 and Bug 7 fixes.

## New Spec Documents (Normative)

- [specification/v1.0/conformance.md](specification/v1.0/conformance.md):
  conformance levels (Core, Streaming, Strict), test catalog,
  self-verification procedure, multi-runtime extension procedure.
- [specification/v1.0/regression-protocol.md](specification/v1.0/regression-protocol.md):
  defect lifecycle, conformance impact classification (none /
  regeneration required / breaking), `BREAKING-CONFORMANCE` PR label
  workflow, audit discipline rule ("no defect acted on without a
  failing test").

## Discovered During Fix Work, Queued for v1.3

Three additional bugs surfaced while executing v1.2 audit fixes. Each is
documented with full evidence in [AUDIT_VERDICTS.md](AUDIT_VERDICTS.md)
and queued for v1.3 with reasons for deferral captured in the verdict
trail.

- **Bug 23 (LOW)**. Pie chart label visual divergence between Compose
  (on-segment text) and SwiftUI (legend chip). Surfaced during WP#4 Bug
  1 fix. Pixel-level parity is not part of conformance; both runtimes
  surface the labels. True 1:1 parity in SwiftUI requires a custom
  Canvas-style pie with on-arc text, which needs proper design time and
  a visual-regression harness.
- **Bug 24 (MEDIUM-perf)**. `AmeFormState` whole-map `@Published`
  causes unrelated-field re-renders per keystroke in SwiftUI. Surfaced
  during WP#4 Bug 5 fix. The Combine-harness test required to lock the
  invariant ("observers of field A don't fire when field B is edited")
  is WP-sized on its own, and per-key publishers via `CurrentValueSubject`
  or a wrapper type is real architectural work. Compose's
  `mutableStateMapOf` already escapes this class; SwiftUI parity in v1.3.
- **Bug 25 (MEDIUM-arch)**. `AmeThemeConfig` lacks an explicit
  success/warning role family. Material 3 has no built-in success/warning
  tokens; v1.2 ships with `isSystemInDarkTheme()`-branched defaults
  (Path D) that preserve recognizable green/orange in both modes without
  introducing new public API surface. The proper redesign. explicit
  `successColor`, `warningColor`, plus the full Material 3 role family
  (`successContainer`, `onSuccess`, `successContrast`; same for warning)
 . needs proper design time and is a v1.3 WP.

## Conformance

**No BREAKING-CONFORMANCE changes.** All 55 v1.1 conformance
`.expected.json` files are byte-identical to v1.1, verified by
`./conformance/regenerate-expected.sh && git diff conformance/` (zero
diff). Two new cases were added (56, 57) to exercise the Bug 6 and Bug
7 fixes. Implementations producing v1.1-compatible JSON continue to be
v1.2-compatible.

The conformance suite is invoked via
[`conformance/check-parity.sh`](conformance/check-parity.sh), which now
supports multi-runtime registration via the `RUNTIMES` configuration
array. The matrix output makes per-runtime status legible at a glance.

## Quality and Testing

AME maintains a three-tier test discipline:

1. **Unit tests** in each module. parser, serializer, renderer logic.
2. **Conformance suite**. 57 canonical `.ame` to JSON cases, verified
   via the multi-runtime `check-parity.sh`.
3. **Audit regression suite**. one test per known historical defect,
   listed in [AUDIT_VERDICTS.md](AUDIT_VERDICTS.md).

Cross-runtime parity at the JSON serialization level is enforced by the
57-case conformance suite. Individual runtime implementations may add
internal property-based or fuzz testing as their own quality concern;
this is not an AME standard requirement (consistent with how JSON
Schema, gRPC's conformance test definitions, h2spec, and the Web
Platform Tests scope conformance vs implementation testing).

## Discipline Acknowledgment

The audit-and-fix work in v1.2 was driven by
[regression-protocol.md](specification/v1.0/regression-protocol.md)
§8's "no defect acted on without a failing test" rule. Every claim was
converted to an executable test before any fix was scoped. Two audit
claims (Bug 17 import resolution, Bug 19 chart-in-each scope) were
refuted by passing tests, preventing phantom fixes. The verdict for
every claim is canonically recorded in
[AUDIT_VERDICTS.md](AUDIT_VERDICTS.md).

Where audit tests had to be refined or refactored during fix work
(Bug 12 in both runtimes; Bug 14 in Compose; Bug 15 in Swift), the
refinements followed the project's reviewer-sign-off requirement and
the rationale is captured in the per-bug verdict entries.

## Compatibility

- **Spec compatibility:** v1.1 documents continue to parse and serialize
  identically under v1.2.
- **JSON compatibility:** v1.1 JSON decodes correctly in v1.2.
- **Runtime requirements:** unchanged. Kotlin Compose for Android;
  SwiftUI for iOS 16+ / macOS 13+.
- **Capability declaration:** hosts may now declare `AME_SUPPORT: v1.2`
  per [integration.md](specification/v1.0/integration.md). Hosts still
  declaring `AME_SUPPORT: v1.1` continue to work; the v1.2 additions
  (e.g., `Callout.color`) are additive and degrade gracefully (the field
  is omitted from JSON when null, and v1.1 renderers ignore unknown
  optional arguments per the syntax.md error-recovery rules).

## Acknowledgments

The v1.2 audit-and-fix work was driven by deliberate scope discipline:
each bug was verified before being scoped, fixed against the verified
contract, and locked in with a permanent regression test. The audit
methodology, conformance procedure, and `regression-protocol.md`
codification are intended as reusable artifacts for any standards
project taking quality seriously.
