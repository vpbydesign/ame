import XCTest
@testable import AMESwiftUI

/// Parser tests covering:
/// - All 21 primitives (happy path)
/// - All 5 action types in btn
/// - Forward references
/// - Data binding ($path, --- separator)
/// - each() construct
/// - 3 complete examples from syntax.md
/// - 6 error recovery cases
///
/// Port of AmeParserTest.kt — v1.1 parity.
final class AmeParserTests: XCTestCase {

    private func parse(_ input: String) -> AmeNode? {
        let parser = AmeParser()
        return parser.parse(input)
    }

    private func parserFor(_ input: String) -> AmeParser {
        let parser = AmeParser()
        let _ = parser.parse(input)
        return parser
    }

    // ════════════════════════════════════════════════════════════════════
    // Happy Path — All 15 Primitives
    // ════════════════════════════════════════════════════════════════════

    func testParseCol() {
        let result = parse("""
            root = col([a, b])
            a = txt("Hello")
            b = txt("World")
            """)

        XCTAssertNotNil(result)
        guard case .col(let children, let align) = result else {
            XCTFail("Expected col"); return
        }
        XCTAssertEqual(children.count, 2)
        XCTAssertEqual(align, .start)
        guard case .txt(let text, _, _, _) = children[0] else { XCTFail("Expected txt"); return }
        XCTAssertEqual(text, "Hello")
    }

    func testParseColWithAlign() {
        let result = parse("""
            root = col([a], center)
            a = txt("Centered")
            """)

        XCTAssertNotNil(result)
        guard case .col(_, let align) = result else { XCTFail("Expected col"); return }
        XCTAssertEqual(align, .center)
    }

    func testParseRow() {
        let result = parse("""
            root = row([a, b], space_between)
            a = txt("Left")
            b = txt("Right")
            """)

        XCTAssertNotNil(result)
        guard case .row(let children, let align, let gap) = result else {
            XCTFail("Expected row"); return
        }
        XCTAssertEqual(children.count, 2)
        XCTAssertEqual(align, .spaceBetween)
        XCTAssertEqual(gap, 8)
    }

    func testParseRowWithGap() {
        let result = parse("""
            root = row([a, b], 12)
            a = txt("A")
            b = txt("B")
            """)

        XCTAssertNotNil(result)
        guard case .row(_, let align, let gap) = result else { XCTFail("Expected row"); return }
        XCTAssertEqual(gap, 12)
        XCTAssertEqual(align, .start)
    }

    func testParseRowWithAlignAndGap() {
        let result = parse("""
            root = row([a, b], space_between, 16)
            a = txt("A")
            b = txt("B")
            """)

        XCTAssertNotNil(result)
        guard case .row(_, let align, let gap) = result else { XCTFail("Expected row"); return }
        XCTAssertEqual(align, .spaceBetween)
        XCTAssertEqual(gap, 16)
    }

    func testParseTxt() {
        let result = parse(#"root = txt("Hello World", headline)"#)

        XCTAssertNotNil(result)
        guard case .txt(let text, let style, _, _) = result else { XCTFail("Expected txt"); return }
        XCTAssertEqual(text, "Hello World")
        XCTAssertEqual(style, .headline)
    }

    func testParseTxtDefaults() {
        let result = parse(#"root = txt("Simple text")"#)

        XCTAssertNotNil(result)
        guard case .txt(let text, let style, let maxLines, _) = result else { XCTFail("Expected txt"); return }
        XCTAssertEqual(text, "Simple text")
        XCTAssertEqual(style, .body)
        XCTAssertNil(maxLines)
    }

    func testParseTxtWithMaxLines() {
        let result = parse(#"root = txt("Long text", body, max_lines=3)"#)

        XCTAssertNotNil(result)
        guard case .txt(_, _, let maxLines, _) = result else { XCTFail("Expected txt"); return }
        XCTAssertEqual(maxLines, 3)
    }

    func testParseTxtWithEscapes() {
        let result = parse(#"root = txt("She said \"hello\"")"#)

        XCTAssertNotNil(result)
        guard case .txt(let text, _, _, _) = result else { XCTFail("Expected txt"); return }
        XCTAssertEqual(text, #"She said "hello""#)
    }

    func testParseImg() {
        let result = parse(#"root = img("https://example.com/photo.jpg", 180)"#)

        XCTAssertNotNil(result)
        guard case .img(let url, let height) = result else { XCTFail("Expected img"); return }
        XCTAssertEqual(url, "https://example.com/photo.jpg")
        XCTAssertEqual(height, 180)
    }

    func testParseImgNoHeight() {
        let result = parse(#"root = img("https://example.com/photo.jpg")"#)

        XCTAssertNotNil(result)
        guard case .img(_, let height) = result else { XCTFail("Expected img"); return }
        XCTAssertNil(height)
    }

    func testParseIcon() {
        let result = parse(#"root = icon("partly_cloudy_day", 28)"#)

        XCTAssertNotNil(result)
        guard case .icon(let name, let size) = result else { XCTFail("Expected icon"); return }
        XCTAssertEqual(name, "partly_cloudy_day")
        XCTAssertEqual(size, 28)
    }

    func testParseIconDefaults() {
        let result = parse(#"root = icon("star")"#)

        XCTAssertNotNil(result)
        guard case .icon(let name, let size) = result else { XCTFail("Expected icon"); return }
        XCTAssertEqual(name, "star")
        XCTAssertEqual(size, 20)
    }

    func testParseDivider() {
        let result = parse("root = divider()")
        XCTAssertNotNil(result)
        guard case .divider = result else { XCTFail("Expected divider"); return }
    }

    func testParseSpacer() {
        let result = parse("root = spacer(16)")
        XCTAssertNotNil(result)
        guard case .spacer(let height) = result else { XCTFail("Expected spacer"); return }
        XCTAssertEqual(height, 16)
    }

    func testParseSpacerDefaults() {
        let result = parse("root = spacer()")
        XCTAssertNotNil(result)
        guard case .spacer(let height) = result else { XCTFail("Expected spacer"); return }
        XCTAssertEqual(height, 8)
    }

    func testParseCard() {
        let result = parse("""
            root = card([title, body])
            title = txt("Title", title)
            body = txt("Body text")
            """)

        XCTAssertNotNil(result)
        guard case .card(let children, let elevation) = result else { XCTFail("Expected card"); return }
        XCTAssertEqual(children.count, 2)
        XCTAssertEqual(elevation, 1)
    }

    func testParseCardWithElevation() {
        let result = parse("""
            root = card([a], 0)
            a = txt("Flat")
            """)

        XCTAssertNotNil(result)
        guard case .card(_, let elevation) = result else { XCTFail("Expected card"); return }
        XCTAssertEqual(elevation, 0)
    }

    func testParseBadge() {
        let result = parse(#"root = badge("★4.5", info)"#)

        XCTAssertNotNil(result)
        guard case .badge(let label, let variant, _) = result else { XCTFail("Expected badge"); return }
        XCTAssertEqual(label, "★4.5")
        XCTAssertEqual(variant, .info)
    }

    func testParseBadgeDefaults() {
        let result = parse(#"root = badge("Tag")"#)

        XCTAssertNotNil(result)
        guard case .badge(_, let variant, _) = result else { XCTFail("Expected badge"); return }
        XCTAssertEqual(variant, .default)
    }

    func testParseProgress() {
        let result = parse(#"root = progress(0.67, "67% complete")"#)

        XCTAssertNotNil(result)
        guard case .progress(let value, let label) = result else { XCTFail("Expected progress"); return }
        XCTAssertEqual(value, 0.67, accuracy: 0.01)
        XCTAssertEqual(label, "67% complete")
    }

    func testParseProgressNoLabel() {
        let result = parse("root = progress(0.3)")

        XCTAssertNotNil(result)
        guard case .progress(let value, let label) = result else { XCTFail("Expected progress"); return }
        XCTAssertEqual(value, 0.3, accuracy: 0.01)
        XCTAssertNil(label)
    }

    func testParseInput() {
        let result = parse(#"root = input("email", "Email Address", email)"#)

        XCTAssertNotNil(result)
        guard case .input(let id, let label, let type, _) = result else { XCTFail("Expected input"); return }
        XCTAssertEqual(id, "email")
        XCTAssertEqual(label, "Email Address")
        XCTAssertEqual(type, .email)
    }

    func testParseInputDefaults() {
        let result = parse(#"root = input("name", "Your Name")"#)

        XCTAssertNotNil(result)
        guard case .input(_, _, let type, let options) = result else { XCTFail("Expected input"); return }
        XCTAssertEqual(type, .text)
        XCTAssertNil(options)
    }

    func testParseInputSelect() {
        let result = parse(#"root = input("guests", "Number of Guests", select, options=["1","2","3","4"])"#)

        XCTAssertNotNil(result)
        guard case .input(let id, _, let type, let options) = result else { XCTFail("Expected input"); return }
        XCTAssertEqual(id, "guests")
        XCTAssertEqual(type, .select)
        XCTAssertNotNil(options)
        XCTAssertEqual(options, ["1", "2", "3", "4"])
    }

    func testParseToggle() {
        let result = parse(#"root = toggle("agree", "I agree to the terms")"#)

        XCTAssertNotNil(result)
        guard case .toggle(let id, let label, let defaultVal) = result else { XCTFail("Expected toggle"); return }
        XCTAssertEqual(id, "agree")
        XCTAssertEqual(label, "I agree to the terms")
        XCTAssertEqual(defaultVal, false)
    }

    func testParseToggleWithDefault() {
        let result = parse(#"root = toggle("notifications", "Enable notifications", true)"#)

        XCTAssertNotNil(result)
        guard case .toggle(_, _, let defaultVal) = result else { XCTFail("Expected toggle"); return }
        XCTAssertEqual(defaultVal, true)
    }

    func testParseList() {
        let result = parse("""
            root = list([a, b, c])
            a = txt("Item 1")
            b = txt("Item 2")
            c = txt("Item 3")
            """)

        XCTAssertNotNil(result)
        guard case .dataList(let children, let dividers) = result else { XCTFail("Expected dataList"); return }
        XCTAssertEqual(children.count, 3)
        XCTAssertEqual(dividers, true)
    }

    func testParseListNoDividers() {
        let result = parse("""
            root = list([a], false)
            a = txt("Solo")
            """)

        XCTAssertNotNil(result)
        guard case .dataList(_, let dividers) = result else { XCTFail("Expected dataList"); return }
        XCTAssertEqual(dividers, false)
    }

    func testParseTable() {
        let result = parse(#"root = table(["Feature", "Basic", "Pro"], [["Storage", "50 GB", "500 GB"], ["Users", "1", "10"]])"#)

        XCTAssertNotNil(result)
        guard case .table(let headers, let rows) = result else { XCTFail("Expected table"); return }
        XCTAssertEqual(headers, ["Feature", "Basic", "Pro"])
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[0], ["Storage", "50 GB", "500 GB"])
        XCTAssertEqual(rows[1], ["Users", "1", "10"])
    }

    // ════════════════════════════════════════════════════════════════════
    // Button with All 5 Action Types
    // ════════════════════════════════════════════════════════════════════

    func testParseBtnWithToolAction() {
        let result = parse(#"root = btn("Save", tool(add_note, title="Meeting Notes"), primary)"#)

        XCTAssertNotNil(result)
        guard case .btn(let label, let action, let style, _) = result else { XCTFail("Expected btn"); return }
        XCTAssertEqual(label, "Save")
        XCTAssertEqual(style, .primary)
        guard case .callTool(let name, let args) = action else { XCTFail("Expected callTool"); return }
        XCTAssertEqual(name, "add_note")
        XCTAssertEqual(args["title"], "Meeting Notes")
    }

    func testParseBtnWithUriAction() {
        let result = parse(#"root = btn("Directions", uri("geo:40.72,-73.99?q=Luigi's"), text)"#)

        XCTAssertNotNil(result)
        guard case .btn(let label, let action, let style, _) = result else { XCTFail("Expected btn"); return }
        XCTAssertEqual(label, "Directions")
        XCTAssertEqual(style, .text)
        guard case .openUri(let uri) = action else { XCTFail("Expected openUri"); return }
        XCTAssertEqual(uri, "geo:40.72,-73.99?q=Luigi's")
    }

    func testParseBtnWithNavAction() {
        let result = parse(#"root = btn("Home", nav("home"), outline)"#)

        XCTAssertNotNil(result)
        guard case .btn(_, let action, let style, _) = result else { XCTFail("Expected btn"); return }
        XCTAssertEqual(style, .outline)
        guard case .navigate(let route) = action else { XCTFail("Expected navigate"); return }
        XCTAssertEqual(route, "home")
    }

    func testParseBtnWithCopyAction() {
        let result = parse(#"root = btn("Copy Address", copy("119 Mulberry St"), text)"#)

        XCTAssertNotNil(result)
        guard case .btn(_, let action, _, _) = result else { XCTFail("Expected btn"); return }
        guard case .copyText(let text) = action else { XCTFail("Expected copyText"); return }
        XCTAssertEqual(text, "119 Mulberry St")
    }

    func testParseBtnWithSubmitAction() {
        let result = parse(#"root = btn("Confirm Booking", submit(create_reservation, restaurant="Luigi's"), primary)"#)

        XCTAssertNotNil(result)
        guard case .btn(let label, let action, _, _) = result else { XCTFail("Expected btn"); return }
        XCTAssertEqual(label, "Confirm Booking")
        guard case .submit(let toolName, let staticArgs) = action else { XCTFail("Expected submit"); return }
        XCTAssertEqual(toolName, "create_reservation")
        XCTAssertEqual(staticArgs["restaurant"], "Luigi's")
    }

    func testParseBtnWithIcon() {
        let result = parse(#"root = btn("Call", uri("tel:+15551234567"), primary, icon="phone")"#)

        XCTAssertNotNil(result)
        guard case .btn(_, _, _, let icon) = result else { XCTFail("Expected btn"); return }
        XCTAssertEqual(icon, "phone")
    }

    func testParseBtnDefaultStyle() {
        let result = parse(#"root = btn("Click", nav("home"))"#)

        XCTAssertNotNil(result)
        guard case .btn(_, _, let style, _) = result else { XCTFail("Expected btn"); return }
        XCTAssertEqual(style, .primary)
    }

    // ════════════════════════════════════════════════════════════════════
    // Forward References
    // ════════════════════════════════════════════════════════════════════

    func testParseForwardRefChildBeforeParent() {
        let result = parse("""
            root = col([header, body])
            header = txt("Title", title)
            body = card([content])
            content = txt("Details", body)
            """)

        XCTAssertNotNil(result)
        guard case .col(let children, _) = result else { XCTFail("Expected col"); return }
        XCTAssertEqual(children.count, 2)

        guard case .txt(let headerText, _, _, _) = children[0] else { XCTFail("Expected txt"); return }
        XCTAssertEqual(headerText, "Title")

        guard case .card(let cardChildren, _) = children[1] else { XCTFail("Expected card"); return }
        XCTAssertEqual(cardChildren.count, 1)

        guard case .txt(let contentText, _, _, _) = cardChildren[0] else { XCTFail("Expected txt"); return }
        XCTAssertEqual(contentText, "Details")
    }

    func testStreamingModeProducesRefs() {
        let parser = AmeParser()

        let rootResult = parser.parseLine("root = col([header, body])")
        XCTAssertNotNil(rootResult)
        XCTAssertEqual(rootResult?.0, "root")

        let rootNode = rootResult!.1
        guard case .col(let children, _) = rootNode else { XCTFail("Expected col"); return }
        XCTAssertTrue(children.allSatisfy { if case .ref = $0 { return true }; return false })

        let _ = parser.parseLine(#"header = txt("Title", title)"#)
        let tree = parser.getResolvedTree()
        XCTAssertNotNil(tree)

        guard case .col(let resolvedChildren, _) = tree else { XCTFail("Expected col"); return }
        guard case .txt(let resolvedText, _, _, _) = resolvedChildren[0] else { XCTFail("Expected txt"); return }
        XCTAssertEqual(resolvedText, "Title")

        if case .ref = resolvedChildren[1] {} else { XCTFail("body should still be a Ref") }
    }

    // ════════════════════════════════════════════════════════════════════
    // Data Binding
    // ════════════════════════════════════════════════════════════════════

    func testParseDataRefTopLevel() {
        let result = parse("root = txt($name, title)")

        XCTAssertNotNil(result)
        guard case .txt(let text, let style, _, _) = result else { XCTFail("Expected txt"); return }
        XCTAssertEqual(text, "$name")
        XCTAssertEqual(style, .title)
    }

    func testParseDataRefNested() {
        let result = parse("root = txt($address/city, caption)")

        XCTAssertNotNil(result)
        guard case .txt(let text, _, _, _) = result else { XCTFail("Expected txt"); return }
        XCTAssertEqual(text, "$address/city")
    }

    func testParseDataSection() {
        let parser = parserFor("""
            root = col([name_label, rating_label])
            name_label = txt($name, title)
            rating_label = badge($rating, info)
            ---
            {"name": "Luigi's", "rating": "★4.5"}
            """)

        XCTAssertNotNil(parser.getDataModel())
        XCTAssertEqual(parser.resolveDataPath("name"), "Luigi's")
        XCTAssertEqual(parser.resolveDataPath("rating"), "★4.5")
    }

    func testParseDataSectionNestedPath() {
        let parser = parserFor("""
            root = txt($address/city, caption)
            ---
            {"address": {"city": "New York", "state": "NY"}}
            """)

        XCTAssertEqual(parser.resolveDataPath("address/city"), "New York")
    }

    // ════════════════════════════════════════════════════════════════════
    // each() Construct
    // ════════════════════════════════════════════════════════════════════

    func testParseEach() {
        let parser = AmeParser()
        let result = parser.parse("""
            root = col([title, results])
            title = txt("Italian Restaurants", headline)
            results = each($places, place_tpl)
            place_tpl = card([txt($name, title)])
            """)

        XCTAssertNotNil(result)
        guard case .col(let children, _) = result else { XCTFail("Expected col"); return }

        guard case .each(let dataPath, let templateId) = children[1] else { XCTFail("Expected each"); return }
        XCTAssertEqual(dataPath, "places")
        XCTAssertEqual(templateId, "place_tpl")
    }

    // ════════════════════════════════════════════════════════════════════
    // Complete Examples from syntax.md
    // ════════════════════════════════════════════════════════════════════

    func testParseWeatherCard() {
        let result = parse("""
            root = card([weather_header, temp, condition, details])
            weather_header = row([city, weather_icon], space_between)
            city = txt("San Francisco", title)
            weather_icon = icon("partly_cloudy_day", 28)
            temp = txt("62°", display)
            condition = txt("Partly Cloudy", body)
            details = row([high_low, humidity], space_between)
            high_low = txt("H:68°  L:55°", caption)
            humidity = txt("Humidity: 72%", caption)
            """)

        XCTAssertNotNil(result)
        guard case .card(let children, _) = result else { XCTFail("Expected card"); return }
        XCTAssertEqual(children.count, 4)

        guard case .row(let headerChildren, let headerAlign, _) = children[0] else { XCTFail("Expected row"); return }
        XCTAssertEqual(headerAlign, .spaceBetween)
        XCTAssertEqual(headerChildren.count, 2)

        guard case .txt(let cityText, let cityStyle, _, _) = headerChildren[0] else { XCTFail("Expected txt"); return }
        XCTAssertEqual(cityText, "San Francisco")
        XCTAssertEqual(cityStyle, .title)

        guard case .icon(let iconName, let iconSize) = headerChildren[1] else { XCTFail("Expected icon"); return }
        XCTAssertEqual(iconName, "partly_cloudy_day")
        XCTAssertEqual(iconSize, 28)

        guard case .txt(let tempText, let tempStyle, _, _) = children[1] else { XCTFail("Expected txt"); return }
        XCTAssertEqual(tempText, "62°")
        XCTAssertEqual(tempStyle, .display)

        guard case .txt(let condText, _, _, _) = children[2] else { XCTFail("Expected txt"); return }
        XCTAssertEqual(condText, "Partly Cloudy")

        guard case .row(let detailChildren, let detailAlign, _) = children[3] else { XCTFail("Expected row"); return }
        XCTAssertEqual(detailChildren.count, 2)
        XCTAssertEqual(detailAlign, .spaceBetween)

        guard case .txt(let hlText, let hlStyle, _, _) = detailChildren[0] else { XCTFail("Expected txt"); return }
        XCTAssertEqual(hlText, "H:68°  L:55°")
        XCTAssertEqual(hlStyle, .caption)
    }

    func testParsePlaceSearch() {
        let input = """
            root = col([header, results])
            header = txt("Italian Restaurants Nearby", headline)
            results = list([p1, p2, p3])
            p1 = card([p1_top, p1_addr, p1_btns])
            p1_top = row([p1_name, p1_rating], space_between)
            p1_name = txt("Luigi's", title)
            p1_rating = badge("★4.5", info)
            p1_addr = txt("119 Mulberry St, New York", caption)
            p1_btns = row([p1_sched, p1_dir], 8)
            p1_sched = btn("Schedule", tool(create_calendar_event, title="Dinner at Luigi's", location="119 Mulberry St"), primary)
            p1_dir = btn("Directions", uri("geo:40.72,-73.99?q=Luigi's"), text)
            p2 = card([p2_top, p2_addr, p2_btns])
            p2_top = row([p2_name, p2_rating], space_between)
            p2_name = txt("Joe's Pizza", title)
            p2_rating = badge("★4.3", info)
            p2_addr = txt("375 Canal St, New York", caption)
            p2_btns = row([p2_sched, p2_dir], 8)
            p2_sched = btn("Schedule", tool(create_calendar_event, title="Dinner at Joe's Pizza", location="375 Canal St"), primary)
            p2_dir = btn("Directions", uri("geo:40.72,-74.00?q=Joe's Pizza"), text)
            p3 = card([p3_top, p3_addr, p3_btns])
            p3_top = row([p3_name, p3_rating], space_between)
            p3_name = txt("Carbone", title)
            p3_rating = badge("★4.7", info)
            p3_addr = txt("181 Thompson St, New York", caption)
            p3_btns = row([p3_sched, p3_dir], 8)
            p3_sched = btn("Schedule", tool(create_calendar_event, title="Dinner at Carbone", location="181 Thompson St"), primary)
            p3_dir = btn("Directions", uri("geo:40.73,-74.00?q=Carbone"), text)
            """

        let result = parse(input)
        XCTAssertNotNil(result)
        guard case .col(let children, _) = result else { XCTFail("Expected col"); return }
        XCTAssertEqual(children.count, 2)

        guard case .txt(let headerText, let headerStyle, _, _) = children[0] else { XCTFail("Expected txt"); return }
        XCTAssertEqual(headerText, "Italian Restaurants Nearby")
        XCTAssertEqual(headerStyle, .headline)

        guard case .dataList(let listChildren, _) = children[1] else { XCTFail("Expected dataList"); return }
        XCTAssertEqual(listChildren.count, 3)

        // Verify first card
        guard case .card(let p1Children, _) = listChildren[0] else { XCTFail("Expected card"); return }
        XCTAssertEqual(p1Children.count, 3)

        guard case .row(let p1TopChildren, let p1TopAlign, _) = p1Children[0] else { XCTFail("Expected row"); return }
        XCTAssertEqual(p1TopAlign, .spaceBetween)

        guard case .txt(let p1Name, _, _, _) = p1TopChildren[0] else { XCTFail("Expected txt"); return }
        XCTAssertEqual(p1Name, "Luigi's")

        guard case .badge(let p1Rating, let p1Variant, _) = p1TopChildren[1] else { XCTFail("Expected badge"); return }
        XCTAssertEqual(p1Rating, "★4.5")
        XCTAssertEqual(p1Variant, .info)

        guard case .row(let p1BtnChildren, _, _) = p1Children[2] else { XCTFail("Expected row"); return }
        XCTAssertEqual(p1BtnChildren.count, 2)

        guard case .btn(let schedLabel, let schedAction, let schedStyle, _) = p1BtnChildren[0] else { XCTFail("Expected btn"); return }
        XCTAssertEqual(schedLabel, "Schedule")
        XCTAssertEqual(schedStyle, .primary)
        guard case .callTool(let toolName, let toolArgs) = schedAction else { XCTFail("Expected callTool"); return }
        XCTAssertEqual(toolName, "create_calendar_event")
        XCTAssertEqual(toolArgs["title"], "Dinner at Luigi's")

        // Verify third card name
        guard case .card(let p3Children, _) = listChildren[2] else { XCTFail("Expected card"); return }
        guard case .row(let p3TopChildren, _, _) = p3Children[0] else { XCTFail("Expected row"); return }
        guard case .txt(let p3Name, _, _, _) = p3TopChildren[0] else { XCTFail("Expected txt"); return }
        XCTAssertEqual(p3Name, "Carbone")
    }

    func testParseBookingForm() {
        let input = """
            root = card([form_title, form_fields, form_actions])
            form_title = txt("Book a Table", headline)
            form_fields = col([date_field, time_field, guests_field, notes_field])
            date_field = input("date", "Date", date)
            time_field = input("time", "Time", time)
            guests_field = input("guests", "Number of Guests", select, options=["1","2","3","4","5","6","7","8"])
            notes_field = input("notes", "Special Requests", text)
            form_actions = row([cancel_btn, confirm_btn], space_between)
            cancel_btn = btn("Cancel", nav("home"), text)
            confirm_btn = btn("Confirm Booking", submit(create_reservation, restaurant="Luigi's"), primary)
            """

        let result = parse(input)
        XCTAssertNotNil(result)
        guard case .card(let children, _) = result else { XCTFail("Expected card"); return }
        XCTAssertEqual(children.count, 3)

        guard case .txt(let titleText, let titleStyle, _, _) = children[0] else { XCTFail("Expected txt"); return }
        XCTAssertEqual(titleText, "Book a Table")
        XCTAssertEqual(titleStyle, .headline)

        guard case .col(let fields, _) = children[1] else { XCTFail("Expected col"); return }
        XCTAssertEqual(fields.count, 4)

        guard case .input(let dateId, _, let dateType, _) = fields[0] else { XCTFail("Expected input"); return }
        XCTAssertEqual(dateId, "date")
        XCTAssertEqual(dateType, .date)

        guard case .input(_, _, let timeType, _) = fields[1] else { XCTFail("Expected input"); return }
        XCTAssertEqual(timeType, .time)

        guard case .input(let guestsId, _, let guestsType, let guestsOptions) = fields[2] else { XCTFail("Expected input"); return }
        XCTAssertEqual(guestsId, "guests")
        XCTAssertEqual(guestsType, .select)
        XCTAssertNotNil(guestsOptions)
        XCTAssertEqual(guestsOptions!.count, 8)

        guard case .row(let actionChildren, let actionAlign, _) = children[2] else { XCTFail("Expected row"); return }
        XCTAssertEqual(actionAlign, .spaceBetween)
        XCTAssertEqual(actionChildren.count, 2)

        guard case .btn(_, let cancelAction, let cancelStyle, _) = actionChildren[0] else { XCTFail("Expected btn"); return }
        XCTAssertEqual(cancelStyle, .text)
        guard case .navigate(let route) = cancelAction else { XCTFail("Expected navigate"); return }
        XCTAssertEqual(route, "home")

        guard case .btn(_, let confirmAction, let confirmStyle, _) = actionChildren[1] else { XCTFail("Expected btn"); return }
        XCTAssertEqual(confirmStyle, .primary)
        guard case .submit(let toolName, let staticArgs) = confirmAction else { XCTFail("Expected submit"); return }
        XCTAssertEqual(toolName, "create_reservation")
        XCTAssertEqual(staticArgs["restaurant"], "Luigi's")
    }

    // ════════════════════════════════════════════════════════════════════
    // Inline Component Calls in Children Arrays
    // ════════════════════════════════════════════════════════════════════

    func testParseInlineComponentCallsInArray() {
        let result = parse(#"root = row([txt("Name", title), badge("★4.5", info)], space_between)"#)

        XCTAssertNotNil(result)
        guard case .row(let children, _, _) = result else { XCTFail("Expected row"); return }
        XCTAssertEqual(children.count, 2)

        guard case .txt(let name, let nameStyle, _, _) = children[0] else { XCTFail("Expected txt"); return }
        XCTAssertEqual(name, "Name")
        XCTAssertEqual(nameStyle, .title)

        guard case .badge(let badgeLabel, _, _) = children[1] else { XCTFail("Expected badge"); return }
        XCTAssertEqual(badgeLabel, "★4.5")
    }

    // ════════════════════════════════════════════════════════════════════
    // Error Cases — Parser Must Not Crash
    // ════════════════════════════════════════════════════════════════════

    func testParseMalformedLineNoEquals() {
        let parser = AmeParser()
        let result = parser.parse("""
            root = txt("Hello")
            this line has no equals sign
            another = txt("World")
            """)

        XCTAssertNotNil(result)
        guard case .txt(let text, _, _, _) = result else { XCTFail("Expected txt"); return }
        XCTAssertEqual(text, "Hello")
        XCTAssertFalse(parser.errors.isEmpty, "Should log error for malformed line")
    }

    func testParseUnknownComponent() {
        let parser = AmeParser()
        let result = parser.parse(#"root = foobar("test")"#)

        XCTAssertNotNil(result)
        guard case .txt(let text, _, _, _) = result else { XCTFail("Expected txt"); return }
        XCTAssertTrue(text.contains("Unknown"), "Unknown component should produce warning txt")
        XCTAssertTrue(parser.warnings.contains(where: { $0.contains("Unknown") }))
    }

    func testParseUnclosedParenthesis() {
        let parser = AmeParser()
        let result = parser.parse(#"root = txt("Hello", headline"#)

        XCTAssertNotNil(result)
        guard case .txt(let text, _, _, _) = result else { XCTFail("Expected txt"); return }
        XCTAssertEqual(text, "Hello")
        XCTAssertTrue(parser.warnings.contains(where: { $0.contains("parenthesis") || $0.contains("Unclosed") }))
    }

    func testParseUnclosedString() {
        let parser = AmeParser()
        let result = parser.parse(#"root = txt("Hello World)"#)

        XCTAssertNotNil(result)
        XCTAssertTrue(parser.warnings.contains(where: { $0.contains("string") || $0.contains("Unclosed") }))
    }

    func testParseDuplicateIdentifier() {
        let parser = AmeParser()
        let result = parser.parse("""
            root = col([header])
            header = txt("First")
            header = txt("Second")
            """)

        XCTAssertNotNil(result)
        guard case .col(let children, _) = result else { XCTFail("Expected col"); return }

        guard case .txt(let text, _, _, _) = children[0] else { XCTFail("Expected txt"); return }
        XCTAssertEqual(text, "Second")
        XCTAssertTrue(parser.warnings.contains(where: { $0.contains("Duplicate") }))
    }

    func testParseEmptyInput() {
        let result = parse("")
        XCTAssertNil(result)
    }

    func testParseOnlyComments() {
        let result = parse("""
            // This is a comment
            // Another comment
            """)
        XCTAssertNil(result)
    }

    func testParseCommentsInterspersed() {
        let result = parse("""
            // Header section
            root = col([header, body])
            // Title
            header = txt("Welcome", headline)
            body = txt("Content")
            """)

        XCTAssertNotNil(result)
        guard case .col(let children, _) = result else { XCTFail("Expected col"); return }
        XCTAssertEqual(children.count, 2)
    }

    // ════════════════════════════════════════════════════════════════════
    // Parser Leniency
    // ════════════════════════════════════════════════════════════════════

    func testParseLenientUnquotedInputId() {
        let result = parse(#"root = input(email, "Email Address", email)"#)

        XCTAssertNotNil(result)
        guard case .input(let id, _, _, _) = result else { XCTFail("Expected input"); return }
        XCTAssertEqual(id, "email")
    }

    func testParseLenientQuotedToolName() {
        let result = parse(#"root = btn("Save", tool("add_note", title="Notes"), primary)"#)

        XCTAssertNotNil(result)
        guard case .btn(_, let action, _, _) = result else { XCTFail("Expected btn"); return }
        guard case .callTool(let name, _) = action else { XCTFail("Expected callTool"); return }
        XCTAssertEqual(name, "add_note")
    }

    // ════════════════════════════════════════════════════════════════════
    // Data Path in Action Arguments
    // ════════════════════════════════════════════════════════════════════

    func testParseDataRefInActionArg() {
        let result = parse(#"root = btn("Directions", uri($map_url), text)"#)

        XCTAssertNotNil(result)
        guard case .btn(_, let action, _, _) = result else { XCTFail("Expected btn"); return }
        guard case .openUri(let uri) = action else { XCTFail("Expected openUri"); return }
        XCTAssertEqual(uri, "$map_url")
    }

    // ════════════════════════════════════════════════════════════════════
    // Tool Action with Multiple Named Args
    // ════════════════════════════════════════════════════════════════════

    func testParseToolActionMultipleArgs() {
        let result = parse(#"root = btn("Schedule", tool(create_event, title="Dinner", date="2026-04-15", location="Cafe"), primary)"#)

        XCTAssertNotNil(result)
        guard case .btn(_, let action, _, _) = result else { XCTFail("Expected btn"); return }
        guard case .callTool(let name, let args) = action else { XCTFail("Expected callTool"); return }
        XCTAssertEqual(name, "create_event")
        XCTAssertEqual(args.count, 3)
        XCTAssertEqual(args["title"], "Dinner")
        XCTAssertEqual(args["date"], "2026-04-15")
        XCTAssertEqual(args["location"], "Cafe")
    }

    // ════════════════════════════════════════════════════════════════════
    // Example .ame Files Smoke Tests
    // ════════════════════════════════════════════════════════════════════

    func testParseWeatherCardAmeFile() {
        let input = """
        // weather-card.ame
        root = card([weather_header, temp, condition, details])
        weather_header = row([city, weather_icon], space_between)
        city = txt("San Francisco", title)
        weather_icon = icon("partly_cloudy_day", 28)
        temp = txt("62°", display)
        condition = txt("Partly Cloudy", body)
        details = row([high_low, humidity], space_between)
        high_low = txt("H:68°  L:55°", caption)
        humidity = txt("Humidity: 72%", caption)
        """
        XCTAssertNotNil(parse(input))
    }

    func testParseBookingFormAmeFile() {
        let input = """
        // booking-form.ame
        root = card([form_title, form_fields, form_actions])
        form_title = txt("Book a Table", headline)
        form_fields = col([date_field, time_field, guests_field, notes_field])
        date_field = input("date", "Date", date)
        time_field = input("time", "Time", time)
        guests_field = input("guests", "Number of Guests", select, options=["1","2","3","4","5","6","7","8"])
        notes_field = input("notes", "Special Requests", text)
        form_actions = row([cancel_btn, confirm_btn], space_between)
        cancel_btn = btn("Cancel", nav("home"), text)
        confirm_btn = btn("Confirm Booking", submit(create_reservation, restaurant="Luigi's"), primary)
        """
        XCTAssertNotNil(parse(input))
    }

    func testParsePlaceSearchAmeFile() {
        let input = """
        // place-search.ame
        root = col([header, results])
        header = txt("Italian Restaurants Nearby", headline)
        results = list([p1, p2, p3])
        p1 = card([p1_top, p1_addr, p1_btns])
        p1_top = row([p1_name, p1_rating], space_between)
        p1_name = txt("Luigi's", title)
        p1_rating = badge("★4.5", info)
        p1_addr = txt("119 Mulberry St, New York", caption)
        p1_btns = row([p1_sched, p1_dir], 8)
        p1_sched = btn("Schedule", tool(create_calendar_event, title="Dinner at Luigi's"), primary)
        p1_dir = btn("Directions", uri("geo:40.72,-73.99"), text)
        p2 = card([p2_top, p2_addr])
        p2_top = row([p2_name, p2_rating], space_between)
        p2_name = txt("Joe's Pizza", title)
        p2_rating = badge("★4.3", info)
        p2_addr = txt("375 Canal St, New York", caption)
        p3 = card([p3_top, p3_addr])
        p3_top = row([p3_name, p3_rating], space_between)
        p3_name = txt("Carbone", title)
        p3_rating = badge("★4.7", info)
        p3_addr = txt("181 Thompson St, New York", caption)
        """
        XCTAssertNotNil(parse(input))
    }

    func testParseEmailInboxAmeFile() {
        let input = """
        // email-inbox.ame
        root = col([inbox_title, inbox_list])
        inbox_title = txt("Inbox", headline)
        inbox_list = list([e1, e2, e3])
        e1 = card([e1_top, e1_subj, e1_preview])
        e1_top = row([e1_from, e1_badge], space_between)
        e1_from = txt("Alice Smith", title)
        e1_badge = badge("New", info)
        e1_subj = txt("Project Update", label)
        e1_preview = txt("Here are the latest changes...", caption)
        e2 = card([e2_top, e2_subj, e2_preview])
        e2_top = row([e2_from], space_between)
        e2_from = txt("Bob Jones", title)
        e2_subj = txt("Meeting Tomorrow", label)
        e2_preview = txt("Can we reschedule to 3pm?", caption)
        e3 = card([e3_top, e3_subj, e3_preview])
        e3_top = row([e3_from, e3_badge], space_between)
        e3_from = txt("Carol Lee", title)
        e3_badge = badge("New", info)
        e3_subj = txt("Lunch Plans", label)
        e3_preview = txt("How about the Italian place?", caption)
        """
        XCTAssertNotNil(parse(input))
    }

    func testParseComparisonAmeFile() {
        let input = """
        // comparison.ame
        root = col([comp_title, comp_table, comp_btns])
        comp_title = txt("Choose Your Plan", headline)
        comp_table = table(["Feature", "Basic", "Pro"], [["Storage", "50 GB", "500 GB"], ["Users", "1", "10"], ["Support", "Email", "24/7"]])
        comp_btns = row([basic_btn, pro_btn], space_between)
        basic_btn = btn("Select Basic", tool(select_plan, plan="basic"), outline)
        pro_btn = btn("Select Pro", tool(select_plan, plan="pro"), primary)
        """
        XCTAssertNotNil(parse(input))
    }

    // ════════════════════════════════════════════════════════════════════
    // each() Expansion with Data Model
    // ════════════════════════════════════════════════════════════════════

    func testEachExpandsWithDataSection() {
        let parser = AmeParser()
        let result = parser.parse("""
            root = col([header, results])
            header = txt("Restaurants", headline)
            results = each($places, place_tpl)
            place_tpl = card([txt($name, title)])
            ---
            {"places":[{"name":"Pizza Palace"},{"name":"Sushi Spot"},{"name":"Taco Town"}]}
            """)

        XCTAssertNotNil(result)
        guard case .col(let children, _) = result else { XCTFail("Expected col"); return }
        XCTAssertEqual(children.count, 2)

        guard case .txt(let headerText, _, _, _) = children[0] else { XCTFail("Expected txt"); return }
        XCTAssertEqual(headerText, "Restaurants")

        guard case .col(let expanded, _) = children[1] else { XCTFail("Expected expanded col"); return }
        XCTAssertEqual(expanded.count, 3)

        guard case .card(let card0Children, _) = expanded[0] else { XCTFail("Expected card"); return }
        guard case .txt(let txt0, _, _, _) = card0Children[0] else { XCTFail("Expected txt"); return }
        XCTAssertEqual(txt0, "Pizza Palace")

        guard case .card(let card1Children, _) = expanded[1] else { XCTFail("Expected card"); return }
        guard case .txt(let txt1, _, _, _) = card1Children[0] else { XCTFail("Expected txt"); return }
        XCTAssertEqual(txt1, "Sushi Spot")

        guard case .card(let card2Children, _) = expanded[2] else { XCTFail("Expected card"); return }
        guard case .txt(let txt2, _, _, _) = card2Children[0] else { XCTFail("Expected txt"); return }
        XCTAssertEqual(txt2, "Taco Town")
    }

    func testEachPreservedWithoutDataSection() {
        let parser = AmeParser()
        let result = parser.parse("""
            root = col([title, results])
            title = txt("Restaurants", headline)
            results = each($places, place_tpl)
            place_tpl = card([txt($name, title)])
            """)

        XCTAssertNotNil(result)
        guard case .col(let children, _) = result else { XCTFail("Expected col"); return }
        XCTAssertEqual(children.count, 2)

        guard case .each(let dataPath, let templateId) = children[1] else { XCTFail("Expected each"); return }
        XCTAssertEqual(dataPath, "places")
        XCTAssertEqual(templateId, "place_tpl")
    }

    func testEachEmptyArrayProducesEmptyCol() {
        let parser = AmeParser()
        let result = parser.parse("""
            root = col([header, results])
            header = txt("Results", headline)
            results = each($items, item_tpl)
            item_tpl = txt($label, body)
            ---
            {"items":[]}
            """)

        XCTAssertNotNil(result)
        guard case .col(let children, _) = result else { XCTFail("Expected col"); return }
        XCTAssertEqual(children.count, 2)

        guard case .col(let expanded, _) = children[1] else { XCTFail("Expected expanded col"); return }
        XCTAssertEqual(expanded.count, 0)
    }

    func testEachSingleElementReturnsUnwrapped() {
        let parser = AmeParser()
        let result = parser.parse("""
            root = col([header, results])
            header = txt("Solo", headline)
            results = each($items, item_tpl)
            item_tpl = txt($value, body)
            ---
            {"items":[{"value":"Only One"}]}
            """)

        XCTAssertNotNil(result)
        guard case .col(let children, _) = result else { XCTFail("Expected col"); return }
        XCTAssertEqual(children.count, 2)

        guard case .txt(let text, _, _, _) = children[1] else { XCTFail("Expected unwrapped txt"); return }
        XCTAssertEqual(text, "Only One")
    }

    func testEachResolvesMultiplePathsInTemplate() {
        let parser = AmeParser()
        let result = parser.parse("""
            root = each($contacts, contact_card)
            contact_card = row([txt($name, title), txt($phone, body)])
            ---
            {"contacts":[{"name":"Alice","phone":"555-1234"},{"name":"Bob","phone":"555-5678"}]}
            """)

        XCTAssertNotNil(result)
        guard case .col(let expanded, _) = result else { XCTFail("Expected col"); return }
        XCTAssertEqual(expanded.count, 2)

        guard case .row(let row0Children, _, _) = expanded[0] else { XCTFail("Expected row"); return }
        guard case .txt(let name0, _, _, _) = row0Children[0] else { XCTFail("Expected txt"); return }
        XCTAssertEqual(name0, "Alice")
        guard case .txt(let phone0, _, _, _) = row0Children[1] else { XCTFail("Expected txt"); return }
        XCTAssertEqual(phone0, "555-1234")

        guard case .row(let row1Children, _, _) = expanded[1] else { XCTFail("Expected row"); return }
        guard case .txt(let name1, _, _, _) = row1Children[0] else { XCTFail("Expected txt"); return }
        XCTAssertEqual(name1, "Bob")
        guard case .txt(let phone1, _, _, _) = row1Children[1] else { XCTFail("Expected txt"); return }
        XCTAssertEqual(phone1, "555-5678")
    }

    func testEachMissingPathProducesEmptyCol() {
        let parser = AmeParser()
        let result = parser.parse("""
            root = col([header, results])
            header = txt("Missing", headline)
            results = each($nonexistent, item_tpl)
            item_tpl = txt($value, body)
            ---
            {"other_key":"hello"}
            """)

        XCTAssertNotNil(result)
        guard case .col(let children, _) = result else { XCTFail("Expected col"); return }
        XCTAssertEqual(children.count, 2)

        guard case .col(let expanded, _) = children[1] else { XCTFail("Expected expanded col"); return }
        XCTAssertEqual(expanded.count, 0)

        XCTAssertFalse(parser.warnings.isEmpty)
    }

    func testEachNestedPathResolvesCorrectly() {
        let parser = AmeParser()
        let result = parser.parse("""
            root = each($data/results, item_tpl)
            item_tpl = txt($title, body)
            ---
            {"data":{"results":[{"title":"First"},{"title":"Second"}]}}
            """)

        XCTAssertNotNil(result)
        guard case .col(let expanded, _) = result else { XCTFail("Expected col"); return }
        XCTAssertEqual(expanded.count, 2)

        guard case .txt(let txt0, _, _, _) = expanded[0] else { XCTFail("Expected txt"); return }
        XCTAssertEqual(txt0, "First")

        guard case .txt(let txt1, _, _, _) = expanded[1] else { XCTFail("Expected txt"); return }
        XCTAssertEqual(txt1, "Second")
    }

    // ════════════════════════════════════════════════════════════════════
    // v1.1 Primitives — Parser Tests
    // ════════════════════════════════════════════════════════════════════

    // MARK: - Chart Tests

    func testParseChartBar() {
        let result = parse(#"root = chart(bar, values=[10, 20, 30])"#)
        XCTAssertNotNil(result)
        guard case .chart(let type, let values, _, _, let height, _, _, _, _, _) = result else {
            XCTFail("Expected chart"); return
        }
        XCTAssertEqual(type, .bar)
        XCTAssertEqual(values, [10, 20, 30])
        XCTAssertEqual(height, 200)
    }

    func testParseChartLine() {
        let result = parse(#"root = chart(line, values=[1.5, 2.5, 3.5], height=300)"#)
        XCTAssertNotNil(result)
        guard case .chart(let type, let values, _, _, let height, _, _, _, _, _) = result else {
            XCTFail("Expected chart"); return
        }
        XCTAssertEqual(type, .line)
        XCTAssertEqual(values, [1.5, 2.5, 3.5])
        XCTAssertEqual(height, 300)
    }

    func testParseChartWithColor() {
        let result = parse(#"root = chart(pie, values=[40, 60], color=success)"#)
        XCTAssertNotNil(result)
        guard case .chart(let type, _, _, _, _, let color, _, _, _, _) = result else {
            XCTFail("Expected chart"); return
        }
        XCTAssertEqual(type, .pie)
        XCTAssertEqual(color, .success)
    }

    func testParseChartWithLabels() {
        let result = parse(#"root = chart(bar, values=[10, 20], labels=["A", "B"])"#)
        XCTAssertNotNil(result)
        guard case .chart(_, _, let labels, _, _, _, _, _, _, _) = result else {
            XCTFail("Expected chart"); return
        }
        XCTAssertEqual(labels, ["A", "B"])
    }

    func testParseChartDataBinding() {
        let parser = AmeParser()
        let result = parser.parse("""
            root = chart(bar, values=$metrics)
            ---
            {"metrics": [5, 10, 15]}
            """)
        XCTAssertNotNil(result)
        guard case .chart(_, let values, _, _, _, _, let valuesPath, _, _, _) = result else {
            XCTFail("Expected chart"); return
        }
        XCTAssertEqual(values, [5, 10, 15])
        XCTAssertNil(valuesPath)
    }

    // MARK: - Code Tests

    func testParseCode() {
        let result = parse(#"root = code("swift", "print(\"hello\")")"#)
        XCTAssertNotNil(result)
        guard case .code(let language, let content, let title) = result else {
            XCTFail("Expected code"); return
        }
        XCTAssertEqual(language, "swift")
        XCTAssertEqual(content, #"print("hello")"#)
        XCTAssertNil(title)
    }

    func testParseCodeWithTitle() {
        let result = parse(#"root = code("kotlin", "val x = 1", "Example")"#)
        XCTAssertNotNil(result)
        guard case .code(_, _, let title) = result else {
            XCTFail("Expected code"); return
        }
        XCTAssertEqual(title, "Example")
    }

    // MARK: - Accordion Tests

    func testParseAccordion() {
        let result = parse("""
            root = accordion("Details", [content])
            content = txt("Hidden text")
            """)
        XCTAssertNotNil(result)
        guard case .accordion(let title, let children, let expanded) = result else {
            XCTFail("Expected accordion"); return
        }
        XCTAssertEqual(title, "Details")
        XCTAssertEqual(children.count, 1)
        XCTAssertFalse(expanded)
    }

    func testParseAccordionExpanded() {
        let result = parse("""
            root = accordion("Open", [inner], true)
            inner = txt("Visible")
            """)
        XCTAssertNotNil(result)
        guard case .accordion(_, _, let expanded) = result else {
            XCTFail("Expected accordion"); return
        }
        XCTAssertTrue(expanded)
    }

    // MARK: - Carousel Tests

    func testParseCarousel() {
        let result = parse("""
            root = carousel([a, b])
            a = txt("Slide 1")
            b = txt("Slide 2")
            """)
        XCTAssertNotNil(result)
        guard case .carousel(let children, let peek) = result else {
            XCTFail("Expected carousel"); return
        }
        XCTAssertEqual(children.count, 2)
        XCTAssertEqual(peek, 24)
    }

    func testParseCarouselWithPeek() {
        let result = parse("""
            root = carousel([a], peek=40)
            a = txt("Slide")
            """)
        XCTAssertNotNil(result)
        guard case .carousel(_, let peek) = result else {
            XCTFail("Expected carousel"); return
        }
        XCTAssertEqual(peek, 40)
    }

    // MARK: - Callout Tests

    func testParseCallout() {
        let result = parse(#"root = callout(warning, "Careful!")"#)
        XCTAssertNotNil(result)
        guard case .callout(let type, let content, let title, _) = result else {
            XCTFail("Expected callout"); return
        }
        XCTAssertEqual(type, .warning)
        XCTAssertEqual(content, "Careful!")
        XCTAssertNil(title)
    }

    func testParseCalloutWithTitle() {
        let result = parse(#"root = callout(error, "Something failed", "Error")"#)
        XCTAssertNotNil(result)
        guard case .callout(let type, _, let title, _) = result else {
            XCTFail("Expected callout"); return
        }
        XCTAssertEqual(type, .error)
        XCTAssertEqual(title, "Error")
    }

    // MARK: - Timeline Tests

    func testParseTimeline() {
        let result = parse("""
            root = timeline([s1, s2])
            s1 = timeline_item("Step 1", "Done", done)
            s2 = timeline_item("Step 2")
            """)
        XCTAssertNotNil(result)
        guard case .timeline(let children) = result else {
            XCTFail("Expected timeline"); return
        }
        XCTAssertEqual(children.count, 2)
    }

    func testParseTimelineItem() {
        let result = parse(#"root = timeline_item("Deploy", "In progress", active)"#)
        XCTAssertNotNil(result)
        guard case .timelineItem(let title, let subtitle, let status) = result else {
            XCTFail("Expected timeline_item"); return
        }
        XCTAssertEqual(title, "Deploy")
        XCTAssertEqual(subtitle, "In progress")
        XCTAssertEqual(status, .active)
    }

    func testParseTimelineItemDefaults() {
        let result = parse(#"root = timeline_item("Pending step")"#)
        XCTAssertNotNil(result)
        guard case .timelineItem(let title, let subtitle, let status) = result else {
            XCTFail("Expected timeline_item"); return
        }
        XCTAssertEqual(title, "Pending step")
        XCTAssertNil(subtitle)
        XCTAssertEqual(status, .pending)
    }

    // MARK: - SemanticColor on txt / badge

    func testParseTxtWithColor() {
        let result = parse(#"root = txt("Colored text", body, color=error)"#)
        XCTAssertNotNil(result)
        guard case .txt(let text, _, _, let color) = result else {
            XCTFail("Expected txt"); return
        }
        XCTAssertEqual(text, "Colored text")
        XCTAssertEqual(color, .error)
    }

    func testParseTxtColorDefaults() {
        let result = parse(#"root = txt("Plain")"#)
        XCTAssertNotNil(result)
        guard case .txt(_, _, _, let color) = result else {
            XCTFail("Expected txt"); return
        }
        XCTAssertNil(color)
    }

    func testParseBadgeWithColor() {
        let result = parse(#"root = badge("Hot", default, color=warning)"#)
        XCTAssertNotNil(result)
        guard case .badge(let label, _, let color) = result else {
            XCTFail("Expected badge"); return
        }
        XCTAssertEqual(label, "Hot")
        XCTAssertEqual(color, .warning)
    }

    func testParseBadgeColorDefaults() {
        let result = parse(#"root = badge("Tag")"#)
        XCTAssertNotNil(result)
        guard case .badge(_, _, let color) = result else {
            XCTFail("Expected badge"); return
        }
        XCTAssertNil(color)
    }

    func testParseChartSparkline() {
        let result = parse(#"root = chart(sparkline, values=[1, 2, 3, 4])"#)
        XCTAssertNotNil(result)
        guard case .chart(let type, let values, _, _, _, _, _, _, _, _) = result else {
            XCTFail("Expected chart"); return
        }
        XCTAssertEqual(type, .sparkline)
        XCTAssertEqual(values, [1, 2, 3, 4])
    }

    func testParseChartPie() {
        let result = parse(#"root = chart(pie, values=[30, 50, 20])"#)
        XCTAssertNotNil(result)
        guard case .chart(let type, let values, _, _, _, _, _, _, _, _) = result else {
            XCTFail("Expected chart"); return
        }
        XCTAssertEqual(type, .pie)
        XCTAssertEqual(values, [30, 50, 20])
    }

    func testParseChartUnknownType() {
        let result = parse(#"root = chart(donut, values=[1, 2])"#)
        XCTAssertNotNil(result)
        guard case .chart(let type, _, _, _, _, _, _, _, _, _) = result else {
            XCTFail("Expected chart"); return
        }
        XCTAssertEqual(type, .bar)
    }

    func testParseChartEmptyValues() {
        let result = parse(#"root = chart(bar)"#)
        XCTAssertNotNil(result)
        guard case .chart(let type, let values, _, _, _, _, _, _, _, _) = result else {
            XCTFail("Expected chart"); return
        }
        XCTAssertEqual(type, .bar)
        XCTAssertNil(values)
    }

    func testParseChartMultiSeries() {
        let result = parse(#"root = chart(line, series=[[1,2,3],[4,5,6]], labels=["a","b","c"])"#)
        XCTAssertNotNil(result)
        guard case .chart(let type, _, let labels, let series, _, _, _, _, _, _) = result else {
            XCTFail("Expected chart"); return
        }
        XCTAssertEqual(type, .line)
        XCTAssertNotNil(series)
        XCTAssertEqual(series?.count, 2)
        XCTAssertEqual(series?[0], [1, 2, 3])
        XCTAssertEqual(series?[1], [4, 5, 6])
        XCTAssertEqual(labels, ["a", "b", "c"])
    }

    func testParseCodeWithEscapes() {
        let result = parse(#"root = code("kotlin", "line1\nline2\ttab\\end\"quote")"#)
        XCTAssertNotNil(result)
        guard case .code(_, let content, _) = result else {
            XCTFail("Expected code"); return
        }
        XCTAssertEqual(content, "line1\nline2\ttab\\end\"quote")
    }

    func testParseAccordionDefaultCollapsed() {
        let result = parse(#"root = accordion("FAQ", [txt("Answer")])"#)
        XCTAssertNotNil(result)
        guard case .accordion(_, _, let expanded) = result else {
            XCTFail("Expected accordion"); return
        }
        XCTAssertFalse(expanded)
    }

    func testParseCarouselDefaultPeek() {
        let result = parse(#"root = carousel([txt("A")])"#)
        XCTAssertNotNil(result)
        guard case .carousel(_, let peek) = result else {
            XCTFail("Expected carousel"); return
        }
        XCTAssertEqual(peek, 24)
    }

    func testParseCalloutInfo() {
        let result = parse(#"root = callout(info, "This is informational")"#)
        XCTAssertNotNil(result)
        guard case .callout(let type, let content, let title, _) = result else {
            XCTFail("Expected callout"); return
        }
        XCTAssertEqual(type, .info)
        XCTAssertEqual(content, "This is informational")
        XCTAssertNil(title)
    }

    func testParseCalloutAllTypes() {
        let cases: [(String, CalloutType)] = [
            ("info", .info), ("warning", .warning), ("error", .error),
            ("success", .success), ("tip", .tip)
        ]
        for (name, expected) in cases {
            let result = parse("root = callout(\(name), \"msg\")")
            XCTAssertNotNil(result, "callout(\(name)) returned nil")
            guard case .callout(let type, _, _, _) = result else {
                XCTFail("Expected callout for \(name)"); return
            }
            XCTAssertEqual(type, expected, "callout(\(name)) type mismatch")
        }
    }

    func testParseCalloutUnknownType() {
        let result = parse(#"root = callout(banana, "msg")"#)
        XCTAssertNotNil(result)
        guard case .callout(let type, _, _, _) = result else {
            XCTFail("Expected callout"); return
        }
        XCTAssertEqual(type, .info)
    }

    // MARK: - WP#5b.1 Regression: Chart $path inside each()

    func testChartInsideEachResolvesPerItemScope() {
        let parser = AmeParser()
        let result = parser.parse("""
            root = col([results])
            results = each($restaurants, tpl)
            tpl = col([name, spending])
            name = txt($name, title)
            spending = chart(bar, values=$sales)
            ---
            {"restaurants":[{"name":"Luigi's","sales":[10,20,30]},{"name":"Bella's","sales":[40,50,60]}]}
            """)

        XCTAssertNotNil(result)
        guard case .col(let rootChildren, _) = result else { XCTFail("Expected col"); return }

        guard case .col(let expanded, _) = rootChildren[0] else { XCTFail("Expected expanded col"); return }
        XCTAssertEqual(expanded.count, 2)

        guard case .col(let tpl1Children, _) = expanded[0] else { XCTFail("Expected col tpl1"); return }
        guard case .txt(let name1, _, _, _) = tpl1Children[0] else { XCTFail("Expected txt"); return }
        XCTAssertEqual(name1, "Luigi's")
        guard case .chart(_, let values1, _, _, _, _, let vp1, _, _, _) = tpl1Children[1] else {
            XCTFail("Expected chart"); return
        }
        XCTAssertEqual(values1, [10, 20, 30])
        XCTAssertNil(vp1)

        guard case .col(let tpl2Children, _) = expanded[1] else { XCTFail("Expected col tpl2"); return }
        guard case .txt(let name2, _, _, _) = tpl2Children[0] else { XCTFail("Expected txt"); return }
        XCTAssertEqual(name2, "Bella's")
        guard case .chart(_, let values2, _, _, _, _, let vp2, _, _, _) = tpl2Children[1] else {
            XCTFail("Expected chart"); return
        }
        XCTAssertEqual(values2, [40, 50, 60])
        XCTAssertNil(vp2)
    }

    func testParseTimelineItemAllStatuses() {
        let cases: [(String, TimelineStatus)] = [
            ("done", .done), ("active", .active), ("pending", .pending), ("error", .error)
        ]
        for (name, expected) in cases {
            let result = parse("root = timeline_item(\"t\", \"s\", \(name))")
            XCTAssertNotNil(result, "timeline_item with status=\(name) returned nil")
            guard case .timelineItem(_, _, let status) = result else {
                XCTFail("Expected timeline_item for status=\(name)"); return
            }
            XCTAssertEqual(status, expected, "status=\(name) mismatch")
        }
    }
}
