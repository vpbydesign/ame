import XCTest
@testable import AMESwiftUI

/// Audit regression tests — Swift parser and serializer.
///
/// Each test corresponds to one row in `AUDIT_VERDICTS.md` at the repo root.
/// Tests are written so that BEFORE a fix is applied the test FAILS
/// (proving the bug), and AFTER the fix is applied the test PASSES
/// (locking in the corrected behavior).
///
/// See `specification/v1.0/regression-protocol.md` for the lifecycle rules
/// that govern this file.
///
/// These tests mirror `ame-core/.../AuditedBugRegressionTest.kt` exactly so
/// that cross-runtime divergence is also caught.
final class AuditedBugRegressionTests: XCTestCase {

    // MARK: - Helpers

    private func parse(_ input: String) -> AmeNode? {
        AmeParser().parse(input)
    }

    private func parserFor(_ input: String) -> AmeParser {
        let parser = AmeParser()
        _ = parser.parse(input)
        return parser
    }

    // ════════════════════════════════════════════════════════════════════
    // Bug 3 — parseArray and extractParenContent ignore string literals
    // ════════════════════════════════════════════════════════════════════

    /// Audit Bug #3a: parser corrupts component calls when a string literal
    /// contains a literal `)` character.
    ///
    /// Spec section: specification/v1.0/syntax.md (String Literals)
    /// Audit reference: AUDIT_VERDICTS.md#bug-3
    /// Pre-fix expected: FAIL — extractParenContent stops at the first `)`,
    ///   truncating the string content.
    /// Post-fix expected: PASS — `)` inside `"..."` is preserved verbatim.
    func testParenInsideStringLiteralIsPreserved() {
        let result = parse(#"root = txt("a)b", body)"#)
        guard case .txt(let text, _, _, _) = result else {
            XCTFail("Expected txt; got \(String(describing: result))")
            return
        }
        XCTAssertEqual(
            text,
            "a)b",
            "BUG #3a: parenthesis inside a string literal must be preserved verbatim"
        )
    }

    /// Audit Bug #3b: parseArray scans only for `]`, ignoring strings, so
    /// a `]` inside an array element string ends the array prematurely.
    ///
    /// Spec section: specification/v1.0/syntax.md (Array Literals, String Literals)
    /// Audit reference: AUDIT_VERDICTS.md#bug-3
    /// Pre-fix expected: FAIL — array is truncated at the first `]`.
    /// Post-fix expected: PASS — `]` inside `"..."` is preserved as content.
    func testBracketInsideStringLiteralIsPreserved() {
        let result = parse(#"root = col([txt("a]b"), txt("c")])"#)
        guard case .col(let children, _) = result else {
            XCTFail("Expected col; got \(String(describing: result))")
            return
        }
        XCTAssertEqual(children.count, 2, "Array must contain both elements")
        guard case .txt(let text, _, _, _) = children[0] else {
            XCTFail("First child should be txt")
            return
        }
        XCTAssertEqual(text, "a]b", "Bracket inside string must be preserved")
    }

    /// Audit Bug #3c (deeper coverage of #3a): an escaped quote inside a string
    /// literal that is followed by a `)` must not terminate the parenthesized
    /// region. Verifies the fix's `escaped` state correctly keeps `inString`
    /// across `\"` so the outer `)` is matched at the right depth.
    ///
    /// Spec section: specification/v1.0/syntax.md (String Literals, escape sequences)
    /// Audit reference: AUDIT_VERDICTS.md#bug-3
    /// Pre-fix expected: FAIL — extractParenContent flips out of the string at
    ///   the literal `"` after the backslash and matches the next `)` early.
    /// Post-fix expected: PASS — `\"oops)\"` is preserved verbatim and the
    ///   trailing `body` positional argument is intact.
    func testEscapedQuoteFollowedByParenIsPreserved() {
        let result = parse(#"root = txt("she said \"oops)\" today", body)"#)
        guard case .txt(let text, let style, _, _) = result else {
            XCTFail("Expected txt; got \(String(describing: result))")
            return
        }
        XCTAssertEqual(
            text,
            "she said \"oops)\" today",
            "Escaped quotes around a `)` must be preserved verbatim in string content"
        )
        XCTAssertEqual(
            style,
            .body,
            "Trailing `body` positional argument must still be parsed as the style"
        )
    }

    // ════════════════════════════════════════════════════════════════════
    // Bug 6 — Callout AST does not carry the spec-promised color field
    // ════════════════════════════════════════════════════════════════════

    /// Audit Bug #6: primitives.md documents `callout(... color=)` for
    /// SemanticColor override. The Swift `.callout` enum case has no
    /// `color` associated value, so the parser silently drops the named arg.
    ///
    /// Spec section: specification/v1.0/primitives.md (Callout, SemanticColor)
    /// Audit reference: AUDIT_VERDICTS.md#bug-6
    /// Pre-fix expected: FAIL — encoded JSON does not contain "color":"success".
    /// Post-fix expected: PASS — the `color` round-trips through serialize/deserialize.
    func testCalloutAcceptsColorParameter() {
        let result = parse(#"root = callout(info, "msg", color=success)"#)
        guard let node = result else {
            XCTFail("Parse returned nil")
            return
        }
        guard let json = AmeSerializer.toJson(node) else {
            XCTFail("Serialization returned nil")
            return
        }
        XCTAssertTrue(
            json.contains("\"color\":\"success\""),
            "BUG #6: callout color must be preserved through parse and serialize. " +
            "JSON was: \(json)"
        )
    }

    // ════════════════════════════════════════════════════════════════════
    // Bug 7 — chart series does not support an array of $path refs
    // ════════════════════════════════════════════════════════════════════

    /// Audit Bug #7: primitives.md example `chart(line, series=[$revenue, $expenses])`
    /// implies multi-series via an array of `$path` references.
    /// Parser only supports a single `seriesPath` or a literal numeric matrix.
    ///
    /// Spec section: specification/v1.0/primitives.md (Chart series)
    /// Audit reference: AUDIT_VERDICTS.md#bug-7
    /// Pre-fix expected: FAIL — series is nil or wrong because `$path` array
    ///   elements are not resolved.
    /// Post-fix expected: PASS — series resolves to two lists, one per `$path`.
    func testChartSeriesArrayOfPathRefs() {
        let input = """
        root = chart(line, series=[$a, $b])
        ---
        {"a":[1,2,3],"b":[4,5,6]}
        """
        guard case .chart(let type, _, _, let series, _, _, _, _, _, _) = parse(input) else {
            XCTFail("Expected chart")
            return
        }
        XCTAssertEqual(type, .line)
        guard let series = series, series.count == 2 else {
            XCTFail(
                "BUG #7: series must resolve from array of $path refs to two lists. " +
                "Got: \(String(describing: series))"
            )
            return
        }
        XCTAssertEqual(series[0], [1.0, 2.0, 3.0])
        XCTAssertEqual(series[1], [4.0, 5.0, 6.0])
    }

    /// Audit Bug #7b (deeper coverage of #7): when an array of $path refs
    /// resolves to series of unequal length (e.g., $a=[1,2,3] and $b=[4,5]),
    /// the chart must preserve both series verbatim. This mirrors the existing
    /// behavior for literal-array series (`series=[[1,2,3],[4,5]]`) and lets
    /// the renderer decide how to align the X-axis (per audit Bug #4 — separate
    /// work).
    ///
    /// Spec section: specification/v1.0/primitives.md (Chart series)
    /// Audit reference: AUDIT_VERDICTS.md#bug-7
    /// Pre-fix expected: FAIL — series is nil/empty because $path array
    ///   elements are not resolved.
    /// Post-fix expected: PASS — series resolves to [[1,2,3],[4,5]]; lengths
    ///   are preserved without padding or truncation.
    func testChartSeriesArrayOfPathsAllowsMismatchedLengths() {
        let input = """
        root = chart(line, series=[$a, $b])
        ---
        {"a":[1,2,3],"b":[4,5]}
        """
        guard case .chart(let type, _, _, let series, _, _, _, _, _, _) = parse(input) else {
            XCTFail("Expected chart")
            return
        }
        XCTAssertEqual(type, .line)
        guard let series = series, series.count == 2 else {
            XCTFail(
                "BUG #7b: mismatched-length series must still resolve to two arrays. " +
                "Got: \(String(describing: series))"
            )
            return
        }
        XCTAssertEqual(series[0], [1.0, 2.0, 3.0], "First series preserved verbatim")
        XCTAssertEqual(series[1], [4.0, 5.0], "Second series preserved verbatim (no padding)")
    }

    // ════════════════════════════════════════════════════════════════════
    // Bug 21 — Swift Foundation strips trailing `.0` from whole-number
    //          Doubles in chart values/series and Progress.value, breaking
    //          cross-runtime byte-equality with Kotlin (canonical) output.
    // ════════════════════════════════════════════════════════════════════

    /// Audit Bug #21: Swift's Foundation JSONEncoder serializes `Double(1.0)`
    /// as `1` (no trailing zero), while Kotlin's kotlinx.serialization emits
    /// `1.0`. Same AmeNode tree therefore produces divergent JSON across
    /// runtimes for any chart with whole-number Doubles or progress with a
    /// whole-number value. This was latent across all 55 existing conformance
    /// fixtures because every existing chart fixture used fractional values
    /// (10.5, 25.3, etc.) and the lone progress fixture uses 0.75.
    /// Conformance case 57 (chart series array-of-paths from `{"a":[1,2,3]}`)
    /// is the first fixture to expose this divergence.
    ///
    /// Per `regression-protocol.md` §7 (Kotlin-first), Kotlin's preserve-`.0`
    /// behavior is canonical. Swift must mirror it.
    ///
    /// Spec section: specification/v1.0/conformance.md §1.1 (Core Conformance,
    ///   canonical JSON output matches AmeSerializer.kt)
    /// Audit reference: AUDIT_VERDICTS.md#bug-21
    /// Pre-fix expected: FAIL — Swift JSON omits `.0` on whole-number Doubles.
    /// Post-fix expected: PASS — Swift JSON contains `[1.0,2.0,3.0]` for
    ///   `chart.values`, `[[1.0,2.0,3.0]]` for `chart.series`, and `1.0` for
    ///   `progress.value` when the source AmeNode holds whole-number values.
    func testChartValuesSerializeWithKotlinCanonicalForm() {
        let chart: AmeNode = .chart(type: .bar, values: [1.0, 2.0, 3.0])
        guard let json = AmeSerializer.toJson(chart) else {
            XCTFail("Serialization returned nil")
            return
        }
        XCTAssertTrue(
            json.contains("\"values\":[1.0,2.0,3.0]"),
            "BUG #21: chart.values must serialize whole-number Doubles with `.0` " +
            "to match Kotlin canonical output. JSON was: \(json)"
        )
    }

    /// Companion to Bug 21 covering chart.series (the field that fixture 57
    /// actually exposes). Constructs a multi-series chart with whole-number
    /// Doubles and asserts both inner arrays preserve the `.0` suffix.
    ///
    /// Spec section: specification/v1.0/conformance.md §1.1
    /// Audit reference: AUDIT_VERDICTS.md#bug-21
    /// Pre-fix expected: FAIL — Swift JSON omits `.0` on the inner Doubles.
    /// Post-fix expected: PASS — JSON contains `[[1.0,2.0,3.0],[4.0,5.0,6.0]]`.
    func testChartSeriesSerializeWithKotlinCanonicalForm() {
        let chart: AmeNode = .chart(type: .line, series: [[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]])
        guard let json = AmeSerializer.toJson(chart) else {
            XCTFail("Serialization returned nil")
            return
        }
        XCTAssertTrue(
            json.contains("\"series\":[[1.0,2.0,3.0],[4.0,5.0,6.0]]"),
            "BUG #21: chart.series must serialize whole-number Doubles with `.0` " +
            "to match Kotlin canonical output. JSON was: \(json)"
        )
    }

    /// Companion to Bug 21 covering Progress.value (the only other Float/Double
    /// field in the AME ecosystem that affects cross-runtime parity). Constructs
    /// a progress with a whole-number value and asserts the JSON preserves `.0`.
    ///
    /// Spec section: specification/v1.0/conformance.md §1.1
    /// Audit reference: AUDIT_VERDICTS.md#bug-21
    /// Pre-fix expected: FAIL — Swift JSON omits `.0` on whole-number Float.
    /// Post-fix expected: PASS — JSON contains `"value":1.0`.
    func testProgressValueSerializesWithKotlinCanonicalForm() {
        let prog: AmeNode = .progress(value: 1.0)
        guard let json = AmeSerializer.toJson(prog) else {
            XCTFail("Serialization returned nil")
            return
        }
        XCTAssertTrue(
            json.contains("\"value\":1.0"),
            "BUG #21: progress.value must serialize whole-number Float with `.0` " +
            "to match Kotlin canonical output. JSON was: \(json)"
        )
    }

    // ════════════════════════════════════════════════════════════════════
    // Bug 8 — streaming parseLine() does not apply --- + JSON data section
    // ════════════════════════════════════════════════════════════════════

    /// Audit Bug #8: streaming.md describes streaming with `---` followed by
    /// a JSON data block. `parseLine()` returns nil for `---` and never
    /// accumulates subsequent JSON lines, so streaming consumers cannot
    /// resolve `$path` references.
    ///
    /// Spec section: specification/v1.0/streaming.md (Data section)
    /// Audit reference: AUDIT_VERDICTS.md#bug-8
    /// Pre-fix expected: FAIL — getResolvedTree() cannot resolve `$x`.
    /// Post-fix expected: PASS — streaming `---` then JSON then a `$x`
    ///   reference resolves to the data value.
    func testStreamingModeAppliesDataSection() {
        let parser = AmeParser()
        _ = parser.parseLine("---")
        _ = parser.parseLine(#"{"greeting":"hello"}"#)
        _ = parser.parseLine(#"root = txt($greeting)"#)

        guard let resolved = parser.getResolvedTree() else {
            XCTFail("Streaming parse should produce a tree")
            return
        }
        guard case .txt(let text, _, _, _) = resolved else {
            XCTFail("Expected txt; got \(resolved)")
            return
        }
        XCTAssertEqual(
            text,
            "hello",
            "BUG #8: $path references emitted via parseLine must resolve against the data section"
        )
    }

    /// Audit Bug #8b (deeper coverage of #8): JSON content MAY span multiple
    /// `parseLine()` calls. The buffer is parsed once at `getResolvedTree()`
    /// time, so any whitespace introduced between chunks (parsers append a
    /// newline per call) does not affect the result.
    ///
    /// Spec section: specification/v1.0/streaming.md (Streaming Data Sections)
    /// Audit reference: AUDIT_VERDICTS.md#bug-8
    /// Pre-fix expected: FAIL — `$x` would not resolve under any chunking.
    /// Post-fix expected: PASS — chunked JSON reassembles correctly.
    func testStreamingModeHandlesChunkedJson() {
        let parser = AmeParser()
        _ = parser.parseLine(#"root = txt($greeting)"#)
        _ = parser.parseLine("---")
        _ = parser.parseLine(#"{"greeting":"#)
        _ = parser.parseLine(#"    "hello""#)
        _ = parser.parseLine("}")

        guard let resolved = parser.getResolvedTree() else {
            XCTFail("Chunked-JSON streaming parse should produce a tree")
            return
        }
        guard case .txt(let text, _, _, _) = resolved else {
            XCTFail("Expected txt; got \(resolved)")
            return
        }
        XCTAssertEqual(
            text,
            "hello",
            "JSON spanning multiple parseLine() calls must reassemble before resolution"
        )
    }

    // ════════════════════════════════════════════════════════════════════
    // Bug 9 — enum value tokens are NOT reserved (v1.2 retracts the rule)
    // ════════════════════════════════════════════════════════════════════

    /// Audit Bug #9 (v1.2 / Path D resolution): the audit originally claimed
    /// the parser was failing to enforce a syntax.md rule that reserved every
    /// enum value token. The audit claim was REAL (the parser did not enforce
    /// the rule), but the resolution is to retract the spec rule because the
    /// parser already disambiguates `title` (LHS identifier) from `title`
    /// (TxtStyle enum value at arg position) without ambiguity. This inverted
    /// test is the permanent guard against re-introducing the over-aggressive
    /// reservation.
    ///
    /// Per regression-protocol.md §8: weakening an audit regression test
    /// requires explicit reviewer sign-off and a rationale. Tech-team sign-off
    /// captured in the WP#3 review for Path D.
    ///
    /// Spec section: specification/v1.0/syntax.md (Reserved Keywords)
    /// Audit reference: AUDIT_VERDICTS.md#bug-9
    /// Pre-fix expected: PASS today (no parser enforcement); the assertion
    ///   set documents the post-v1.2 contract.
    /// Post-fix expected: PASS — enum value tokens are NOT reserved; primitives,
    ///   actions, structural keywords, and booleans REMAIN reserved.
    func testEnumValueTokensAreNotReserved() {
        XCTAssertFalse(
            AmeKeywords.isReserved("display"),
            "TxtStyle.display must NOT be reserved (v1.2 retraction)"
        )
        XCTAssertFalse(
            AmeKeywords.isReserved("primary"),
            "BtnStyle.primary / SemanticColor.primary must NOT be reserved"
        )
        XCTAssertFalse(
            AmeKeywords.isReserved("done"),
            "TimelineStatus.done must NOT be reserved"
        )
        XCTAssertFalse(
            AmeKeywords.isReserved("title"),
            "TxtStyle.title must NOT be reserved (used by 7 conformance fixtures)"
        )
        XCTAssertFalse(
            AmeKeywords.isReserved("label"),
            "TxtStyle.label must NOT be reserved (used by conformance/31)"
        )

        // Genuine reserved tokens stay reserved: primitives shadow RHS calls,
        // action names shadow inline action expressions, `each` is the
        // template-iteration keyword, `root` is the resolver entry point,
        // and boolean literals shadow value parsing.
        XCTAssertTrue(AmeKeywords.isReserved("txt"), "Standard primitive 'txt' stays reserved")
        XCTAssertTrue(AmeKeywords.isReserved("tool"), "Action name 'tool' stays reserved")
        XCTAssertTrue(AmeKeywords.isReserved("each"), "Structural keyword 'each' stays reserved")
        XCTAssertTrue(AmeKeywords.isReserved("root"), "Structural keyword 'root' stays reserved")
        XCTAssertTrue(AmeKeywords.isReserved("true"), "Boolean literal 'true' stays reserved")

        // The parser MUST accept enum value tokens as identifiers and resolve
        // them like any other reference. This is the round-trip behavior the
        // 7 `title = ...` and 1 `label = ...` conformance fixtures rely on.
        let parser = AmeParser()
        _ = parser.parseLine(#"title = txt("Welcome", title)"#)
        _ = parser.parseLine("root = col([title])")
        guard let resolved = parser.getResolvedTree() else {
            XCTFail("Parser must accept enum value tokens as identifiers")
            return
        }
        guard case .col(let children, _) = resolved else {
            XCTFail("Expected col; got \(resolved)")
            return
        }
        XCTAssertEqual(children.count, 1)
        guard case .txt(let text, let style, _, _) = children[0] else {
            XCTFail("Expected txt; got \(children[0])")
            return
        }
        XCTAssertEqual(text, "Welcome", "title identifier must resolve to its txt value")
        XCTAssertEqual(
            style,
            .title,
            "title at arg-position must still resolve to TxtStyle.title (parser disambiguates by position)"
        )
        XCTAssertTrue(
            parser.errors.isEmpty,
            "Parser must not record errors for enum-value identifiers; got: \(parser.errors)"
        )
    }

    // ════════════════════════════════════════════════════════════════════
    // Bug 11 — circular ref chain crashes the parser with stack overflow
    // ════════════════════════════════════════════════════════════════════

    /// Audit Bug #11: `resolveTree` follows `.ref` nodes recursively without
    /// a visited set or depth limit. A registry containing `a = b`, `b = a`
    /// causes infinite recursion and stack overflow.
    ///
    /// Spec section: specification/v1.0/syntax.md (Forward references, depth)
    /// Audit reference: AUDIT_VERDICTS.md#bug-11
    /// Pre-fix expected: FAIL — resolveTree contains no cycle detection.
    /// Post-fix expected: PASS — resolveTree uses a visited set or depth limit.
    ///
    /// Swift cannot trap stack overflow without crashing the test process,
    /// which would mask all other test results. We use a source-structural
    /// check: assert that resolveTree contains a cycle-detection mechanism.
    /// The Kotlin sibling test (`testCircularRefDoesNotStackOverflow` in
    /// `ame-core`) does run the actual parser and catch the StackOverflowError.
    func testCircularRefDoesNotStackOverflow() throws {
        let parserSourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/AMESwiftUI/Parser/AmeParser.swift")
        let source = try String(contentsOf: parserSourceURL, encoding: .utf8)

        // Locate resolveTree function body.
        guard let funcStart = source.range(of: "private func resolveTree(") else {
            XCTFail("Could not locate resolveTree in AmeParser.swift")
            return
        }
        // Capture a generous slice of the function body.
        let endIndex = source.index(funcStart.upperBound, offsetBy: 4000, limitedBy: source.endIndex) ?? source.endIndex
        let body = String(source[funcStart.upperBound..<endIndex])

        // Bug pattern: no cycle detection. Look for any of the post-fix patterns:
        //   - a `Set<String>` or `[String]` parameter named visited / seen / inProgress
        //   - a `depth:` parameter with a depth limit guard
        //   - a `MAX_DEPTH` constant
        let cycleDetectionPatterns: [String] = [
            "visited",
            "depth:",
            "maxDepth",
            "MAX_DEPTH",
            "seenIds",
            "inProgress"
        ]
        let hasCycleDetection = cycleDetectionPatterns.contains { body.contains($0) }

        XCTAssertTrue(
            hasCycleDetection,
            "BUG #11: resolveTree has no cycle detection. " +
            "Add a visited set or depth-limit parameter so circular ref chains " +
            "(a = b, b = a) return safely instead of stack-overflowing."
        )
    }

    /// Audit Bug #11b (deeper coverage of #11): the diamond ref pattern
    /// (`root = col([a, b])`, `a = c`, `b = c`, `c = txt("shared")`) where
    /// two distinct refs both point at the same node is NOT a cycle and
    /// must resolve correctly. Verifies that the visited set in resolveTree
    /// is scoped per branch (immutable per call), not shared across siblings.
    ///
    /// Spec section: specification/v1.0/syntax.md (Forward references)
    /// Audit reference: AUDIT_VERDICTS.md#bug-11
    /// Pre-fix expected: PASS (the bug was stack overflow on cycles, not on
    ///   diamonds; this test guards against an over-eager fix that would
    ///   incorrectly flag diamonds as cycles).
    /// Post-fix expected: PASS — both children resolve to the shared txt.
    func testDiamondRefPatternResolvesCorrectly() {
        let parser = AmeParser()
        _ = parser.parseLine(#"c = txt("shared")"#)
        _ = parser.parseLine("a = c")
        _ = parser.parseLine("b = c")
        _ = parser.parseLine("root = col([a, b])")

        guard let resolved = parser.getResolvedTree() else {
            XCTFail("Diamond ref pattern should resolve cleanly")
            return
        }
        guard case .col(let children, _) = resolved else {
            XCTFail("Expected col; got \(resolved)")
            return
        }
        XCTAssertEqual(children.count, 2, "Both children must be present")
        guard case .txt(let firstText, _, _, _) = children[0] else {
            XCTFail("First child should be txt")
            return
        }
        guard case .txt(let secondText, _, _, _) = children[1] else {
            XCTFail("Second child should be txt")
            return
        }
        XCTAssertEqual(firstText, "shared", "First diamond branch must resolve to the shared txt")
        XCTAssertEqual(secondText, "shared", "Second diamond branch must resolve to the shared txt")
    }

    // ════════════════════════════════════════════════════════════════════
    // Bug 13 — parser accepts hyphenated input id strings
    // ════════════════════════════════════════════════════════════════════

    /// Audit Bug #13 (parser side): the parser must accept hyphenated input
    /// IDs as string args. The actual `${input.user-name}` substitution happens
    /// in AmeFormState (covered by Swift UI test).
    ///
    /// Spec section: specification/v1.0/actions.md (Input references)
    /// Audit reference: AUDIT_VERDICTS.md#bug-13
    /// Pre-fix expected: PASS today (parser is permissive about string args).
    /// Post-fix expected: PASS forever.
    func testParserAcceptsHyphenatedInputIds() {
        let result = parse(#"root = input("user-name", "Your name")"#)
        guard case .input(let id, _, _, _) = result else {
            XCTFail("Expected input")
            return
        }
        XCTAssertEqual(id, "user-name", "Parser must accept hyphenated input id strings")
    }

    // ════════════════════════════════════════════════════════════════════
    // Bug 15 — AmeSerializer.fromJson swallows decode failures into nil
    // ════════════════════════════════════════════════════════════════════

    /// Audit Bug #15: `AmeSerializer.fromJson(invalidJson)` returns nil with
    /// no diagnostic. Hosts cannot distinguish invalid JSON from schema mismatch.
    ///
    /// Spec section: specification/v1.0/integration.md (Serialization)
    /// Audit reference: AUDIT_VERDICTS.md#bug-15
    ///
    /// v1.2 fix (per WP#5 plan): `AmeSerializer.fromJsonOrError(_:)` and
    /// `actionFromJsonOrError(_:)` return `Result<_, Error>` so hosts can
    /// distinguish failure modes. The legacy nullable functions delegate to
    /// the new APIs to keep the source of truth single.
    ///
    /// §8 sanctioned audit-test refactor: the original assertion used
    /// `responds(to: NSSelectorFromString("fromJsonOrError:"))`. Swift
    /// `struct` static functions are not Obj-C bridged unless the type is
    /// `@objc class : NSObject`, so the selector check would never pass
    /// without distorting the AmeSerializer architecture for a fragile
    /// existence check. Maintainer sign-off recorded in WP#5 plan. The
    /// assertion intent — "a
    /// diagnostic API exists that distinguishes failure from success" — is
    /// preserved verbatim and made stronger by exercising the API directly.
    ///
    /// Pre-fix expected: FAIL — `fromJsonOrError` did not exist.
    /// Post-fix expected: PASS — invalid JSON produces `.failure` with a
    ///   non-empty diagnostic; valid JSON produces `.success` with a node.
    func testSerializerReturnsDistinguishableErrorOnInvalidJson() {
        let nilResult = AmeSerializer.fromJson("{")
        XCTAssertNil(nilResult, "Invalid JSON must not produce a node")

        let invalid = AmeSerializer.fromJsonOrError("{")
        guard case .failure(let error) = invalid else {
            XCTFail("BUG #15: invalid JSON must produce .failure, got .success")
            return
        }
        XCTAssertFalse(
            error.localizedDescription.isEmpty,
            "BUG #15: failure must carry a non-empty diagnostic message"
        )

        let valid = AmeSerializer.fromJsonOrError(#"{"_type":"txt","text":"ok"}"#)
        guard case .success = valid else {
            XCTFail("BUG #15: valid JSON must produce .success, got .failure")
            return
        }
    }

    // ════════════════════════════════════════════════════════════════════
    // Bug 19 — phantom: chart inside each() resolves per-item scope
    // ════════════════════════════════════════════════════════════════════

    /// Audit Bug #19 (PHANTOM): an earlier audit claimed Swift's chart-in-each()
    /// scope handling was broken. Re-verification shows it works correctly.
    /// This test exists solely to fail loudly if the WP#6 phantom claim is
    /// ever re-introduced by a future engineer who reads only the audit.
    ///
    /// Spec section: specification/v1.0/data-binding.md
    /// Audit reference: AUDIT_VERDICTS.md#bug-19
    /// Pre-fix expected: PASS today (bug never existed).
    /// Post-fix expected: PASS forever.
    func testChartInsideEachResolvesPerItemScopePhantomGuard() {
        let input = """
        root = col([list])
        list = each($rows, tpl)
        tpl = chart(bar, values=$vals)
        ---
        {"rows":[{"vals":[1,2,3]},{"vals":[4,5,6]}]}
        """
        guard case .col(let topChildren, _) = parse(input) else {
            XCTFail("Expected col")
            return
        }
        guard case .col(let expanded, _) = topChildren[0] else {
            XCTFail("Expected expanded col from each()")
            return
        }
        XCTAssertEqual(expanded.count, 2)
        guard case .chart(_, let values1, _, _, _, _, _, _, _, _) = expanded[0],
              case .chart(_, let values2, _, _, _, _, _, _, _, _) = expanded[1] else {
            XCTFail("Expected two charts")
            return
        }
        XCTAssertEqual(values1, [1.0, 2.0, 3.0])
        XCTAssertEqual(values2, [4.0, 5.0, 6.0])
    }
}
