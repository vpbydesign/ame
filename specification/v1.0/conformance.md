# AME Conformance

This document defines what it means for an implementation to be AME-compliant,
the test catalog implementations are evaluated against, and the procedure
implementers follow to self-verify before claiming a conformance level.

## 1. Conformance Levels

AME defines three conformance levels. Each level subsumes all requirements of
the levels below it. Implementations claiming AME support MUST state the
highest level they conform to.

### 1.1 AME Core Conformance

An implementation claims **AME Core Conformance** when:

1. **Parser** handles all 21 standard primitives defined in
   [primitives.md](primitives.md), plus `each()` from
   [data-binding.md](data-binding.md), plus `Ref` for forward references.
2. **Parser** handles the `---` data separator and resolves `$path`
   references against the data model.
3. **Parser** implements all error recovery rules from
   [syntax.md](syntax.md) (unknown component, unclosed parenthesis,
   unclosed string, malformed line, duplicate identifier, invalid number,
   invalid enum value). The parser MUST NOT crash on any input.
4. **Renderer** displays all 21 standard primitives as native platform
   widgets.
5. **Renderer** dispatches all actions through an action handler interface
   (see [actions.md](actions.md)).
6. All 9 example `.ame` files in the `examples/` directory parse and
   render without errors.
7. The implementation passes every test case in the normative subset of the
   conformance suite (see §2).

### 1.2 AME Streaming Conformance

An implementation claims **AME Streaming Conformance** when it meets all
AME Core Conformance requirements AND:

1. **Parser** supports incremental parsing via a `parseLine()` method
   (or equivalent) that processes one line at a time.
2. **Parser** correctly applies `---` and JSON data section content emitted
   line-by-line through the streaming API (see also Bug 8 in
   [`AUDIT_VERDICTS.md`](../../AUDIT_VERDICTS.md) at the repo root for the
   reference implementation's current state).
3. **Renderer** shows skeleton placeholders for unresolved `Ref` nodes.
4. **Renderer** replaces skeletons with rendered components when the
   defining statement arrives.
5. Forward references resolve correctly regardless of emission order
   (top-down, bottom-up, or mixed).

Streaming Conformance is OPTIONAL. Implementations that only support
batch parsing (entire document at once) claim Core Conformance only.

### 1.3 AME Strict Conformance

An implementation claims **AME Strict Conformance** when it meets all
AME Core or AME Streaming Conformance requirements AND:

1. The implementation passes every regression test in the audit regression
   suite for its platform. The audit regression tests are listed in
   [`AUDIT_VERDICTS.md`](../../AUDIT_VERDICTS.md) and live in the per-module
   `Audited*` test files. They encode every known historical defect of the
   reference implementations and the expected post-fix behavior.
2. The implementation runs the `verify-bugs.sh` script (or equivalent) in
   continuous integration on every change.
3. The implementation publishes a public link to its audit regression test
   results, updated on every release.

Strict Conformance is the recommended level for any implementation expected
to handle arbitrary LLM-generated input in production.

## 2. Conformance Test Catalog

The conformance suite lives in [`conformance/`](../../conformance/). It
contains 57 numbered test cases as of v1.2 (55 from v1.1 plus
`56-callout-with-color` and `57-chart-series-array-of-paths` added in
v1.2 to exercise the Bug 6 and Bug 7 fixes). Each case has two files:

- `NN-name.ame` — the input AME source.
- `NN-name.expected.json` — the canonical JSON output produced by the
  reference Kotlin parser via `AmeSerializer.toJson(parser.parse(input))`.

| # | Slug | Coverage |
|---|------|----------|
| 01 | basic-col | `col`, `txt` styles |
| 02 | row-layout | `row` align, gap, `space_between` |
| 03 | all-content | All `txt` styles, `img`, `icon`, `divider`, `spacer` |
| 04 | card-badge-progress | `card`, `badge` variants, `progress` |
| 05 | interactive | `btn` (all 5 actions), `input` (text, number, select), `toggle` |
| 06 | data-list-table | `list`, `table` |
| 07 | forward-refs | Forward references |
| 08 | each-with-data | `each()` + data + `$` fields in template |
| 09 | path-resolution | Root-scope `$path` with `/` segments |
| 10 | each-empty-array | `each()` over empty array |
| 11 | each-missing-path | `each()` when path missing → no children |
| 12 | error-recovery | Unknown v1.0-style component → warning `txt` |
| 13-20 | chart-* | Bar, line, pie, sparkline, multi-series, height/color, no-labels, data binding |
| 21-23 | code-* | Basic, with-title, empty content |
| 24-28 | accordion-* | Basic, expanded, nested, multiple, empty |
| 29-31 | carousel-* | Basic, peek, single child |
| 32-37 | callout-* | All five types + with-title |
| 38-42 | timeline-* | Basic, all-statuses, single, item-minimal, empty |
| 43-45 | semantic-color-* | `txt` color, `badge` color, all colors |
| 46-49 | v11-mixed | v1.1 primitives in cards, columns, mixed layouts, code-in-accordion |
| 50-51 | carousel-rich | Carousel of images, of cards |
| 52 | each-chart-binding | Chart inside `each()` with per-item `$path` (regression for WP#6 phantom — see Bug 19 in audit verdicts) |
| 53 | chart-root-binding | Chart `$path` resolution against root scope |
| 54 | each-v11-mixed | `each()` instantiating v1.1 primitives with per-item data |
| 55 | error-recovery-v11 | Unknown v1.1 primitive name → warning `txt` |

### 2.1 Normative vs Informative Tests

All 55 test cases are **normative** as of v1.1. Implementations claiming
Core Conformance MUST pass all 55. Future minor versions may add cases
(safe, since additions cannot break existing passing implementations). Removing
or modifying an existing case requires a major version bump per §4.

### 2.2 Audit Regression Suite (Strict Conformance only)

The audit regression suite lives in:

- `ame-core/src/test/kotlin/com/agenticmobile/ame/AuditedBugRegressionTest.kt`
- `ame-compose/src/test/kotlin/com/agenticmobile/ame/compose/AuditedBugRegressionTest.kt`
- `ame-swiftui/Tests/AMESwiftUITests/AuditedBugRegressionTests.swift`
- `ame-swiftui/Tests/AMESwiftUITests/AuditedSwiftUIBugTests.swift`

Each test corresponds to one row in
[`AUDIT_VERDICTS.md`](../../AUDIT_VERDICTS.md) and either proves a known
historical defect (REAL bugs that fix-PRs must turn green) or guards
against a phantom claim (NOT REAL bugs that must stay green forever).

Strict Conformance implementations must include analogous tests covering
the same bugs in their own runtime.

## 3. Self-Verification Procedure

To verify your AME implementation against the conformance suite:

```bash
# 1. Clone the reference repository.
git clone https://github.com/agenticmobile/ame-spec.git
cd ame-spec

# 2. Build the reference Kotlin CLI.
./gradlew :ame-core:installDist

# 3. Run the parity script. It runs the reference Kotlin CLI and the
#    reference Swift CLI against every conformance case and diffs against
#    the expected.json. The script runs each runtime independently per
#    fixture (Bug 16 was fixed in v1.2; see AUDIT_VERDICTS.md).
./conformance/check-parity.sh

# 4. To add a third-party implementation, write a CLI that takes one .ame
#    file and prints AmeNode JSON to stdout in the canonical format
#    (sorted keys, `_type` discriminator, default values omitted), then
#    extend check-parity.sh to invoke it the same way.

# 5. For Strict Conformance, additionally run the audit regression suite.
./verify-bugs.sh
```

The implementation is conformant at level X when all required tests for
level X pass without modification.

### 3.1 Reporting Conformance Results

Implementations advertising AME conformance SHOULD include a status line
in their README:

```text
AME Conformance: Strict (v1.2). 57/57 conformance tests pass,
                                 audit regression suite passes.
```

Or for partial conformance:

```text
AME Conformance: Core (v1.2). 57/57 conformance tests pass.
                               Streaming and Strict not yet supported.
```

Honesty is a strict requirement of conformance. Inflated or unverifiable
conformance claims may be reported to the project maintainers and listed
in a public errata document.

## 4. Conformance Test Versioning

Changes to the conformance suite follow these rules:

- **Adding a new test case** is a minor version change (e.g., 1.1 → 1.2).
  Existing implementations remain conformant at the previous level.
- **Modifying an existing `.expected.json`** in a way that requires
  third-party implementations to change their behavior is a **breaking
  change**. Such PRs MUST carry the `BREAKING-CONFORMANCE` label and
  follow the procedure in
  [regression-protocol.md](regression-protocol.md) §4. The release
  containing the change requires a minor version bump at minimum, and
  a major bump if the change breaks any documented spec promise.
- **Removing a test case** is always a major version change.

The reference implementation is responsible for regenerating
`*.expected.json` from the corrected Kotlin parser. The script
[`conformance/regenerate-expected.sh`](../../conformance/regenerate-expected.sh)
performs this regeneration. See `regression-protocol.md` §4.

## 5. Implementing AME on a New Platform

For implementers porting AME to Flutter, React Native, Kotlin/XML, or any
other framework:

1. Implement the parser per [syntax.md](syntax.md) and
   [data-binding.md](data-binding.md). Use `AmeNode.kt` or `AmeNode.swift`
   as the AST data model reference.
2. Implement `AmeSerializer` so that the JSON output matches the format
   defined in `AmeSerializer.kt` (sorted keys, `_type` discriminator,
   default omission). The conformance suite assumes this format.
3. Implement a CLI that takes an `.ame` file path and prints
   `AmeSerializer.toJson(parser.parse(file))` to stdout.
4. Append a new entry to the `RUNTIMES` array in
   [`check-parity.sh`](../../conformance/check-parity.sh) (see the script
   header for the `name|command-template` format). The new runtime is
   then checked in parallel with all others against the 57 fixtures, and
   per-runtime PASS/FAIL is reported in the matrix output.
5. (Strict only) Port the audit regression tests from
   `AUDIT_VERDICTS.md` to your platform's test framework.
6. (Renderer only) Implement the rendering layer per
   [primitives.md](primitives.md). Visual fidelity is not part of
   conformance; behavioral correctness (correct primitive types, correct
   action dispatch) is.

Open a PR or RFC issue at the AME repository to register your
implementation in the implementations directory.
