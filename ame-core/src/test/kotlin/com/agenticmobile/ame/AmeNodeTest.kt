package com.agenticmobile.ame

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

/**
 * Round-trip serialization tests for all AmeNode and AmeAction types.
 * Verifies: serialize to JSON -> deserialize back -> assertEquals on original.
 */
class AmeNodeTest {

    // ── Helper ─────────────────────────────────────────────────────────

    private fun assertRoundTrip(node: AmeNode) {
        val json = AmeSerializer.toJson(node)
        val restored = AmeSerializer.fromJson(json)
        assertNotNull(restored, "Deserialization returned null for: $json")
        assertEquals(node, restored, "Round-trip failed for: $json")
    }

    private fun assertActionRoundTrip(action: AmeAction) {
        val json = AmeSerializer.actionToJson(action)
        val restored = AmeSerializer.actionFromJson(json)
        assertNotNull(restored, "Action deserialization returned null for: $json")
        assertEquals(action, restored, "Action round-trip failed for: $json")
    }

    // ── Layout Primitives ──────────────────────────────────────────────

    @Test
    fun roundTripCol() {
        val node = AmeNode.Col(
            children = listOf(
                AmeNode.Txt("Hello", TxtStyle.TITLE),
                AmeNode.Txt("World", TxtStyle.BODY)
            ),
            align = Align.CENTER
        )
        assertRoundTrip(node)
    }

    @Test
    fun roundTripColDefaults() {
        val node = AmeNode.Col(
            children = listOf(AmeNode.Txt("A"))
        )
        assertRoundTrip(node)
        val json = AmeSerializer.toJson(node)
        assertTrue(!json.contains("\"align\""), "Default align should not be encoded: $json")
    }

    @Test
    fun roundTripRow() {
        val node = AmeNode.Row(
            children = listOf(
                AmeNode.Txt("Left"),
                AmeNode.Txt("Right")
            ),
            align = Align.SPACE_BETWEEN,
            gap = 16
        )
        assertRoundTrip(node)
    }

    @Test
    fun roundTripRowDefaults() {
        val node = AmeNode.Row(
            children = listOf(AmeNode.Txt("Item"))
        )
        assertRoundTrip(node)
        val json = AmeSerializer.toJson(node)
        assertTrue(!json.contains("\"gap\""), "Default gap should not be encoded: $json")
        assertTrue(!json.contains("\"align\""), "Default align should not be encoded: $json")
    }

    // ── Content Primitives ─────────────────────────────────────────────

    @Test
    fun roundTripTxt() {
        val node = AmeNode.Txt("Hello World", TxtStyle.HEADLINE, maxLines = 2)
        assertRoundTrip(node)
    }

    @Test
    fun roundTripTxtDefaults() {
        val node = AmeNode.Txt("Simple text")
        assertRoundTrip(node)
        val json = AmeSerializer.toJson(node)
        assertTrue(!json.contains("\"style\""), "Default style should not be encoded: $json")
        assertTrue(!json.contains("\"maxLines\""), "Null maxLines should not be encoded: $json")
    }

    @Test
    fun roundTripImg() {
        val node = AmeNode.Img("https://example.com/photo.jpg", height = 180)
        assertRoundTrip(node)
    }

    @Test
    fun roundTripImgNoHeight() {
        val node = AmeNode.Img("https://example.com/photo.jpg")
        assertRoundTrip(node)
    }

    @Test
    fun roundTripIcon() {
        val node = AmeNode.Icon("partly_cloudy_day", size = 28)
        assertRoundTrip(node)
    }

    @Test
    fun roundTripIconDefaults() {
        val node = AmeNode.Icon("star")
        assertRoundTrip(node)
    }

    @Test
    fun roundTripDivider() {
        val node = AmeNode.Divider
        assertRoundTrip(node)
        val json = AmeSerializer.toJson(node)
        assertEquals("{\"_type\":\"divider\"}", json)
    }

    @Test
    fun roundTripSpacer() {
        val node = AmeNode.Spacer(height = 16)
        assertRoundTrip(node)
    }

    @Test
    fun roundTripSpacerDefaults() {
        val node = AmeNode.Spacer()
        assertRoundTrip(node)
    }

    // ── Semantic Primitives ────────────────────────────────────────────

    @Test
    fun roundTripCard() {
        val node = AmeNode.Card(
            children = listOf(
                AmeNode.Txt("Title", TxtStyle.TITLE),
                AmeNode.Txt("Description")
            ),
            elevation = 2
        )
        assertRoundTrip(node)
    }

    @Test
    fun roundTripBadge() {
        val node = AmeNode.Badge("★4.5", BadgeVariant.INFO)
        assertRoundTrip(node)
    }

    @Test
    fun roundTripBadgeDefaults() {
        val node = AmeNode.Badge("Tag")
        assertRoundTrip(node)
    }

    @Test
    fun roundTripProgress() {
        val node = AmeNode.Progress(0.67f, "67% complete")
        assertRoundTrip(node)
    }

    @Test
    fun roundTripProgressNoLabel() {
        val node = AmeNode.Progress(0.3f)
        assertRoundTrip(node)
    }

    // ── Interactive Primitives ─────────────────────────────────────────

    @Test
    fun roundTripBtnWithToolAction() {
        val node = AmeNode.Btn(
            label = "Save",
            action = AmeAction.CallTool(
                name = "add_note",
                args = mapOf("title" to "Meeting Notes")
            ),
            style = BtnStyle.PRIMARY
        )
        assertRoundTrip(node)
    }

    @Test
    fun roundTripBtnWithUriAction() {
        val node = AmeNode.Btn(
            label = "Directions",
            action = AmeAction.OpenUri("geo:40.72,-73.99?q=Luigi's"),
            style = BtnStyle.TEXT
        )
        assertRoundTrip(node)
    }

    @Test
    fun roundTripBtnWithNavAction() {
        val node = AmeNode.Btn(
            label = "Home",
            action = AmeAction.Navigate("home"),
            style = BtnStyle.OUTLINE
        )
        assertRoundTrip(node)
    }

    @Test
    fun roundTripBtnWithCopyAction() {
        val node = AmeNode.Btn(
            label = "Copy Address",
            action = AmeAction.CopyText("119 Mulberry St"),
            style = BtnStyle.TEXT
        )
        assertRoundTrip(node)
    }

    @Test
    fun roundTripBtnWithSubmitAction() {
        val node = AmeNode.Btn(
            label = "Confirm",
            action = AmeAction.Submit(
                toolName = "create_reservation",
                staticArgs = mapOf("restaurant" to "Luigi's")
            ),
            style = BtnStyle.PRIMARY
        )
        assertRoundTrip(node)
    }

    @Test
    fun roundTripBtnWithIcon() {
        val node = AmeNode.Btn(
            label = "Call",
            action = AmeAction.OpenUri("tel:+15551234567"),
            style = BtnStyle.PRIMARY,
            icon = "phone"
        )
        assertRoundTrip(node)
    }

    @Test
    fun roundTripInput() {
        val node = AmeNode.Input("email", "Email Address", InputType.EMAIL)
        assertRoundTrip(node)
    }

    @Test
    fun roundTripInputSelect() {
        val node = AmeNode.Input(
            id = "guests",
            label = "Number of Guests",
            type = InputType.SELECT,
            options = listOf("1", "2", "3", "4", "5", "6")
        )
        assertRoundTrip(node)
    }

    @Test
    fun roundTripInputDefaults() {
        val node = AmeNode.Input("name", "Your Name")
        assertRoundTrip(node)
    }

    @Test
    fun roundTripToggle() {
        val node = AmeNode.Toggle("notifications", "Enable notifications", default = true)
        assertRoundTrip(node)
    }

    @Test
    fun roundTripToggleDefaults() {
        val node = AmeNode.Toggle("agree", "I agree to the terms")
        assertRoundTrip(node)
        val json = AmeSerializer.toJson(node)
        assertTrue(!json.contains("\"default\""), "Default false should not be encoded: $json")
    }

    // ── Data Primitives ────────────────────────────────────────────────

    @Test
    fun roundTripDataList() {
        val node = AmeNode.DataList(
            children = listOf(
                AmeNode.Txt("Item 1"),
                AmeNode.Txt("Item 2"),
                AmeNode.Txt("Item 3")
            ),
            dividers = true
        )
        assertRoundTrip(node)
    }

    @Test
    fun roundTripDataListNoDividers() {
        val node = AmeNode.DataList(
            children = listOf(AmeNode.Txt("A"), AmeNode.Txt("B")),
            dividers = false
        )
        assertRoundTrip(node)
    }

    @Test
    fun roundTripTable() {
        val node = AmeNode.Table(
            headers = listOf("Feature", "Basic", "Pro"),
            rows = listOf(
                listOf("Storage", "50 GB", "500 GB"),
                listOf("Users", "1", "10"),
                listOf("Support", "Email", "24/7")
            )
        )
        assertRoundTrip(node)
    }

    // ── Structural Types ───────────────────────────────────────────────

    @Test
    fun roundTripRef() {
        val node = AmeNode.Ref("header")
        assertRoundTrip(node)
    }

    @Test
    fun roundTripEach() {
        val node = AmeNode.Each(dataPath = "places", templateId = "place_tpl")
        assertRoundTrip(node)
    }

    // ── Action Round-Trip Tests ────────────────────────────────────────

    @Test
    fun roundTripCallToolAction() {
        val action = AmeAction.CallTool(
            name = "create_calendar_event",
            args = mapOf(
                "title" to "Dinner at Luigi's",
                "date" to "2026-04-15"
            )
        )
        assertActionRoundTrip(action)
    }

    @Test
    fun roundTripCallToolWithInputRef() {
        val action = AmeAction.CallTool(
            name = "send_message",
            args = mapOf(
                "to" to "\${input.recipient}",
                "body" to "\${input.body}"
            )
        )
        assertActionRoundTrip(action)
        val json = AmeSerializer.actionToJson(action)
        assertTrue(json.contains("\${input.recipient}"), "Input ref must survive as literal: $json")
    }

    @Test
    fun roundTripOpenUriAction() {
        assertActionRoundTrip(AmeAction.OpenUri("geo:40.72,-73.99?q=Luigi's"))
    }

    @Test
    fun roundTripNavigateAction() {
        assertActionRoundTrip(AmeAction.Navigate("calendar"))
    }

    @Test
    fun roundTripCopyTextAction() {
        assertActionRoundTrip(AmeAction.CopyText("119 Mulberry St, New York"))
    }

    @Test
    fun roundTripSubmitAction() {
        val action = AmeAction.Submit(
            toolName = "create_reservation",
            staticArgs = mapOf("restaurant" to "Luigi's")
        )
        assertActionRoundTrip(action)
    }

    @Test
    fun roundTripSubmitActionEmpty() {
        val action = AmeAction.Submit(toolName = "save_draft")
        assertActionRoundTrip(action)
    }

    // ── Complex Tree: Weather Card (syntax.md Example 1) ───────────────

    @Test
    fun roundTripWeatherCardTree() {
        val tree = AmeNode.Card(
            children = listOf(
                AmeNode.Row(
                    children = listOf(
                        AmeNode.Txt("San Francisco", TxtStyle.TITLE),
                        AmeNode.Icon("partly_cloudy_day", 28)
                    ),
                    align = Align.SPACE_BETWEEN
                ),
                AmeNode.Txt("62°", TxtStyle.DISPLAY),
                AmeNode.Txt("Partly Cloudy", TxtStyle.BODY),
                AmeNode.Row(
                    children = listOf(
                        AmeNode.Txt("H:68°  L:55°", TxtStyle.CAPTION),
                        AmeNode.Txt("Humidity: 72%", TxtStyle.CAPTION)
                    ),
                    align = Align.SPACE_BETWEEN
                )
            )
        )
        assertRoundTrip(tree)

        val json = AmeSerializer.toJson(tree)
        assertTrue(json.contains("\"San Francisco\""), "Tree JSON must contain city name")
        assertTrue(json.contains("\"partly_cloudy_day\""), "Tree JSON must contain icon name")
        assertTrue(json.contains("\"62°\""), "Tree JSON must contain temperature")
    }

    @Test
    fun weatherCardJsonIsCompact() {
        val tree = AmeNode.Card(
            children = listOf(
                AmeNode.Txt("62°", TxtStyle.DISPLAY),
                AmeNode.Txt("Partly Cloudy")
            )
        )
        val json = AmeSerializer.toJson(tree)
        assertTrue(!json.contains("\"elevation\""), "Default elevation should not be in JSON")
    }

    // ── Nested Tree Serialization ──────────────────────────────────────

    @Test
    fun roundTripDeeplyNestedTree() {
        val tree = AmeNode.Col(
            children = listOf(
                AmeNode.Card(
                    children = listOf(
                        AmeNode.Row(
                            children = listOf(
                                AmeNode.Txt("Name", TxtStyle.TITLE),
                                AmeNode.Badge("★4.5", BadgeVariant.INFO)
                            ),
                            align = Align.SPACE_BETWEEN
                        ),
                        AmeNode.Txt("123 Main St", TxtStyle.CAPTION),
                        AmeNode.Row(
                            children = listOf(
                                AmeNode.Btn(
                                    label = "Schedule",
                                    action = AmeAction.CallTool(
                                        "create_event",
                                        mapOf("title" to "Dinner")
                                    ),
                                    style = BtnStyle.PRIMARY
                                ),
                                AmeNode.Btn(
                                    label = "Directions",
                                    action = AmeAction.OpenUri("geo:40.72,-73.99"),
                                    style = BtnStyle.TEXT
                                )
                            ),
                            gap = 8
                        )
                    )
                )
            )
        )
        assertRoundTrip(tree)
    }

    // ── Children with Ref nodes (streaming scenario) ───────────────────

    @Test
    fun roundTripTreeWithRefs() {
        val tree = AmeNode.Col(
            children = listOf(
                AmeNode.Ref("header"),
                AmeNode.Ref("body"),
                AmeNode.Ref("footer")
            )
        )
        assertRoundTrip(tree)
        val json = AmeSerializer.toJson(tree)
        assertTrue(json.contains("\"_type\":\"ref\""), "Ref type discriminator must be present")
    }

    // ── Each node in tree ──────────────────────────────────────────────

    @Test
    fun roundTripTreeWithEach() {
        val tree = AmeNode.Col(
            children = listOf(
                AmeNode.Txt("Nearby Places", TxtStyle.HEADLINE),
                AmeNode.Each(dataPath = "places", templateId = "place_tpl")
            )
        )
        assertRoundTrip(tree)
    }

    // ── encodeDefaults=false verification ──────────────────────────────

    @Test
    fun encodeDefaultsFalseOmitsDefaults() {
        val txt = AmeNode.Txt("Hello")
        val json = AmeSerializer.toJson(txt)
        assertEquals("{\"_type\":\"txt\",\"text\":\"Hello\"}", json)
    }

    @Test
    fun encodeDefaultsFalseIncludesNonDefaults() {
        val txt = AmeNode.Txt("Hello", TxtStyle.HEADLINE)
        val json = AmeSerializer.toJson(txt)
        assertTrue(json.contains("\"style\":\"headline\""), "Non-default style must be encoded: $json")
    }

    // ── Type discriminator verification ────────────────────────────────

    @Test
    fun typeDiscriminatorUsesSerialName() {
        val json = AmeSerializer.toJson(AmeNode.Badge("New", BadgeVariant.SUCCESS))
        assertTrue(json.startsWith("{\"_type\":\"badge\""), "Type discriminator must use @SerialName: $json")
    }

    @Test
    fun dividerTypeDiscriminator() {
        val json = AmeSerializer.toJson(AmeNode.Divider)
        assertTrue(json.contains("\"_type\":\"divider\""), "Divider discriminator must be 'divider': $json")
    }
}
