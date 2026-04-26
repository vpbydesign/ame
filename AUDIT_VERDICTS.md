# Audit Verdicts

Record of every defect claim against AME, its verdict, and the test
that proves or refutes it.

## Status Legend

- **REAL.** Verified by a failing test.
- **NOT REAL.** Refuted by a passing test. Guard test retained.
- **DEFERRED.** Real but scheduled for a future release.

## Verdicts

| Bug | Summary | Severity | Platforms | Status | Fixed |
|-----|---------|----------|-----------|--------|-------|
| 1 | Swift renderer drops chart labels | HIGH | SwiftUI | REAL | v1.2 |
| 2 | Swift carousel ignores peek parameter | HIGH | SwiftUI | REAL | v1.2 |
| 3 | Parser corrupts strings containing `)` or `]` | CRITICAL | Kotlin, Swift | REAL | v1.2 |
| 4 | Compose chart math breaks on negative values, single points, mismatched series | HIGH | Compose | REAL | v1.2 |
| 5 | Swift FormState mutates @Published during view body | HIGH | SwiftUI | REAL | v1.2 |
| 6 | Callout AST missing color field | HIGH | Kotlin, Swift | REAL | v1.2 |
| 7 | Chart series array-of-paths not supported end-to-end | HIGH | Kotlin, Swift | REAL | v1.2 |
| 8 | Streaming parseLine() cannot apply data section | HIGH | Kotlin, Swift | REAL | v1.2 |
| 9 | Reserved enum keywords not enforced | MEDIUM | Kotlin, Swift | REAL | v1.2 |
| 10 | Chart color default documentation drift | LOW | Spec | REAL | v1.2 |
| 11 | Ref recursion has no cycle limit | HIGH | Kotlin, Swift | REAL | v1.2 |
| 12 | Input/toggle ID collision silently merges | MEDIUM | Kotlin, Swift | REAL | v1.2 |
| 13 | Input ref regex rejects hyphens | MEDIUM | Kotlin, Swift | REAL | v1.2 |
| 14 | Compose theme hardcodes light-mode colors | MEDIUM | Compose | REAL | v1.2 |
| 15 | Serializer swallows decode failures | MEDIUM | Kotlin, Swift | REAL | v1.2 |
| 16 | Conformance parity script masks single-runtime regressions | TOOLING | Tooling | REAL | v1.2 |
| 17 | Compose missing lazy items import | — | Compose | NOT REAL | — |
| 18 | Accordion expanded parameter not reactive | MEDIUM | Kotlin, Swift | REAL | v1.2 |
| 19 | Kotlin chart-in-each() scope handling | — | Kotlin | NOT REAL | — |
| 21 | Swift Foundation strips .0 from Doubles | HIGH | Swift | REAL | v1.2 |
| 23 | Pie label visual parity drift | LOW | SwiftUI, Compose | DEFERRED | — |
| 24 | FormState whole-map publish causes unrelated re-renders | MEDIUM | SwiftUI | DEFERRED | — |
| 25 | Theme lacks explicit success/warning role family | LOW | All | DEFERRED | — |
| 26 | Flutter parser corrupts strings containing `)` or `]` | CRITICAL | Flutter | REAL | v1.3 |
| 27 | Flutter ref recursion has no cycle limit | HIGH | Flutter | REAL | v1.3 |
| 28 | Flutter chart math breaks on negatives, single points, mismatched series | HIGH | Flutter | REAL | v1.3 |
| 29 | Dart jsonEncode strips .0 from Doubles | — | Flutter | NOT REAL | — |
| 30 | Flutter callout AST missing color field | HIGH | Flutter | REAL | v1.3 |
| 31 | Flutter chart series array-of-paths not supported | HIGH | Flutter | REAL | v1.3 |
| 32 | Flutter streaming parseLine() cannot apply data section | HIGH | Flutter | REAL | v1.3 |
| 33 | Flutter input/toggle ID collision silently merges | MEDIUM | Flutter | REAL | v1.3 |
| 34 | Flutter input ref regex rejects hyphens | MEDIUM | Flutter | REAL | v1.3 |
| 35 | Flutter serializer swallows decode failures | MEDIUM | Flutter | REAL | v1.3 |
| 36 | Flutter accordion expanded not reactive | MEDIUM | Flutter | REAL | v1.3 |
| 37 | Flutter theme hardcodes light-mode colors | MEDIUM | Flutter | REAL | v1.3 |
| 38 | Flutter date/time picker allocates controller inside build() | MEDIUM | Flutter | REAL | v1.3 |
| 39 | DataList items render with zero vertical rhythm | MEDIUM | All | REAL | v1.4 |
| 40 | Carousel items grow beyond comfortable widths on tablets | MEDIUM | All | REAL | v1.4 |
| 41a | Badge variant not announced by screen readers | MEDIUM | All | REAL | v1.4 |
| 41b | Card children not grouped as single semantics node | MEDIUM | All | REAL | v1.4 |

All conformance impact: **none**. No BREAKING-CONFORMANCE changes
across any release.
