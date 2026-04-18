import XCTest
@testable import AMESwiftUI

/// Round-trip serialization tests for all AmeNode and AmeAction types.
/// Verifies: serialize to JSON -> deserialize back -> assertEqual on original.
///
/// Port of AmeNodeTest.kt — v1.1 parity.
final class AmeNodeTests: XCTestCase {

    // MARK: - Helpers

    private func assertRoundTrip(_ node: AmeNode, file: StaticString = #filePath, line: UInt = #line) {
        guard let json = AmeSerializer.toJson(node) else {
            XCTFail("Serialization returned nil", file: file, line: line)
            return
        }
        guard let restored = AmeSerializer.fromJson(json) else {
            XCTFail("Deserialization returned nil for: \(json)", file: file, line: line)
            return
        }
        XCTAssertEqual(node, restored, "Round-trip failed for: \(json)", file: file, line: line)
    }

    private func assertActionRoundTrip(_ action: AmeAction, file: StaticString = #filePath, line: UInt = #line) {
        guard let json = AmeSerializer.actionToJson(action) else {
            XCTFail("Action serialization returned nil", file: file, line: line)
            return
        }
        guard let restored = AmeSerializer.actionFromJson(json) else {
            XCTFail("Action deserialization returned nil for: \(json)", file: file, line: line)
            return
        }
        XCTAssertEqual(action, restored, "Action round-trip failed for: \(json)", file: file, line: line)
    }

    // MARK: - Layout Primitives

    func testRoundTripCol() {
        let node = AmeNode.col(
            children: [
                .txt(text: "Hello", style: .title),
                .txt(text: "World", style: .body)
            ],
            align: .center
        )
        assertRoundTrip(node)
    }

    func testRoundTripColDefaults() {
        let node = AmeNode.col(children: [.txt(text: "A")])
        assertRoundTrip(node)
        let json = AmeSerializer.toJson(node)!
        XCTAssertFalse(json.contains("\"align\""), "Default align should not be encoded: \(json)")
    }

    func testRoundTripRow() {
        let node = AmeNode.row(
            children: [.txt(text: "Left"), .txt(text: "Right")],
            align: .spaceBetween,
            gap: 16
        )
        assertRoundTrip(node)
    }

    func testRoundTripRowDefaults() {
        let node = AmeNode.row(children: [.txt(text: "Item")])
        assertRoundTrip(node)
        let json = AmeSerializer.toJson(node)!
        XCTAssertFalse(json.contains("\"gap\""), "Default gap should not be encoded: \(json)")
        XCTAssertFalse(json.contains("\"align\""), "Default align should not be encoded: \(json)")
    }

    // MARK: - Content Primitives

    func testRoundTripTxt() {
        let node = AmeNode.txt(text: "Hello World", style: .headline, maxLines: 2)
        assertRoundTrip(node)
    }

    func testRoundTripTxtDefaults() {
        let node = AmeNode.txt(text: "Simple text")
        assertRoundTrip(node)
        let json = AmeSerializer.toJson(node)!
        XCTAssertFalse(json.contains("\"style\""), "Default style should not be encoded: \(json)")
        XCTAssertFalse(json.contains("\"maxLines\""), "Null maxLines should not be encoded: \(json)")
    }

    func testRoundTripImg() {
        let node = AmeNode.img(url: "https://example.com/photo.jpg", height: 180)
        assertRoundTrip(node)
    }

    func testRoundTripImgNoHeight() {
        let node = AmeNode.img(url: "https://example.com/photo.jpg")
        assertRoundTrip(node)
    }

    func testRoundTripIcon() {
        let node = AmeNode.icon(name: "partly_cloudy_day", size: 28)
        assertRoundTrip(node)
    }

    func testRoundTripIconDefaults() {
        let node = AmeNode.icon(name: "star")
        assertRoundTrip(node)
    }

    func testRoundTripDivider() {
        let node = AmeNode.divider
        assertRoundTrip(node)
        let json = AmeSerializer.toJson(node)!
        XCTAssertTrue(json.contains("\"_type\":\"divider\""), "Divider JSON: \(json)")
    }

    func testRoundTripSpacer() {
        let node = AmeNode.spacer(height: 16)
        assertRoundTrip(node)
    }

    func testRoundTripSpacerDefaults() {
        let node = AmeNode.spacer()
        assertRoundTrip(node)
    }

    // MARK: - Semantic Primitives

    func testRoundTripCard() {
        let node = AmeNode.card(
            children: [
                .txt(text: "Title", style: .title),
                .txt(text: "Description")
            ],
            elevation: 2
        )
        assertRoundTrip(node)
    }

    func testRoundTripBadge() {
        let node = AmeNode.badge(label: "★4.5", variant: .info)
        assertRoundTrip(node)
    }

    func testRoundTripBadgeDefaults() {
        let node = AmeNode.badge(label: "Tag")
        assertRoundTrip(node)
    }

    func testRoundTripProgress() {
        let node = AmeNode.progress(value: 0.67, label: "67% complete")
        assertRoundTrip(node)
    }

    func testRoundTripProgressNoLabel() {
        let node = AmeNode.progress(value: 0.3)
        assertRoundTrip(node)
    }

    // MARK: - Interactive Primitives

    func testRoundTripBtnWithToolAction() {
        let node = AmeNode.btn(
            label: "Save",
            action: .callTool(name: "add_note", args: ["title": "Meeting Notes"]),
            style: .primary
        )
        assertRoundTrip(node)
    }

    func testRoundTripBtnWithUriAction() {
        let node = AmeNode.btn(
            label: "Directions",
            action: .openUri(uri: "geo:40.72,-73.99?q=Luigi's"),
            style: .text
        )
        assertRoundTrip(node)
    }

    func testRoundTripBtnWithNavAction() {
        let node = AmeNode.btn(
            label: "Home",
            action: .navigate(route: "home"),
            style: .outline
        )
        assertRoundTrip(node)
    }

    func testRoundTripBtnWithCopyAction() {
        let node = AmeNode.btn(
            label: "Copy Address",
            action: .copyText(text: "119 Mulberry St"),
            style: .text
        )
        assertRoundTrip(node)
    }

    func testRoundTripBtnWithSubmitAction() {
        let node = AmeNode.btn(
            label: "Confirm",
            action: .submit(toolName: "create_reservation", staticArgs: ["restaurant": "Luigi's"]),
            style: .primary
        )
        assertRoundTrip(node)
    }

    func testRoundTripBtnWithIcon() {
        let node = AmeNode.btn(
            label: "Call",
            action: .openUri(uri: "tel:+15551234567"),
            style: .primary,
            icon: "phone"
        )
        assertRoundTrip(node)
    }

    func testRoundTripInput() {
        let node = AmeNode.input(id: "email", label: "Email Address", type: .email)
        assertRoundTrip(node)
    }

    func testRoundTripInputSelect() {
        let node = AmeNode.input(
            id: "guests",
            label: "Number of Guests",
            type: .select,
            options: ["1", "2", "3", "4", "5", "6"]
        )
        assertRoundTrip(node)
    }

    func testRoundTripInputDefaults() {
        let node = AmeNode.input(id: "name", label: "Your Name")
        assertRoundTrip(node)
    }

    func testRoundTripToggle() {
        let node = AmeNode.toggle(id: "notifications", label: "Enable notifications", default: true)
        assertRoundTrip(node)
    }

    func testRoundTripToggleDefaults() {
        let node = AmeNode.toggle(id: "agree", label: "I agree to the terms")
        assertRoundTrip(node)
        let json = AmeSerializer.toJson(node)!
        XCTAssertFalse(json.contains("\"default\""), "Default false should not be encoded: \(json)")
    }

    // MARK: - Data Primitives

    func testRoundTripDataList() {
        let node = AmeNode.dataList(
            children: [.txt(text: "Item 1"), .txt(text: "Item 2"), .txt(text: "Item 3")],
            dividers: true
        )
        assertRoundTrip(node)
    }

    func testRoundTripDataListNoDividers() {
        let node = AmeNode.dataList(
            children: [.txt(text: "A"), .txt(text: "B")],
            dividers: false
        )
        assertRoundTrip(node)
    }

    func testRoundTripTable() {
        let node = AmeNode.table(
            headers: ["Feature", "Basic", "Pro"],
            rows: [
                ["Storage", "50 GB", "500 GB"],
                ["Users", "1", "10"],
                ["Support", "Email", "24/7"]
            ]
        )
        assertRoundTrip(node)
    }

    // MARK: - Structural Types

    func testRoundTripRef() {
        let node = AmeNode.ref(id: "header")
        assertRoundTrip(node)
    }

    func testRoundTripEach() {
        let node = AmeNode.each(dataPath: "places", templateId: "place_tpl")
        assertRoundTrip(node)
    }

    // MARK: - Action Round-Trip Tests

    func testRoundTripCallToolAction() {
        let action = AmeAction.callTool(
            name: "create_calendar_event",
            args: ["title": "Dinner at Luigi's", "date": "2026-04-15"]
        )
        assertActionRoundTrip(action)
    }

    func testRoundTripCallToolWithInputRef() {
        let action = AmeAction.callTool(
            name: "send_message",
            args: ["to": "${input.recipient}", "body": "${input.body}"]
        )
        assertActionRoundTrip(action)
        let json = AmeSerializer.actionToJson(action)!
        XCTAssertTrue(json.contains("${input.recipient}"), "Input ref must survive as literal: \(json)")
    }

    func testRoundTripOpenUriAction() {
        assertActionRoundTrip(.openUri(uri: "geo:40.72,-73.99?q=Luigi's"))
    }

    func testRoundTripNavigateAction() {
        assertActionRoundTrip(.navigate(route: "calendar"))
    }

    func testRoundTripCopyTextAction() {
        assertActionRoundTrip(.copyText(text: "119 Mulberry St, New York"))
    }

    func testRoundTripSubmitAction() {
        let action = AmeAction.submit(
            toolName: "create_reservation",
            staticArgs: ["restaurant": "Luigi's"]
        )
        assertActionRoundTrip(action)
    }

    func testRoundTripSubmitActionEmpty() {
        let action = AmeAction.submit(toolName: "save_draft")
        assertActionRoundTrip(action)
    }

    // MARK: - Complex Tree: Weather Card

    func testRoundTripWeatherCardTree() {
        let tree = AmeNode.card(children: [
            .row(children: [
                .txt(text: "San Francisco", style: .title),
                .icon(name: "partly_cloudy_day", size: 28)
            ], align: .spaceBetween),
            .txt(text: "62°", style: .display),
            .txt(text: "Partly Cloudy", style: .body),
            .row(children: [
                .txt(text: "H:68°  L:55°", style: .caption),
                .txt(text: "Humidity: 72%", style: .caption)
            ], align: .spaceBetween)
        ])
        assertRoundTrip(tree)

        let json = AmeSerializer.toJson(tree)!
        XCTAssertTrue(json.contains("\"San Francisco\""), "Tree JSON must contain city name")
        XCTAssertTrue(json.contains("\"partly_cloudy_day\""), "Tree JSON must contain icon name")
        XCTAssertTrue(json.contains("\"62°\""), "Tree JSON must contain temperature")
    }

    func testWeatherCardJsonIsCompact() {
        let tree = AmeNode.card(children: [
            .txt(text: "62°", style: .display),
            .txt(text: "Partly Cloudy")
        ])
        let json = AmeSerializer.toJson(tree)!
        XCTAssertFalse(json.contains("\"elevation\""), "Default elevation should not be in JSON")
    }

    // MARK: - Nested Tree Serialization

    func testRoundTripDeeplyNestedTree() {
        let tree = AmeNode.col(children: [
            .card(children: [
                .row(children: [
                    .txt(text: "Name", style: .title),
                    .badge(label: "★4.5", variant: .info)
                ], align: .spaceBetween),
                .txt(text: "123 Main St", style: .caption),
                .row(children: [
                    .btn(label: "Schedule",
                         action: .callTool(name: "create_event", args: ["title": "Dinner"]),
                         style: .primary),
                    .btn(label: "Directions",
                         action: .openUri(uri: "geo:40.72,-73.99"),
                         style: .text)
                ], gap: 8)
            ])
        ])
        assertRoundTrip(tree)
    }

    // MARK: - Children with Ref Nodes

    func testRoundTripTreeWithRefs() {
        let tree = AmeNode.col(children: [
            .ref(id: "header"),
            .ref(id: "body"),
            .ref(id: "footer")
        ])
        assertRoundTrip(tree)
        let json = AmeSerializer.toJson(tree)!
        XCTAssertTrue(json.contains("\"_type\":\"ref\""), "Ref type discriminator must be present")
    }

    // MARK: - Each Node in Tree

    func testRoundTripTreeWithEach() {
        let tree = AmeNode.col(children: [
            .txt(text: "Nearby Places", style: .headline),
            .each(dataPath: "places", templateId: "place_tpl")
        ])
        assertRoundTrip(tree)
    }

    // MARK: - encodeDefaults=false Verification

    func testEncodeDefaultsFalseOmitsDefaults() {
        let txt = AmeNode.txt(text: "Hello")
        let json = AmeSerializer.toJson(txt)!
        // With sortedKeys, the output is deterministic
        XCTAssertTrue(json.contains("\"_type\":\"txt\""), "Must have type discriminator")
        XCTAssertTrue(json.contains("\"text\":\"Hello\""), "Must have text")
        XCTAssertFalse(json.contains("\"style\""), "Default style must not be encoded")
        XCTAssertFalse(json.contains("\"maxLines\""), "Null maxLines must not be encoded")
    }

    func testEncodeDefaultsFalseIncludesNonDefaults() {
        let txt = AmeNode.txt(text: "Hello", style: .headline)
        let json = AmeSerializer.toJson(txt)!
        XCTAssertTrue(json.contains("\"style\":\"headline\""), "Non-default style must be encoded: \(json)")
    }

    // MARK: - Type Discriminator Verification

    func testTypeDiscriminatorUsesSerialName() {
        let json = AmeSerializer.toJson(.badge(label: "New", variant: .success))!
        XCTAssertTrue(json.contains("\"_type\":\"badge\""), "Type discriminator must use serial name: \(json)")
    }

    func testDividerTypeDiscriminator() {
        let json = AmeSerializer.toJson(.divider)!
        XCTAssertTrue(json.contains("\"_type\":\"divider\""), "Divider discriminator must be 'divider': \(json)")
    }

    func testDataListSerializesAsList() {
        let json = AmeSerializer.toJson(.dataList(children: [.txt(text: "A")]))!
        XCTAssertTrue(json.contains("\"_type\":\"list\""), "DataList must serialize as 'list': \(json)")
        XCTAssertFalse(json.contains("\"data_list\""), "Must not use 'data_list'")
        XCTAssertFalse(json.contains("\"dataList\""), "Must not use 'dataList'")
    }

    // MARK: - Kotlin JSON Cross-Compatibility (Decision #5)

    /// Verifies that a JSON string produced by the Kotlin serializer can be
    /// decoded by the Swift deserializer. The JSON below was constructed
    /// deterministically from AmeSerializer.kt with classDiscriminator="_type"
    /// and encodeDefaults=false, matching the Weather Card tree in AmeNodeTest.kt.
    func testKotlinJsonCrossDecodeWeatherCard() {
        // Kotlin-format JSON for the Weather Card tree.
        // kotlinx.serialization outputs properties in declaration order
        // with _type first (classDiscriminator).
        let kotlinJson = """
        {"_type":"card","children":[{"_type":"row","children":[{"_type":"txt","text":"San Francisco","style":"title"},{"_type":"icon","name":"partly_cloudy_day","size":28}],"align":"space_between"},{"_type":"txt","text":"62°","style":"display"},{"_type":"txt","text":"Partly Cloudy"},{"_type":"row","children":[{"_type":"txt","text":"H:68°  L:55°","style":"caption"},{"_type":"txt","text":"Humidity: 72%","style":"caption"}],"align":"space_between"}]}
        """

        guard let decoded = AmeSerializer.fromJson(kotlinJson) else {
            XCTFail("Swift decoder failed to decode Kotlin-produced JSON")
            return
        }

        // Verify the decoded tree structure
        guard case .card(let children, let elevation) = decoded else {
            XCTFail("Expected card, got \(decoded)")
            return
        }
        XCTAssertEqual(elevation, 1) // default, omitted from JSON
        XCTAssertEqual(children.count, 4)

        // weather_header = row
        guard case .row(let headerChildren, let headerAlign, _) = children[0] else {
            XCTFail("Expected row for header")
            return
        }
        XCTAssertEqual(headerAlign, .spaceBetween)
        XCTAssertEqual(headerChildren.count, 2)

        guard case .txt(let cityText, let cityStyle, _, _) = headerChildren[0] else {
            XCTFail("Expected txt for city")
            return
        }
        XCTAssertEqual(cityText, "San Francisco")
        XCTAssertEqual(cityStyle, .title)

        guard case .icon(let iconName, let iconSize) = headerChildren[1] else {
            XCTFail("Expected icon")
            return
        }
        XCTAssertEqual(iconName, "partly_cloudy_day")
        XCTAssertEqual(iconSize, 28)

        // temp
        guard case .txt(let tempText, let tempStyle, _, _) = children[1] else {
            XCTFail("Expected txt for temp")
            return
        }
        XCTAssertEqual(tempText, "62°")
        XCTAssertEqual(tempStyle, .display)

        // condition
        guard case .txt(let condText, let condStyle, _, _) = children[2] else {
            XCTFail("Expected txt for condition")
            return
        }
        XCTAssertEqual(condText, "Partly Cloudy")
        XCTAssertEqual(condStyle, .body) // default, omitted from JSON

        // details row
        guard case .row(let detailChildren, let detailAlign, _) = children[3] else {
            XCTFail("Expected row for details")
            return
        }
        XCTAssertEqual(detailAlign, .spaceBetween)
        XCTAssertEqual(detailChildren.count, 2)
    }

    /// Verifies cross-decode of a Kotlin-format action JSON.
    func testKotlinJsonCrossDecodeSubmitAction() {
        let kotlinJson = """
        {"_type":"submit","toolName":"create_reservation","staticArgs":{"restaurant":"Luigi's"}}
        """
        guard let decoded = AmeSerializer.actionFromJson(kotlinJson) else {
            XCTFail("Swift decoder failed to decode Kotlin action JSON")
            return
        }
        guard case .submit(let toolName, let staticArgs) = decoded else {
            XCTFail("Expected submit action")
            return
        }
        XCTAssertEqual(toolName, "create_reservation")
        XCTAssertEqual(staticArgs["restaurant"], "Luigi's")
    }

    // MARK: - AmeIcons Verification

    func testIconRegistryCount() {
        XCTAssertEqual(AmeIcons.registryCount, 57, "Must have exactly 57 icon mappings")
    }

    func testUnknownIconReturnsFallback() {
        XCTAssertEqual(AmeIcons.resolve("nonexistent"), "questionmark.circle")
    }

    // ════════════════════════════════════════════════════════════════════
    // v1.1 Primitives — Codable Round-Trip Tests
    // ════════════════════════════════════════════════════════════════════

    func testChartCodableRoundTrip() {
        let node = AmeNode.chart(type: .bar, values: [10, 20, 30], labels: ["A", "B", "C"],
                                 height: 250, color: .primary)
        let json = AmeSerializer.toJson(node)!
        let decoded = AmeSerializer.fromJson(json)!
        guard case .chart(let type, let values, let labels, _, let height, let color, _, _, _, _) = decoded else {
            XCTFail("Expected chart"); return
        }
        XCTAssertEqual(type, .bar)
        XCTAssertEqual(values, [10, 20, 30])
        XCTAssertEqual(labels, ["A", "B", "C"])
        XCTAssertEqual(height, 250)
        XCTAssertEqual(color, .primary)
    }

    func testChartDefaultsCodable() {
        let node = AmeNode.chart(type: .line)
        let json = AmeSerializer.toJson(node)!
        let decoded = AmeSerializer.fromJson(json)!
        guard case .chart(let type, let values, let labels, let series, let height, let color, _, _, _, _) = decoded else {
            XCTFail("Expected chart"); return
        }
        XCTAssertEqual(type, .line)
        XCTAssertNil(values)
        XCTAssertNil(labels)
        XCTAssertNil(series)
        XCTAssertEqual(height, 200)
        XCTAssertNil(color)
    }

    func testChartMultiSeriesCodable() {
        let node = AmeNode.chart(type: .line, series: [[1, 2], [3, 4]])
        let json = AmeSerializer.toJson(node)!
        let decoded = AmeSerializer.fromJson(json)!
        guard case .chart(_, _, _, let series, _, _, _, _, _, _) = decoded else {
            XCTFail("Expected chart"); return
        }
        XCTAssertEqual(series, [[1, 2], [3, 4]])
    }

    func testCodeCodableRoundTrip() {
        let node = AmeNode.code(language: "swift", content: "let x = 1", title: "Example")
        let json = AmeSerializer.toJson(node)!
        let decoded = AmeSerializer.fromJson(json)!
        guard case .code(let language, let content, let title) = decoded else {
            XCTFail("Expected code"); return
        }
        XCTAssertEqual(language, "swift")
        XCTAssertEqual(content, "let x = 1")
        XCTAssertEqual(title, "Example")
    }

    func testCodeNoTitleCodable() {
        let node = AmeNode.code(language: "python", content: "print()")
        let json = AmeSerializer.toJson(node)!
        let decoded = AmeSerializer.fromJson(json)!
        guard case .code(_, _, let title) = decoded else {
            XCTFail("Expected code"); return
        }
        XCTAssertNil(title)
    }

    func testAccordionCodableRoundTrip() {
        let node = AmeNode.accordion(title: "FAQ", children: [.txt(text: "Answer")], expanded: true)
        let json = AmeSerializer.toJson(node)!
        let decoded = AmeSerializer.fromJson(json)!
        guard case .accordion(let title, let children, let expanded) = decoded else {
            XCTFail("Expected accordion"); return
        }
        XCTAssertEqual(title, "FAQ")
        XCTAssertEqual(children.count, 1)
        XCTAssertTrue(expanded)
    }

    func testAccordionDefaultsCodable() {
        let node = AmeNode.accordion(title: "Section")
        let json = AmeSerializer.toJson(node)!
        let decoded = AmeSerializer.fromJson(json)!
        guard case .accordion(_, let children, let expanded) = decoded else {
            XCTFail("Expected accordion"); return
        }
        XCTAssertTrue(children.isEmpty)
        XCTAssertFalse(expanded)
    }

    func testCarouselCodableRoundTrip() {
        let node = AmeNode.carousel(children: [.txt(text: "Slide 1"), .txt(text: "Slide 2")], peek: 40)
        let json = AmeSerializer.toJson(node)!
        let decoded = AmeSerializer.fromJson(json)!
        guard case .carousel(let children, let peek) = decoded else {
            XCTFail("Expected carousel"); return
        }
        XCTAssertEqual(children.count, 2)
        XCTAssertEqual(peek, 40)
    }

    func testCarouselDefaultsCodable() {
        let node = AmeNode.carousel()
        let json = AmeSerializer.toJson(node)!
        let decoded = AmeSerializer.fromJson(json)!
        guard case .carousel(let children, let peek) = decoded else {
            XCTFail("Expected carousel"); return
        }
        XCTAssertTrue(children.isEmpty)
        XCTAssertEqual(peek, 24)
    }

    func testCalloutCodableRoundTrip() {
        let node = AmeNode.callout(type: .warning, content: "Be careful", title: "Warning")
        let json = AmeSerializer.toJson(node)!
        let decoded = AmeSerializer.fromJson(json)!
        guard case .callout(let type, let content, let title, _) = decoded else {
            XCTFail("Expected callout"); return
        }
        XCTAssertEqual(type, .warning)
        XCTAssertEqual(content, "Be careful")
        XCTAssertEqual(title, "Warning")
    }

    func testCalloutNoTitleCodable() {
        let node = AmeNode.callout(type: .info, content: "Note this")
        let json = AmeSerializer.toJson(node)!
        let decoded = AmeSerializer.fromJson(json)!
        guard case .callout(let type, _, let title, _) = decoded else {
            XCTFail("Expected callout"); return
        }
        XCTAssertEqual(type, .info)
        XCTAssertNil(title)
    }

    func testTimelineCodableRoundTrip() {
        let node = AmeNode.timeline(children: [
            .timelineItem(title: "Step 1", subtitle: "Done", status: .done),
            .timelineItem(title: "Step 2", status: .active)
        ])
        let json = AmeSerializer.toJson(node)!
        let decoded = AmeSerializer.fromJson(json)!
        guard case .timeline(let children) = decoded else {
            XCTFail("Expected timeline"); return
        }
        XCTAssertEqual(children.count, 2)
        guard case .timelineItem(let t1, let s1, let st1) = children[0] else {
            XCTFail("Expected timeline_item"); return
        }
        XCTAssertEqual(t1, "Step 1")
        XCTAssertEqual(s1, "Done")
        XCTAssertEqual(st1, .done)
    }

    func testTimelineItemCodableRoundTrip() {
        let node = AmeNode.timelineItem(title: "Deploy", subtitle: "Running", status: .active)
        let json = AmeSerializer.toJson(node)!
        let decoded = AmeSerializer.fromJson(json)!
        guard case .timelineItem(let title, let subtitle, let status) = decoded else {
            XCTFail("Expected timeline_item"); return
        }
        XCTAssertEqual(title, "Deploy")
        XCTAssertEqual(subtitle, "Running")
        XCTAssertEqual(status, .active)
    }

    func testTimelineItemDefaultsCodable() {
        let node = AmeNode.timelineItem(title: "Waiting")
        let json = AmeSerializer.toJson(node)!
        let decoded = AmeSerializer.fromJson(json)!
        guard case .timelineItem(_, let subtitle, let status) = decoded else {
            XCTFail("Expected timeline_item"); return
        }
        XCTAssertNil(subtitle)
        XCTAssertEqual(status, .pending)
    }

    func testTxtWithColorCodable() {
        let node = AmeNode.txt(text: "Error msg", style: .body, color: .error)
        let json = AmeSerializer.toJson(node)!
        let decoded = AmeSerializer.fromJson(json)!
        guard case .txt(let text, _, _, let color) = decoded else {
            XCTFail("Expected txt"); return
        }
        XCTAssertEqual(text, "Error msg")
        XCTAssertEqual(color, .error)
    }

    func testTxtWithoutColorCodable() {
        let node = AmeNode.txt(text: "Plain")
        let json = AmeSerializer.toJson(node)!
        let decoded = AmeSerializer.fromJson(json)!
        guard case .txt(_, _, _, let color) = decoded else {
            XCTFail("Expected txt"); return
        }
        XCTAssertNil(color)
    }

    func testBadgeWithColorCodable() {
        let node = AmeNode.badge(label: "Alert", variant: .default, color: .warning)
        let json = AmeSerializer.toJson(node)!
        let decoded = AmeSerializer.fromJson(json)!
        guard case .badge(let label, _, let color) = decoded else {
            XCTFail("Expected badge"); return
        }
        XCTAssertEqual(label, "Alert")
        XCTAssertEqual(color, .warning)
    }

    func testBadgeWithoutColorCodable() {
        let node = AmeNode.badge(label: "Tag")
        let json = AmeSerializer.toJson(node)!
        let decoded = AmeSerializer.fromJson(json)!
        guard case .badge(_, _, let color) = decoded else {
            XCTFail("Expected badge"); return
        }
        XCTAssertNil(color)
    }

    func testChartSparklineCodable() {
        let node = AmeNode.chart(type: .sparkline, values: [1, 2, 3])
        let json = AmeSerializer.toJson(node)!
        let decoded = AmeSerializer.fromJson(json)!
        guard case .chart(let type, let values, _, _, _, _, _, _, _, _) = decoded else {
            XCTFail("Expected chart"); return
        }
        XCTAssertEqual(type, .sparkline)
        XCTAssertEqual(values, [1, 2, 3])
    }

    func testChartPieCodable() {
        let node = AmeNode.chart(type: .pie, values: [30, 40, 30], color: .success)
        let json = AmeSerializer.toJson(node)!
        let decoded = AmeSerializer.fromJson(json)!
        guard case .chart(let type, let values, _, _, _, let color, _, _, _, _) = decoded else {
            XCTFail("Expected chart"); return
        }
        XCTAssertEqual(type, .pie)
        XCTAssertEqual(values, [30, 40, 30])
        XCTAssertEqual(color, .success)
    }

    func testAllCalloutTypes() {
        for calloutType in CalloutType.allCases {
            let node = AmeNode.callout(type: calloutType, content: "Test")
            let json = AmeSerializer.toJson(node)!
            let decoded = AmeSerializer.fromJson(json)!
            guard case .callout(let decodedType, _, _, _) = decoded else {
                XCTFail("Expected callout for type \(calloutType)"); return
            }
            XCTAssertEqual(decodedType, calloutType)
        }
    }

    func testAllTimelineStatuses() {
        for status in TimelineStatus.allCases {
            let node = AmeNode.timelineItem(title: "Step", status: status)
            let json = AmeSerializer.toJson(node)!
            let decoded = AmeSerializer.fromJson(json)!
            guard case .timelineItem(_, _, let decodedStatus) = decoded else {
                XCTFail("Expected timeline_item for status \(status)"); return
            }
            XCTAssertEqual(decodedStatus, status)
        }
    }

    func testRoundTripChartType() {
        for ct in ChartType.allCases {
            let node = AmeNode.chart(type: ct)
            assertRoundTrip(node)
        }
    }

    func testRoundTripSemanticColor() {
        for sc in SemanticColor.allCases {
            let node = AmeNode.txt(text: "test", color: sc)
            assertRoundTrip(node)
        }
    }

    func testRoundTripTreeWithNewPrimitives() {
        let tree = AmeNode.col(children: [
            .callout(type: .tip, content: "Hint", title: "Pro Tip"),
            .accordion(title: "Details", children: [
                .code(language: "json", content: "{\"key\":\"val\"}"),
                .chart(type: .sparkline, values: [1, 3, 2])
            ], expanded: true),
            .carousel(children: [
                .card(children: [.txt(text: "Slide 1")]),
                .card(children: [.txt(text: "Slide 2")])
            ], peek: 40),
            .timeline(children: [
                .timelineItem(title: "Ordered", subtitle: "April 1", status: .done),
                .timelineItem(title: "Shipped", status: .active),
                .timelineItem(title: "Delivered", status: .pending)
            ])
        ])
        assertRoundTrip(tree)
    }
}
