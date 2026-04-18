package com.agenticmobile.ame

import org.junit.jupiter.api.Assertions.assertDoesNotThrow
import org.junit.jupiter.api.Assertions.assertTimeoutPreemptively
import java.time.Duration
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertIs
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue
import kotlin.test.assertFalse

/**
 * Audit regression tests — Kotlin parser and serializer.
 *
 * Each test corresponds to one row in [AUDIT_VERDICTS.md] at the repo root.
 * Tests are written so that BEFORE a fix is applied the test FAILS
 * (proving the bug), and AFTER the fix is applied the test PASSES
 * (locking in the corrected behavior).
 *
 * See specification/v1.0/regression-protocol.md for the lifecycle rules
 * that govern this file.
 */
class AuditedBugRegressionTest {

    private fun parse(input: String): AmeNode? = AmeParser().parse(input)

    private fun parserFor(input: String): AmeParser {
        val parser = AmeParser()
        parser.parse(input)
        return parser
    }

    // ════════════════════════════════════════════════════════════════════
    // Bug 3 — parseArray and extractParenContent ignore string literals
    // ════════════════════════════════════════════════════════════════════

    /**
     * Audit Bug #3a: parser corrupts component calls when a string literal
     * contains a literal `)` character.
     *
     * Spec section: specification/v1.0/syntax.md (String Literals)
     * Audit reference: AUDIT_VERDICTS.md#bug-3
     * Pre-fix expected: FAIL — extractParenContent stops at the first `)`,
     *   truncating the string content.
     * Post-fix expected: PASS — the inner `)` inside `"..."` is preserved.
     */
    @Test
    fun testParenInsideStringLiteralIsPreserved() {
        val result = parse("""root = txt("a)b", body)""")
        assertNotNull(result, "Parser returned null for valid input")
        assertIs<AmeNode.Txt>(result)
        assertEquals(
            "a)b",
            result.text,
            "Parenthesis inside a string literal must be preserved verbatim"
        )
    }

    /**
     * Audit Bug #3b: parseArray scans only for `]`, ignoring strings, so
     * a `]` inside an array element string ends the array prematurely.
     *
     * Spec section: specification/v1.0/syntax.md (Array Literals, String Literals)
     * Audit reference: AUDIT_VERDICTS.md#bug-3
     * Pre-fix expected: FAIL — array is truncated at the first `]`.
     * Post-fix expected: PASS — `]` inside `"..."` is preserved as content.
     */
    @Test
    fun testBracketInsideStringLiteralIsPreserved() {
        // Use inline form so the `]` is inside an array literal at parse time.
        // This is what actually exercises parseArray's bracket-matching loop.
        val result = parse("""root = col([txt("a]b"), txt("c")])""")
        assertNotNull(result, "Parser must not return null on valid input")
        assertIs<AmeNode.Col>(result)
        assertEquals(2, result.children.size, "Array must contain both elements")
        val first = result.children[0]
        assertIs<AmeNode.Txt>(first)
        assertEquals("a]b", first.text, "Bracket inside string must be preserved")
    }

    /**
     * Audit Bug #3c (deeper coverage of #3a): an escaped quote inside a string
     * literal that is followed by a `)` must not terminate the parenthesized
     * region. Verifies the fix's `escaped` state correctly keeps `inString`
     * across `\"` so the outer `)` is matched at the right depth.
     *
     * Spec section: specification/v1.0/syntax.md (String Literals, escape sequences)
     * Audit reference: AUDIT_VERDICTS.md#bug-3
     * Pre-fix expected: FAIL — extractParenContent flips out of the string at
     *   the literal `"` after the backslash and matches the next `)` early.
     * Post-fix expected: PASS — `\"oops)\"` is preserved verbatim and the
     *   trailing `body` positional argument is intact.
     */
    @Test
    fun testEscapedQuoteFollowedByParenIsPreserved() {
        val result = parse("""root = txt("she said \"oops)\" today", body)""")
        assertNotNull(result, "Parser returned null for valid input")
        assertIs<AmeNode.Txt>(result)
        assertEquals(
            "she said \"oops)\" today",
            result.text,
            "Escaped quotes around a `)` must be preserved verbatim in string content"
        )
        assertEquals(
            TxtStyle.BODY,
            result.style,
            "Trailing `body` positional argument must still be parsed as the style"
        )
    }

    // ════════════════════════════════════════════════════════════════════
    // Bug 6 — Callout AST does not carry the spec-promised color field
    // ════════════════════════════════════════════════════════════════════

    /**
     * Audit Bug #6: primitives.md documents `callout(... color=)` for
     * SemanticColor override, but `AmeNode.Callout` has no `color` field.
     * Parser silently drops the named arg.
     *
     * Spec section: specification/v1.0/primitives.md (Callout, SemanticColor)
     * Audit reference: AUDIT_VERDICTS.md#bug-6
     * Pre-fix expected: FAIL — Callout class has no `color` member.
     * Post-fix expected: PASS — Callout has `color: SemanticColor?` and the
     *   parser populates it from the named arg.
     */
    @Test
    fun testCalloutAcceptsColorParameter() {
        val calloutClass = AmeNode.Callout::class
        val colorMember = calloutClass.members.firstOrNull { it.name == "color" }
        assertNotNull(
            colorMember,
            "AmeNode.Callout must have a `color` member per primitives.md"
        )

        val result = parse("""root = callout(info, "msg", color=success)""")
        assertNotNull(result)
        assertIs<AmeNode.Callout>(result)

        // Reflection-read the color value (avoids compile-time dependency on
        // a member that does not yet exist).
        val readColor = colorMember.call(result)
        assertEquals(
            SemanticColor.SUCCESS,
            readColor,
            "Parser must populate Callout.color from the `color=` named arg"
        )
    }

    // ════════════════════════════════════════════════════════════════════
    // Bug 7 — chart series does not support an array of $path refs
    // ════════════════════════════════════════════════════════════════════

    /**
     * Audit Bug #7: primitives.md example `chart(line, series=[$revenue, $expenses])`
     * implies multi-series via an array of `$path` references.
     * Parser only supports a single `seriesPath` or a literal numeric matrix.
     *
     * Spec section: specification/v1.0/primitives.md (Chart series)
     * Audit reference: AUDIT_VERDICTS.md#bug-7
     * Pre-fix expected: FAIL — series is null or a single empty list because
     *   `$path` array elements are not resolved.
     * Post-fix expected: PASS — series resolves to two lists, one per `$path`.
     */
    @Test
    fun testChartSeriesArrayOfPathRefs() {
        val result = parse("""
            root = chart(line, series=[${"$"}a, ${"$"}b])
            ---
            {"a":[1,2,3],"b":[4,5,6]}
        """.trimIndent())
        assertNotNull(result)
        assertIs<AmeNode.Chart>(result)
        assertEquals(ChartType.LINE, result.type)
        assertNotNull(result.series, "series must resolve from array of \$path refs")
        assertEquals(2, result.series!!.size, "series must contain two paths' data")
        assertEquals(listOf(1.0, 2.0, 3.0), result.series!![0])
        assertEquals(listOf(4.0, 5.0, 6.0), result.series!![1])
    }

    /**
     * Audit Bug #7b (deeper coverage of #7): when an array of $path refs
     * resolves to series of unequal length (e.g., $a=[1,2,3] and $b=[4,5]),
     * the chart must preserve both series verbatim. This mirrors the existing
     * behavior for literal-array series (`series=[[1,2,3],[4,5]]`) and lets
     * the renderer decide how to align the X-axis (per audit Bug #4 — separate
     * work).
     *
     * Spec section: specification/v1.0/primitives.md (Chart series)
     * Audit reference: AUDIT_VERDICTS.md#bug-7
     * Pre-fix expected: FAIL — series is empty/null because $path array
     *   elements are not resolved.
     * Post-fix expected: PASS — series resolves to [[1,2,3],[4,5]]; lengths
     *   are preserved without padding or truncation.
     */
    @Test
    fun testChartSeriesArrayOfPathsAllowsMismatchedLengths() {
        val result = parse("""
            root = chart(line, series=[${"$"}a, ${"$"}b])
            ---
            {"a":[1,2,3],"b":[4,5]}
        """.trimIndent())
        assertNotNull(result, "Parser returned null for valid input")
        assertIs<AmeNode.Chart>(result)
        assertEquals(ChartType.LINE, result.type)
        assertNotNull(result.series, "Mismatched-length series must still resolve")
        assertEquals(2, result.series!!.size, "Both paths must produce a series")
        assertEquals(listOf(1.0, 2.0, 3.0), result.series!![0], "First series preserved verbatim")
        assertEquals(listOf(4.0, 5.0), result.series!![1], "Second series preserved verbatim (no padding)")
    }

    // ════════════════════════════════════════════════════════════════════
    // Bug 8 — streaming parseLine() does not apply --- + JSON data section
    // ════════════════════════════════════════════════════════════════════

    /**
     * Audit Bug #8: streaming.md describes streaming with `---` followed by
     * a JSON data block. `parseLine()` returns null for `---` and never
     * accumulates subsequent JSON lines, so streaming consumers cannot
     * resolve `$path` references.
     *
     * Spec section: specification/v1.0/streaming.md (Data section)
     * Audit reference: AUDIT_VERDICTS.md#bug-8
     * Pre-fix expected: FAIL — `getResolvedTree()` cannot resolve `$x`
     *   because the data section was never ingested via parseLine.
     * Post-fix expected: PASS — streaming a `---` line followed by JSON lines
     *   stores the data model and `$x` resolves to its value.
     */
    @Test
    fun testStreamingModeAppliesDataSection() {
        val parser = AmeParser()
        parser.parseLine("---")
        parser.parseLine("""{"greeting":"hello"}""")
        parser.parseLine("""root = txt(${"$"}greeting)""")

        val resolved = parser.getResolvedTree()
        assertNotNull(resolved, "Streaming parse should produce a tree")
        assertIs<AmeNode.Txt>(resolved)
        assertEquals(
            "hello",
            resolved.text,
            "\$path references emitted via parseLine must resolve against the data section"
        )
    }

    /**
     * Audit Bug #8b (deeper coverage of #8): JSON content MAY span multiple
     * `parseLine()` calls. The buffer is parsed once at `getResolvedTree()`
     * time, so any whitespace introduced between chunks (parsers append a
     * newline per call) does not affect the result.
     *
     * Spec section: specification/v1.0/streaming.md (Streaming Data Sections)
     * Audit reference: AUDIT_VERDICTS.md#bug-8
     * Pre-fix expected: FAIL — `\$x` would not resolve under any chunking.
     * Post-fix expected: PASS — chunked JSON reassembles correctly.
     */
    @Test
    fun testStreamingModeHandlesChunkedJson() {
        val parser = AmeParser()
        parser.parseLine("""root = txt(${"$"}greeting)""")
        parser.parseLine("---")
        parser.parseLine("""{"greeting":""")
        parser.parseLine("""    "hello"""")
        parser.parseLine("}")

        val resolved = parser.getResolvedTree()
        assertNotNull(resolved, "Chunked-JSON streaming parse should produce a tree")
        assertIs<AmeNode.Txt>(resolved)
        assertEquals(
            "hello",
            resolved.text,
            "JSON spanning multiple parseLine() calls must reassemble before resolution"
        )
    }

    // ════════════════════════════════════════════════════════════════════
    // Bug 9 — reserved enum keywords are not enforced as identifiers
    // ════════════════════════════════════════════════════════════════════

    /**
     * Audit Bug #9: syntax.md reserves enum tokens like `display`, `primary`,
     * `line`, `done` as identifiers users MUST NOT define. `AmeKeywords.isReserved()`
     * only blocks primitives, action names, structural keywords, and booleans.
     *
     * Spec section: specification/v1.0/syntax.md (Reserved Keywords)
     * Audit reference: AUDIT_VERDICTS.md#bug-9
     * Pre-fix expected: FAIL — `isReserved("display")` returns false.
     * Post-fix expected: PASS — enum-value identifiers are reserved and
     *   parsing `display = ...` records an error.
     */
    @Test
    fun testEnumValueTokensAreNotReserved() {
        // v1.2 / Bug 9 resolution (Path D): the audit originally claimed the
        // parser was failing to enforce a syntax.md rule that reserved every
        // enum value token. The audit claim was REAL (the parser did not
        // enforce the rule), but the resolution is to retract the spec rule
        // because the parser already disambiguates `title` (LHS identifier)
        // from `title` (TxtStyle enum value at arg position) without
        // ambiguity. This inverted test is the permanent guard against
        // re-introducing the over-aggressive reservation.
        //
        // Per regression-protocol.md §8: weakening an audit regression test
        // requires explicit reviewer sign-off and a rationale. Tech-team
        // sign-off captured in the WP#3 review for Path D.
        assertFalse(
            AmeKeywords.isReserved("display"),
            "TxtStyle.display must NOT be reserved (v1.2 retraction)"
        )
        assertFalse(
            AmeKeywords.isReserved("primary"),
            "BtnStyle.primary / SemanticColor.primary must NOT be reserved"
        )
        assertFalse(
            AmeKeywords.isReserved("done"),
            "TimelineStatus.done must NOT be reserved"
        )
        assertFalse(
            AmeKeywords.isReserved("title"),
            "TxtStyle.title must NOT be reserved (used by 7 conformance fixtures)"
        )
        assertFalse(
            AmeKeywords.isReserved("label"),
            "TxtStyle.label must NOT be reserved (used by conformance/31)"
        )

        // Genuine reserved tokens stay reserved: primitives shadow RHS calls,
        // action names shadow inline action expressions, `each` is the
        // template-iteration keyword, `root` is the resolver entry point,
        // and boolean literals shadow value parsing.
        assertTrue(AmeKeywords.isReserved("txt"), "Standard primitive 'txt' stays reserved")
        assertTrue(AmeKeywords.isReserved("tool"), "Action name 'tool' stays reserved")
        assertTrue(AmeKeywords.isReserved("each"), "Structural keyword 'each' stays reserved")
        assertTrue(AmeKeywords.isReserved("root"), "Structural keyword 'root' stays reserved")
        assertTrue(AmeKeywords.isReserved("true"), "Boolean literal 'true' stays reserved")

        // The parser MUST accept enum value tokens as identifiers and resolve
        // them like any other reference. This is the round-trip behavior the
        // 7 `title = ...` and 1 `label = ...` conformance fixtures rely on.
        val parser = AmeParser()
        parser.parseLine("""title = txt("Welcome", title)""")
        parser.parseLine("""root = col([title])""")
        val resolved = parser.getResolvedTree()
        assertNotNull(resolved, "Parser must accept enum value tokens as identifiers")
        assertIs<AmeNode.Col>(resolved)
        assertEquals(1, resolved.children.size)
        val first = resolved.children[0]
        assertIs<AmeNode.Txt>(first)
        assertEquals("Welcome", first.text, "title identifier must resolve to its txt value")
        assertEquals(
            TxtStyle.TITLE,
            first.style,
            "title at arg-position must still resolve to TxtStyle.TITLE (parser disambiguates by position)"
        )
        assertTrue(
            parser.errors.isEmpty(),
            "Parser must not record errors for enum-value identifiers; got: ${parser.errors}"
        )
    }

    // ════════════════════════════════════════════════════════════════════
    // Bug 11 — circular ref chain crashes the parser with stack overflow
    // ════════════════════════════════════════════════════════════════════

    /**
     * Audit Bug #11: `resolveTree` follows `Ref` nodes recursively without
     * a visited set or depth limit. A registry containing `a = b`, `b = a`
     * causes infinite recursion and a StackOverflowError.
     *
     * Spec section: specification/v1.0/syntax.md (Forward references, depth)
     * Audit reference: AUDIT_VERDICTS.md#bug-11
     * Pre-fix expected: FAIL — parse() throws StackOverflowError or hangs.
     * Post-fix expected: PASS — parser detects the cycle, records a warning,
     *   and returns within a reasonable time without crashing.
     */
    @Test
    fun testCircularRefDoesNotStackOverflow() {
        assertTimeoutPreemptively(Duration.ofSeconds(2)) {
            assertDoesNotThrow {
                val parser = AmeParser()
                parser.parseLine("a = b")
                parser.parseLine("b = a")
                parser.parseLine("root = a")
                // Should not throw StackOverflowError; result may be a
                // ref-loop placeholder or the original ref node.
                parser.getResolvedTree()
            }
        }
    }

    /**
     * Audit Bug #11b (deeper coverage of #11): the diamond ref pattern
     * (`root = col([a, b])`, `a = c`, `b = c`, `c = txt("shared")`) where
     * two distinct refs both point at the same node is NOT a cycle and must
     * resolve correctly. Verifies that the visited set in resolveTree is
     * scoped per branch (immutable per call), not shared across siblings.
     *
     * Spec section: specification/v1.0/syntax.md (Forward references)
     * Audit reference: AUDIT_VERDICTS.md#bug-11
     * Pre-fix expected: PASS (the bug was stack overflow on cycles, not on
     *   diamonds; this test guards against an over-eager fix that would
     *   incorrectly flag diamonds as cycles).
     * Post-fix expected: PASS — both children resolve to the shared txt node.
     */
    @Test
    fun testDiamondRefPatternResolvesCorrectly() {
        val parser = AmeParser()
        parser.parseLine("c = txt(\"shared\")")
        parser.parseLine("a = c")
        parser.parseLine("b = c")
        parser.parseLine("root = col([a, b])")

        val resolved = parser.getResolvedTree()
        assertNotNull(resolved, "Diamond ref pattern should resolve cleanly")
        assertIs<AmeNode.Col>(resolved)
        assertEquals(2, resolved.children.size, "Both children must be present")
        val first = resolved.children[0]
        val second = resolved.children[1]
        assertIs<AmeNode.Txt>(first)
        assertIs<AmeNode.Txt>(second)
        assertEquals("shared", first.text, "First diamond branch must resolve to the shared txt")
        assertEquals("shared", second.text, "Second diamond branch must resolve to the shared txt")
    }

    // ════════════════════════════════════════════════════════════════════
    // Bug 13 — input-ref regex does not accept hyphenated field IDs
    // ════════════════════════════════════════════════════════════════════

    /**
     * Audit Bug #13: the `${'$'}{input.fieldId}` substitution regex is
     * `\$\{input\.(\w+)\}`. `\w` excludes `-`, so hyphenated field IDs like
     * `user-name` are silently rejected.
     *
     * Spec section: specification/v1.0/actions.md (Input references)
     * Audit reference: AUDIT_VERDICTS.md#bug-13
     * Pre-fix expected: FAIL — substitution does not occur for hyphenated ID.
     * Post-fix expected: PASS — `user-name` field substitutes correctly.
     *
     * Note: this Kotlin-side test exercises the parser's tolerance for
     * hyphenated field IDs in `input(...)` calls. The actual substitution
     * happens in `ame-compose/AmeFormState.kt` (covered by
     * `ame-compose/.../AuditedBugRegressionTest.testInputRefRegexAcceptsHyphenatedIds`).
     * This test confirms the parser accepts hyphenated identifiers in input
     * id positions in the first place.
     */
    @Test
    fun testParserAcceptsHyphenatedInputIds() {
        // Parser is currently strict: identifiers must start with isLetter().
        // Hyphens inside input id arguments (string-quoted) should be fine.
        val result = parse("""root = input("user-name", "Your name")""")
        assertNotNull(result)
        assertIs<AmeNode.Input>(result)
        assertEquals(
            "user-name",
            result.id,
            "Parser must accept hyphenated input id strings"
        )
    }

    // ════════════════════════════════════════════════════════════════════
    // Bug 15 — AmeSerializer.fromJson swallows decode failures into null
    // ════════════════════════════════════════════════════════════════════

    /**
     * Audit Bug #15: `AmeSerializer.fromJson(invalidJson)` returns null with
     * no diagnostic. Hosts cannot distinguish invalid JSON from schema mismatch
     * from missing root.
     *
     * Spec section: specification/v1.0/integration.md (Serialization)
     * Audit reference: AUDIT_VERDICTS.md#bug-15
     * Pre-fix expected: FAIL — `fromJsonOrError` API does not exist; only
     *   `fromJson` returning nullable exists, with no diagnostic.
     * Post-fix expected: PASS — a diagnostic API exists that returns either
     *   the decoded node or a structured error describing why decoding failed.
     */
    @Test
    fun testSerializerReturnsDistinguishableErrorOnInvalidJson() {
        // Today: only `fromJson(String): AmeNode?` exists. Both `null` and a
        // valid decoding fall on the same return type with no diagnostic.
        val nullResult = AmeSerializer.fromJson("{")
        assertNull(nullResult, "Invalid JSON must not produce a node")

        // The fix should add a `fromJsonOrError(String): Result<AmeNode>`
        // (or sealed sealed-class equivalent) that surfaces the failure reason.
        val serializerClass = AmeSerializer::class
        val diagnosticApi = serializerClass.members.firstOrNull {
            it.name == "fromJsonOrError" || it.name == "fromJsonResult"
        }
        assertNotNull(
            diagnosticApi,
            "AmeSerializer must expose a diagnostic decoding API per Bug 15"
        )
    }

    // ════════════════════════════════════════════════════════════════════
    // Bug 19 — phantom: chart inside each() resolves per-item scope (NOT REAL)
    // ════════════════════════════════════════════════════════════════════

    /**
     * Audit Bug #19 (PHANTOM): an earlier audit claimed Kotlin's chart-in-each()
     * scope handling was broken. Re-verification shows the existing test
     * `AmeParserTest.chartInsideEachResolvesPerItemScope` and conformance case
     * `52-each-chart-binding` already cover this and pass. This test exists
     * solely to fail loudly if the WP#6 phantom claim is ever re-introduced
     * by a future engineer who reads only the original audit report.
     *
     * Spec section: specification/v1.0/data-binding.md
     * Audit reference: AUDIT_VERDICTS.md#bug-19
     * Pre-fix expected: PASS today (bug never existed).
     * Post-fix expected: PASS forever.
     */
    @Test
    fun testChartInsideEachResolvesPerItemScopePhantomGuard() {
        val parser = AmeParser()
        val result = parser.parse("""
            root = col([list])
            list = each(${"$"}rows, tpl)
            tpl = chart(bar, values=${"$"}vals)
            ---
            {"rows":[{"vals":[1,2,3]},{"vals":[4,5,6]}]}
        """.trimIndent())

        assertNotNull(result)
        assertIs<AmeNode.Col>(result)
        val expanded = result.children[0]
        assertIs<AmeNode.Col>(expanded)
        assertEquals(2, expanded.children.size)
        val chart1 = expanded.children[0]
        val chart2 = expanded.children[1]
        assertIs<AmeNode.Chart>(chart1)
        assertIs<AmeNode.Chart>(chart2)
        assertEquals(listOf(1.0, 2.0, 3.0), chart1.values)
        assertEquals(listOf(4.0, 5.0, 6.0), chart2.values)
    }
}
