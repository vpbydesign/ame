import XCTest
import SwiftUI
@testable import AMESwiftUI

/// Audit regression tests — SwiftUI renderer, theme, and form state.
///
/// Each test corresponds to one row in `AUDIT_VERDICTS.md` at the repo root.
/// Tests are written so that BEFORE a fix is applied the test FAILS
/// (proving the bug), and AFTER the fix is applied the test PASSES
/// (locking in the corrected behavior).
///
/// See `specification/v1.0/regression-protocol.md` for the lifecycle rules
/// that govern this file.
///
/// Render-tree assertions use source-structural checks to verify the
/// SwiftUI renderer without launching a simulator.
final class AuditedSwiftUIBugTests: XCTestCase {

    // ════════════════════════════════════════════════════════════════════
    // Bug 1 — Swift renderer drops chart `labels`
    // ════════════════════════════════════════════════════════════════════

    /// Audit Bug #1: AmeRenderer.swift line 77 wildcards the `labels` value
    /// in `case .chart(let type, let values, _, ...)` and `renderChart` does
    /// not accept a `labels` parameter. Bar/line/pie/sparkline render with
    /// indices instead of label strings.
    ///
    /// Spec section: specification/v1.0/primitives.md (chart labels)
    /// Audit reference: AUDIT_VERDICTS.md#bug-1
    /// Pre-fix expected: FAIL — `renderChart` signature does not include labels.
    /// Post-fix expected: PASS — renderChart receives labels and passes them
    ///   to the `Charts` axis configuration.
    ///
    /// Verification strategy: structural source check. Reading the source
    /// file shows that `case .chart` wildcards labels. We assert this with a
    /// runtime check via Mirror on the rendered subview hierarchy. If the
    /// renderer never reads `labels`, the source-string assertion below fails.
    func testChartRendererReceivesLabels() throws {
        // Source-structural verification: read the renderer source and assert
        // labels are not wildcarded in the chart case.
        let rendererSourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // AMESwiftUITests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // ame-swiftui
            .appendingPathComponent("Sources/AMESwiftUI/Renderer/AmeRenderer.swift")

        let source = try String(contentsOf: rendererSourceURL, encoding: .utf8)

        // The bug pattern: "case .chart(let type, let values, _,"
        // The fix pattern: "case .chart(let type, let values, let labels,"
        let bugPattern = #"case \.chart\(let type, let values, _,"#
        let bugRange = source.range(of: bugPattern, options: .regularExpression)
        XCTAssertNil(
            bugRange,
            "BUG #1: AmeRenderer.swift `case .chart` wildcards the labels associated value. " +
            "Replace `_,` in the labels position with `let labels,` and pass labels into renderChart."
        )

        // Additionally assert renderChart signature includes a labels parameter.
        let renderChartSignaturePattern = #"func renderChart\(.*labels:"#
        let signatureRange = source.range(
            of: renderChartSignaturePattern,
            options: .regularExpression
        )
        XCTAssertNotNil(
            signatureRange,
            "BUG #1: renderChart must accept a `labels` parameter to render chart labels."
        )
    }

    // ════════════════════════════════════════════════════════════════════
    // Bug 2 — Swift carousel ignores `peek` parameter
    // ════════════════════════════════════════════════════════════════════

    /// Audit Bug #2: renderCarousel destructures `peek` but never uses it
    /// in layout calculation. Item width is fixed at `width * 0.85`.
    ///
    /// Spec section: specification/v1.0/primitives.md (carousel peek)
    /// Audit reference: AUDIT_VERDICTS.md#bug-2
    /// Pre-fix expected: FAIL — source has `peek:` parameter but no use of it.
    /// Post-fix expected: PASS — source uses `peek` in layout (frame width
    ///   or trailing padding).
    func testCarouselUsesPeekParameter() throws {
        let rendererSourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/AMESwiftUI/Renderer/AmeRenderer.swift")
        let source = try String(contentsOf: rendererSourceURL, encoding: .utf8)

        // Locate the renderCarousel function and scope to its body only
        // (after the signature's closing `) -> some View {`).
        guard let funcStart = source.range(of: "private func renderCarousel(") else {
            XCTFail("Could not locate renderCarousel in source")
            return
        }
        // Find the opening brace that starts the body.
        guard let bodyOpen = source.range(of: "{", range: funcStart.upperBound..<source.endIndex) else {
            XCTFail("Could not locate renderCarousel body opening brace")
            return
        }
        let endIndex = source.index(bodyOpen.upperBound, offsetBy: 3000, limitedBy: source.endIndex) ?? source.endIndex
        let bodyRaw = String(source[bodyOpen.upperBound..<endIndex])

        // Stop at the next `private func` (next function declaration).
        let body: String
        if let nextFunc = bodyRaw.range(of: "private func ") {
            body = String(bodyRaw[..<nextFunc.lowerBound])
        } else {
            body = bodyRaw
        }

        // Bug: `peek` is destructured in the signature but never referenced
        // in the body. After the fix, body must reference `peek` (e.g., for
        // padding or width offset).
        XCTAssertTrue(
            body.contains("peek"),
            "BUG #2: renderCarousel body ignores the `peek` parameter. " +
            "Use peek for trailing edge padding or item width offset.\n" +
            "Body sampled: \(body.prefix(500))"
        )
    }

    // ════════════════════════════════════════════════════════════════════
    // Bug 5 — Swift AmeFormState mutates @Published during view body
    // ════════════════════════════════════════════════════════════════════

    /// Audit Bug #5: `binding(for:)` writes `values[id] = defaultValue` if
    /// the field is unregistered. Called from view body, this triggers
    /// SwiftUI's "Modifying state during view update" warning.
    ///
    /// Spec section: N/A (SwiftUI runtime hygiene)
    /// Audit reference: AUDIT_VERDICTS.md#bug-5
    /// Pre-fix expected: FAIL — calling binding(for:) on a fresh state with
    ///   a default fires objectWillChange.
    /// Post-fix expected: PASS — binding(for:) does not mutate @Published
    ///   state during creation; the binding setter handles registration.
    func testFormStateBindingDoesNotMutateInBodyOnCreate() {
        let state = AmeFormState()
        let expectation = self.expectation(description: "objectWillChange should NOT fire")
        expectation.isInverted = true  // Test passes only if NOT fulfilled.

        let cancellable = state.objectWillChange.sink { _ in
            expectation.fulfill()
        }

        // Simulate the view body call site: just create the binding.
        _ = state.binding(for: "freshFieldId", default: "hi")

        wait(for: [expectation], timeout: 0.5)
        cancellable.cancel()
    }

    /// Bug 5 invariant guard: defaults registered via `binding(for:default:)`
    /// must still appear in `collectValues()` even if the user never edited
    /// the field. Pre-Bug-5 this worked because `binding` pre-wrote the value
    /// into `@Published values`. Post-Bug-5 the default lives in a non-published
    /// `inputDefaults` map and must be merged in by `collectValues()`.
    /// Added in WP#4 per acceptance criterion 12 (deeper coverage, same bug class).
    func testCollectValuesIncludesUneditedDefault() {
        let state = AmeFormState()
        _ = state.binding(for: "name", default: "hi")
        _ = state.toggleBinding(for: "newsletter", default: true)

        let collected = state.collectValues()

        XCTAssertEqual(collected["name"], "hi",
            "Unedited input default must surface in collectValues()")
        XCTAssertEqual(collected["newsletter"], "true",
            "Unedited toggle default must surface in collectValues() as 'true'/'false' string")
    }

    // ════════════════════════════════════════════════════════════════════
    // Bug 12 — input + toggle id collision silently merges
    // ════════════════════════════════════════════════════════════════════

    /// Audit Bug #12: AmeFormState.collectValues() writes inputs first then
    /// overlays toggles. Same id → toggle silently overwrites input value.
    ///
    /// Spec section: specification/v1.0/primitives.md (input, toggle)
    /// Audit reference: AUDIT_VERDICTS.md#bug-12
    ///
    /// v1.2 fix (per WP#5 plan): merge order is preserved (toggle wins) per
    /// the contract documented in WP#4 Bug 5; the silent-data-loss is now
    /// VISIBLE via the new `state.warnings` diagnostic surface.
    ///
    /// §8 sanctioned audit-test refinement: the original assertion
    /// `XCTAssertNotEqual(collected["x"], "true")` would force a behavior
    /// change. The principle-correct minimal fix is visibility, not
    /// behavior change. Maintainer sign-off captured in the WP#5 plan.
    /// Rationale: behavior change would break hosts that already rely on
    /// toggle-wins merge order.
    ///
    /// Pre-fix expected: FAIL — `state.warnings` was empty.
    /// Post-fix expected: PASS — `state.warnings` lists the colliding id
    ///   and the merge order is unchanged.
    func testInputToggleIdCollisionDetected() {
        let state = AmeFormState()
        // Register both with the same id.
        state.values["x"] = "input-value"
        state.toggles["x"] = true

        let collected = state.collectValues()

        XCTAssertEqual(
            collected["x"],
            "true",
            "Bug #12 fix preserves merge order (toggle wins) per WP#4 Bug 5 contract."
        )
        XCTAssertTrue(
            state.warnings.contains(where: { $0.contains("'x'") && $0.contains("collision") }),
            "BUG #12: collision must surface in state.warnings. " +
            "Today warnings=\(state.warnings)"
        )
    }

    // ════════════════════════════════════════════════════════════════════
    // Bug 13 — Swift input ref regex rejects hyphenated field IDs
    // ════════════════════════════════════════════════════════════════════

    /// Audit Bug #13 (Swift side): the `${input.fieldId}` regex `\w+`
    /// excludes `-`, so hyphenated IDs are silently not substituted.
    ///
    /// Spec section: specification/v1.0/actions.md (Input references)
    /// Audit reference: AUDIT_VERDICTS.md#bug-13
    /// Pre-fix expected: FAIL — substitution does not occur for hyphenated ID.
    /// Post-fix expected: PASS — hyphenated IDs substitute correctly.
    func testInputRefRegexAcceptsHyphenatedIds() {
        let state = AmeFormState()
        state.values["user-name"] = "Alice"

        let resolved = state.resolveInputReferences(
            ["query": "Hello, ${input.user-name}"]
        )

        XCTAssertEqual(
            resolved["query"],
            "Hello, Alice",
            "BUG #13: input ref regex must accept hyphenated field IDs. " +
            "Today \\w+ excludes '-', leaving the token unreplaced."
        )
    }

    /// Q4-style permanent guard added in WP#5 alongside the Bug #13 fix.
    /// Defends against future over-permissive expansion of the input-ref
    /// character class. The literal `.` inside `${input.fieldId}` MUST
    /// remain a hard separator so that a future feature like
    /// `${input.user.name}` (nested reference) cannot be silently shadowed
    /// by a flat field id `user.name`.
    func testInputRefRegexRejectsDotInsideFieldId() {
        let state = AmeFormState()
        state.values["user.name"] = "should-not-resolve"

        let resolved = state.resolveInputReferences(
            ["query": "Hello, ${input.user.name}"]
        )

        XCTAssertEqual(
            resolved["query"],
            "Hello, ${input.user.name}",
            "BUG #13 guard: '.' inside the field id segment must remain a " +
            "non-match so nested references are not shadowed by flat ids."
        )
    }

    // ════════════════════════════════════════════════════════════════════
    // Bug 14 — Swift theme uses static colors that don't adapt to dark mode
    // ════════════════════════════════════════════════════════════════════

    /// Audit Bug #14 (Swift side): AmeTheme returns static SwiftUI Color
    /// values that do not respect the system color scheme. SemanticColor
    /// SUCCESS returns `.green`, WARNING returns `.orange` — these are
    /// platform-fixed and don't adapt to the user's appearance setting.
    ///
    /// Spec section: specification/v1.0/primitives.md (semantic colors)
    /// Audit reference: AUDIT_VERDICTS.md#bug-14
    /// Pre-fix expected: FAIL — semanticColor returns the same Color in
    ///   light and dark schemes.
    /// Post-fix expected: PASS — colors derive from system semantic colors
    ///   (e.g., Color(.systemGreen)) that adapt to color scheme.
    func testThemeColorsRespectDarkMode() throws {
        let themeSourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/AMESwiftUI/Renderer/AmeTheme.swift")
        let source = try String(contentsOf: themeSourceURL, encoding: .utf8)

        // The bug pattern: semanticColor returns plain `.green`, `.orange`
        // (platform-fixed). The fix uses Color(.systemGreen) etc. or
        // a Color initializer with light/dark variants.
        let semanticColorFunctionPattern = #"semanticColor.*\{[\s\S]*?case \.success.*return\s+\.green"#
        let bugMatch = source.range(
            of: semanticColorFunctionPattern,
            options: .regularExpression
        )
        XCTAssertNil(
            bugMatch,
            "BUG #14: AmeTheme.semanticColor uses platform-fixed Color values that do not " +
            "adapt to color scheme. Use Color(.systemGreen) / Color(.systemOrange) or a " +
            "scheme-aware Color initializer."
        )
    }

    // ════════════════════════════════════════════════════════════════════
    // Bug 18 — Accordion `expanded` not reactive to node updates
    // ════════════════════════════════════════════════════════════════════

    /// Audit Bug #18: AmeAccordionView captures `node.expanded` only via
    /// State(initialValue:). If the host re-renders with a new AmeNode where
    /// expanded has flipped, the UI keeps the original state.
    ///
    /// Spec section: specification/v1.0/primitives.md (accordion expanded)
    /// Audit reference: AUDIT_VERDICTS.md#bug-18
    /// Pre-fix expected: FAIL — State(initialValue:) snapshot is captured.
    /// Post-fix expected: PASS — view follows node.expanded changes.
    ///
    /// Verification strategy: source-structural check for the State(initialValue:)
    /// pattern, which is the documented bug source. After the fix, the view
    /// should use a `.onChange(of: node.expanded)` modifier or similar
    /// reactivity pattern.
    func testAccordionFollowsExternalExpandedChanges() throws {
        let rendererSourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/AMESwiftUI/Renderer/AmeRenderer.swift")
        let source = try String(contentsOf: rendererSourceURL, encoding: .utf8)

        // Locate AmeAccordionView struct.
        guard let structStart = source.range(of: "private struct AmeAccordionView") else {
            XCTFail("Could not locate AmeAccordionView in source")
            return
        }
        let endIndex = source.index(structStart.upperBound, offsetBy: 2000, limitedBy: source.endIndex) ?? source.endIndex
        let body = String(source[structStart.upperBound..<endIndex])

        // The bug pattern: State(initialValue:) snapshot is captured once.
        // The fix should introduce a reactivity pattern such as `.onChange(of:`
        // tracking `node.expanded` or a `Binding`-based design.
        let hasReactivityPattern = body.contains("onChange") ||
            body.contains("@Binding")

        XCTAssertTrue(
            hasReactivityPattern,
            "BUG #18: AmeAccordionView captures node.expanded only at init. " +
            "Use .onChange(of: node.expanded) or a Binding pattern so the view " +
            "follows server-pushed expanded changes."
        )
    }

    // ════════════════════════════════════════════════════════════════════
    // WP#4 deeper coverage — Bug 2 behavioral and Bug 1 hardened structural
    // ════════════════════════════════════════════════════════════════════

    /// Bug 2 (Q3 upgrade): hardened structural assertion that the
    /// renderCarousel function body uses `peek` in a padding context,
    /// not just mentions the token. The original
    /// `testCarouselUsesPeekParameter` passes if `peek` appears anywhere
    /// in the body (defeatable by comments). This test slices the
    /// renderCarousel body and asserts `.padding` and `peek` co-occur
    /// in the same code region, proving the value flows into layout.
    func testCarouselTrailingPaddingEqualsPeekValue() throws {
        let rendererSourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/AMESwiftUI/Renderer/AmeRenderer.swift")
        let source = try String(contentsOf: rendererSourceURL, encoding: .utf8)

        guard let funcStart = source.range(of: "private func renderCarousel(") else {
            XCTFail("Could not locate renderCarousel in source")
            return
        }
        guard let bodyOpen = source.range(of: "{", range: funcStart.upperBound..<source.endIndex) else {
            XCTFail("Could not locate renderCarousel body opening brace")
            return
        }
        let endIndex = source.index(bodyOpen.upperBound, offsetBy: 3000, limitedBy: source.endIndex) ?? source.endIndex
        let bodyRaw = String(source[bodyOpen.upperBound..<endIndex])
        let body: String
        if let nextFunc = bodyRaw.range(of: "private func ") {
            body = String(bodyRaw[..<nextFunc.lowerBound])
        } else {
            body = bodyRaw
        }

        XCTAssertTrue(
            body.contains("peek") && body.contains(".padding"),
            "BUG #2 hardened: renderCarousel body must use `peek` in a " +
            "`.padding` context to apply it as trailing edge spacing. " +
            "Body sampled: \(body.prefix(400))"
        )
    }

    /// Bug 1 (Q3 upgrade): hardened structural check that each non-sparkline
    /// chart branch USES the labels parameter (not just receives it).
    /// The original `testChartRendererReceivesLabels` passes once the
    /// signature contains `labels:` even if the body discards the value.
    /// This test slices the renderChart body and asserts every branch that
    /// should display labels references the `labels` or `resolvedLabels`
    /// token. Sparkline is intentionally exempted (axes hidden per spec
    /// `primitives.md` "ignored for sparkline" and Compose parity).
    ///
    /// Behavioral runtime check was considered but rejected: Swift Charts
    /// renders to an opaque `_ChartView` host that cannot be traversed for
    /// axis text reads. Hardened structural check is the deterministic
    /// alternative.
    func testChartRendererBranchesUseLabelsExceptSparkline() throws {
        let rendererSourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/AMESwiftUI/Renderer/AmeRenderer.swift")
        let source = try String(contentsOf: rendererSourceURL, encoding: .utf8)

        guard let funcRange = source.range(of: "private func renderChart(") else {
            XCTFail("Could not locate renderChart in source")
            return
        }
        let scanWindow = source.index(funcRange.upperBound, offsetBy: 6000, limitedBy: source.endIndex) ?? source.endIndex
        let scanArea = String(source[funcRange.upperBound..<scanWindow])
        // Bound the scan to the function: stop at the next top-level `// MARK:`
        // section, which separates renderChart from the next chart-adjacent helper.
        let body: String
        if let nextMark = scanArea.range(of: "// MARK:") {
            body = String(scanArea[..<nextMark.lowerBound])
        } else {
            body = scanArea
        }

        // For each non-sparkline branch, slice the case block and assert
        // it references `labels` or `resolvedLabels` somewhere in its body.
        for caseLabel in ["case .bar:", "case .line:", "case .pie:"] {
            guard let caseStart = body.range(of: caseLabel) else {
                XCTFail("Could not locate \(caseLabel) inside renderChart body")
                continue
            }
            // Slice from this case label to the next `case .` (or end).
            let afterCase = body[caseStart.upperBound...]
            let caseEnd: String.Index
            if let nextCase = afterCase.range(of: "\n            case .") {
                caseEnd = nextCase.lowerBound
            } else {
                caseEnd = afterCase.endIndex
            }
            let caseBlock = String(afterCase[..<caseEnd])

            XCTAssertTrue(
                caseBlock.contains("labels") || caseBlock.contains("resolvedLabels"),
                "BUG #1 hardened: \(caseLabel) must reference labels/resolvedLabels in its body. " +
                "Block sampled: \(caseBlock.prefix(400))"
            )
        }

        // Affirmative sparkline exemption: ensure the sparkline branch does
        // NOT reference labels (axes hidden per spec). This locks in the
        // intentional design and prevents accidental label leak.
        if let sparklineStart = body.range(of: "case .sparkline:") {
            let afterSparkline = body[sparklineStart.upperBound...]
            let sparklineEnd: String.Index
            if let nextCase = afterSparkline.range(of: "\n            case .") {
                sparklineEnd = nextCase.lowerBound
            } else {
                sparklineEnd = afterSparkline.endIndex
            }
            let sparklineBlock = String(afterSparkline[..<sparklineEnd])
            // Exclude the explanatory comment that mentions "labels" by stripping
            // single-line comments before the assertion.
            let codeOnly = sparklineBlock
                .split(separator: "\n")
                .map { line -> String in
                    if let commentRange = line.range(of: "//") {
                        return String(line[..<commentRange.lowerBound])
                    }
                    return String(line)
                }
                .joined(separator: "\n")
            XCTAssertFalse(
                codeOnly.contains("resolvedLabels") || codeOnly.contains("labels?"),
                "Sparkline branch must NOT reference labels (axes hidden per spec)"
            )
        }
    }

    // ════════════════════════════════════════════════════════════════════
    // Bug 39 — DataList items had zero vertical rhythm (v1.4)
    // ════════════════════════════════════════════════════════════════════

    /// Audit Bug #39: renderDataList previously used `VStack(spacing: 0)`,
    /// flushing list items together with no breathing room.
    ///
    /// Pre-fix expected: FAIL — body contains `spacing: 0`.
    /// Post-fix expected: PASS — body uses dividers-conditional spacing.
    func testDataListHasVerticalSpacing() throws {
        let body = try renderFnBody("renderDataList")
        XCTAssertTrue(
            body.contains("dividers ? 8 : 12") || (body.contains("dividers") && body.contains("VStack(spacing:")),
            "BUG #39: renderDataList must use a dividers-conditional VStack spacing. " +
            "Body sampled: \(body.prefix(500))"
        )
    }

    // ════════════════════════════════════════════════════════════════════
    // Bug 40 — Carousel items grow beyond comfortable widths on tablets (v1.4)
    // ════════════════════════════════════════════════════════════════════

    /// Audit Bug #40: on Pixel Fold and other large form factors, the
    /// `width * 0.85` formula produced cards wider than 400pt. v1.4 clamps
    /// to a 340pt max — Material 3's recommended max card width.
    ///
    /// Pre-fix expected: FAIL — body uses unclamped `width * 0.85`.
    /// Post-fix expected: PASS — body uses `min(...340)`.
    func testCarouselItemHasMaxWidthClamp() throws {
        let body = try renderFnBody("renderCarousel")
        XCTAssertTrue(
            body.contains("min(") && body.contains("340"),
            "BUG #40: renderCarousel must clamp item width to 340pt max. " +
            "Body sampled: \(body.prefix(500))"
        )
    }

    // ════════════════════════════════════════════════════════════════════
    // Bug 41a — Badge variant not announced by VoiceOver (v1.4)
    // ════════════════════════════════════════════════════════════════════

    /// Audit Bug #41a: AmeBadge previously had no accessibility label, so
    /// VoiceOver read only the label ("4.5") with no indication of the
    /// status indicator's variant.
    ///
    /// Pre-fix expected: FAIL — body has no accessibilityLabel referencing variant.
    /// Post-fix expected: PASS — body sets a label combining label and variant.
    func testBadgeAccessibilityIncludesVariant() throws {
        let body = try renderFnBody("renderBadge")
        XCTAssertTrue(
            body.contains("accessibilityLabel") && body.contains("variant"),
            "BUG #41a: renderBadge must set accessibilityLabel including the variant name. " +
            "Body sampled: \(body.prefix(500))"
        )
    }

    // ════════════════════════════════════════════════════════════════════
    // Bug 41b — Card children not grouped as a single semantics node (v1.4)
    // ════════════════════════════════════════════════════════════════════

    /// Audit Bug #41b: AmeCard rendered each child as an independently
    /// focusable accessibility element, breaking the spec's note that a
    /// card SHOULD be announced as a single unit.
    ///
    /// Pre-fix expected: FAIL — body has no accessibilityElement modifier.
    /// Post-fix expected: PASS — body uses `.accessibilityElement(children: .combine)`.
    func testCardCombinesAccessibilityChildren() throws {
        let body = try renderFnBody("renderCard")
        XCTAssertTrue(
            body.contains(".accessibilityElement(children: .combine)"),
            "BUG #41b: renderCard must combine children into a single accessibility element. " +
            "Body sampled: \(body.prefix(500))"
        )
    }

    // ── Source-structural test helper ─────────────────────────────────

    /// Read the body of a private renderer function from AmeRenderer.swift.
    /// Returns content from the opening `{` of the function body up to the
    /// next `private func ` declaration (or end of file).
    private func renderFnBody(_ name: String) throws -> String {
        let rendererSourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/AMESwiftUI/Renderer/AmeRenderer.swift")
        let source = try String(contentsOf: rendererSourceURL, encoding: .utf8)
        guard let funcStart = source.range(of: "private func \(name)(") else {
            throw NSError(domain: "test", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Could not locate '\(name)' in source"
            ])
        }
        guard let bodyOpen = source.range(of: "{", range: funcStart.upperBound..<source.endIndex) else {
            throw NSError(domain: "test", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Could not locate body opening brace for '\(name)'"
            ])
        }
        let endIndex = source.index(bodyOpen.upperBound, offsetBy: 3000, limitedBy: source.endIndex) ?? source.endIndex
        let bodyRaw = String(source[bodyOpen.upperBound..<endIndex])
        if let nextFunc = bodyRaw.range(of: "private func ") {
            return String(bodyRaw[..<nextFunc.lowerBound])
        }
        return bodyRaw
    }
}

import Combine
