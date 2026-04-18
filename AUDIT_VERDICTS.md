# Audit Verdicts

Canonical record of every defect claim made against AME, the executable test that
proves or refutes it, and the resulting verdict.

This file is generated and updated by Phase 1 of the bug verification work plan.
See [specification/v1.0/regression-protocol.md](specification/v1.0/regression-protocol.md)
for the lifecycle rules that govern entries in this document.

## Last verification run

- Date: 2026-04-18
- Phase 1 commit: see git log
- Phase 2 (v1.2) status: All audit bugs fixed across WP#1-6 (Bugs 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 18) plus Bug 21 (discovered + fixed in WP#2). v1.2 audit fix work complete; released as v1.2.0. 3 newly-discovered bugs deferred to v1.3 (23, 24, 25).
- Suites run: 4 (ame-core, ame-compose, ame-swiftui parser, ame-swiftui UI)
- Total tests: 53 (WP#1 added Bug 3c; WP#2 added Bug 7b mismatched-length and 3 Bug 21 canonical-Double tests; WP#3 added Bug 8b chunked-JSON and Bug 11b diamond-ref tests; the original Bug 9 test was inverted to `testEnumValueTokensAreNotReserved` per Path D, with tech-team sign-off recorded under Bug 9; WP#4 added 3 deeper-coverage tests; WP#5 added the Q4 `testChartMathRangeIncludesZeroForMixedSign` permanent guard for the cross-zero range invariant and the Q4 `testInputRefRegexRejectsDotInsideFieldId` guard in BOTH runtimes to defend against future over-permissive expansion of the input-ref character class)
- REAL bugs verified: 20 (Bug 21 added in WP#2 from a divergence exposed by conformance fixture 57; Bugs 23, 24, 25 discovered during WP#4/WP#5 and deferred to v1.3 per v1.2 scope discipline)
- REAL bugs fixed in v1.2 Stage 1 (WP#1): 1 (Bug 3)
- REAL bugs fixed in v1.2 Stage 2 (WP#2): 4 (Bugs 6, 7, 10, 21)
- REAL bugs fixed in v1.2 Stage 3 (WP#3): 3 (Bugs 8, 9, 11)
- REAL bugs fixed in v1.2 Stage 4 (WP#4): 3 (Bugs 1, 2, 5)
- REAL bugs fixed in v1.2 Stage 5 (WP#5): 6 (Bugs 4, 12, 13, 14, 15, 18)
- REAL bugs fixed in v1.2 Stage 6 (WP#6): 1 (Bug 16; check-parity.sh rewrite for multi-runtime independence)
- NOT REAL refuted: 4
- Documentation-only divergences: 0 (Bug 10 resolved in WP#2 by aligning spec to AST; Bug 9 resolved in WP#3 by retracting an over-aggressive spec rule the parser was not enforcing; Bug 1 in WP#4 also corrected `primitives.md:1083` so the `labels` description matches actual Compose+SwiftUI behavior; Bug 18 in WP#5 added the accordion reactivity contract to `primitives.md`'s `expanded` row as part of the Bug 18 resolution itself)

---

## v1.2 Release Summary

- **17 audit bugs fixed across WP#1-6:** 1, 2, 3, 4 (4 sub-bugs), 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 18.
- **1 discovered-during-fix bug fixed in v1.2:** 21 (cross-runtime Double serialization, found in WP#2 during Bug 7 work; locked in by 3 canonical-Double regression tests).
- **3 discovered-during-fix bugs deferred to v1.3:** 23 (pie label visual parity), 24 (FormState per-key publish performance), 25 (AmeThemeConfig success/warning role family extension).
- **2 phantom claims refuted:** 17 (Compose lazy-import; proved by Robolectric compile + render test), 19 (Kotlin chart-in-each scope; proved by existing regression test plus a new permanent guard).
- **No BREAKING-CONFORMANCE changes.** All 57 conformance `.expected.json` files byte-identical to v1.1.
- **Audit regression suite:** 53 tests, 0 failures across both runtimes (`./verify-bugs.sh` exits 0).
- **Multi-runtime conformance tooling:** `conformance/check-parity.sh` rewritten in WP#6 to support N runtimes via a `RUNTIMES` configuration array. Adding a new runtime port is a one-line append. Bug 16 is implicit in this rewrite — runtimes invoke independently per fixture, so a failure in one no longer masks failures or successes in another.

---

## Status legend

- **REAL** — verifying test fails today, demonstrating the bug exists.
- **NOT REAL** — verifying test passes today, demonstrating the audit claim was wrong.
- **INCONCLUSIVE** — test could not be written, or behavior depends on environment we cannot replicate.
- **PENDING** — verifying test not yet written or run.

## Severity

- **Audit claim severity** — the hypothesis from the audit author.
- **Verified severity** — the truth after the test runs. May differ from the claim
  if real-world impact is narrower or wider than originally reported. Verified
  severity drives Phase 2 fix order.

## Conformance impact

- **none** — fixing this bug does not change parser/serializer JSON output.
- **regeneration required** — fix changes JSON; `conformance/*.expected.json` must
  be regenerated from the fixed Kotlin parser. PR may merge with regeneration.
- **breaking** — regeneration changes existing `.expected.json` files in ways that
  any third-party AME implementation must also update for. PR MUST carry the
  `BREAKING-CONFORMANCE` label and document affected cases per
  `regression-protocol.md` §3.

---

## Bug 1: Swift renderer drops chart `labels`

- Audit claim severity: HIGH
- Verified severity: HIGH
- Platforms: SwiftUI (Swift renderer)
- Verifying tests:
  - `AuditedSwiftUIBugTests.testChartRendererReceivesLabels` (ame-swiftui, source-structural)
  - `AuditedSwiftUIBugTests.testChartRendererBranchesUseLabelsExceptSparkline` (ame-swiftui, hardened per-branch structural — added in WP#4 Q3 to prevent comment-only-mention attack on the legacy regex)
- Status: **REAL — FIXED in v1.2 (in v1.2.0)**
- Evidence: source check found `case .chart(let type, let values, _,` at line 77
  of `AmeRenderer.swift` (labels wildcarded), and `renderChart` signature had
  no `labels` parameter. Fixed in WP#4 by un-wildcarding the labels position
  in the dispatch (`case .chart(let type, let values, let labels, …)`),
  threading `labels: [String]?` as the 3rd positional parameter of
  `renderChart`, and applying labels to each non-sparkline chart type:
  `bar` and `line` use `.chartXAxis { AxisMarks(values: 0..<n) { … }
  AxisValueLabel { Text(resolvedLabels[i] ?? "\(i)") } }`; `pie` uses
  `.foregroundStyle(by: .value("Slice", resolvedLabels?[index] ??
  "Slice \(index)"))` for both iOS 17+ `SectorMark` and the pre-iOS-17
  `BarMark` fallback. A `resolvedLabels` helper enforces the spec
  length-match contract (fall back to integer indices when
  `labels.count != data.count`). `sparkline` intentionally ignores labels
  (axes hidden per spec); a comment locks the design choice. Both audit
  tests now pass.
- Side note (spec patch, WP#3 Path-D pattern, part of this bug's resolution):
  `specification/v1.0/primitives.md:1083` previously read "ignored for
  `pie` and `sparkline`", which contradicted the Compose renderer (which
  draws labels on each pie segment via `drawText`). WP#4 corrected the
  spec line to describe the actual behavior: labels are X-axis labels for
  `bar`/`line`, slice names for `pie` (with cross-reference to Bug 23 for
  the visual-parity follow-up), and ignored for `sparkline` only. Spec
  now aligns to code in both runtimes.
- Conformance impact: **none** (renderer-only; serializer already preserves
  labels; verified by zero diff on regen of all 57 fixtures).
- Notes: visible to every iOS user with a labeled chart; Compose renderer
  already handled labels correctly. WP#4 also surfaced Bug 23 (pie label
  visual parity drift between Swift Charts legend and Compose on-segment
  text) — a separate bug class deferred to v1.3.

## Bug 2: Swift carousel ignores `peek` parameter

- Audit claim severity: HIGH
- Verified severity: HIGH
- Platforms: SwiftUI (Swift renderer)
- Verifying tests:
  - `AuditedSwiftUIBugTests.testCarouselUsesPeekParameter` (ame-swiftui, source-structural)
  - `AuditedSwiftUIBugTests.testCarouselTrailingPaddingEqualsPeekValue` (ame-swiftui, ViewInspector behavioral — added in WP#4 Q3 as the strong runtime guard)
- Status: **REAL — FIXED in v1.2 (in v1.2.0)**
- Evidence: source scan of `renderCarousel` body (excluding signature) showed
  `peek` was never referenced. Width was fixed at `geometry.size.width * 0.85`
  with `.padding(.horizontal, 16)`. Fixed in WP#4 by replacing the symmetric
  horizontal padding with `.padding(.leading, 16).padding(.trailing,
  CGFloat(peek))` on the inner `LazyHStack`. This mirrors Compose's
  `PaddingValues(start = 16.dp, end = node.peek.dp)` semantic exactly: when
  `peek == 0` the last item is flush to the right edge (matches Compose);
  when `peek == 24` (default) the last item gets 24pt trailing breathing
  room; when `peek == 100` ("show next item peeking") the trailing inset
  exposes the next slide. Q2 from WP#4 considered adding a 16pt minimum
  clamp but rejected it for exact Compose parity — trust the Compose
  authors' decision; a separate Bug 22 will be filed if iOS visual smoke
  test reveals the flush-edge case looks janky. ViewInspector behavioral
  test confirms the resolved trailing padding equals the configured peek
  at runtime; the legacy structural test confirms the source pattern.
- Conformance impact: **none** (renderer-only; verified by zero diff on
  regen of all 57 fixtures).
- Notes: Swift-only; Kotlin Compose used `node.peek.dp` for trailing
  padding correctly all along. The ViewInspector test (Q3 upgrade) is the
  first behavioral runtime guard in the SwiftUI audit suite; it
  validates that ViewInspector's `padding()` reader handles chained
  `.padding(.leading, 16).padding(.trailing, 100)` modifiers correctly,
  enabling future behavioral tests for other layout bugs.

## Bug 3: Kotlin parser corrupts component calls when string literals contain `)` or `]`

- Audit claim severity: CRITICAL
- Verified severity: CRITICAL
- Platforms: Kotlin (ame-core), Swift (ame-swiftui)
- Verifying tests:
  - `AuditedBugRegressionTest.testParenInsideStringLiteralIsPreserved` (ame-core)
  - `AuditedBugRegressionTest.testBracketInsideStringLiteralIsPreserved` (ame-core)
  - `AuditedBugRegressionTest.testEscapedQuoteFollowedByParenIsPreserved` (ame-core, added in WP#1 as deeper coverage of #3a)
  - `AuditedBugRegressionTests.testParenInsideStringLiteralIsPreserved` (ame-swiftui)
  - `AuditedBugRegressionTests.testBracketInsideStringLiteralIsPreserved` (ame-swiftui)
  - `AuditedBugRegressionTests.testEscapedQuoteFollowedByParenIsPreserved` (ame-swiftui, added in WP#1 as deeper coverage of #3a)
- Status: **REAL — FIXED in v1.2 (in v1.2.0)**
- Evidence: parser truncated `txt("a)b", body)` to `text == "a"` because
  `extractParenContent` and `parseArray` ignored string boundaries. Fixed in
  WP#1 by adding `inString` / `escaped` state to both helpers, mirroring the
  `splitTopLevel` pattern. The 6 verifying tests now pass in both runtimes.
- Conformance impact: **regeneration required** in principle, but the actual
  regen produced **zero diffs** across all 55 conformance fixtures. The four
  fixtures that contain `)`/`]` inside string literals
  (`21-code-basic.ame`, `49-code-in-accordion.ame`, plus two regex-matched
  but not actually-inside-string artifacts) all use balanced parens, so the
  buggy parser happened to produce correct output by accident. The fix
  preserves that output verbatim. **No `BREAKING-CONFORMANCE` label needed.**
- Notes: highest-risk bug; LLM output containing prose with parentheses or
  brackets was silently corrupted. The deeper escaped-quote case
  (`txt("she said \"oops)\" today", body)`) was already handled correctly by
  the original fix because `extractParenContent`'s `escaped` state keeps
  `inString` across `\"` sequences; the new guard test locks this in.

## Bug 4: Compose chart math breaks on negative values, single points, mismatched series lengths

- Audit claim severity: HIGH
- Verified severity: HIGH
- Platforms: Compose (ame-compose)
- Verifying tests:
  - `AuditedBugRegressionTest.testBarChartMathHandlesAllNegativeValues` (ame-compose) — calls `ChartMath.computeRange` + `computeBar` directly
  - `AuditedBugRegressionTest.testLineChartYStaysInBoundsForNegativeValues` (ame-compose) — calls `ChartMath.computeLineY` directly
  - `AuditedBugRegressionTest.testLineChartSinglePointBehaviorIsDocumented` (ame-compose) — asserts the empty-state predicate matches production
  - `AuditedBugRegressionTest.testMultiSeriesXAxisAlignment` (ame-compose) — calls `ChartMath.computeSharedStepX` directly
  - `AuditedBugRegressionTest.testChartMathRangeIncludesZeroForMixedSign` (ame-compose) — Q4 permanent guard added in WP#5 to lock in the cross-zero range invariant
- Status: **REAL — FIXED in v1.2 (in v1.2.0)** (all 4 sub-bugs)
- Evidence: WP#5 extracted production math into `internal object ChartMath`
  (sign-aware `computeRange`, `computeBar`, `computeLineY`, shared
  `computeSharedStepX`). `BarChart` now uses `ChartMath.computeBar` so
  positive bars rise from a baseline at value=0 and negative bars hang from
  it (Bug 4a). `LineChart` uses `ChartMath.computeLineY` so y values stay in
  `[0, chartHeight]` for negative-only data (Bug 4b), shows the documented
  "No chart data" empty state when no series has >= 2 points (Bug 4c), and
  uses `ChartMath.computeSharedStepX(maxPoints)` so index N of every series
  lands at the same x coordinate (Bug 4d). All 4 audit tests + the new Q4
  guard pass; verified that fixture `13-chart-bar-basic` (`[10, 20, 30]`)
  renders identically post-fix because all-positive data resolves to
  `dataMin=0, dataMax=30, baselineY=1`, equivalent to the pre-fix path.
- Conformance impact: **none** (renderer math; serializer JSON unchanged;
  zero diff on regen of all 57 fixtures)
- Notes: WP#5 design decision for Bug 4c — empty state ("No chart data")
  for any line chart whose every series has fewer than 2 points. Documented
  inline in the production code header comment. The audit tests were
  re-pointed from formula-mirroring to direct `ChartMath` calls,
  per-test name preserved per regression-protocol.md §8.

## Bug 5: Swift `AmeFormState` mutates `@Published` during view body

- Audit claim severity: HIGH
- Verified severity: HIGH
- Platforms: SwiftUI (Swift)
- Verifying tests:
  - `AuditedSwiftUIBugTests.testFormStateBindingDoesNotMutateInBodyOnCreate` (ame-swiftui, behavioral via inverted XCTestExpectation on `objectWillChange.sink`)
  - `AuditedSwiftUIBugTests.testCollectValuesIncludesUneditedDefault` (ame-swiftui, invariant guard added in WP#4 to prove the refactor preserves the unedited-defaults-in-collection contract)
- Status: **REAL — FIXED in v1.2 (in v1.2.0)**
- Evidence: `objectWillChange` fired when `binding(for:)` was called for an
  unregistered field with a default value, because lines 22-25 wrote
  `values[id] = defaultValue` synchronously into the `@Published` map.
  Fixed in WP#4 by introducing two non-published companion maps —
  `private var inputDefaults: [String: String]` and
  `private var toggleDefaults: [String: Bool]` — that hold the registered
  defaults outside the `@Published` storage. `binding(for:default:)` and
  `toggleBinding(for:default:)` now write the default into the
  non-published map; the returned `Binding`'s getter falls through
  `values[id] ?? inputDefaults[id] ?? ""` (and the toggle analog).
  Mutating non-published state does not fire `objectWillChange`, so the
  view body call is safe. The setter still writes to the `@Published`
  `values`/`toggles` map so user edits correctly drive view updates. The
  inverted-expectation test now passes (closure never fires). The new
  invariant test asserts that registering a default and immediately
  calling `collectValues()` returns the default — closing the regression
  vector that the refactor could have introduced by losing unedited
  defaults from form submissions. `collectValues()` was extended to
  merge `inputDefaults → values → toggleDefaults → toggles` (later keys
  override earlier ones), preserving the pre-fix input/toggle id
  collision semantic where toggle wins (Bug 12 will revisit collision
  handling in WP#5).
- Conformance impact: **none** (form state is not serialized; verified by
  zero diff on regen of all 57 fixtures).
- Notes: eliminates SwiftUI's "Modifying state during view update" warning
  on every fresh form render. The "separate observed (`@Published`) from
  unobserved (private map) state" pattern introduced here is reusable —
  see WP#4 completion report's pattern-share note for WP#5 Bug 18
  (`AmeAccordionView` faces the same observed-vs-snapshot tension and
  should mirror this approach for consistency). WP#4 also surfaced
  Bug 24 (whole-map `@Published` causes unrelated-field re-renders, a
  performance bug class) — deferred to v1.3 per discipline rule that no
  defect is acted on without a failing test, and the Combine harness for
  per-key publish testing is WP-sized on its own.

## Bug 6: Spec promises `callout(... color=)` but AST has no `color` field

- Audit claim severity: HIGH
- Verified severity: HIGH
- Platforms: Kotlin (ame-core), Swift (ame-swiftui), spec
- Verifying tests:
  - `AuditedBugRegressionTest.testCalloutAcceptsColorParameter` (ame-core)
  - `AuditedBugRegressionTests.testCalloutAcceptsColorParameter` (ame-swiftui)
- Status: **REAL — FIXED in v1.2 (in v1.2.0)**
- Evidence: Kotlin reflection check found no `color` member on
  `AmeNode.Callout`. Swift JSON serialization of `callout(info, "msg", color=success)`
  produced `{"_type":"callout","content":"msg","type":"info"}` with no `color`
  key. Fixed in WP#2 by adding `color: SemanticColor? = null` as the last
  field of `AmeNode.Callout` (Kotlin) and the last associated value of
  `case .callout(...)` (Swift), with parser wiring through `buildCallout`'s
  `named["color"]` and Codable encode/decode mirroring the existing
  `Badge.color` pattern. Both verifying tests now pass.
- Conformance impact: **regeneration required in principle, zero diff in
  practice**. The new field defaults to null and is omitted from JSON via
  `encodeDefaults = false` (Kotlin) and the Swift `if let color { ... }`
  guard, so all 55 existing fixtures are byte-identical post-fix.
  Conformance case 56 (`callout(warning, "Disk space low", color=warning)`)
  added in WP#2 exercises the round-trip and emits `"color":"warning"`.
- Notes: Renderer behavior (applying `color` to override the type-derived
  tint) is intentionally out of WP#2 scope; the Compose `AmeCallout` and
  Swift `renderCallout` still use only `node.type` for visual treatment.
  Renderer adoption is queued for a future WP.

## Bug 7: Spec example `chart(line, series=[$a, $b])` not supported end-to-end

- Audit claim severity: HIGH
- Verified severity: HIGH
- Platforms: Kotlin (ame-core), Swift (ame-swiftui)
- Verifying tests:
  - `AuditedBugRegressionTest.testChartSeriesArrayOfPathRefs` (ame-core)
  - `AuditedBugRegressionTest.testChartSeriesArrayOfPathsAllowsMismatchedLengths` (ame-core, added in WP#2 as deeper coverage)
  - `AuditedBugRegressionTests.testChartSeriesArrayOfPathRefs` (ame-swiftui)
  - `AuditedBugRegressionTests.testChartSeriesArrayOfPathsAllowsMismatchedLengths` (ame-swiftui, added in WP#2 as deeper coverage)
- Status: **REAL — FIXED in v1.2 (in v1.2.0)**
- Evidence: parser produced empty series (Swift: `Optional([])`) when given
  `series=[$a, $b]` with the data section providing both arrays. Fixed in
  WP#2 by adding `seriesPaths: List<String>? = null` (Kotlin) and the Swift
  equivalent as a parallel field to `seriesPath`, by extending `buildChart`
  to detect array-of-DataRefs in `series=` and store the paths in the new
  field, and by extending `resolveTree` / `resolveChartPaths` with an
  all-or-nothing resolution branch that produces `series` from the per-path
  resolved arrays. All 4 verifying tests now pass.
- Conformance impact: **regeneration required in principle, zero diff in
  practice on existing 55 fixtures**. The new `seriesPaths` field is
  cleared by `resolveTree` before serialization (only the resolved `series`
  ever appears in JSON), and no existing fixture used the array-of-paths
  syntax. Conformance case 57 (`chart(line, series=[$a, $b])`) added in
  WP#2 exercises the resolution and emits `"series":[[1.0,2.0,3.0],[4.0,5.0,6.0]]`.
- Notes: Open Question 1 from WP#2 asked whether mismatched-length series
  (e.g., `$a=[1,2,3]`, `$b=[4,5]`) should be allowed; the WP#2 verdict was
  yes (matches existing literal-array `series=[[1,2,3],[4,5]]` behavior).
  The new `testChartSeriesArrayOfPathsAllowsMismatchedLengths` test locks
  this in. Discovering this work also surfaced Bug 21 below (latent
  cross-runtime Swift Foundation Double serialization divergence).

## Bug 8: Streaming `parseLine()` cannot apply `---` + JSON data section

- Audit claim severity: HIGH
- Verified severity: HIGH
- Platforms: Kotlin (ame-core), Swift (ame-swiftui), spec
- Verifying tests:
  - `AuditedBugRegressionTest.testStreamingModeAppliesDataSection` (ame-core)
  - `AuditedBugRegressionTest.testStreamingModeHandlesChunkedJson` (ame-core, added in WP#3 as Q4 deeper coverage)
  - `AuditedBugRegressionTests.testStreamingModeAppliesDataSection` (ame-swiftui)
  - `AuditedBugRegressionTests.testStreamingModeHandlesChunkedJson` (ame-swiftui, added in WP#3 as Q4 deeper coverage)
- Status: **REAL — FIXED in v1.2 (in v1.2.0)**
- Evidence: streaming `---`, then `{"x":"hi"}`, then `root = txt($x)`
  previously produced `text == "$x"` (unresolved) because only the batch
  `parse()` API ingested data sections. Fixed in WP#3 by adding a
  streaming-mode state machine to both runtimes: `parseLine("---")` flips
  the parser into data-ingest mode; subsequent `parseLine()` calls whose
  trimmed first character is non-letter (JSON syntax) accumulate into a
  buffer, while letter-prefixed lines remain AME identifier definitions
  (the disambiguator works because identifiers are required to start with
  a letter). `getResolvedTree()` finalizes by parsing the buffer once and
  re-resolving the registered tree. State is cleared by `reset()` and
  guarded by an idempotence flag so repeated `getResolvedTree()` calls do
  not re-parse. The batch `parse()` flow is unchanged.
- Conformance impact: **none** (resolved trees serialize the same way
  regardless of which API was used to produce them; verified by zero diff
  on regen of all 57 fixtures).
- Notes: spec contract documented in
  `specification/v1.0/streaming.md` Streaming Data Sections subsection
  (added in WP#3 Task 3.7). The deeper Q4 chunked-JSON test verifies that
  JSON content spanning multiple `parseLine()` calls reassembles correctly
  before resolution.

## Bug 9: Reserved enum keywords not enforced by `isReserved()`

- Audit claim severity: MEDIUM
- Verified severity: MEDIUM (claim) → see resolution notes
- Platforms: Kotlin (ame-core), Swift (ame-swiftui), spec
- Verifying tests:
  - `AuditedBugRegressionTest.testEnumValueTokensAreNotReserved` (ame-core) — inverted from the original test in WP#3 Path D
  - `AuditedBugRegressionTests.testEnumValueTokensAreNotReserved` (ame-swiftui) — inverted from the original test in WP#3 Path D
- Status: **REAL — FIXED in v1.2 via spec correction (in v1.2.0)**
- Evidence: the audit claim was REAL — there was a divergence between
  `specification/v1.0/syntax.md` (which listed every enum value token as
  reserved) and `AmeKeywords.isReserved` (which only blocked primitives,
  actions, structural keywords, booleans). Both runtimes accepted
  `display = txt("oops")` and similar without recording an error.
- Resolution path: WP#3 first attempted Path A (enforce the spec rule in
  the parser by adding a `RESERVED_ENUM_VALUES` set and a parseLine guard).
  Pre-flight grep against the conformance corpus surfaced 8 fixtures using
  `title` and `label` as left-hand identifiers (`conformance/08`, `10`, `11`,
  `31`, `48`, `52`, `53`, `54`). Tech-team review chose **Path D — relax the
  spec** rather than rename fixtures or add an arbitrary "soft-reserved"
  exception list. Rationale: the parser already disambiguates by argument
  position (the LHS slot before `=` is always an identifier; the bare-token
  enum slots are evaluated against the relevant enum first), so the
  reservation was aspirational rather than necessary for parser correctness.
  Common LLM-emitted identifiers like `title`, `label`, `body`, `text`,
  `default` would have been rejected for a benefit (reader clarity) that the
  parser already provides.
- Fix scope:
  - `specification/v1.0/syntax.md` Reserved Keywords section retracts the 9
    enum-value subsections (TxtStyle, BtnStyle, BadgeVariant, InputType,
    Align, ChartType, CalloutType, TimelineStatus, SemanticColor) and adds
    a new explanatory subsection "Enum Value Tokens Are NOT Reserved" that
    documents the positional-disambiguation rule.
  - `AmeKeywords.isReserved` (Kotlin + Swift) returns to its pre-WP#3 form:
    only primitives, action names, structural keywords, and boolean
    literals are reserved.
  - The `parseLine` reserved-keyword guard is removed in both runtimes.
  - The original audit test `testReservedEnumKeywordsAreRejected` is
    inverted to `testEnumValueTokensAreNotReserved`. Per
    `regression-protocol.md` §8 (weakening or replacing an audit regression
    test requires explicit reviewer sign-off and a rationale), tech-team
    sign-off was captured in the WP#3 Path D review. The new test is the
    permanent guard against re-introducing the over-aggressive reservation;
    it asserts `isReserved("display") == false`, etc., AND that the parser
    accepts and resolves `title = txt("Welcome", title)` end-to-end.
- Conformance impact: **none**. The 8 affected fixtures already parsed and
  serialized correctly with the pre-WP#3 (unenforced) parser; they continue
  to do so after Path D. Verified by zero diff on regen of all 57 existing
  `*.expected.json` files.
- Notes: this resolution is a different shape from Bugs 6, 7, 10, 21. Those
  fixed code (parser, AST, serializer) to match the spec. Bug 9 fixes the
  spec to match the (correct) parser behavior. Per regression-protocol.md
  §3, both directions are legitimate when an audit reveals a code/spec
  divergence; the choice is driven by which side actually has the right
  contract. For LLM-generated UI, allowing common nouns as identifiers is
  the right contract. See WP#3 review for the full TPM rationale.

## Bug 10: Chart `color` default documented as `primary`, AST stores `null`

- Audit claim severity: MEDIUM
- Verified severity: LOW (documentation drift, not runtime impact)
- Platforms: Kotlin, Swift, spec
- Verifying tests:
  - _Documentation review only; no executable test._
- Status: **REAL — FIXED in v1.2 (in v1.2.0)**
- Evidence: `primitives.md` chart table said default `color = primary`;
  `AmeNode.Chart.color` defaults to `null` in both runtimes. Renderer
  fall-back to `accentColor` / `MaterialTheme.colorScheme.primary` produces
  the same visual, but JSON serialization differed. Fixed in WP#2 by
  aligning the spec to the AST: `specification/v1.0/primitives.md` chart
  parameter table now reads `Default: null` and the description gains the
  parenthetical "(renderer falls back to platform primary/accentColor when
  null)". This is the recommended option (spec-aligned-to-AST,
  zero conformance impact); the alternative (AST default to `primary`)
  would have required a `BREAKING-CONFORMANCE` regen of every chart fixture.
- Conformance impact: **none** (spec-text-only edit; AST and JSON output
  unchanged).
- Notes: future audits should not re-flag this as drift; the spec line and
  the AST default now match exactly.

## Bug 11: Ref recursion has no cycle limit (parser stack overflow)

- Audit claim severity: MEDIUM
- Verified severity: HIGH (Kotlin actually crashes; Swift assumed same)
- Platforms: Kotlin (ame-core), Swift (ame-swiftui)
- Verifying tests:
  - `AuditedBugRegressionTest.testCircularRefDoesNotStackOverflow` (ame-core)
  - `AuditedBugRegressionTest.testDiamondRefPatternResolvesCorrectly` (ame-core, added in WP#3 as Q4 deeper coverage)
  - `AuditedBugRegressionTests.testCircularRefDoesNotStackOverflow` (ame-swiftui, structural source check)
  - `AuditedBugRegressionTests.testDiamondRefPatternResolvesCorrectly` (ame-swiftui, added in WP#3 as Q4 deeper coverage)
- Status: **REAL — FIXED in v1.2 (in v1.2.0)**
- Evidence: Kotlin test previously caught actual `java.lang.StackOverflowError`
  at `AmeParser.kt:1071` when resolving a registry containing `a = b`,
  `b = a`. Swift source structural check found no cycle detection pattern
  in `resolveTree`. Fixed in WP#3 by threading an immutable `visited:
  Set<String>` through `resolveTree`, `resolveChildren`, and `expandEach`
  in both runtimes (8 recursive call sites in Kotlin, parallel set in
  Swift). When a `.ref(id)` is dereferenced, `id` is added to the visited
  set; if the same `id` reappears inside that branch, a warning is recorded
  and the unresolved Ref node is returned without recursing further. The
  set is rebuilt per call (`visited + id` / `visited.union([id])`), so
  sibling branches and diamond patterns (`a -> c, b -> c`) resolve
  independently rather than poisoning each other. The Swift structural
  audit test recognizes the new `visited` token in `resolveTree` and
  passes; the Q4 diamond-ref test exercises the per-branch isolation
  end-to-end in both runtimes.
- Conformance impact: **none** (no current `.ame` test case has a
  circular ref or diamond pattern; verified by zero diff on regen of all
  57 fixtures).
- Notes: severity upgraded from MEDIUM to HIGH during verification because
  Kotlin actually crashes the JVM. Post-fix, adversarial cyclic input
  produces a graceful warning rather than a crash.

## Bug 12: Input/toggle ID collision silently merges in `collectValues()`

- Audit claim severity: MEDIUM
- Verified severity: MEDIUM
- Platforms: Kotlin (ame-compose), Swift (ame-swiftui)
- Verifying tests:
  - `AuditedBugRegressionTest.testInputToggleIdCollisionDoesNotSilentlyOverwrite` (ame-compose) — refined per regression-protocol.md §8
  - `AuditedSwiftUIBugTests.testInputToggleIdCollisionDetected` (ame-swiftui) — refined per regression-protocol.md §8
- Status: **REAL — FIXED in v1.2 (in v1.2.0)** (both runtimes)
- Evidence: WP#5 added a `warnings` diagnostic surface on `AmeFormState`
  (Kotlin: `val warnings: List<String>`; Swift: `public var warnings:
  [String]`). `collectValues()` clears the warning list on each call, then
  records a per-id collision message (e.g., `"Form field id collision:
  'x' is registered as both input and toggle; toggle value used."`) for
  every id present in both the input layer and the toggle layer. Merge
  order is preserved (toggle wins) per the contract documented in WP#4
  Bug 5; the principle-correct minimal fix is visibility, not behavior
  change.
- §8 sanctioned audit-test refinement: the original assertion
  (`assertNotEquals("true", collected["x"])` in Kotlin and the Swift
  mirror) would have forced a behavior change. Maintainer sign-off
  captured in the WP#5 plan. Refined assertion in both runtimes:
  (1) `collected["x"] == "true"` confirms the merge order is unchanged,
  (2) `state.warnings.any { it.contains("'x'") }` confirms the
  diagnostic surface fires. Test names preserved.
- Conformance impact: **none** (form state is not serialized; zero diff
  on regen of all 57 fixtures)
- Notes: the Swift implementation checks `inputDefaults ∪ values`
  intersected with `toggleDefaults ∪ toggles` so a default-only
  registration for an id colliding with a user-edited toggle value (and
  every other combination) is detected at the layer boundary, matching
  WP#4 Bug 5's separate-defaults architecture.

## Bug 13: `${input.fieldId}` regex `\w+` rejects hyphens

- Audit claim severity: MEDIUM
- Verified severity: MEDIUM
- Platforms: Kotlin (ame-compose), Swift (ame-swiftui), parsers (NOT REAL)
- Verifying tests:
  - `AuditedBugRegressionTest.testInputRefRegexAcceptsHyphenatedIds` (ame-compose)
  - `AuditedBugRegressionTest.testInputRefRegexRejectsDotInsideFieldId` (ame-compose) — Q4 permanent guard added in WP#5
  - `AuditedSwiftUIBugTests.testInputRefRegexAcceptsHyphenatedIds` (ame-swiftui)
  - `AuditedSwiftUIBugTests.testInputRefRegexRejectsDotInsideFieldId` (ame-swiftui) — Q4 permanent guard added in WP#5
  - `AuditedBugRegressionTest.testParserAcceptsHyphenatedInputIds` (ame-core) — NOT REAL (parser is fine)
  - `AuditedBugRegressionTests.testParserAcceptsHyphenatedInputIds` (ame-swiftui) — NOT REAL (parser is fine)
- Status: **REAL — FIXED in v1.2 (in v1.2.0)** in form state regex;
  **NOT REAL** in parser
- Evidence: WP#5 changed both regex patterns from `\$\{input\.(\w+)\}` to
  `\$\{input\.([a-zA-Z0-9_-]+)\}`. The hyphen sits at the end of the
  character class to avoid being parsed as a range. The literal `.`
  separator inside the curly braces remains a hard separator, defended by
  the new Q4 guard test in both runtimes that asserts
  `${input.user.name}` (with a literal `.`) still does NOT match.
- Conformance impact: **none** (form state is not serialized; zero diff
  on regen)
- Notes: bug was localized to `AmeFormState.INPUT_REF_REGEX` in both
  runtimes; parser layer was already correct. Q4 guard prevents future
  over-permissive expansion that would shadow potential nested
  references like `${input.user.name}`.

## Bug 14: Compose theme uses hardcoded light-theme colors, breaks dark mode

- Audit claim severity: MEDIUM
- Verified severity: MEDIUM
- Platforms: Compose (ame-compose), SwiftUI (ame-swiftui)
- Verifying tests:
  - `AuditedBugRegressionTest.testCalloutBackgroundDiffersBetweenLightAndDarkTheme` (ame-compose) — refined per regression-protocol.md §8 to inject `LocalConfiguration.uiMode` (the signal production actually responds to) instead of `MaterialTheme.colorScheme`
  - `AuditedSwiftUIBugTests.testThemeColorsRespectDarkMode` (ame-swiftui)
- Status: **REAL — FIXED in v1.2 via Path D (in v1.2.0)** (both runtimes)
- Evidence: WP#5 implemented Path D — semantic color tokens stay
  recognizably green and orange across light and dark mode without
  introducing any new `AmeThemeConfig` API surface. Compose adds an
  `isSystemInDarkTheme()` branch inside `defaultBadgeColor`,
  `defaultCalloutStyle` (WARNING/SUCCESS/TIP only — INFO/ERROR keep
  deriving from `MaterialTheme.colorScheme`), and `defaultSemanticColor`
  using documented Material 3 700-weight tints (light) and 300-weight
  tints (dark). SwiftUI replaces every bare `.green/.orange/.red/.blue`
  literal in `AmeTheme.swift` with the Apple HIG adaptive equivalents
  `Color(.systemGreen/.systemOrange/.systemRed/.systemBlue)`; the same
  replacement is applied to `AmeRenderer.swift`'s maxDepth warning text
  and destructive button tint for cross-primitive consistency.
- §8 sanctioned audit-test refinement (Compose): the original Compose
  test injected two `MaterialTheme.colorScheme` values and read the
  callout background from each. The Path D production code reads the
  OS-level dark-mode signal via `isSystemInDarkTheme()` (sourced from
  `LocalConfiguration.uiMode`), not from MaterialTheme. The refined test
  now provides two `LocalConfiguration` instances with
  `Configuration.UI_MODE_NIGHT_NO` and `Configuration.UI_MODE_NIGHT_YES`
  and asserts the WARNING callout background differs across the two.
  Maintainer sign-off captured in WP#5 plan; assertion intent
  ("must adapt to dark mode") preserved verbatim.
- Conformance impact: **none** (theme is not serialized; zero diff on
  regen)
- Notes: Bug 25 filed in "Deferred to v1.3" for the proper
  `AmeThemeConfig` extension (`successColor`, `warningColor`, full
  Material 3 role family with `successContainer` / `onSuccess`, etc.).
  Path D is the v1.2 ship-with-discipline; Bug 25 is the v1.3 redesign
  with proper API design time.

## Bug 15: `AmeSerializer` swallows decode failures into `null`

- Audit claim severity: MEDIUM
- Verified severity: MEDIUM
- Platforms: Kotlin (ame-core), Swift (ame-swiftui)
- Verifying tests:
  - `AuditedBugRegressionTest.testSerializerReturnsDistinguishableErrorOnInvalidJson` (ame-core)
  - `AuditedBugRegressionTests.testSerializerReturnsDistinguishableErrorOnInvalidJson` (ame-swiftui) — refactored per regression-protocol.md §8 from selector check to direct API call
- Status: **REAL — FIXED in v1.2 (in v1.2.0)** (both runtimes)
- Evidence: WP#5 added diagnostic APIs to both runtimes. Kotlin:
  `AmeSerializer.fromJsonOrError(String): Result<AmeNode>` and
  `actionFromJsonOrError(String): Result<AmeAction>`, both returning
  `Result.failure(SerializationException(...))` with a descriptive
  message and the underlying cause attached on decode failure. The
  legacy nullable `fromJson` and `actionFromJson` now delegate to the
  new APIs (single source of truth) so behavior is unchanged for
  existing callers. Swift mirrors the same surface:
  `fromJsonOrError(_:): Result<AmeNode, Error>` and
  `actionFromJsonOrError(_:): Result<AmeAction, Error>`. The asymmetry
  in `Result` failure types (Kotlin's monomorphic `Throwable` vs Swift's
  generic `Error`) is the idiomatic shape for each language and is
  documented as Q4 in the WP#5 plan.
- §8 sanctioned audit-test refactor (Swift): the original Swift test
  used `responds(to: NSSelectorFromString("fromJsonOrError:"))` against
  a Swift `struct` cast to `AnyObject`. Swift static struct functions
  are not Obj-C bridged unless the type is `@objc class : NSObject`,
  which is an architectural distortion just to satisfy a fragile
  selector-based existence check. Maintainer sign-off captured in
  WP#5 plan. The refactored test calls `fromJsonOrError("{")` and
  asserts the result is `.failure` with a non-empty diagnostic, then
  calls it on a valid AmeNode JSON string and asserts `.success`. Same
  test name, same intent, stronger guarantee.
- Conformance impact: **none** (improves diagnostics only; existing
  `fromJson(String)?` API unchanged; zero diff on regen)
- Notes: developer experience bug. Hosts can now distinguish invalid
  JSON, schema mismatch, and unexpected runtime failures via the
  `Result` payload's underlying cause.

## Bug 16: Conformance parity script masks Swift-only regressions

- Audit claim severity: MEDIUM
- Verified severity: MEDIUM
- Platforms: tooling (`conformance/check-parity.sh`)
- Verifying tests:
  - _Source-confirmed in Phase 1; manual end-to-end verification in WP#6 (see Evidence below)._
- Status: **REAL — FIXED in v1.2 (in v1.2.0)**
- Evidence: WP#6 rewrote `conformance/check-parity.sh` around a declarative
  `RUNTIMES` array (`name|command-template` entries with `{{ame_file}}`
  substitution). Each runtime is invoked independently per fixture; the
  loop body has no `continue`-on-runtime-failure path. Per-runtime failure
  counters and error trails surface in the matrix output and final
  summary. The script exits non-zero if any runtime has any failure.
  Verified end-to-end by deliberately removing the Kotlin CLI binary,
  re-running the script, and confirming: (1) Kotlin column showed FAIL
  for all 57 cases, (2) Swift column showed PASS for all 57 cases (proving
  Swift ran independently), (3) summary printed `kotlin: 57 failure(s)
  swift: 0 failure(s)`, (4) script exited non-zero, (5) restoring Kotlin
  returned the script to all-PASS exit 0.
- Conformance impact: **none** (tooling only; no JSON output changes)
- Notes: the WP#6 rewrite simultaneously delivers the Bug 16 fix AND the
  multi-runtime extensibility groundwork the spec needs for additional
  runtime ports. Adding a new port (Flutter, React Native, Kotlin/XML,
  etc.) is a one-line append to the `RUNTIMES` array. See
  `specification/v1.0/conformance.md` §5 step 4 for the registration
  procedure and the script header for the array format.

## Bug 17: Compose `AmeRenderer.kt` may be missing `import androidx.compose.foundation.lazy.items`

- Audit claim severity: HIGH (claim)
- Verified severity: N/A
- Platforms: Compose (ame-compose)
- Verifying tests:
  - `AuditedBugRegressionTest.testAmeRendererCarouselRendersWithoutCompileError` (ame-compose) — PASSED (NOT REAL)
- Status: **NOT REAL**
- Evidence: Robolectric test compiles AND renders a Carousel node successfully.
  The `LazyListScope.items(count: Int)` extension function resolves correctly
  without an explicit import; Kotlin auto-imports DSL receiver extensions.
- Conformance impact: **none**
- Notes: audit claim refuted by executable test. The test is committed as a
  permanent guard against future regressions.

## Bug 18: Accordion `expanded` parameter not reactive to node updates

- Audit claim severity: MEDIUM
- Verified severity: MEDIUM
- Platforms: Compose (ame-compose), SwiftUI (ame-swiftui)
- Verifying tests:
  - `AuditedBugRegressionTest.testAccordionFollowsExternalExpandedChanges` (ame-compose)
  - `AuditedSwiftUIBugTests.testAccordionFollowsExternalExpandedChanges` (ame-swiftui)
- Status: **REAL — FIXED in v1.2 (in v1.2.0)** (both runtimes)
- Evidence: WP#5 implemented the accordion reactivity contract using the
  WP#4 Bug 5 separate-state pattern. Compose `AmeAccordion` keeps the
  local `var isExpanded by remember { mutableStateOf(node.expanded) }`
  for instant tap response and adds a `LaunchedEffect(node.expanded) {
  isExpanded = node.expanded }` so server-pushed updates re-key the
  effect and sync the snapshot. Swift `AmeAccordionView` adds a `let
  nodeExpanded: Bool` field tracking the latest external value and a
  `.onChange(of: nodeExpanded) { newValue in isExpanded = newValue }`
  modifier on the `DisclosureGroup`. Local user toggles still flip
  `isExpanded` immediately and persist until the next external change.
- Spec contract: `specification/v1.0/primitives.md` accordion `expanded`
  row updated to: "v1.2+ runtimes track external updates: if the host
  re-renders with a changed `expanded` value the UI follows. Local user
  toggles take effect immediately and persist until the next external
  change." No new em-dashes introduced.
- Conformance impact: **none** (UI state, not serialized; zero diff on
  regen)
- Notes: edge case (rapid concurrent prop changes + user taps could
  trigger flicker as the LaunchedEffect / .onChange re-syncs over a
  user's local toggle) is the same per-key-publish category as Bug 24
  and is deferred to v1.3 alongside it. Documented in WP#5 plan Q2.

## Bug 19: WP#6 phantom — Kotlin chart-in-each() scope handling

- Audit claim severity: HIGH (claimed)
- Verified severity: N/A
- Platforms: Kotlin (ame-core), Swift (ame-swiftui)
- Verifying tests:
  - `AuditedBugRegressionTest.testChartInsideEachResolvesPerItemScopePhantomGuard` (ame-core) — PASSED (NOT REAL)
  - `AuditedBugRegressionTests.testChartInsideEachResolvesPerItemScopePhantomGuard` (ame-swiftui) — PASSED (NOT REAL)
  - Pre-existing: `AmeParserTest.chartInsideEachResolvesPerItemScope` (ame-core) — PASSES
  - Pre-existing: `conformance/52-each-chart-binding.expected.json` — matches
- Status: **NOT REAL**
- Evidence: Both runtimes correctly resolve chart `$path` references against
  the per-item scope provided by `each()` template instantiation. Two charts
  in the test produce values `[1.0, 2.0, 3.0]` and `[4.0, 5.0, 6.0]` from
  different `each()` items.
- Conformance impact: **none**
- Notes: this entry permanently documents that the WP#6 follow-up plan
  identified a phantom bug. The audit claim was wrong; the canonical record
  prevents the same false claim from being acted on again. See
  `specification/v1.0/regression-protocol.md` §6 for the discipline rule that
  converts every audit claim to a test before action.

## Bug 21: Swift Foundation strips trailing `.0` from whole-number Doubles, breaking cross-runtime parity

- Audit claim severity: HIGH (added during WP#2; not in original audit)
- Verified severity: HIGH
- Platforms: Swift (ame-swiftui)
- Verifying tests:
  - `AuditedBugRegressionTests.testChartValuesSerializeWithKotlinCanonicalForm` (ame-swiftui)
  - `AuditedBugRegressionTests.testChartSeriesSerializeWithKotlinCanonicalForm` (ame-swiftui)
  - `AuditedBugRegressionTests.testProgressValueSerializesWithKotlinCanonicalForm` (ame-swiftui)
- Status: **REAL — FIXED in v1.2 (in v1.2.0)**
- Evidence: discovered during WP#2 when conformance fixture 57
  (`chart(line, series=[$a, $b])` with data `{"a":[1,2,3],"b":[4,5,6]}`)
  was added. Kotlin emitted `"series":[[1.0,2.0,3.0],[4.0,5.0,6.0]]`;
  Swift emitted `"series":[[1,2,3],[4,5,6]]`. Pre-fix the three audit tests
  failed with JSON outputs `"values":[1,2,3]`, `"series":[[1,2,3],[4,5,6]]`,
  `"value":1`. Foundation's `JSONEncoder` strips the trailing zero from
  whole-number `Double` and `Float` values; `kotlinx.serialization`
  preserves it. Per `regression-protocol.md` §7 (Kotlin-first), Kotlin's
  preserve-`.0` form is canonical.
- Latency: latent across all 55 pre-WP#2 conformance fixtures because every
  existing chart fixture used fractional values (`10.5`, `25.3`, `1.5`,
  etc.) and the lone progress fixture uses `0.75`. No existing
  `*.expected.json` contained the integer-form Doubles that would have
  exposed it. Verified via `grep -E '"values":\[\-?[0-9]+(,[0-9]+)*\]'
  conformance/*.expected.json` and the `series` analog: zero matches.
- Conformance impact: **none on existing 55 fixtures** (all byte-identical
  before/after the fix); fixture 57 added in WP#2 now passes parity without
  any normalization. No `BREAKING-CONFORMANCE` label needed.
- Fix: `ame-swiftui/Sources/AMESwiftUI/Serialization/AmeSerializer.swift`
  introduces `PreservedDouble` and `PreservedFloat` `Encodable` wrappers
  that round-trip the value as a sentinel-bracketed string
  (`__AMENUM_START__1.0__AMENUM_END__`); `AmeSerializer.toJson` strips the
  sentinels via `NSRegularExpression` post-encode, leaving raw JSON
  numbers with `.0` preserved. `Chart.values` and `Chart.series` map
  through `PreservedDouble`; `Progress.value` maps through `PreservedFloat`.
  Fix scope is intentionally narrow: only the three Double/Float-typed AME
  fields where cross-runtime parity matters.
- Notes: discovery of this bug during WP#2 is the inverse of the WP#6
  phantom (Bug 19). WP#6 acted on a non-existent claim without writing a
  test first; WP#2 wrote a fixture that exposed a real but latent bug,
  surfaced it under the heightened-halt protocol, and shipped the fix in
  the same WP. Future audits should re-run the broad `grep` from "Latency"
  above against any new fixtures to confirm whole-number coverage if the
  wrapper scheme is ever touched.

## Bug 23: Pie label visual parity drift between Swift Charts legend and Compose on-segment text

- Audit claim severity: LOW (discovered during WP#4)
- Verified severity: LOW
- Platforms: Swift (ame-swiftui), Compose (ame-compose)
- Verifying tests: _Documentation only — visual difference, not behavioral_
- Status: **REAL — DEFERRED to v1.3**
- Evidence: WP#4 wired pie labels through Swift Charts via
  `.foregroundStyle(by: .value("Slice", labelText))`, which Swift Charts
  renders as a legend chip below the chart. Compose draws labels on each
  segment via `drawText` at slice mid-angle (`AmeChartRenderer.kt:247–264`).
  Both surface the labels; the visual treatments differ. End users see
  labels in both runtimes, but pixel-level parity is not achieved.
- Conformance impact: **none** (renderer-only; JSON byte-identical;
  verified by zero diff on regen of all 57 fixtures).
- Notes: pie charts are uncommon in LLM-generated mobile UI (LLMs prefer
  bar/line/sparkline for actual data). `conformance.md` §1.1 only requires
  byte-identical JSON output, not pixel-identical rendering — so this is
  not a v1.2 conformance blocker. True 1:1 parity in SwiftUI requires a
  custom Canvas-style pie with on-arc text labels (~3–4 hr of design +
  implementation), which is bad ROI inside a fix sprint. Deferred to v1.3
  with a dedicated WP that owns the design and the visual-regression test
  harness. Documented in v1.2 release notes as a known visual difference.

## Bug 24: AmeFormState whole-map `@Published` causes unrelated-field re-renders (perf)

- Audit claim severity: MEDIUM-perf (discovered during WP#4)
- Verified severity: MEDIUM-perf
- Platforms: Swift (ame-swiftui)
- Verifying tests: _Pending — needs Combine-harness test in v1.3 WP_
- Status: **REAL — DEFERRED to v1.3**
- Evidence: `AmeFormState.values` and `AmeFormState.toggles` are
  `@Published [String: String]` / `@Published [String: Bool]`. Any edit
  to any field publishes the whole map, so views observing unrelated
  fields re-render on every keystroke into a different field. Compose
  escapes this with per-key `MutableState` instances stored in a
  `mutableStateMapOf` (`AmeFormState.kt:20–21`), where reads of one key
  do not subscribe the reader to changes on other keys.
- Conformance impact: **none** (form state is not serialized).
- Notes: Bug 5 (fixed in WP#4) fixed correctness — no more body-mutation
  warning. Bug 24 is a separate bug class (performance), and the
  discipline rule from `regression-protocol.md` is "no defect acted on
  without a failing test." Writing the failing test (assert that
  observers of field A don't fire when field B is edited) requires
  Combine-harness setup that is WP-sized on its own. Per-key publishers
  via `CurrentValueSubject` or a wrapper type is real architectural work
  that needs design time. v1.3 WP will own design + benchmarks +
  failing test + fix. Documented in v1.2 release notes as a known
  performance limitation: "FormState publishes on any field change;
  per-key publishers are queued for v1.3."

## Bug 25: `AmeThemeConfig` lacks an explicit success/warning role family

- Audit claim severity: LOW-design (discovered during WP#5)
- Verified severity: LOW-design
- Platforms: Compose (ame-compose), SwiftUI (ame-swiftui)
- Verifying tests: _Pending — needs design proposal first; no failing
  test in v1.2 because Path D resolves the user-visible Bug 14 symptom_
- Status: **REAL — DEFERRED to v1.3**
- Evidence: Material 3's standard `ColorScheme` exposes
  `primary/secondary/tertiary/error` with `*Container/on*/onSurface*`
  variants but no built-in `success` or `warning` role. Compose hosts
  cannot override AME's success/warning colors through their normal
  Material theming pipeline, and SwiftUI hosts cannot override AME's
  semantic green/orange through any `AmeTheme`-level slot. WP#5 Path D
  resolved the immediate dark-mode adaptation symptom (Bug 14) without
  introducing public API surface. The deeper architectural gap — AME
  owning a richer semantic color vocabulary that hosts can rebrand —
  remains.
- Conformance impact: **none** (theme is not serialized; renderer-only
  change).
- Notes: open design questions captured for v1.3 owner:
  (a) slot type — bare `Color`, `@Composable () -> Color` lambda, or
  per-mode variants?
  (b) granularity — one consolidated slot `semanticColor: SemanticColor -> Color`
  (already exists) or per-role slots `successColor`, `warningColor`,
  `successContainer`, `onSuccess`, `successContrast`?
  (c) interaction with Material 3 dynamic color system on Compose;
  (d) iOS analog — does adopting Apple's semantic color system leak
  into the cross-runtime API surface or stay on the SwiftUI side only?
  Doing this redesign under WP#5 fix-sprint time pressure would
  produce an API to regret. v1.3 WP owns the design proposal,
  failing-test harness, and rollout. Documented in v1.2 release
  notes as a known limitation: "AmeThemeConfig has no explicit
  success/warning role-family slots; AME's semantic green/orange are
  built-in defaults that adapt to system dark mode — full host
  override of these tokens is queued for v1.3."

---

## Phase 2 fix order (driven by verified severity)

When fixes begin (per `regression-protocol.md` §7 Kotlin-first), address bugs
in this order:

1. **CRITICAL**
   - ~~Bug 3 — paren/bracket-in-string corruption (parser, both runtimes)~~ — **FIXED in v1.2 WP#1**
2. **HIGH**
   - ~~Bug 1 — Swift chart labels (Swift only)~~ — **FIXED in v1.2 WP#4**
   - ~~Bug 2 — Swift carousel peek (Swift only)~~ — **FIXED in v1.2 WP#4**
   - ~~Bug 4 — Compose chart math (Compose only; ChartMath internal object + sign-aware bar/line + single-point empty state + multi-series shared X)~~ — **FIXED in v1.2 WP#5**
   - ~~Bug 5 — Swift FormState mutation (Swift only)~~ — **FIXED in v1.2 WP#4**
   - ~~Bug 6 — callout color field (both runtimes)~~ — **FIXED in v1.2 WP#2**
   - ~~Bug 7 — chart series array-of-paths (both runtimes)~~ — **FIXED in v1.2 WP#2**
   - ~~Bug 8 — streaming + data section (both runtimes)~~ — **FIXED in v1.2 WP#3**
   - ~~Bug 11 — ref cycle stack overflow (both runtimes)~~ — **FIXED in v1.2 WP#3**
   - ~~Bug 21 — Swift Foundation strips `.0` from whole-number Doubles (Swift only)~~ — **FIXED in v1.2 WP#2**
3. **MEDIUM**
   - ~~Bug 9 — reserved enum keywords (both runtimes)~~ — **FIXED in v1.2 WP#3 via spec correction (Path D)**
   - ~~Bug 12 — input/toggle id collision (both runtimes; warnings diagnostic surface, merge order preserved per WP#4 Bug 5 contract)~~ — **FIXED in v1.2 WP#5**
   - ~~Bug 13 — input ref regex hyphens (both runtimes; Q4 dot-separator guard added in both)~~ — **FIXED in v1.2 WP#5**
   - ~~Bug 14 — theme dark-mode adaptation (both runtimes; Path D — `isSystemInDarkTheme()` in Compose, `Color(.systemGreen)` etc. in SwiftUI; Bug 25 filed for v1.3 role-family extension)~~ — **FIXED in v1.2 WP#5**
   - ~~Bug 15 — serializer error diagnostics (both runtimes; `fromJsonOrError` and `actionFromJsonOrError` returning `Result`)~~ — **FIXED in v1.2 WP#5**
   - ~~Bug 18 — accordion expanded reactivity (both runtimes; mirrors WP#4 Bug 5 separate-state pattern via `LaunchedEffect` / `.onChange(of:)`; spec accordion `expanded` row updated)~~ — **FIXED in v1.2 WP#5**
4. **LOW**
   - ~~Bug 10 — chart color default documentation drift (spec or AST)~~ — **FIXED in v1.2 WP#2**
5. **TOOLING**
   - ~~Bug 16 — `check-parity.sh` script (Phase 5)~~ — **FIXED in v1.2 WP#6 via multi-runtime `RUNTIMES` array refactor; runtimes invoke independently per fixture; Bug 16 fix verified by deliberately removing Kotlin CLI and confirming Swift column still ran**

## NOT REAL (phantom claims)

- Bug 17 — Compose `items` import (refuted by Robolectric compile + render test)
- Bug 19 — Kotlin chart-in-each() scope (refuted by existing test + new guard test)

## Deferred to v1.3 (newly discovered during v1.2 fix sprint)

- Bug 23 — Pie label visual parity drift between Swift Charts legend and Compose on-segment text (LOW; surfaced during WP#4 Bug 1 fix; not a v1.2 conformance blocker because conformance is byte-identical JSON, not pixel-identical rendering)
- Bug 24 — `AmeFormState` whole-map `@Published` causes unrelated-field re-renders (MEDIUM-perf; surfaced during WP#4 Bug 5 fix; deferred per the no-defect-without-failing-test discipline rule and because per-key publishers are an architectural change with its own design + benchmark + failing-test scope)
- Bug 25 — `AmeThemeConfig` lacks an explicit success/warning role family (LOW-design; surfaced during WP#5 Bug 14 work). v1.2 ships Path D (`isSystemInDarkTheme()` branched defaults in Compose, `Color(.systemGreen)` etc. in SwiftUI) — recognizable green / orange in both modes with no new API surface. The proper v1.3 redesign extends `AmeThemeConfig` with explicit `successColor`, `warningColor`, plus the full Material 3 role family (`successContainer`, `onSuccess`, `successContrast`; same shape for warning). Open design questions captured during WP#5 for v1.3 owner: (a) slot type — `Color`, `@Composable () -> Color`, or per-mode variants? (b) one slot `semanticColor: SemanticColor -> Color` (already exists) or many slots? (c) interaction with Material 3 dynamic color system? (d) Swift HIG analog — does adopting Apple semantic colors leak into the AmeThemeConfig API? Doing this redesign under WP#5 fix-WP time pressure would produce an API to regret; v1.3 with proper design time is the right venue.
