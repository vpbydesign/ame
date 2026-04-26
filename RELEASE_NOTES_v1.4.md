# AME v1.4 Release Notes

**Date:** 2026-04-21
**Conformance impact:** none — all 57 v1.3 fixtures byte-identical; 5 new fixtures added.

## Summary

v1.4 closes six gaps surfaced in testing: one new visual primitive, two new `row` layout fields, two new `Align` enum values, and four renderer-quality fixes. All changes apply identically across the three reference runtimes (Kotlin Compose, SwiftUI, Flutter).

## What's new

### `list_item` primitive (22nd standard primitive)

`list_item(title, subtitle?, leading?, trailing?, action=...)` is a structured single-row list entry that solves a common composition problem: a `row` containing an icon + text column + trailing badge or button squeezed the text column to zero width when the trailing content was wide on small screens..

```
pizza_row = list_item("Pizza Place", "71 Mulberry St", icon("restaurant"), badge("4.5", info))
tappable_row = list_item("Pizza Place", "71 Mulberry St", icon("restaurant"), btn("Directions", nav("/directions")), action=nav("/detail"))
```

Key properties:

- **Guaranteed vertical alignment.** The leading slot top-aligns with the title; the trailing slot is vertically centered with a guaranteed minimum width.
- **Nested click target isolation (NORMATIVE).** When the row has both a row-level `action` and a `trailing` that is itself an interactive node (`btn`), the renderer MUST isolate the trailing tap so it does not also fire the row action. Material 3's `ListItem`, SwiftUI's `.highPriorityGesture`, and Flutter's `ListTile` all implement this natively.
- **`action` is named-only.** The 5th positional slot is reserved; `list_item("Title", action=nav("/x"))` is the only legal form. This avoids LLM disambiguation hazards from 5 mixed-type positional args.
- **Single-element semantics group.** Like `card`, a `list_item` is announced as one unit by screen readers, with the trailing interactive node remaining independently focusable.
- **Renderer mappings.** Compose: Material 3 `ListItem` slot API. SwiftUI: custom `HStack` with `.contentShape(Rectangle())` and `.highPriorityGesture` on trailing. Flutter: `ListTile` with `MergeSemantics`.

See `specification/v1.0/primitives.md` §`list_item` for the complete normative reference.

### `row` layout extensions

`row` gains two named-only optional fields:

- **`weights: [Int]`** — per-child flex weights for proportional width distribution. `null` = all intrinsic (v1.3 behavior). `0` = intrinsic. `>0` = proportional fill of remaining space. Mismatched length to children logs a warning and falls back to intrinsic sizing.
- **`crossAlign: Align`** — cross-axis (vertical) alignment of children within the row. Valid values: `top`, `center`, `bottom`. `null` = `center` (v1.3 behavior).

```
title_row = row([title_text, info_badge], weights=[1, 0])
list_row = row([leading_icon, info_col], crossAlign=top)
both = row([title_text, info_badge], space_between, 12, weights=[1, 0], crossAlign=top)
```

The parser accepts both `crossAlign=` and `cross_align=` for LLM leniency. JSON serializes as `cross_align` per AME convention.

### Align enum gains `top` and `bottom`

The Align enum grows from 5 to 7 values. `top` and `bottom` are reserved for the new `crossAlign` argument on `row`. Using them in a main-axis `align=` slot is a parser warning (renderer falls back to `start`).

### Renderer-quality fixes (Bugs 39, 40, 41a, 41b)

All four fixes apply identically across Compose, SwiftUI, and Flutter:

- **Bug 39 — DataList vertical rhythm.** List items had zero spacing between rows. Fixed by adding 8dp spacing with dividers, 12dp without. Matches Material 3 LazyColumn defaults.
- **Bug 40 — Carousel max-width clamp.** On Pixel Fold and other large form factors, items grew beyond comfortable widths. Fixed by clamping each item to a 340dp max — Material 3's recommended max card width.
- **Bug 41a — Badge accessibility.** Variant was not announced by screen readers ("4.5" with no indication of the indicator type). Fixed by including the variant name in the accessibility description ("4.5, info indicator").
- **Bug 41b — Card accessibility.** Card children were independently focusable, breaking the spec's note that a card SHOULD be a single semantics unit. Fixed via `mergeDescendants` (Compose), `.accessibilityElement(children: .combine)` (SwiftUI), and `MergeSemantics` (Flutter).

## Backward compatibility

- **No `BREAKING-CONFORMANCE` label.** All 57 existing conformance `.expected.json` files are byte-identical to v1.3.
- **Row data shape preserved.** New `weights` and `crossAlign` fields default to `null` and are omitted from JSON.
- **`Align` additions are additive.** Existing `Align` serializations are unchanged; the parser already used case-insensitive enum lookup.
- **No public API removed or renamed.**

Host apps SHOULD validate against the new audit tests (Bugs 39, 40, 41a, 41b) before upgrading to confirm their custom renderer extensions don't override the upstream fixes.

## Conformance

- 62 fixtures (was 57). 5 new: `58-list-item-basic`, `59-list-item-action-trailing`, `60-row-weights`, `61-row-cross-align`, `62-list-item-minimal`.
- All 62 pass on all 3 reference runtimes (verified via `./conformance/check-parity.sh`).

## Audit regression suite

- 6 audit suites total (one per runtime/area). Bug count grows from 81 to 96 across the suites:
  - `ame-core/AuditedBugRegressionTest` — unchanged (parser-only).
  - `ame-compose/AuditedBugRegressionTest` — 11 → 16 (+5: Bugs 39, 40, 41a, 41b + nested click target Robolectric test).
  - `ame-swiftui/AuditedSwiftUIBugTests` — 11 → 15 (+4: Bugs 39, 40, 41a, 41b).
  - `ame-flutter-ui/audited_ui_bug_regression_test` — 7 → 13 (+6: Bugs 39, 40, 41a, 41b, list_item dispatch, row weights).
- The Compose nested click target test was written failing-first, before the v1.4 `AmeListItem` composable was implemented.

## Migration notes

- **Existing `row` calls** require no changes. Parsers accept the v1.3 form unchanged.
- **Existing `Align` references** require no changes.
- **Hosts that wrap or override `AmeRenderer`** for `row`, `card`, `badge`, `list`, or `carousel` should review the v1.4 fixes and either inherit them or document the deviation.
- **LLM system prompts** can announce the new `list_item` primitive and `row` extensions at the integrator's discretion. Without announcement, the model continues using the v1.3 vocabulary, which still works.


---

*See `AUDIT_VERDICTS.md` for the per-bug verdict trail and `specification/v1.0/primitives.md` for the complete normative spec.*
