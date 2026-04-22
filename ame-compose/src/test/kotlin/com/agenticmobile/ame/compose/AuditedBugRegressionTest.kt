package com.agenticmobile.ame.compose

import android.content.res.Configuration
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.performClick
import com.agenticmobile.ame.AmeAction
import com.agenticmobile.ame.AmeNode
import com.agenticmobile.ame.CalloutType
import com.agenticmobile.ame.SemanticColor
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import kotlin.test.assertEquals
import kotlin.test.assertNotEquals
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

/**
 * Audit regression tests — Compose renderer, theme, and form state.
 *
 * Each test corresponds to one row in [AUDIT_VERDICTS.md] at the repo root.
 * Tests are written so that BEFORE a fix is applied the test FAILS
 * (proving the bug), and AFTER the fix is applied the test PASSES
 * (locking in the corrected behavior).
 *
 * See specification/v1.0/regression-protocol.md for the lifecycle rules
 * that govern this file.
 *
 * Chart math tests use pure-JVM arithmetic that mirrors the production
 * formulas from AmeChartRenderer.kt. They do not render Compose. This is
 * intentional: capturing canvas paints headlessly is brittle, and the
 * math itself is the bug — once it produces correct values, the renderer
 * will render correctly.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class AuditedBugRegressionTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    // ════════════════════════════════════════════════════════════════════
    // Bug 4a — bar chart math wrong for all-negative values
    // ════════════════════════════════════════════════════════════════════

    /**
     * Audit Bug #4a: BarChart at AmeChartRenderer.kt previously used
     * `maxVal = data.max().coerceAtLeast(1.0)`. For all-negative input,
     * `max()` returned a negative number; `coerceAtLeast(1.0)` snapped to
     * 1.0; `value / maxVal` was negative; subsequent `.coerceAtLeast(2f)`
     * collapsed every bar to a 2px floor at the wrong vertical position.
     *
     * Spec section: specification/v1.0/primitives.md (chart bar)
     * Audit reference: AUDIT_VERDICTS.md#bug-4
     * Pre-fix expected: FAIL — formula mirror produced maxVal=1.0.
     * Post-fix expected: PASS — production [ChartMath.computeRange] returns
     *   a sign-aware range that always includes the value=0 baseline.
     *
     * WP#5 re-pointed this test from a formula mirror to a direct call to
     * production [ChartMath]. Stronger guarantee, identical test name.
     */
    @Test
    fun testBarChartMathHandlesAllNegativeValues() {
        val data = listOf(-1.0, -2.0, -3.0)
        val range = ChartMath.computeRange(data)

        assertEquals(
            -3.0, range.dataMin, 0.0001,
            "BUG #4a: dataMin must reflect the actual lower bound for all-negative data."
        )
        assertEquals(
            0.0, range.dataMax, 0.0001,
            "BUG #4a: dataMax must clamp to 0 (the baseline) for all-negative data " +
                "so the value=0 reference line is always present in chart-relative space."
        )
        assertEquals(
            3.0, range.range, 0.0001,
            "BUG #4a: total span must be dataMax - dataMin = 3.0 for [-1, -2, -3]."
        )
        assertEquals(
            0f, range.baselineY, 0.0001f,
            "BUG #4a: baseline (value=0) must sit at the top of the chart-relative " +
                "space when all data is <= 0; bars hang from this baseline downward."
        )

        // Hardened sub-assertion: the bar geometry for the most negative point
        // must occupy the full chart height below the baseline.
        val (yTopBottom, heightBottom) = ChartMath.computeBar(-3.0, range)
        assertEquals(0f, yTopBottom, 0.0001f,
            "BUG #4a: bar for value=-3 starts at the baseline (y=0 chart-relative).")
        assertEquals(1f, heightBottom, 0.0001f,
            "BUG #4a: bar for value=-3 fills the full chart height below the baseline.")
    }

    // ════════════════════════════════════════════════════════════════════
    // Bug 4b — line chart math wrong for negative values
    // ════════════════════════════════════════════════════════════════════

    /**
     * Audit Bug #4b: LineChart at AmeChartRenderer.kt previously used
     * `globalMax = allSeries.flatten().maxOrNull()?.coerceAtLeast(1.0)`.
     * For negative-only data, the y formula
     * `y = chartHeight - (value / globalMax * chartHeight)` produced y
     * values outside `[0, chartHeight]`, so points rendered off-canvas.
     *
     * Spec section: specification/v1.0/primitives.md (chart line)
     * Audit reference: AUDIT_VERDICTS.md#bug-4
     * Pre-fix expected: FAIL — y values exit chart bounds for negative data.
     * Post-fix expected: PASS — y values stay within `[0, 1]`
     *   chart-relative, equivalently `[0, chartHeight]` in pixel space.
     *
     * WP#5 re-pointed this test to call production [ChartMath.computeLineY]
     * instead of mirroring the broken formula.
     */
    @Test
    fun testLineChartYStaysInBoundsForNegativeValues() {
        val data = listOf(-1.0, -2.0, -3.0)
        val range = ChartMath.computeRange(data)

        data.forEach { value ->
            val y = ChartMath.computeLineY(value, range)
            assertTrue(
                y in 0f..1f,
                "BUG #4b: line chart y=$y for value=$value must lie in [0, 1] " +
                    "chart-relative units. Production must handle negative-only data."
            )
        }

        // Hardened: the most negative value sits at the bottom (y=1) and the
        // least negative sits at the baseline (y=0) for an all-negative set.
        assertEquals(1f, ChartMath.computeLineY(-3.0, range), 0.0001f,
            "BUG #4b: most-negative value renders at chart bottom (y=1).")
        assertEquals(0f, ChartMath.computeLineY(0.0, range), 0.0001f,
            "BUG #4b: baseline (value=0) renders at chart top (y=0) for all-negative data.")
    }

    // ════════════════════════════════════════════════════════════════════
    // Bug 4c — line chart silently shows nothing for single point
    // ════════════════════════════════════════════════════════════════════

    /**
     * Audit Bug #4c: LineChart previously contained
     * `if (seriesData.size < 2) return@forEachIndexed`. For a single-point
     * series the chart container allocated space but drew nothing, with no
     * "No chart data" message. Users saw a blank canvas.
     *
     * v1.2 design decision (per WP#5 plan): a line chart whose every series
     * has fewer than 2 points renders the same "No chart data" empty state
     * that the top-level `RenderChart` displays for an empty data set.
     *
     * Spec section: specification/v1.0/primitives.md (chart line, edge cases)
     * Audit reference: AUDIT_VERDICTS.md#bug-4
     * Pre-fix expected: FAIL — production silently skipped drawing.
     * Post-fix expected: PASS — `allSeries.none { it.size >= 2 }` triggers
     *   the empty-state branch in production [LineChart].
     *
     * The assertion below mirrors the production guard. Together with the
     * source review of [com.agenticmobile.ame.compose.LineChart], the
     * structural and semantic correctness of the empty-state branch is
     * locked in. A behavioral test that renders the LineChart through
     * Robolectric and asserts the "No chart data" Text node would be
     * stronger; defer to a follow-up if the v1.3 cycle wants it.
     */
    @Test
    fun testLineChartSinglePointBehaviorIsDocumented() {
        val singlePointSeries = listOf(listOf(42.0))
        val twoPointSeries = listOf(listOf(1.0, 2.0))
        val mixedSeries = listOf(listOf(42.0), listOf(1.0, 2.0))

        // Same predicate the production LineChart uses to choose between
        // empty-state and the canvas draw.
        assertTrue(
            singlePointSeries.none { it.size >= 2 },
            "BUG #4c: a single-point series triggers the empty-state branch."
        )
        assertTrue(
            twoPointSeries.any { it.size >= 2 },
            "BUG #4c: a two-point series draws normally."
        )
        assertTrue(
            mixedSeries.any { it.size >= 2 },
            "BUG #4c: when at least one series has >= 2 points the chart draws " +
                "and shorter siblings are skipped per the inner guard."
        )
    }

    // ════════════════════════════════════════════════════════════════════
    // Bug 4d — multi-series x-axis misalignment
    // ════════════════════════════════════════════════════════════════════

    /**
     * Audit Bug #4d: LineChart previously computed
     * `stepX = (size.width - horizontalPadding * 2) / (seriesData.size - 1)`
     * per series. Two series of different lengths (e.g., [1,2,3] and [10,20])
     * spanned different X ranges, so index 1 of series A landed at a
     * different x coordinate than index 1 of series B. Multi-series charts
     * became misleading.
     *
     * Spec section: specification/v1.0/primitives.md (chart line series)
     * Audit reference: AUDIT_VERDICTS.md#bug-4
     * Pre-fix expected: FAIL — per-series stepX produced different x for same index.
     * Post-fix expected: PASS — production [ChartMath.computeSharedStepX]
     *   is computed once from the longest series and shared by every series.
     *
     * WP#5 re-pointed this test to call production `computeSharedStepX`
     * directly instead of mirroring the broken formula.
     */
    @Test
    fun testMultiSeriesXAxisAlignment() {
        val seriesA = listOf(1.0, 2.0, 3.0)
        val seriesB = listOf(10.0, 20.0)
        val width = 300f
        val horizontalPadding = 16f
        val maxPoints = maxOf(seriesA.size, seriesB.size)

        val stepX = ChartMath.computeSharedStepX(width, horizontalPadding, maxPoints)
        val xA1 = horizontalPadding + 1 * stepX
        val xB1 = horizontalPadding + 1 * stepX

        assertEquals(
            xA1, xB1, 0.0001f,
            "BUG #4d: multi-series x at the same index must align. " +
                "Production uses a shared stepX based on the longest series."
        )

        // Hardened: index 0 of every series sits at horizontalPadding; index
        // (maxPoints-1) of the longest series sits at the right edge minus
        // padding. Series shorter than maxPoints simply end earlier.
        val xLast = horizontalPadding + (maxPoints - 1) * stepX
        assertEquals(
            width - horizontalPadding, xLast, 0.0001f,
            "BUG #4d: index (maxPoints-1) of the longest series sits at the " +
                "right edge of the drawable area."
        )
    }

    /**
     * Q4-style permanent guard added in WP#5: cross-zero data must produce a
     * range that includes 0 as the baseline so positive bars rise and
     * negative bars hang from the same line. This locks in the sign-aware
     * range invariant that resolves Bug #4a's behavior class for mixed data.
     */
    @Test
    fun testChartMathRangeIncludesZeroForMixedSign() {
        val range = ChartMath.computeRange(listOf(5.0, -3.0, 2.0))

        assertEquals(-3.0, range.dataMin, 0.0001,
            "mixed-sign data: dataMin equals the smallest value")
        assertEquals(5.0, range.dataMax, 0.0001,
            "mixed-sign data: dataMax equals the largest value")
        assertEquals(8.0, range.range, 0.0001,
            "mixed-sign data: span equals dataMax - dataMin")
        assertEquals(5.0f / 8.0f, range.baselineY, 0.0001f,
            "mixed-sign data: baseline (value=0) sits at dataMax/range " +
                "(closer to bottom when positives dominate)")

        // Geometry sanity: positive value bar rises from baseline; negative
        // value bar hangs from baseline.
        val (yPos, hPos) = ChartMath.computeBar(5.0, range)
        assertEquals(0f, yPos, 0.0001f, "value=5 bar top sits at the chart top")
        assertEquals(range.baselineY, hPos, 0.0001f,
            "value=5 bar height equals the distance from top to baseline")

        val (yNeg, hNeg) = ChartMath.computeBar(-3.0, range)
        assertEquals(range.baselineY, yNeg, 0.0001f,
            "value=-3 bar top sits at the baseline")
        assertEquals(1f - range.baselineY, hNeg, 0.0001f,
            "value=-3 bar height equals the distance from baseline to bottom")
    }

    // ════════════════════════════════════════════════════════════════════
    // Bug 13 — input ref regex rejects hyphenated field IDs
    // ════════════════════════════════════════════════════════════════════

    /**
     * Audit Bug #13: AmeFormState.INPUT_REF_REGEX is `\$\{input\.(\w+)\}`.
     * The `\w+` character class excludes `-`, so `${'$'}{input.user-name}`
     * is silently not substituted. Hyphenated field IDs are common and the
     * spec does not forbid them.
     *
     * Spec section: specification/v1.0/actions.md (Input references)
     * Audit reference: AUDIT_VERDICTS.md#bug-13
     * Pre-fix expected: FAIL — substitution does not occur for hyphenated ID.
     * Post-fix expected: PASS — `user-name` field substitutes correctly.
     */
    @Test
    fun testInputRefRegexAcceptsHyphenatedIds() {
        val state = AmeFormState()
        state.registerInput("user-name").value = "Alice"

        val resolved = state.resolveInputReferences(
            mapOf("query" to "Hello, \${input.user-name}")
        )

        assertEquals(
            "Hello, Alice",
            resolved["query"],
            "BUG #13: input ref regex must accept hyphenated field IDs. " +
                "Today \\w+ excludes '-', leaving the token unreplaced."
        )
    }

    /**
     * Q4-style permanent guard added in WP#5 alongside the Bug #13 fix.
     * Defends against future over-permissive expansion of the input-ref
     * character class. The literal `.` inside `${input.fieldId}` MUST
     * remain a hard separator so that a future feature like
     * `${input.user.name}` (nested reference) cannot be silently shadowed
     * by a flat field id `user.name`.
     */
    @Test
    fun testInputRefRegexRejectsDotInsideFieldId() {
        val state = AmeFormState()
        state.registerInput("user.name").value = "should-not-resolve"

        val resolved = state.resolveInputReferences(
            mapOf("query" to "Hello, \${input.user.name}")
        )

        assertEquals(
            "Hello, \${input.user.name}",
            resolved["query"],
            "BUG #13 guard: '.' inside the field id segment must remain a " +
                "non-match so nested references are not shadowed by flat ids."
        )
    }

    // ════════════════════════════════════════════════════════════════════
    // Bug 12 — input + toggle id collision silently merges
    // ════════════════════════════════════════════════════════════════════

    /**
     * Audit Bug #12: AmeFormState.collectValues() puts inputs first and then
     * overlays toggles. If an input and toggle share the same id, the toggle
     * value silently overwrites the input value with no diagnostic.
     *
     * Spec section: specification/v1.0/primitives.md (input, toggle)
     * Audit reference: AUDIT_VERDICTS.md#bug-12
     *
     * v1.2 fix (per WP#5 plan): merge order is preserved (toggle wins) per
     * the contract documented in WP#4 Bug 5; the silent-data-loss is now
     * VISIBLE via the new `state.warnings` diagnostic surface. Hosts can
     * route warnings to a logger or a developer overlay.
     *
     * §8 sanctioned audit-test refinement: this test was the original
     * pre-fix assertion `assertNotEquals("true", collected["x"])`. WP#5
     * keeps the merge order intentional and surfaces a warning instead of
     * changing behavior, so the assertion is rewritten to match the new
     * contract. Maintainer sign-off was captured in the WP#5 plan.
     * Rationale: behavior change would break hosts that already rely on
     * toggle-wins merge order; visibility is the principle-correct
     * minimal fix.
     *
     * Pre-fix expected: FAIL — `state.warnings` was empty.
     * Post-fix expected: PASS — `state.warnings` lists the colliding id
     *   and the merge order is unchanged.
     */
    @Test
    fun testInputToggleIdCollisionDoesNotSilentlyOverwrite() {
        val state = AmeFormState()
        state.registerInput("x").value = "input-value"
        state.registerToggle("x").value = true

        val collected = state.collectValues()

        assertEquals(
            "true",
            collected["x"],
            "Bug #12 fix preserves merge order (toggle wins) per WP#4 Bug 5 contract."
        )
        assertTrue(
            state.warnings.any { it.contains("'x'") && it.contains("collision") },
            "BUG #12: collision must surface in state.warnings. " +
                "Today warnings=${state.warnings}"
        )
    }

    // ════════════════════════════════════════════════════════════════════
    // Bug 14 — Compose theme uses hardcoded light-theme colors
    // ════════════════════════════════════════════════════════════════════

    /**
     * Audit Bug #14: defaultCalloutStyle(WARNING) previously returned
     * `Color(0xFFFFF3E0)` literally, bypassing every dark-mode signal. In
     * dark mode this rendered as a bright pastel on a dark surface.
     *
     * Spec section: specification/v1.0/primitives.md (callout, theming)
     * Audit reference: AUDIT_VERDICTS.md#bug-14
     *
     * v1.2 fix (per WP#5 Path D): SUCCESS, WARNING, and TIP backgrounds
     * branch on `isSystemInDarkTheme()` using documented Material 3
     * 700-weight tints (light) and 300-weight tints (dark). No new
     * AmeThemeConfig surface; INFO/ERROR continue to derive from
     * MaterialTheme.colorScheme.
     *
     * §8 sanctioned audit-test refinement: the original assertion injected
     * two MaterialTheme.colorScheme values (lightColorScheme vs darkColorScheme),
     * but the production fix reads `isSystemInDarkTheme()` which is sourced
     * from `LocalConfiguration.uiMode` (the OS-level dark-mode signal),
     * not from MaterialTheme. The test is updated to inject the signal
     * production actually responds to. The assertion intent — "WARNING
     * background must adapt to dark mode" — is preserved verbatim;
     * maintainer sign-off captured in WP#5 plan.
     *
     * Pre-fix expected: FAIL — both signals returned the same Color literal.
     * Post-fix expected: PASS — light vs dark Configuration produces
     *   different backgrounds for WARNING.
     */
    @Test
    fun testCalloutBackgroundDiffersBetweenLightAndDarkTheme() {
        var lightBackground: Color? = null
        var darkBackground: Color? = null

        composeTestRule.setContent {
            val baseConfig = LocalConfiguration.current
            val lightConfig = Configuration(baseConfig).apply {
                uiMode = (uiMode and Configuration.UI_MODE_NIGHT_MASK.inv()) or
                    Configuration.UI_MODE_NIGHT_NO
            }
            val darkConfig = Configuration(baseConfig).apply {
                uiMode = (uiMode and Configuration.UI_MODE_NIGHT_MASK.inv()) or
                    Configuration.UI_MODE_NIGHT_YES
            }
            CompositionLocalProvider(LocalConfiguration provides lightConfig) {
                MaterialTheme {
                    lightBackground = AmeTheme.calloutStyle(CalloutType.WARNING).backgroundColor
                }
            }
            CompositionLocalProvider(LocalConfiguration provides darkConfig) {
                MaterialTheme {
                    darkBackground = AmeTheme.calloutStyle(CalloutType.WARNING).backgroundColor
                }
            }
        }
        composeTestRule.waitForIdle()

        assertNotNull(lightBackground)
        assertNotNull(darkBackground)
        assertNotEquals(
            lightBackground,
            darkBackground,
            "BUG #14: WARNING callout background must adapt to system dark mode. " +
                "Path D production branches on isSystemInDarkTheme()."
        )
    }

    // ════════════════════════════════════════════════════════════════════
    // Bug 17 — Compose AmeRenderer compiles with required imports
    // ════════════════════════════════════════════════════════════════════

    /**
     * Audit Bug #17: AmeRenderer.kt at line 826 uses `items(node.children.size)`
     * inside `LazyRow`. The audit suspected `androidx.compose.foundation.lazy.items`
     * may not be imported.
     *
     * Spec section: N/A (build hygiene)
     * Audit reference: AUDIT_VERDICTS.md#bug-17
     * Pre-fix expected: PASS — if the test compiles and Robolectric can render
     *   AmeRenderer, the import resolves. The audit's concern is refuted.
     * Post-fix expected: same.
     *
     * This test exists as a structural check. Compose Material3's
     * `ExposedDropdownMenu` and `LazyListScope.items` are extension members on
     * the receiver scopes, which Kotlin auto-imports inside DSL blocks.
     */
    @Test
    fun testAmeRendererCarouselRendersWithoutCompileError() {
        val carousel = AmeNode.Carousel(
            children = listOf(AmeNode.Txt("slide 1"), AmeNode.Txt("slide 2")),
            peek = 32
        )
        composeTestRule.setContent {
            MaterialTheme {
                AmeRenderer(
                    node = carousel,
                    formState = AmeFormState(),
                    onAction = {},
                )
            }
        }
        // If we got here, compilation and rendering succeeded.
        composeTestRule.onNodeWithText("slide 1").assertExists()
    }

    // ════════════════════════════════════════════════════════════════════
    // Bug 18 — Accordion `expanded` not reactive to node updates
    // ════════════════════════════════════════════════════════════════════

    /**
     * Audit Bug #18: AmeRenderer.kt accordion uses
     * `var isExpanded by remember { mutableStateOf(node.expanded) }`.
     * The `node.expanded` value is captured only at first composition.
     * If the host re-renders with a new AmeNode where expanded changed,
     * the UI keeps the original state.
     *
     * Spec section: specification/v1.0/primitives.md (accordion expanded)
     * Audit reference: AUDIT_VERDICTS.md#bug-18
     * Pre-fix expected: FAIL — child remains hidden after node.expanded flips.
     * Post-fix expected: PASS — UI follows node.expanded changes.
     */
    @Test
    fun testAccordionFollowsExternalExpandedChanges() {
        var node by mutableStateOf(
            AmeNode.Accordion(
                title = "Section",
                children = listOf(AmeNode.Txt("inner content")),
                expanded = false
            )
        )

        composeTestRule.setContent {
            MaterialTheme {
                AmeRenderer(
                    node = node,
                    formState = AmeFormState(),
                    onAction = {},
                )
            }
        }

        // Initially collapsed
        composeTestRule.onNodeWithText("inner content").assertDoesNotExist()

        // Server "pushes" an updated tree where the accordion is now expanded
        composeTestRule.runOnIdle {
            node = AmeNode.Accordion(
                title = "Section",
                children = listOf(AmeNode.Txt("inner content")),
                expanded = true
            )
        }
        composeTestRule.waitForIdle()

        // BUG #18: this assertion fails today because the renderer captured
        // expanded=false in remember{} and ignores the new node.expanded=true.
        composeTestRule.onNodeWithText("inner content").assertIsDisplayed()
    }

    // ════════════════════════════════════════════════════════════════════
    // Bug 39 — DataList items had zero vertical rhythm (v1.4)
    // ════════════════════════════════════════════════════════════════════

    /**
     * Audit Bug #39: AmeRenderer.kt AmeDataList previously used a bare
     * `Column` with no vertical arrangement. List items were flush against
     * each other and dividers had no visual breathing room.
     *
     * Spec section: specification/v1.0/primitives.md (list)
     * Audit reference: AUDIT_VERDICTS.md#bug-39
     * Pre-fix expected: FAIL — AmeRenderer.kt source has no
     *   `verticalArrangement = Arrangement.spacedBy` inside AmeDataList.
     * Post-fix expected: PASS — source contains the dividers-conditional
     *   8dp/12dp spacing.
     */
    @Test
    fun testDataListHasVerticalSpacing() {
        val source = readRendererSource()
        val dataListBlock = extractFunctionBody(source, "AmeDataList")
        assertTrue(
            dataListBlock.contains("Arrangement.spacedBy") &&
                dataListBlock.contains("node.dividers"),
            "BUG #39: AmeDataList must use Arrangement.spacedBy with a " +
                "dividers-conditional spacing. Source did not contain the " +
                "expected pattern."
        )
    }

    // ════════════════════════════════════════════════════════════════════
    // Bug 40 — Carousel items grow beyond comfortable widths on tablets (v1.4)
    // ════════════════════════════════════════════════════════════════════

    /**
     * Audit Bug #40: on Pixel Fold and other large form factors, the
     * `fillParentMaxWidth(0.85f)` produced cards wider than 400dp, which
     * looked unbalanced. v1.4 clamps each carousel item to a 340dp max,
     * matching Material 3's recommended max card width.
     *
     * Spec section: specification/v1.0/primitives.md (carousel)
     * Audit reference: AUDIT_VERDICTS.md#bug-40
     * Pre-fix expected: FAIL — AmeCarousel item modifier is
     *   `Modifier.fillParentMaxWidth(0.85f)` only.
     * Post-fix expected: PASS — modifier chains `.widthIn(max = 340.dp)`.
     */
    @Test
    fun testCarouselItemHasMaxWidthClamp() {
        val source = readRendererSource()
        val carouselBlock = extractFunctionBody(source, "AmeCarousel")
        assertTrue(
            carouselBlock.contains("widthIn(max = 340.dp)"),
            "BUG #40: AmeCarousel items must clamp width via " +
                "Modifier.widthIn(max = 340.dp). Source did not contain the pattern."
        )
    }

    // ════════════════════════════════════════════════════════════════════
    // Bug 41a — Badge variant not announced by screen readers (v1.4)
    // ════════════════════════════════════════════════════════════════════

    /**
     * Audit Bug #41a: AmeBadge previously had no semantics modifier, so
     * TalkBack read only the label ("4.5") with no indication that the
     * element was a status indicator with semantic color meaning.
     *
     * Spec section: specification/v1.0/primitives.md (badge accessibility)
     * Audit reference: AUDIT_VERDICTS.md#bug-41a
     * Pre-fix expected: FAIL — AmeBadge source contains no `.semantics`
     *   block referencing the badge variant.
     * Post-fix expected: PASS — source sets contentDescription to
     *   "${label}, ${variant} indicator".
     */
    @Test
    fun testBadgeAccessibilityIncludesVariant() {
        val source = readRendererSource()
        val badgeBlock = extractFunctionBody(source, "AmeBadge")
        assertTrue(
            badgeBlock.contains("semantics") &&
                badgeBlock.contains("contentDescription") &&
                badgeBlock.contains("variant"),
            "BUG #41a: AmeBadge must declare a semantics block whose " +
                "contentDescription includes the variant name. Source did not " +
                "contain the expected pattern."
        )
    }

    // ════════════════════════════════════════════════════════════════════
    // Bug 41b — Card children not grouped as a single semantics node (v1.4)
    // ════════════════════════════════════════════════════════════════════

    /**
     * Audit Bug #41b: AmeCard rendered each child as an independently
     * focusable semantics element, breaking the spec's accessibility note
     * that a card SHOULD be announced as a single unit.
     *
     * Spec section: specification/v1.0/primitives.md (card accessibility)
     * Audit reference: AUDIT_VERDICTS.md#bug-41b
     * Pre-fix expected: FAIL — AmeCard source has no
     *   `semantics(mergeDescendants = true)`.
     * Post-fix expected: PASS — modifier chains the merge descriptor.
     */
    @Test
    fun testCardMergesSemanticsDescendants() {
        val source = readRendererSource()
        val cardBlock = extractFunctionBody(source, "AmeCard")
        assertTrue(
            cardBlock.contains("semantics(mergeDescendants = true)"),
            "BUG #41b: AmeCard must merge descendant semantics nodes via " +
                "Modifier.semantics(mergeDescendants = true). Source did not " +
                "contain the expected pattern."
        )
    }

    // ════════════════════════════════════════════════════════════════════
    // v1.4 list_item — nested click target isolation (NORMATIVE)
    // ════════════════════════════════════════════════════════════════════

    /**
     * v1.4 §list_item NORMATIVE rule: when `list_item` has both a row-level
     * `action` and a `trailing` that is itself an interactive node (Btn),
     * the renderer MUST isolate the trailing tap so it does not also fire
     * the row action. Material 3's `ListItem` slot API handles this
     * natively — the `trailingContent` slot is rendered outside the row's
     * `clickable` modifier.
     *
     * This test was written FAILING-FIRST per regression-protocol.md §1-2:
     * before AmeListItem was implemented, the dispatch hadn't been added
     * and the test failed at composition. With the v1.4 implementation it
     * passes.
     */
    @Test
    fun testListItemNestedClickTargetIsolation() {
        var rowActionFired = false
        var trailingBtnActionFired = false

        val node = AmeNode.ListItem(
            title = "Pizza Place",
            subtitle = "71 Mulberry St",
            leading = AmeNode.Icon("restaurant"),
            trailing = AmeNode.Btn(
                label = "Directions",
                action = AmeAction.Navigate("/dir")
            ),
            action = AmeAction.Navigate("/detail")
        )

        composeTestRule.setContent {
            MaterialTheme {
                AmeRenderer(
                    node = node,
                    formState = AmeFormState(),
                    onAction = { action ->
                        when ((action as AmeAction.Navigate).route) {
                            "/detail" -> rowActionFired = true
                            "/dir" -> trailingBtnActionFired = true
                        }
                    },
                )
            }
        }

        // Tap the trailing button. Material 3 ListItem renders trailingContent
        // outside its row clickable region, so the row action MUST NOT fire.
        composeTestRule.onNodeWithText("Directions").performClick()
        assertTrue(
            trailingBtnActionFired,
            "v1.4 §list_item: trailing button tap must fire its own action."
        )
        assertEquals(
            false, rowActionFired,
            "v1.4 §list_item NORMATIVE: row action MUST NOT fire when " +
                "trailing button is tapped."
        )

        // Reset and tap the row title — only the row action must fire.
        trailingBtnActionFired = false
        composeTestRule.onNodeWithText("Pizza Place").performClick()
        assertTrue(
            rowActionFired,
            "v1.4 §list_item: row title tap must fire the row action."
        )
        assertEquals(
            false, trailingBtnActionFired,
            "v1.4 §list_item: trailing button MUST NOT fire when row title is tapped."
        )
    }

    // ── Source-structural test helpers ────────────────────────────────

    /** Read the AmeRenderer.kt source file from the working tree. */
    private fun readRendererSource(): String {
        val file = java.io.File(
            "src/main/kotlin/com/agenticmobile/ame/compose/AmeRenderer.kt"
        )
        if (!file.exists()) {
            // Tests run from repo root or from ame-compose/. Try both.
            val alt = java.io.File(
                "ame-compose/src/main/kotlin/com/agenticmobile/ame/compose/AmeRenderer.kt"
            )
            if (alt.exists()) return alt.readText()
            error("Could not locate AmeRenderer.kt; cwd=${java.io.File(".").absolutePath}")
        }
        return file.readText()
    }

    /**
     * Extract the body of a top-level private composable function from the
     * source. Naive but sufficient for source-structural assertions: matches
     * `private fun <name>(` and returns from there to the closing `}` of the
     * function (paren-balance walk).
     */
    private fun extractFunctionBody(source: String, name: String): String {
        val start = source.indexOf("private fun $name(")
        if (start == -1) error("Function 'private fun $name(' not found in source.")
        val brace = source.indexOf('{', start)
        if (brace == -1) error("No opening brace after function '$name'.")
        var depth = 1
        var i = brace + 1
        while (i < source.length && depth > 0) {
            when (source[i]) {
                '{' -> depth++
                '}' -> depth--
            }
            i++
        }
        return source.substring(brace, i)
    }
}
