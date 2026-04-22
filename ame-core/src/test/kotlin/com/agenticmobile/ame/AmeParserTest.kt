package com.agenticmobile.ame

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertIs
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * Parser tests covering:
 * - All 15 primitives (happy path)
 * - All 5 action types in btn
 * - Forward references
 * - Data binding ($path, --- separator)
 * - each() construct
 * - 3 complete examples from syntax.md
 * - 6 error recovery cases
 */
class AmeParserTest {

    private fun parse(input: String): AmeNode? {
        val parser = AmeParser()
        return parser.parse(input)
    }

    private fun parserFor(input: String): AmeParser {
        val parser = AmeParser()
        parser.parse(input)
        return parser
    }

    // ════════════════════════════════════════════════════════════════════
    // Happy Path — All 15 Primitives
    // ════════════════════════════════════════════════════════════════════

    @Test
    fun parseCol() {
        val result = parse("""
            root = col([a, b])
            a = txt("Hello")
            b = txt("World")
        """.trimIndent())

        assertNotNull(result)
        assertIs<AmeNode.Col>(result)
        assertEquals(2, result.children.size)
        assertEquals(Align.START, result.align)
        assertIs<AmeNode.Txt>(result.children[0])
        assertEquals("Hello", (result.children[0] as AmeNode.Txt).text)
    }

    @Test
    fun parseColWithAlign() {
        val result = parse("""
            root = col([a], center)
            a = txt("Centered")
        """.trimIndent())

        assertNotNull(result)
        assertIs<AmeNode.Col>(result)
        assertEquals(Align.CENTER, result.align)
    }

    @Test
    fun parseRow() {
        val result = parse("""
            root = row([a, b], space_between)
            a = txt("Left")
            b = txt("Right")
        """.trimIndent())

        assertNotNull(result)
        assertIs<AmeNode.Row>(result)
        assertEquals(2, result.children.size)
        assertEquals(Align.SPACE_BETWEEN, result.align)
        assertEquals(8, result.gap)
    }

    @Test
    fun parseRowWithGap() {
        val result = parse("""
            root = row([a, b], 12)
            a = txt("A")
            b = txt("B")
        """.trimIndent())

        assertNotNull(result)
        assertIs<AmeNode.Row>(result)
        assertEquals(12, result.gap)
        assertEquals(Align.START, result.align)
    }

    @Test
    fun parseRowWithAlignAndGap() {
        val result = parse("""
            root = row([a, b], space_between, 16)
            a = txt("A")
            b = txt("B")
        """.trimIndent())

        assertNotNull(result)
        assertIs<AmeNode.Row>(result)
        assertEquals(Align.SPACE_BETWEEN, result.align)
        assertEquals(16, result.gap)
    }

    @Test
    fun parseTxt() {
        val result = parse("""root = txt("Hello World", headline)""")

        assertNotNull(result)
        assertIs<AmeNode.Txt>(result)
        assertEquals("Hello World", result.text)
        assertEquals(TxtStyle.HEADLINE, result.style)
    }

    @Test
    fun parseTxtDefaults() {
        val result = parse("""root = txt("Simple text")""")

        assertNotNull(result)
        assertIs<AmeNode.Txt>(result)
        assertEquals("Simple text", result.text)
        assertEquals(TxtStyle.BODY, result.style)
        assertNull(result.maxLines)
    }

    @Test
    fun parseTxtWithMaxLines() {
        val result = parse("""root = txt("Long text", body, max_lines=3)""")

        assertNotNull(result)
        assertIs<AmeNode.Txt>(result)
        assertEquals(3, result.maxLines)
    }

    @Test
    fun parseTxtWithEscapes() {
        val result = parse("""root = txt("She said \"hello\"")""")

        assertNotNull(result)
        assertIs<AmeNode.Txt>(result)
        assertEquals("She said \"hello\"", result.text)
    }

    @Test
    fun parseImg() {
        val result = parse("""root = img("https://example.com/photo.jpg", 180)""")

        assertNotNull(result)
        assertIs<AmeNode.Img>(result)
        assertEquals("https://example.com/photo.jpg", result.url)
        assertEquals(180, result.height)
    }

    @Test
    fun parseImgNoHeight() {
        val result = parse("""root = img("https://example.com/photo.jpg")""")

        assertNotNull(result)
        assertIs<AmeNode.Img>(result)
        assertNull(result.height)
    }

    @Test
    fun parseIcon() {
        val result = parse("""root = icon("partly_cloudy_day", 28)""")

        assertNotNull(result)
        assertIs<AmeNode.Icon>(result)
        assertEquals("partly_cloudy_day", result.name)
        assertEquals(28, result.size)
    }

    @Test
    fun parseIconDefaults() {
        val result = parse("""root = icon("star")""")

        assertNotNull(result)
        assertIs<AmeNode.Icon>(result)
        assertEquals("star", result.name)
        assertEquals(20, result.size)
    }

    @Test
    fun parseDivider() {
        val result = parse("""root = divider()""")

        assertNotNull(result)
        assertIs<AmeNode.Divider>(result)
    }

    @Test
    fun parseSpacer() {
        val result = parse("""root = spacer(16)""")

        assertNotNull(result)
        assertIs<AmeNode.Spacer>(result)
        assertEquals(16, result.height)
    }

    @Test
    fun parseSpacerDefaults() {
        val result = parse("""root = spacer()""")

        assertNotNull(result)
        assertIs<AmeNode.Spacer>(result)
        assertEquals(8, result.height)
    }

    @Test
    fun parseCard() {
        val result = parse("""
            root = card([title, body])
            title = txt("Title", title)
            body = txt("Body text")
        """.trimIndent())

        assertNotNull(result)
        assertIs<AmeNode.Card>(result)
        assertEquals(2, result.children.size)
        assertEquals(1, result.elevation)
    }

    @Test
    fun parseCardWithElevation() {
        val result = parse("""
            root = card([a], 0)
            a = txt("Flat")
        """.trimIndent())

        assertNotNull(result)
        assertIs<AmeNode.Card>(result)
        assertEquals(0, result.elevation)
    }

    @Test
    fun parseBadge() {
        val result = parse("""root = badge("★4.5", info)""")

        assertNotNull(result)
        assertIs<AmeNode.Badge>(result)
        assertEquals("★4.5", result.label)
        assertEquals(BadgeVariant.INFO, result.variant)
    }

    @Test
    fun parseBadgeDefaults() {
        val result = parse("""root = badge("Tag")""")

        assertNotNull(result)
        assertIs<AmeNode.Badge>(result)
        assertEquals(BadgeVariant.DEFAULT, result.variant)
    }

    @Test
    fun parseProgress() {
        val result = parse("""root = progress(0.67, "67% complete")""")

        assertNotNull(result)
        assertIs<AmeNode.Progress>(result)
        assertEquals(0.67f, result.value, 0.01f)
        assertEquals("67% complete", result.label)
    }

    @Test
    fun parseProgressNoLabel() {
        val result = parse("""root = progress(0.3)""")

        assertNotNull(result)
        assertIs<AmeNode.Progress>(result)
        assertEquals(0.3f, result.value, 0.01f)
        assertNull(result.label)
    }

    @Test
    fun parseInput() {
        val result = parse("""root = input("email", "Email Address", email)""")

        assertNotNull(result)
        assertIs<AmeNode.Input>(result)
        assertEquals("email", result.id)
        assertEquals("Email Address", result.label)
        assertEquals(InputType.EMAIL, result.type)
    }

    @Test
    fun parseInputDefaults() {
        val result = parse("""root = input("name", "Your Name")""")

        assertNotNull(result)
        assertIs<AmeNode.Input>(result)
        assertEquals(InputType.TEXT, result.type)
        assertNull(result.options)
    }

    @Test
    fun parseInputSelect() {
        val result = parse("""root = input("guests", "Number of Guests", select, options=["1","2","3","4"])""")

        assertNotNull(result)
        assertIs<AmeNode.Input>(result)
        assertEquals("guests", result.id)
        assertEquals(InputType.SELECT, result.type)
        assertNotNull(result.options)
        assertEquals(listOf("1", "2", "3", "4"), result.options)
    }

    @Test
    fun parseToggle() {
        val result = parse("""root = toggle("agree", "I agree to the terms")""")

        assertNotNull(result)
        assertIs<AmeNode.Toggle>(result)
        assertEquals("agree", result.id)
        assertEquals("I agree to the terms", result.label)
        assertEquals(false, result.default)
    }

    @Test
    fun parseToggleWithDefault() {
        val result = parse("""root = toggle("notifications", "Enable notifications", true)""")

        assertNotNull(result)
        assertIs<AmeNode.Toggle>(result)
        assertEquals(true, result.default)
    }

    @Test
    fun parseList() {
        val result = parse("""
            root = list([a, b, c])
            a = txt("Item 1")
            b = txt("Item 2")
            c = txt("Item 3")
        """.trimIndent())

        assertNotNull(result)
        assertIs<AmeNode.DataList>(result)
        assertEquals(3, result.children.size)
        assertEquals(true, result.dividers)
    }

    @Test
    fun parseListNoDividers() {
        val result = parse("""
            root = list([a], false)
            a = txt("Solo")
        """.trimIndent())

        assertNotNull(result)
        assertIs<AmeNode.DataList>(result)
        assertEquals(false, result.dividers)
    }

    @Test
    fun parseTable() {
        val result = parse("""root = table(["Feature", "Basic", "Pro"], [["Storage", "50 GB", "500 GB"], ["Users", "1", "10"]])""")

        assertNotNull(result)
        assertIs<AmeNode.Table>(result)
        assertEquals(listOf("Feature", "Basic", "Pro"), result.headers)
        assertEquals(2, result.rows.size)
        assertEquals(listOf("Storage", "50 GB", "500 GB"), result.rows[0])
        assertEquals(listOf("Users", "1", "10"), result.rows[1])
    }

    // ════════════════════════════════════════════════════════════════════
    // Button with All 5 Action Types
    // ════════════════════════════════════════════════════════════════════

    @Test
    fun parseBtnWithToolAction() {
        val result = parse("""root = btn("Save", tool(add_note, title="Meeting Notes"), primary)""")

        assertNotNull(result)
        assertIs<AmeNode.Btn>(result)
        assertEquals("Save", result.label)
        assertEquals(BtnStyle.PRIMARY, result.style)

        val action = result.action
        assertIs<AmeAction.CallTool>(action)
        assertEquals("add_note", action.name)
        assertEquals("Meeting Notes", action.args["title"])
    }

    @Test
    fun parseBtnWithUriAction() {
        val result = parse("""root = btn("Directions", uri("geo:40.72,-73.99?q=Luigi's"), text)""")

        assertNotNull(result)
        assertIs<AmeNode.Btn>(result)
        assertEquals("Directions", result.label)
        assertEquals(BtnStyle.TEXT, result.style)

        val action = result.action
        assertIs<AmeAction.OpenUri>(action)
        assertEquals("geo:40.72,-73.99?q=Luigi's", action.uri)
    }

    @Test
    fun parseBtnWithNavAction() {
        val result = parse("""root = btn("Home", nav("home"), outline)""")

        assertNotNull(result)
        assertIs<AmeNode.Btn>(result)
        assertEquals(BtnStyle.OUTLINE, result.style)

        val action = result.action
        assertIs<AmeAction.Navigate>(action)
        assertEquals("home", action.route)
    }

    @Test
    fun parseBtnWithCopyAction() {
        val result = parse("""root = btn("Copy Address", copy("119 Mulberry St"), text)""")

        assertNotNull(result)
        assertIs<AmeNode.Btn>(result)

        val action = result.action
        assertIs<AmeAction.CopyText>(action)
        assertEquals("119 Mulberry St", action.text)
    }

    @Test
    fun parseBtnWithSubmitAction() {
        val result = parse("""root = btn("Confirm Booking", submit(create_reservation, restaurant="Luigi's"), primary)""")

        assertNotNull(result)
        assertIs<AmeNode.Btn>(result)
        assertEquals("Confirm Booking", result.label)

        val action = result.action
        assertIs<AmeAction.Submit>(action)
        assertEquals("create_reservation", action.toolName)
        assertEquals("Luigi's", action.staticArgs["restaurant"])
    }

    @Test
    fun parseBtnWithIcon() {
        val result = parse("""root = btn("Call", uri("tel:+15551234567"), primary, icon="phone")""")

        assertNotNull(result)
        assertIs<AmeNode.Btn>(result)
        assertEquals("phone", result.icon)
    }

    @Test
    fun parseBtnDefaultStyle() {
        val result = parse("""root = btn("Click", nav("home"))""")

        assertNotNull(result)
        assertIs<AmeNode.Btn>(result)
        assertEquals(BtnStyle.PRIMARY, result.style)
    }

    // ════════════════════════════════════════════════════════════════════
    // Forward References
    // ════════════════════════════════════════════════════════════════════

    @Test
    fun parseForwardRefChildBeforeParent() {
        val result = parse("""
            root = col([header, body])
            header = txt("Title", title)
            body = card([content])
            content = txt("Details", body)
        """.trimIndent())

        assertNotNull(result)
        assertIs<AmeNode.Col>(result)
        assertEquals(2, result.children.size)

        val header = result.children[0]
        assertIs<AmeNode.Txt>(header)
        assertEquals("Title", header.text)

        val body = result.children[1]
        assertIs<AmeNode.Card>(body)
        assertEquals(1, body.children.size)

        val content = body.children[0]
        assertIs<AmeNode.Txt>(content)
        assertEquals("Details", content.text)
    }

    @Test
    fun streamingModeProducesRefs() {
        val parser = AmeParser()

        val rootResult = parser.parseLine("root = col([header, body])")
        assertNotNull(rootResult)
        assertEquals("root", rootResult.first)

        val rootNode = rootResult.second
        assertIs<AmeNode.Col>(rootNode)
        // Children should be Ref nodes (not yet resolved)
        assertTrue(rootNode.children.all { it is AmeNode.Ref })

        // After defining header, getResolvedTree should partially resolve
        parser.parseLine("header = txt(\"Title\", title)")
        val tree = parser.getResolvedTree()
        assertNotNull(tree)
        assertIs<AmeNode.Col>(tree)

        val resolvedHeader = tree.children[0]
        assertIs<AmeNode.Txt>(resolvedHeader)
        assertEquals("Title", resolvedHeader.text)

        // body is still a Ref
        assertIs<AmeNode.Ref>(tree.children[1])
    }

    // ════════════════════════════════════════════════════════════════════
    // Data Binding
    // ════════════════════════════════════════════════════════════════════

    @Test
    fun parseDataRefTopLevel() {
        val result = parse("""root = txt(${"$"}name, title)""")

        assertNotNull(result)
        assertIs<AmeNode.Txt>(result)
        assertEquals("\$name", result.text)
        assertEquals(TxtStyle.TITLE, result.style)
    }

    @Test
    fun parseDataRefNested() {
        val result = parse("""root = txt(${"$"}address/city, caption)""")

        assertNotNull(result)
        assertIs<AmeNode.Txt>(result)
        assertEquals("\$address/city", result.text)
    }

    @Test
    fun parseDataSection() {
        val parser = parserFor("""
            root = col([name_label, rating_label])
            name_label = txt(${"$"}name, title)
            rating_label = badge(${"$"}rating, info)
            ---
            {"name": "Luigi's", "rating": "★4.5"}
        """.trimIndent())

        assertNotNull(parser.getDataModel())
        assertEquals("Luigi's", parser.resolveDataPath("name"))
        assertEquals("★4.5", parser.resolveDataPath("rating"))
    }

    @Test
    fun parseDataSectionNestedPath() {
        val parser = parserFor("""
            root = txt(${"$"}address/city, caption)
            ---
            {"address": {"city": "New York", "state": "NY"}}
        """.trimIndent())

        assertEquals("New York", parser.resolveDataPath("address/city"))
    }

    // ════════════════════════════════════════════════════════════════════
    // each() Construct
    // ════════════════════════════════════════════════════════════════════

    @Test
    fun parseEach() {
        val parser = AmeParser()
        val result = parser.parse("""
            root = col([title, results])
            title = txt("Italian Restaurants", headline)
            results = each(${"$"}places, place_tpl)
            place_tpl = card([txt(${"$"}name, title)])
        """.trimIndent())

        assertNotNull(result)
        assertIs<AmeNode.Col>(result)

        val eachNode = result.children[1]
        assertIs<AmeNode.Each>(eachNode)
        assertEquals("places", eachNode.dataPath)
        assertEquals("place_tpl", eachNode.templateId)
    }

    // ════════════════════════════════════════════════════════════════════
    // Complete Examples from syntax.md
    // ════════════════════════════════════════════════════════════════════

    @Test
    fun parseWeatherCard() {
        // Exact Example 1 from syntax.md — 9 lines
        val result = parse("""
            root = card([weather_header, temp, condition, details])
            weather_header = row([city, weather_icon], space_between)
            city = txt("San Francisco", title)
            weather_icon = icon("partly_cloudy_day", 28)
            temp = txt("62°", display)
            condition = txt("Partly Cloudy", body)
            details = row([high_low, humidity], space_between)
            high_low = txt("H:68°  L:55°", caption)
            humidity = txt("Humidity: 72%", caption)
        """.trimIndent())

        assertNotNull(result)
        assertIs<AmeNode.Card>(result)
        assertEquals(4, result.children.size)

        // weather_header = row with 2 children
        val header = result.children[0]
        assertIs<AmeNode.Row>(header)
        assertEquals(Align.SPACE_BETWEEN, header.align)
        assertEquals(2, header.children.size)

        val city = header.children[0]
        assertIs<AmeNode.Txt>(city)
        assertEquals("San Francisco", city.text)
        assertEquals(TxtStyle.TITLE, city.style)

        val icon = header.children[1]
        assertIs<AmeNode.Icon>(icon)
        assertEquals("partly_cloudy_day", icon.name)
        assertEquals(28, icon.size)

        // temp
        val temp = result.children[1]
        assertIs<AmeNode.Txt>(temp)
        assertEquals("62°", temp.text)
        assertEquals(TxtStyle.DISPLAY, temp.style)

        // condition
        val condition = result.children[2]
        assertIs<AmeNode.Txt>(condition)
        assertEquals("Partly Cloudy", condition.text)

        // details row
        val details = result.children[3]
        assertIs<AmeNode.Row>(details)
        assertEquals(2, details.children.size)
        assertEquals(Align.SPACE_BETWEEN, details.align)

        val highLow = details.children[0]
        assertIs<AmeNode.Txt>(highLow)
        assertEquals("H:68°  L:55°", highLow.text)
        assertEquals(TxtStyle.CAPTION, highLow.style)
    }

    @Test
    fun parsePlaceSearch() {
        // Exact Example 2 from syntax.md — 27 lines
        val input = """
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
        """.trimIndent()

        val result = parse(input)
        assertNotNull(result)
        assertIs<AmeNode.Col>(result)
        assertEquals(2, result.children.size)

        // header
        val header = result.children[0]
        assertIs<AmeNode.Txt>(header)
        assertEquals("Italian Restaurants Nearby", header.text)
        assertEquals(TxtStyle.HEADLINE, header.style)

        // results = list with 3 cards
        val resultsList = result.children[1]
        assertIs<AmeNode.DataList>(resultsList)
        assertEquals(3, resultsList.children.size)

        // Verify first card structure
        val p1 = resultsList.children[0]
        assertIs<AmeNode.Card>(p1)
        assertEquals(3, p1.children.size)

        // p1_top = row with name + rating
        val p1Top = p1.children[0]
        assertIs<AmeNode.Row>(p1Top)
        assertEquals(Align.SPACE_BETWEEN, p1Top.align)

        val p1Name = p1Top.children[0]
        assertIs<AmeNode.Txt>(p1Name)
        assertEquals("Luigi's", p1Name.text)

        val p1Rating = p1Top.children[1]
        assertIs<AmeNode.Badge>(p1Rating)
        assertEquals("★4.5", p1Rating.label)
        assertEquals(BadgeVariant.INFO, p1Rating.variant)

        // p1_addr
        val p1Addr = p1.children[1]
        assertIs<AmeNode.Txt>(p1Addr)
        assertEquals("119 Mulberry St, New York", p1Addr.text)

        // p1_btns = row with schedule + directions
        val p1Btns = p1.children[2]
        assertIs<AmeNode.Row>(p1Btns)
        assertEquals(8, p1Btns.gap)
        assertEquals(2, p1Btns.children.size)

        // Schedule button
        val schedBtn = p1Btns.children[0]
        assertIs<AmeNode.Btn>(schedBtn)
        assertEquals("Schedule", schedBtn.label)
        assertEquals(BtnStyle.PRIMARY, schedBtn.style)

        val schedAction = schedBtn.action
        assertIs<AmeAction.CallTool>(schedAction)
        assertEquals("create_calendar_event", schedAction.name)
        assertEquals("Dinner at Luigi's", schedAction.args["title"])
        assertEquals("119 Mulberry St", schedAction.args["location"])

        // Directions button
        val dirBtn = p1Btns.children[1]
        assertIs<AmeNode.Btn>(dirBtn)
        assertEquals("Directions", dirBtn.label)
        assertEquals(BtnStyle.TEXT, dirBtn.style)

        val dirAction = dirBtn.action
        assertIs<AmeAction.OpenUri>(dirAction)
        assertEquals("geo:40.72,-73.99?q=Luigi's", dirAction.uri)

        // Verify all 3 cards exist
        assertIs<AmeNode.Card>(resultsList.children[1])
        assertIs<AmeNode.Card>(resultsList.children[2])

        // Verify third card's name
        val p3 = resultsList.children[2]
        assertIs<AmeNode.Card>(p3)
        val p3Top = p3.children[0]
        assertIs<AmeNode.Row>(p3Top)
        val p3Name = p3Top.children[0]
        assertIs<AmeNode.Txt>(p3Name)
        assertEquals("Carbone", p3Name.text)
    }

    @Test
    fun parseBookingForm() {
        // Exact Example 4 from syntax.md — 10 lines
        val input = """
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
        """.trimIndent()

        val result = parse(input)
        assertNotNull(result)
        assertIs<AmeNode.Card>(result)
        assertEquals(3, result.children.size)

        // form_title
        val title = result.children[0]
        assertIs<AmeNode.Txt>(title)
        assertEquals("Book a Table", title.text)
        assertEquals(TxtStyle.HEADLINE, title.style)

        // form_fields = col with 4 inputs
        val fields = result.children[1]
        assertIs<AmeNode.Col>(fields)
        assertEquals(4, fields.children.size)

        // date_field
        val dateField = fields.children[0]
        assertIs<AmeNode.Input>(dateField)
        assertEquals("date", dateField.id)
        assertEquals("Date", dateField.label)
        assertEquals(InputType.DATE, dateField.type)

        // time_field
        val timeField = fields.children[1]
        assertIs<AmeNode.Input>(timeField)
        assertEquals(InputType.TIME, timeField.type)

        // guests_field
        val guestsField = fields.children[2]
        assertIs<AmeNode.Input>(guestsField)
        assertEquals("guests", guestsField.id)
        assertEquals(InputType.SELECT, guestsField.type)
        assertNotNull(guestsField.options)
        assertEquals(8, guestsField.options!!.size)
        assertEquals("1", guestsField.options!![0])
        assertEquals("8", guestsField.options!![7])

        // notes_field
        val notesField = fields.children[3]
        assertIs<AmeNode.Input>(notesField)
        assertEquals(InputType.TEXT, notesField.type)

        // form_actions
        val actions = result.children[2]
        assertIs<AmeNode.Row>(actions)
        assertEquals(Align.SPACE_BETWEEN, actions.align)
        assertEquals(2, actions.children.size)

        // cancel_btn
        val cancelBtn = actions.children[0]
        assertIs<AmeNode.Btn>(cancelBtn)
        assertEquals("Cancel", cancelBtn.label)
        assertEquals(BtnStyle.TEXT, cancelBtn.style)
        assertIs<AmeAction.Navigate>(cancelBtn.action)
        assertEquals("home", (cancelBtn.action as AmeAction.Navigate).route)

        // confirm_btn
        val confirmBtn = actions.children[1]
        assertIs<AmeNode.Btn>(confirmBtn)
        assertEquals("Confirm Booking", confirmBtn.label)
        assertEquals(BtnStyle.PRIMARY, confirmBtn.style)

        val submitAction = confirmBtn.action
        assertIs<AmeAction.Submit>(submitAction)
        assertEquals("create_reservation", submitAction.toolName)
        assertEquals("Luigi's", submitAction.staticArgs["restaurant"])
    }

    // ════════════════════════════════════════════════════════════════════
    // Inline Component Calls in Children Arrays
    // ════════════════════════════════════════════════════════════════════

    @Test
    fun parseInlineComponentCallsInArray() {
        val result = parse("""
            root = row([txt("Name", title), badge("★4.5", info)], space_between)
        """.trimIndent())

        assertNotNull(result)
        assertIs<AmeNode.Row>(result)
        assertEquals(2, result.children.size)

        val name = result.children[0]
        assertIs<AmeNode.Txt>(name)
        assertEquals("Name", name.text)
        assertEquals(TxtStyle.TITLE, name.style)

        val badge = result.children[1]
        assertIs<AmeNode.Badge>(badge)
        assertEquals("★4.5", badge.label)
    }

    // ════════════════════════════════════════════════════════════════════
    // Error Cases — Parser Must Not Crash
    // ════════════════════════════════════════════════════════════════════

    @Test
    fun parseMalformedLineNoEquals() {
        val parser = AmeParser()
        val result = parser.parse("""
            root = txt("Hello")
            this line has no equals sign
            another = txt("World")
        """.trimIndent())

        assertNotNull(result)
        assertIs<AmeNode.Txt>(result)
        assertEquals("Hello", result.text)
        assertTrue(parser.errors.isNotEmpty(), "Should log error for malformed line")
    }

    @Test
    fun parseUnknownComponent() {
        val parser = AmeParser()
        val result = parser.parse("""root = foobar("test")""")

        assertNotNull(result)
        assertIs<AmeNode.Txt>(result)
        assertTrue(result.text.contains("Unknown"), "Unknown component should produce warning txt")
        assertTrue(parser.warnings.any { it.contains("Unknown") })
    }

    @Test
    fun parseUnclosedParenthesis() {
        val parser = AmeParser()
        val result = parser.parse("""root = txt("Hello", headline""")

        assertNotNull(result)
        assertIs<AmeNode.Txt>(result)
        assertEquals("Hello", result.text)
        assertTrue(parser.warnings.any { it.contains("parenthesis") || it.contains("Unclosed") })
    }

    @Test
    fun parseUnclosedString() {
        val parser = AmeParser()
        val result = parser.parse("""root = txt("Hello World)""")

        assertNotNull(result)
        // Should recover gracefully
        assertTrue(parser.warnings.any { it.contains("string") || it.contains("Unclosed") })
    }

    @Test
    fun parseDuplicateIdentifier() {
        val parser = AmeParser()
        val result = parser.parse("""
            root = col([header])
            header = txt("First")
            header = txt("Second")
        """.trimIndent())

        assertNotNull(result)
        assertIs<AmeNode.Col>(result)

        // Second definition should replace first
        val header = result.children[0]
        assertIs<AmeNode.Txt>(header)
        assertEquals("Second", header.text)
        assertTrue(parser.warnings.any { it.contains("Duplicate") })
    }

    @Test
    fun parseEmptyInput() {
        val result = parse("")
        assertNull(result)
    }

    @Test
    fun parseOnlyComments() {
        val result = parse("""
            // This is a comment
            // Another comment
        """.trimIndent())
        assertNull(result)
    }

    @Test
    fun parseCommentsInterspersed() {
        val result = parse("""
            // Header section
            root = col([header, body])
            // Title
            header = txt("Welcome", headline)
            body = txt("Content")
        """.trimIndent())

        assertNotNull(result)
        assertIs<AmeNode.Col>(result)
        assertEquals(2, result.children.size)
    }

    // ════════════════════════════════════════════════════════════════════
    // Parser Leniency
    // ════════════════════════════════════════════════════════════════════

    @Test
    fun parseLenientUnquotedInputId() {
        // LLM might generate unquoted id
        val result = parse("""root = input(email, "Email Address", email)""")

        assertNotNull(result)
        assertIs<AmeNode.Input>(result)
        assertEquals("email", result.id)
    }

    @Test
    fun parseLenientQuotedToolName() {
        // LLM might generate quoted tool name
        val result = parse("""root = btn("Save", tool("add_note", title="Notes"), primary)""")

        assertNotNull(result)
        assertIs<AmeNode.Btn>(result)
        val action = result.action
        assertIs<AmeAction.CallTool>(action)
        assertEquals("add_note", action.name)
    }

    // ════════════════════════════════════════════════════════════════════
    // Data Path in Action Arguments
    // ════════════════════════════════════════════════════════════════════

    @Test
    fun parseDataRefInActionArg() {
        val result = parse("""root = btn("Directions", uri(${"$"}map_url), text)""")

        assertNotNull(result)
        assertIs<AmeNode.Btn>(result)
        val action = result.action
        assertIs<AmeAction.OpenUri>(action)
        assertEquals("\$map_url", action.uri)
    }

    // ════════════════════════════════════════════════════════════════════
    // Tool Action with Multiple Named Args
    // ════════════════════════════════════════════════════════════════════

    @Test
    fun parseToolActionMultipleArgs() {
        val result = parse("""root = btn("Schedule", tool(create_event, title="Dinner", date="2026-04-15", location="Cafe"), primary)""")

        assertNotNull(result)
        assertIs<AmeNode.Btn>(result)
        val action = result.action
        assertIs<AmeAction.CallTool>(action)
        assertEquals("create_event", action.name)
        assertEquals(3, action.args.size)
        assertEquals("Dinner", action.args["title"])
        assertEquals("2026-04-15", action.args["date"])
        assertEquals("Cafe", action.args["location"])
    }

    // ════════════════════════════════════════════════════════════════════
    // each() Expansion with Data Model
    // ════════════════════════════════════════════════════════════════════

    @Test
    fun eachExpandsWithDataSection() {
        val parser = AmeParser()
        val result = parser.parse("""
            root = col([header, results])
            header = txt("Restaurants", headline)
            results = each(${"$"}places, place_tpl)
            place_tpl = card([txt(${"$"}name, title)])
            ---
            {"places":[{"name":"Pizza Palace"},{"name":"Sushi Spot"},{"name":"Taco Town"}]}
        """.trimIndent())

        assertNotNull(result)
        assertIs<AmeNode.Col>(result)
        assertEquals(2, result.children.size)

        val header = result.children[0]
        assertIs<AmeNode.Txt>(header)
        assertEquals("Restaurants", header.text)

        val expanded = result.children[1]
        assertIs<AmeNode.Col>(expanded)
        assertEquals(3, expanded.children.size)

        val card0 = expanded.children[0]
        assertIs<AmeNode.Card>(card0)
        val txt0 = card0.children[0]
        assertIs<AmeNode.Txt>(txt0)
        assertEquals("Pizza Palace", txt0.text)

        val card1 = expanded.children[1]
        assertIs<AmeNode.Card>(card1)
        val txt1 = card1.children[0]
        assertIs<AmeNode.Txt>(txt1)
        assertEquals("Sushi Spot", txt1.text)

        val card2 = expanded.children[2]
        assertIs<AmeNode.Card>(card2)
        val txt2 = card2.children[0]
        assertIs<AmeNode.Txt>(txt2)
        assertEquals("Taco Town", txt2.text)
    }

    @Test
    fun eachPreservedWithoutDataSection() {
        val parser = AmeParser()
        val result = parser.parse("""
            root = col([title, results])
            title = txt("Restaurants", headline)
            results = each(${"$"}places, place_tpl)
            place_tpl = card([txt(${"$"}name, title)])
        """.trimIndent())

        assertNotNull(result)
        assertIs<AmeNode.Col>(result)
        assertEquals(2, result.children.size)

        val eachNode = result.children[1]
        assertIs<AmeNode.Each>(eachNode)
        assertEquals("places", eachNode.dataPath)
        assertEquals("place_tpl", eachNode.templateId)
    }

    @Test
    fun eachEmptyArrayProducesEmptyCol() {
        val parser = AmeParser()
        val result = parser.parse("""
            root = col([header, results])
            header = txt("Results", headline)
            results = each(${"$"}items, item_tpl)
            item_tpl = txt(${"$"}label, body)
            ---
            {"items":[]}
        """.trimIndent())

        assertNotNull(result)
        assertIs<AmeNode.Col>(result)
        assertEquals(2, result.children.size)

        val expanded = result.children[1]
        assertIs<AmeNode.Col>(expanded)
        assertEquals(0, expanded.children.size)
    }

    @Test
    fun eachSingleElementReturnsUnwrapped() {
        val parser = AmeParser()
        val result = parser.parse("""
            root = col([header, results])
            header = txt("Solo", headline)
            results = each(${"$"}items, item_tpl)
            item_tpl = txt(${"$"}value, body)
            ---
            {"items":[{"value":"Only One"}]}
        """.trimIndent())

        assertNotNull(result)
        assertIs<AmeNode.Col>(result)
        assertEquals(2, result.children.size)

        val expanded = result.children[1]
        assertIs<AmeNode.Txt>(expanded)
        assertEquals("Only One", expanded.text)
    }

    @Test
    fun eachResolvesMultiplePathsInTemplate() {
        val parser = AmeParser()
        val result = parser.parse("""
            root = each(${"$"}contacts, contact_card)
            contact_card = row([txt(${"$"}name, title), txt(${"$"}phone, body)])
            ---
            {"contacts":[{"name":"Alice","phone":"555-1234"},{"name":"Bob","phone":"555-5678"}]}
        """.trimIndent())

        assertNotNull(result)
        assertIs<AmeNode.Col>(result)
        assertEquals(2, (result as AmeNode.Col).children.size)

        val row0 = result.children[0]
        assertIs<AmeNode.Row>(row0)
        val name0 = row0.children[0]
        assertIs<AmeNode.Txt>(name0)
        assertEquals("Alice", name0.text)
        val phone0 = row0.children[1]
        assertIs<AmeNode.Txt>(phone0)
        assertEquals("555-1234", phone0.text)

        val row1 = result.children[1]
        assertIs<AmeNode.Row>(row1)
        val name1 = row1.children[0]
        assertIs<AmeNode.Txt>(name1)
        assertEquals("Bob", name1.text)
        val phone1 = row1.children[1]
        assertIs<AmeNode.Txt>(phone1)
        assertEquals("555-5678", phone1.text)
    }

    @Test
    fun eachMissingPathProducesEmptyCol() {
        val parser = AmeParser()
        val result = parser.parse("""
            root = col([header, results])
            header = txt("Missing", headline)
            results = each(${"$"}nonexistent, item_tpl)
            item_tpl = txt(${"$"}value, body)
            ---
            {"other_key":"hello"}
        """.trimIndent())

        assertNotNull(result)
        assertIs<AmeNode.Col>(result)
        assertEquals(2, result.children.size)

        val expanded = result.children[1]
        assertIs<AmeNode.Col>(expanded)
        assertEquals(0, expanded.children.size)

        assertTrue(parser.warnings.isNotEmpty())
    }

    @Test
    fun eachNestedPathResolvesCorrectly() {
        val parser = AmeParser()
        val result = parser.parse("""
            root = each(${"$"}data/results, item_tpl)
            item_tpl = txt(${"$"}title, body)
            ---
            {"data":{"results":[{"title":"First"},{"title":"Second"}]}}
        """.trimIndent())

        assertNotNull(result)
        assertIs<AmeNode.Col>(result)
        assertEquals(2, (result as AmeNode.Col).children.size)

        val txt0 = result.children[0]
        assertIs<AmeNode.Txt>(txt0)
        assertEquals("First", txt0.text)

        val txt1 = result.children[1]
        assertIs<AmeNode.Txt>(txt1)
        assertEquals("Second", txt1.text)
    }

    // ── v1.1 Chart Tests ──────────────────────────────────────────────

    @Test
    fun parseChartBar() {
        val result = parse("""
            root = chart(bar, values=[1,2,3], labels=["a","b","c"])
        """.trimIndent())

        assertNotNull(result)
        assertIs<AmeNode.Chart>(result)
        assertEquals(ChartType.BAR, result.type)
        assertEquals(listOf(1.0, 2.0, 3.0), result.values)
        assertEquals(listOf("a", "b", "c"), result.labels)
    }

    @Test
    fun parseChartLine() {
        val result = parse("""
            root = chart(line, values=[10,20], height=180)
        """.trimIndent())

        assertNotNull(result)
        assertIs<AmeNode.Chart>(result)
        assertEquals(ChartType.LINE, result.type)
        assertEquals(listOf(10.0, 20.0), result.values)
        assertEquals(180, result.height)
    }

    @Test
    fun parseChartPie() {
        val result = parse("""
            root = chart(pie, values=[30,50,20])
        """.trimIndent())

        assertNotNull(result)
        assertIs<AmeNode.Chart>(result)
        assertEquals(ChartType.PIE, result.type)
        assertEquals(listOf(30.0, 50.0, 20.0), result.values)
    }

    @Test
    fun parseChartSparkline() {
        val result = parse("""
            root = chart(sparkline, values=[1,3,2,5], height=32, color=success)
        """.trimIndent())

        assertNotNull(result)
        assertIs<AmeNode.Chart>(result)
        assertEquals(ChartType.SPARKLINE, result.type)
        assertEquals(listOf(1.0, 3.0, 2.0, 5.0), result.values)
        assertEquals(32, result.height)
        assertEquals(SemanticColor.SUCCESS, result.color)
    }

    @Test
    fun parseChartWithDataBinding() {
        val result = parse("""
            root = chart(bar, values=${"$"}amounts, labels=${"$"}months)
            ---
            {"amounts":[100,200,300],"months":["Jan","Feb","Mar"]}
        """.trimIndent())

        assertNotNull(result)
        assertIs<AmeNode.Chart>(result)
        assertEquals(ChartType.BAR, result.type)
        assertEquals(listOf(100.0, 200.0, 300.0), result.values)
        assertEquals(listOf("Jan", "Feb", "Mar"), result.labels)
        assertNull(result.valuesPath)
        assertNull(result.labelsPath)
    }

    @Test
    fun parseChartUnknownType() {
        val result = parse("""
            root = chart(donut, values=[1,2])
        """.trimIndent())

        assertNotNull(result)
        assertIs<AmeNode.Chart>(result)
        assertEquals(ChartType.BAR, result.type)
    }

    @Test
    fun parseChartEmptyValues() {
        val result = parse("""
            root = chart(bar)
        """.trimIndent())

        assertNotNull(result)
        assertIs<AmeNode.Chart>(result)
        assertEquals(ChartType.BAR, result.type)
        assertNull(result.values)
    }

    // ── v1.1 Code Tests ───────────────────────────────────────────────

    @Test
    fun parseCode() {
        val result = parse("""
            root = code("kotlin", "val x = 1")
        """.trimIndent())

        assertNotNull(result)
        assertIs<AmeNode.Code>(result)
        assertEquals("kotlin", result.language)
        assertEquals("val x = 1", result.content)
        assertNull(result.title)
    }

    @Test
    fun parseCodeWithTitle() {
        val result = parse("""
            root = code("yaml", "key: val", "config.yml")
        """.trimIndent())

        assertNotNull(result)
        assertIs<AmeNode.Code>(result)
        assertEquals("yaml", result.language)
        assertEquals("key: val", result.content)
        assertEquals("config.yml", result.title)
    }

    @Test
    fun parseCodeWithEscapes() {
        val result = parse("""
            root = code("kotlin", "line1\nline2\ttab\\end\"quote")
        """.trimIndent())

        assertNotNull(result)
        assertIs<AmeNode.Code>(result)
        assertEquals("line1\nline2\ttab\\end\"quote", result.content)
    }

    // ── v1.1 Accordion Tests ──────────────────────────────────────────

    @Test
    fun parseAccordion() {
        val result = parse("""
            c1 = txt("Child 1")
            c2 = txt("Child 2")
            root = accordion("Details", [c1, c2])
        """.trimIndent())

        assertNotNull(result)
        assertIs<AmeNode.Accordion>(result)
        assertEquals("Details", result.title)
        assertEquals(2, result.children.size)
        assertEquals(false, result.expanded)
    }

    @Test
    fun parseAccordionExpanded() {
        val result = parse("""
            c1 = txt("Content")
            root = accordion("Title", [c1], true)
        """.trimIndent())

        assertNotNull(result)
        assertIs<AmeNode.Accordion>(result)
        assertEquals(true, result.expanded)
    }

    @Test
    fun parseAccordionDefaultCollapsed() {
        val result = parse("""
            root = accordion("FAQ", [txt("Answer")])
        """.trimIndent())

        assertNotNull(result)
        assertIs<AmeNode.Accordion>(result)
        assertEquals(false, result.expanded)
    }

    // ── v1.1 Carousel Tests ───────────────────────────────────────────

    @Test
    fun parseCarousel() {
        val result = parse("""
            root = carousel([txt("A"), txt("B"), txt("C")])
        """.trimIndent())

        assertNotNull(result)
        assertIs<AmeNode.Carousel>(result)
        assertEquals(3, result.children.size)
    }

    @Test
    fun parseCarouselWithPeek() {
        val result = parse("""
            root = carousel([txt("A"), txt("B")], peek=32)
        """.trimIndent())

        assertNotNull(result)
        assertIs<AmeNode.Carousel>(result)
        assertEquals(2, result.children.size)
        assertEquals(32, result.peek)
    }

    @Test
    fun parseCarouselDefaultPeek() {
        val result = parse("""
            root = carousel([txt("A")])
        """.trimIndent())

        assertNotNull(result)
        assertIs<AmeNode.Carousel>(result)
        assertEquals(24, result.peek)
    }

    // ── v1.1 Callout Tests ────────────────────────────────────────────

    @Test
    fun parseCalloutInfo() {
        val result = parse("""
            root = callout(info, "This is informational")
        """.trimIndent())

        assertNotNull(result)
        assertIs<AmeNode.Callout>(result)
        assertEquals(CalloutType.INFO, result.type)
        assertEquals("This is informational", result.content)
        assertNull(result.title)
    }

    @Test
    fun parseCalloutWarning() {
        val result = parse("""
            root = callout(warning, "Proceed with caution")
        """.trimIndent())

        assertNotNull(result)
        assertIs<AmeNode.Callout>(result)
        assertEquals(CalloutType.WARNING, result.type)
    }

    @Test
    fun parseCalloutWithTitle() {
        val result = parse("""
            root = callout(tip, "Use keyboard shortcuts", "Pro Tip")
        """.trimIndent())

        assertNotNull(result)
        assertIs<AmeNode.Callout>(result)
        assertEquals(CalloutType.TIP, result.type)
        assertEquals("Use keyboard shortcuts", result.content)
        assertEquals("Pro Tip", result.title)
    }

    @Test
    fun parseCalloutAllTypes() {
        for ((name, expected) in listOf(
            "info" to CalloutType.INFO,
            "warning" to CalloutType.WARNING,
            "error" to CalloutType.ERROR,
            "success" to CalloutType.SUCCESS,
            "tip" to CalloutType.TIP
        )) {
            val result = parse("root = callout($name, \"msg\")")
            assertNotNull(result, "callout($name) returned null")
            assertIs<AmeNode.Callout>(result)
            assertEquals(expected, result.type, "callout($name) type mismatch")
        }
    }

    @Test
    fun parseCalloutUnknownType() {
        val result = parse("""
            root = callout(banana, "msg")
        """.trimIndent())

        assertNotNull(result)
        assertIs<AmeNode.Callout>(result)
        assertEquals(CalloutType.INFO, result.type)
    }

    // ── v1.1 Timeline Tests ───────────────────────────────────────────

    @Test
    fun parseTimeline() {
        val result = parse("""
            s1 = timeline_item("Step 1", "Done", done)
            s2 = timeline_item("Step 2", "In progress", active)
            root = timeline([s1, s2])
        """.trimIndent())

        assertNotNull(result)
        assertIs<AmeNode.Timeline>(result)
        assertEquals(2, result.children.size)

        val item0 = result.children[0]
        assertIs<AmeNode.TimelineItem>(item0)
        assertEquals("Step 1", item0.title)
        assertEquals("Done", item0.subtitle)
        assertEquals(TimelineStatus.DONE, item0.status)

        val item1 = result.children[1]
        assertIs<AmeNode.TimelineItem>(item1)
        assertEquals(TimelineStatus.ACTIVE, item1.status)
    }

    @Test
    fun parseTimelineItem() {
        val result = parse("""
            root = timeline_item("Title", "Subtitle", done)
        """.trimIndent())

        assertNotNull(result)
        assertIs<AmeNode.TimelineItem>(result)
        assertEquals("Title", result.title)
        assertEquals("Subtitle", result.subtitle)
        assertEquals(TimelineStatus.DONE, result.status)
    }

    @Test
    fun parseTimelineItemDefaultStatus() {
        val result = parse("""
            root = timeline_item("Upcoming")
        """.trimIndent())

        assertNotNull(result)
        assertIs<AmeNode.TimelineItem>(result)
        assertEquals(TimelineStatus.PENDING, result.status)
    }

    @Test
    fun parseTimelineItemAllStatuses() {
        for ((name, expected) in listOf(
            "done" to TimelineStatus.DONE,
            "active" to TimelineStatus.ACTIVE,
            "pending" to TimelineStatus.PENDING,
            "error" to TimelineStatus.ERROR
        )) {
            val result = parse("root = timeline_item(\"t\", \"s\", $name)")
            assertNotNull(result, "timeline_item with status=$name returned null")
            assertIs<AmeNode.TimelineItem>(result)
            assertEquals(expected, result.status, "status=$name mismatch")
        }
    }

    // ── v1.1 Txt/Badge Color Tests ────────────────────────────────────

    @Test
    fun parseTxtWithColor() {
        val result = parse("""
            root = txt("Alert text", body, color=warning)
        """.trimIndent())

        assertNotNull(result)
        assertIs<AmeNode.Txt>(result)
        assertEquals("Alert text", result.text)
        assertEquals(TxtStyle.BODY, result.style)
        assertEquals(SemanticColor.WARNING, result.color)
    }

    @Test
    fun parseTxtWithoutColor() {
        val result = parse("""
            root = txt("Normal", headline)
        """.trimIndent())

        assertNotNull(result)
        assertIs<AmeNode.Txt>(result)
        assertNull(result.color)
    }

    @Test
    fun parseBadgeWithColor() {
        val result = parse("""
            root = badge("Live", success, color=success)
        """.trimIndent())

        assertNotNull(result)
        assertIs<AmeNode.Badge>(result)
        assertEquals("Live", result.label)
        assertEquals(BadgeVariant.SUCCESS, result.variant)
        assertEquals(SemanticColor.SUCCESS, result.color)
    }

    // ── v1.1 Chart Multi-Series Test ──────────────────────────────────

    @Test
    fun parseChartMultiSeries() {
        val result = parse("""
            root = chart(line, series=[[1,2,3],[4,5,6]], labels=["a","b","c"])
        """.trimIndent())

        assertNotNull(result)
        assertIs<AmeNode.Chart>(result)
        assertEquals(ChartType.LINE, result.type)
        assertNotNull(result.series)
        assertEquals(2, result.series!!.size)
        assertEquals(listOf(1.0, 2.0, 3.0), result.series!![0])
        assertEquals(listOf(4.0, 5.0, 6.0), result.series!![1])
        assertEquals(listOf("a", "b", "c"), result.labels)
    }

    // ── WP#5b.1 Regression: Chart $path inside each() ─────────────────

    @Test
    fun chartInsideEachResolvesPerItemScope() {
        val parser = AmeParser()
        val result = parser.parse("""
            root = col([results])
            results = each(${"$"}restaurants, tpl)
            tpl = col([name, spending])
            name = txt(${"$"}name, title)
            spending = chart(bar, values=${"$"}sales)
            ---
            {"restaurants":[{"name":"Luigi's","sales":[10,20,30]},{"name":"Bella's","sales":[40,50,60]}]}
        """.trimIndent())

        assertNotNull(result)
        assertIs<AmeNode.Col>(result)

        val expanded = result.children[0]
        assertIs<AmeNode.Col>(expanded)
        assertEquals(2, expanded.children.size)

        val tpl1 = expanded.children[0]
        assertIs<AmeNode.Col>(tpl1)
        val name1 = tpl1.children[0]
        assertIs<AmeNode.Txt>(name1)
        assertEquals("Luigi's", name1.text)
        val chart1 = tpl1.children[1]
        assertIs<AmeNode.Chart>(chart1)
        assertEquals(listOf(10.0, 20.0, 30.0), chart1.values)
        assertNull(chart1.valuesPath)

        val tpl2 = expanded.children[1]
        assertIs<AmeNode.Col>(tpl2)
        val name2 = tpl2.children[0]
        assertIs<AmeNode.Txt>(name2)
        assertEquals("Bella's", name2.text)
        val chart2 = tpl2.children[1]
        assertIs<AmeNode.Chart>(chart2)
        assertEquals(listOf(40.0, 50.0, 60.0), chart2.values)
        assertNull(chart2.valuesPath)
    }

    // ════════════════════════════════════════════════════════════════════
    // v1.4 — Row weights / crossAlign
    // ════════════════════════════════════════════════════════════════════

    @Test
    fun parseRowWithWeights() {
        val result = parse("""
            root = row([a, b], weights=[1, 0])
            a = txt("Wide")
            b = txt("Narrow")
        """.trimIndent())

        assertNotNull(result)
        assertIs<AmeNode.Row>(result)
        assertEquals(listOf(1, 0), result.weights)
        assertNull(result.crossAlign)
    }

    @Test
    fun parseRowWithCrossAlign() {
        val result = parse("""
            root = row([a, b], crossAlign=top)
            a = txt("A")
            b = txt("B")
        """.trimIndent())

        assertNotNull(result)
        assertIs<AmeNode.Row>(result)
        assertEquals(Align.TOP, result.crossAlign)
        assertNull(result.weights)
    }

    @Test
    fun parseRowWithCrossAlignSnakeCase() {
        val result = parse("""
            root = row([a, b], cross_align=bottom)
            a = txt("A")
            b = txt("B")
        """.trimIndent())

        assertNotNull(result)
        assertIs<AmeNode.Row>(result)
        assertEquals(Align.BOTTOM, result.crossAlign)
    }

    @Test
    fun parseRowWithWeightsAndCrossAlign() {
        val result = parse("""
            root = row([a, b], space_between, 12, weights=[1, 1], crossAlign=top)
            a = txt("A")
            b = txt("B")
        """.trimIndent())

        assertNotNull(result)
        assertIs<AmeNode.Row>(result)
        assertEquals(Align.SPACE_BETWEEN, result.align)
        assertEquals(12, result.gap)
        assertEquals(listOf(1, 1), result.weights)
        assertEquals(Align.TOP, result.crossAlign)
    }

    @Test
    fun parseRowWeightsLengthMismatchFallsBack() {
        val src = """
            root = row([a, b, c], weights=[1, 0])
            a = txt("A")
            b = txt("B")
            c = txt("C")
        """.trimIndent()
        val parser = AmeParser()
        val result = parser.parse(src)

        assertNotNull(result)
        assertIs<AmeNode.Row>(result)
        assertNull(result.weights, "Length mismatch must fall back to null (intrinsic)")
        assertTrue(parser.warnings.any { it.contains("weights length") }, "Mismatch must log a warning")
    }

    @Test
    fun parseRowWithoutNewFieldsIsBackwardCompatible() {
        val result = parse("""
            root = row([a, b])
            a = txt("A")
            b = txt("B")
        """.trimIndent())

        assertNotNull(result)
        assertIs<AmeNode.Row>(result)
        assertNull(result.weights)
        assertNull(result.crossAlign)
        assertEquals(Align.START, result.align)
        assertEquals(8, result.gap)
    }

    // ════════════════════════════════════════════════════════════════════
    // v1.4 — list_item primitive
    // ════════════════════════════════════════════════════════════════════

    @Test
    fun parseListItemBasic() {
        val result = parse("""
            root = list_item("Pizza Place", "71 Mulberry St", icon("restaurant"), badge("4.5", info))
        """.trimIndent())

        assertNotNull(result)
        assertIs<AmeNode.ListItem>(result)
        assertEquals("Pizza Place", result.title)
        assertEquals("71 Mulberry St", result.subtitle)
        assertIs<AmeNode.Icon>(result.leading)
        assertEquals("restaurant", (result.leading as AmeNode.Icon).name)
        assertIs<AmeNode.Badge>(result.trailing)
        assertEquals("4.5", (result.trailing as AmeNode.Badge).label)
        assertEquals(BadgeVariant.INFO, (result.trailing as AmeNode.Badge).variant)
        assertNull(result.action)
    }

    @Test
    fun parseListItemMinimal() {
        val result = parse("""root = list_item("Title only")""")

        assertNotNull(result)
        assertIs<AmeNode.ListItem>(result)
        assertEquals("Title only", result.title)
        assertNull(result.subtitle)
        assertNull(result.leading)
        assertNull(result.trailing)
        assertNull(result.action)
    }

    @Test
    fun parseListItemWithAction() {
        val result = parse("""
            root = list_item("Settings", action=nav("/settings"))
        """.trimIndent())

        assertNotNull(result)
        assertIs<AmeNode.ListItem>(result)
        assertEquals("Settings", result.title)
        assertNotNull(result.action)
        assertIs<AmeAction.Navigate>(result.action)
        assertEquals("/settings", (result.action as AmeAction.Navigate).route)
    }

    @Test
    fun parseListItemWithTrailingBtnAndRowAction() {
        // Nested click target case: row has its own action and trailing has a btn
        // with its own action. The parser must capture both independently; the
        // renderer is responsible for tap isolation.
        val result = parse("""
            root = list_item("Pizza Place", "71 Mulberry St", icon("restaurant"), btn("Directions", nav("/dir")), action=nav("/detail"))
        """.trimIndent())

        assertNotNull(result)
        assertIs<AmeNode.ListItem>(result)
        assertIs<AmeNode.Btn>(result.trailing)
        val trailingBtn = result.trailing as AmeNode.Btn
        assertEquals("Directions", trailingBtn.label)
        assertIs<AmeAction.Navigate>(trailingBtn.action)
        assertEquals("/dir", (trailingBtn.action as AmeAction.Navigate).route)

        assertNotNull(result.action)
        assertIs<AmeAction.Navigate>(result.action)
        assertEquals("/detail", (result.action as AmeAction.Navigate).route)
    }

    @Test
    fun parseListItemPositionalActionIsIgnored() {
        // action is named-only by design. A 5th positional arg should not be
        // misinterpreted as an action.
        val parser = AmeParser()
        val result = parser.parse("""
            root = list_item("T", "S", icon("x"), badge("B"), nav("/oops"))
        """.trimIndent())

        assertNotNull(result)
        assertIs<AmeNode.ListItem>(result)
        assertNull(result.action, "5th positional arg must NOT be treated as action; use action= named arg")
    }

    @Test
    fun parseListItemWithIdentifierLeading() {
        val result = parse("""
            root = list_item("Title", "Sub", my_icon)
            my_icon = icon("star")
        """.trimIndent())

        assertNotNull(result)
        assertIs<AmeNode.ListItem>(result)
        assertIs<AmeNode.Icon>(result.leading)
        assertEquals("star", (result.leading as AmeNode.Icon).name)
    }

    @Test
    fun parseListItemResolvesDataPaths() {
        val result = parse("""
            root = list_item(${"$"}name, ${"$"}addr, icon("restaurant"))
            ---
            {"name":"Luigi's","addr":"119 Mulberry St"}
        """.trimIndent())

        assertNotNull(result)
        assertIs<AmeNode.ListItem>(result)
        assertEquals("Luigi's", result.title)
        assertEquals("119 Mulberry St", result.subtitle)
    }
}
