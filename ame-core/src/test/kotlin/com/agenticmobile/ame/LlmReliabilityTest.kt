package com.agenticmobile.ame

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put
import kotlinx.serialization.json.putJsonArray
import kotlinx.serialization.json.putJsonObject
import kotlinx.serialization.json.addJsonObject
import kotlinx.serialization.json.booleanOrNull
import java.io.File
import java.net.URI
import java.net.http.HttpClient
import java.net.http.HttpRequest
import java.net.http.HttpResponse
import java.time.Duration
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import kotlin.test.Test

/**
 * GATE 3: LLM Reliability Benchmark (v1.1 — 21 Primitives)
 *
 * Calls Gemini and Claude APIs with the v1.1 AME system prompt from
 * integration.md, feeds responses to AmeParser, and scores on 4 dimensions
 * (parse, structure, refs, actions). 32 prompts: 20 v1.0 + 12 v1.1.
 *
 * NOT a pass/fail test. This benchmark MEASURES success rates and prints
 * results as markdown tables for llm-reliability.md.
 *
 * Run with API keys as environment variables:
 *   GEMINI_API_KEY=xxx ANTHROPIC_API_KEY=yyy ./gradlew :ame-core:test --tests "*.LlmReliabilityTest"
 */
class LlmReliabilityTest {

    private val httpClient: HttpClient = HttpClient.newBuilder()
        .connectTimeout(Duration.ofSeconds(30))
        .build()

    private val json = Json { ignoreUnknownKeys = true }

    private val logDir: File by lazy {
        val timestamp = LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyy-MM-dd_HHmmss"))
        File("build/benchmark-logs/$timestamp").also { it.mkdirs() }
    }

    // Exact v1.1 system prompt from specification/v1.0/integration.md lines 128-176
    private val systemPrompt = """
--- AME UI Generation ---
When you want to show rich interactive UI (cards, forms, lists, buttons,
charts, timelines), generate an AME document. AME is a line-oriented syntax
where each line binds an identifier to a component.

AME_SUPPORT: v1.1
AME_CATALOG: col, row, txt, btn, card, badge, icon, img, input, toggle, list, table, divider, spacer, progress, chart, code, accordion, carousel, callout, timeline

Rules:
- One statement per line: identifier = Component(args)
- First line MUST be: root = ...
- Identifiers: lowercase with underscores (e.g., p1_name, header)
- Children arrays: [child1, child2, child3]
- IMPORTANT: Every identifier in a children array MUST be defined on its own line

Primitives:
col([children]) row([children], align?) txt("text", style?, color?) btn("label", action, style?)
card([children]) badge("label", variant?, color?) icon("name") img("url", height?)
input(id, "label", type?) toggle(id, "label") list([children]) table(headers, rows)
divider() spacer(height?) progress(value, "label"?)
chart(type, values, labels?, height?) — data visualization. type: line|bar|pie|sparkline
code(lang, content, title?) — syntax-highlighted code block with copy
accordion(title, [children], expanded?) — collapsible section
carousel([children], peek?) — horizontal scrollable container
callout(type, content, title?) — alert/info box. type: info|warning|error|success|tip
timeline([items]) — ordered event sequence. Items: timeline_item(title, subtitle?, status?)

Styles: display, headline, title, body, caption, mono, label
Button styles: primary, secondary, outline, text, destructive
Badge variants: default, success, warning, error, info
Semantic colors (named arg color=): primary, secondary, error, success, warning

Actions:
tool(name, key=val)  - invoke a tool
uri("scheme:...")     - open URI (geo:, tel:, mailto:, https:)
nav("route")         - navigate in app
copy("text")         - copy to clipboard
submit(tool, key=val) - collect form inputs + invoke tool

Example:
root = card([header, details, actions])
header = row([title, temp_badge], space_between)
title = txt("San Francisco", title)
temp_badge = badge("62°F", info)
details = txt("Partly Cloudy — H:68° L:55°", caption)
actions = row([save_btn, share_btn], 8)
save_btn = btn("Save", tool(save_location, city="San Francisco"), primary)
share_btn = btn("Share", copy("San Francisco: 62°F, Partly Cloudy"), text)
--- End AME ---
    """.trim()

    // 20 test prompts from benchmarks/llm-reliability.md
    private val testPrompts = listOf(
        "Show a weather card for Tokyo, 28°C, Sunny",
        "Show 2 restaurant results with ratings and direction buttons",
        "Create a contact card for John Smith, phone 555-1234, email john@example.com",
        "Show a booking form with date, time, and party size inputs",
        "Display a to-do list with 3 items, each with a checkbox",
        "Show a music player card with song title, artist, and play/pause button",
        "Create a comparison of two subscription plans",
        "Show an email preview: from Sarah, subject Meeting Notes, with reply and delete buttons",
        "Display a progress card showing 75% complete for a file upload",
        "Show a settings panel with 3 toggles: notifications, dark mode, auto-save",
        "Create a shipping address form with name, street, city, state, zip",
        "Show search results for 'best coffee shops' with 3 results",
        "Display a calendar event: Team Standup, Monday 9am, Conference Room B",
        "Show a product card: Wireless Headphones, \$79.99, 4.5 stars, Add to Cart button",
        "Create an error card with warning icon, message, and retry button",
        "Show a user profile: name, email, member since date, edit button",
        "Display a notification list with 4 items of varying types",
        "Show a flight result: NYC to LAX, \$299, 5h 30m, with book button",
        "Create a simple about page with app name, version, and support link",
        "Show a recipe card: title, prep time, cook time, ingredients list",
        // v1.1 prompts (21-32)
        "Show a bar chart of monthly spending: Jan \$420, Feb \$580, Mar \$510, Apr \$670",
        "Display this Python code with syntax highlighting: def hello():\\n    print('Hello, World!')",
        "Show medication details with expandable sections for side effects and drug interactions",
        "Show a horizontal carousel of 4 running shoes with images, names, prices, and add-to-cart buttons",
        "Show a warning callout: Do not take ibuprofen on an empty stomach",
        "Show order tracking for Order #4521: Ordered (done), Shipped (done), In Transit (active), Delivered (pending)",
        "Show a sparkline chart of Bitcoin prices next to the current price of \$67,432",
        "Create a dashboard with a line chart of revenue, a success callout about hitting targets, and a summary stat",
        "Show a Kotlin code snippet with a tip callout about best practices below it",
        "Show an FAQ with 3 expandable questions about AME: What is it, How many primitives, Is it open source",
        "Show search results for 'italian restaurants' with name, rating, and address for each result using a data section",
        "Display a list of 3 upcoming calendar events with title, date, and location from a data section"
    )

    private val promptLabels = listOf(
        "Weather Tokyo", "Restaurant results", "Contact card", "Booking form",
        "To-do list", "Music player", "Plan comparison", "Email preview",
        "Progress card", "Settings toggles", "Shipping form", "Coffee shop search",
        "Calendar event", "Product card", "Error card", "User profile",
        "Notification list", "Flight result", "About page", "Recipe card",
        // v1.1 labels (21-32)
        "Chart bar spending", "Code Python", "Accordion medication", "Carousel shoes",
        "Callout warning", "Timeline order", "Chart sparkline BTC", "Dashboard chart+callout",
        "Code+callout combo", "Accordion FAQ", "Each restaurants", "Each events"
    )

    data class TestResult(
        val promptIndex: Int,
        val promptLabel: String,
        val rawResponse: String,
        val extractedAme: String,
        val parseSuccess: Boolean,
        val structureValid: Boolean,
        val refsConsistent: Boolean,
        val actionsValid: Boolean,
        val parserErrors: List<String>,
        val parserWarnings: List<String>,
        val notes: String
    )

    // ── Main Test Entry Point ───────────────────────────────────────────

    @Test
    fun runLlmReliabilityBenchmark() {
        val geminiKey = System.getenv("GEMINI_API_KEY")?.takeIf { it.isNotBlank() }
        val claudeKey = System.getenv("ANTHROPIC_API_KEY")?.takeIf { it.isNotBlank() }

        if (geminiKey == null && claudeKey == null) {
            println("SKIP: No API keys set. Set GEMINI_API_KEY and/or ANTHROPIC_API_KEY.")
            return
        }

        var geminiResults: List<TestResult>? = null
        var claudeResults: List<TestResult>? = null

        if (geminiKey != null) {
            println("\n${"=".repeat(60)}")
            println("GEMINI $GEMINI_MODEL RESULTS")
            println("=".repeat(60))
            geminiResults = runAllPrompts("gemini", geminiKey)
            printResultsTable(geminiResults)
            printFailedResponses(geminiResults, "Gemini")
        } else {
            println("SKIP: GEMINI_API_KEY not set.")
        }

        if (claudeKey != null) {
            println("\n${"=".repeat(60)}")
            println("CLAUDE $CLAUDE_MODEL RESULTS")
            println("=".repeat(60))
            claudeResults = runAllPrompts("claude", claudeKey)
            printResultsTable(claudeResults)
            printFailedResponses(claudeResults, "Claude")
        } else {
            println("SKIP: ANTHROPIC_API_KEY not set.")
        }

        if (geminiResults != null && claudeResults != null) {
            printSummaryTable(geminiResults, claudeResults)
        }

        println("\n  Raw API responses logged to: ${logDir.absolutePath}")
    }

    private fun runAllPrompts(model: String, apiKey: String): List<TestResult> {
        val results = mutableListOf<TestResult>()
        for (i in testPrompts.indices) {
            val prompt = testPrompts[i]
            val label = promptLabels[i]
            println("  [${i + 1}/${testPrompts.size}] $label ...")

            val rawResponse = try {
                when (model) {
                    "gemini" -> callGemini(apiKey, prompt, i + 1)
                    "claude" -> callClaude(apiKey, prompt, i + 1)
                    else -> error("Unknown model: $model")
                }
            } catch (e: Exception) {
                results.add(
                    TestResult(
                        promptIndex = i + 1,
                        promptLabel = label,
                        rawResponse = "API ERROR: ${e.message}",
                        extractedAme = "",
                        parseSuccess = false,
                        structureValid = false,
                        refsConsistent = false,
                        actionsValid = false,
                        parserErrors = emptyList(),
                        parserWarnings = emptyList(),
                        notes = "API error: ${e.message?.take(80)}"
                    )
                )
                if (i < testPrompts.size - 1) Thread.sleep(2000)
                continue
            }

            val extractedAme = extractAme(rawResponse)
            val result = scoreResponse(i + 1, label, rawResponse, extractedAme)
            results.add(result)

            if (i < testPrompts.size - 1) Thread.sleep(2000)
        }
        return results
    }

    // ── Gemini API ──────────────────────────────────────────────────────

    private fun callGemini(apiKey: String, prompt: String, promptIndex: Int): String {
        val url = "https://generativelanguage.googleapis.com/v1beta/models/$GEMINI_MODEL:generateContent?key=$apiKey"

        val requestBody = buildJsonObject {
            putJsonObject("system_instruction") {
                putJsonArray("parts") {
                    addJsonObject { put("text", systemPrompt) }
                }
            }
            putJsonArray("contents") {
                addJsonObject {
                    put("role", "user")
                    putJsonArray("parts") {
                        addJsonObject { put("text", "$prompt\n\nRespond with AME notation only. No explanations.") }
                    }
                }
            }
            putJsonObject("generationConfig") {
                put("temperature", 0.7)
                put("maxOutputTokens", MAX_OUTPUT_TOKENS)
                putJsonObject("thinkingConfig") {
                    put("includeThoughts", true)
                    if (GEMINI_MODEL.startsWith("gemini-3")) {
                        put("thinkingLevel", "minimal")
                    } else {
                        put("thinkingBudget", 0)
                    }
                }
            }
        }.toString()

        return executeHttpRequest(
            url = url,
            method = "POST",
            body = requestBody,
            headers = mapOf("Content-Type" to "application/json")
        ) { responseBody ->
            logRawResponse("gemini", promptIndex, prompt, responseBody)
            extractGeminiText(responseBody)
        }
    }

    /**
     * Extracts the actual answer text from a Gemini API response, filtering
     * out thought summary parts (thought == true). For thinking models like
     * gemini-3-flash-preview, the response may contain multiple parts:
     * thought summaries and the actual answer. We only want the answer.
     */
    private fun extractGeminiText(responseBody: String): String {
        val jsonResponse = json.parseToJsonElement(responseBody).jsonObject
        val parts = jsonResponse["candidates"]
            ?.jsonArray?.getOrNull(0)
            ?.jsonObject?.get("content")
            ?.jsonObject?.get("parts")
            ?.jsonArray
            ?: throw RuntimeException("Unexpected Gemini response structure: ${responseBody.take(200)}")

        val answerParts = parts.filter { part ->
            val isThought = part.jsonObject["thought"]?.jsonPrimitive?.booleanOrNull == true
            !isThought
        }.mapNotNull { it.jsonObject["text"]?.jsonPrimitive?.content }

        if (answerParts.isNotEmpty()) {
            return answerParts.joinToString("\n")
        }

        return parts.firstOrNull()
            ?.jsonObject?.get("text")
            ?.jsonPrimitive?.content
            ?: throw RuntimeException("No text parts in Gemini response: ${responseBody.take(200)}")
    }

    // ── Claude API ──────────────────────────────────────────────────────

    private fun callClaude(apiKey: String, prompt: String, promptIndex: Int): String {
        val url = "https://api.anthropic.com/v1/messages"

        val requestBody = buildJsonObject {
            put("model", CLAUDE_MODEL)
            put("max_tokens", MAX_OUTPUT_TOKENS)
            put("system", systemPrompt)
            putJsonArray("messages") {
                addJsonObject {
                    put("role", "user")
                    put("content", "$prompt\n\nRespond with AME notation only. No explanations.")
                }
            }
        }.toString()

        return executeHttpRequest(
            url = url,
            method = "POST",
            body = requestBody,
            headers = mapOf(
                "Content-Type" to "application/json",
                "x-api-key" to apiKey,
                "anthropic-version" to "2023-06-01"
            )
        ) { responseBody ->
            logRawResponse("claude", promptIndex, prompt, responseBody)
            val jsonResponse = json.parseToJsonElement(responseBody).jsonObject
            jsonResponse["content"]
                ?.jsonArray?.get(0)
                ?.jsonObject?.get("text")
                ?.jsonPrimitive?.content
                ?: throw RuntimeException("Unexpected Claude response structure: ${responseBody.take(200)}")
        }
    }

    // ── Raw Response Logging ────────────────────────────────────────────

    private fun logRawResponse(model: String, promptIndex: Int, prompt: String, responseBody: String) {
        try {
            val file = File(logDir, "${model}_${String.format("%02d", promptIndex)}.json")
            file.writeText(responseBody)
        } catch (e: Exception) {
            println("    WARNING: Failed to log response for $model prompt $promptIndex: ${e.message}")
        }
    }

    // ── HTTP Execution with Retry ───────────────────────────────────────

    private fun executeHttpRequest(
        url: String,
        method: String,
        body: String,
        headers: Map<String, String>,
        extractResponse: (String) -> String
    ): String {
        var lastException: Exception? = null
        for (attempt in 1..2) {
            try {
                val requestBuilder = HttpRequest.newBuilder()
                    .uri(URI.create(url))
                    .timeout(Duration.ofSeconds(60))
                    .method(method, HttpRequest.BodyPublishers.ofString(body))

                headers.forEach { (key, value) ->
                    requestBuilder.header(key, value)
                }

                val response = httpClient.send(
                    requestBuilder.build(),
                    HttpResponse.BodyHandlers.ofString()
                )

                if (response.statusCode() == 429 || response.statusCode() >= 500) {
                    if (attempt == 1) {
                        println("    Retrying after ${response.statusCode()} (attempt $attempt)...")
                        Thread.sleep(5000)
                        continue
                    }
                    throw RuntimeException("HTTP ${response.statusCode()}: ${response.body().take(200)}")
                }

                if (response.statusCode() !in 200..299) {
                    throw RuntimeException("HTTP ${response.statusCode()}: ${response.body().take(300)}")
                }

                return extractResponse(response.body())
            } catch (e: Exception) {
                lastException = e
                if (attempt == 1 && (e.message?.contains("429") == true || e.message?.contains("500") == true)) {
                    Thread.sleep(5000)
                    continue
                }
                throw e
            }
        }
        throw lastException ?: RuntimeException("Request failed after retries")
    }

    // ── AME Extraction ──────────────────────────────────────────────────

    /**
     * Extracts AME notation from an LLM response that may contain markdown
     * fences, conversational text, or raw AME.
     */
    private fun extractAme(response: String): String {
        // Strategy 1: Look for fenced code blocks (```ame or ```)
        val fencePattern = Regex("```(?:ame)?\\s*\\n(.*?)\\n```", RegexOption.DOT_MATCHES_ALL)
        val fenceMatch = fencePattern.find(response)
        if (fenceMatch != null) {
            return stripInlineBackticks(fenceMatch.groupValues[1].trim())
        }

        // Strategy 2: Find first line starting with "root = " and take from there
        val lines = response.lines().map { stripInlineBackticks(it) }
        val rootIndex = lines.indexOfFirst { it.trimStart().startsWith("root") && it.contains("=") }
        if (rootIndex >= 0) {
            val ameLines = mutableListOf<String>()
            for (i in rootIndex until lines.size) {
                val line = lines[i]
                if (line.isBlank() && ameLines.isNotEmpty() && i > rootIndex) {
                    val nextNonBlank = lines.drop(i + 1).firstOrNull { it.isNotBlank() }
                    if (nextNonBlank == null || (!nextNonBlank.contains("=") && !nextNonBlank.trimStart().startsWith("//"))) {
                        break
                    }
                }
                if (line.trimStart().startsWith("```")) continue
                ameLines.add(line)
            }
            return ameLines.joinToString("\n").trim()
        }

        // Strategy 3: Return entire response and let parser handle it
        return stripInlineBackticks(response.trim())
    }

    /**
     * Strips inline markdown backticks that some models wrap around individual
     * AME lines (e.g., `` `root = card(...)` `` instead of `root = card(...)`).
     */
    private fun stripInlineBackticks(text: String): String {
        return text.lines().joinToString("\n") { line ->
            val trimmed = line.trim()
            if (trimmed.startsWith("`") && trimmed.endsWith("`") && !trimmed.startsWith("```")) {
                trimmed.removeSurrounding("`")
            } else {
                line
            }
        }
    }

    // ── Scoring ─────────────────────────────────────────────────────────

    private fun scoreResponse(
        index: Int,
        label: String,
        rawResponse: String,
        extractedAme: String
    ): TestResult {
        val parser = AmeParser()
        val rootNode = parser.parse(extractedAme)

        val parseSuccess = rootNode != null
        val structureValid = parser.getRegistry().containsKey("root")
        val refsConsistent = if (rootNode != null) !hasUnresolvedRefs(rootNode) else false
        val actionsValid = if (rootNode != null) validateActions(rootNode) else false

        val notes = buildList {
            if (!parseSuccess && parser.errors.isNotEmpty()) {
                add("Parse errors: ${parser.errors.first().take(60)}")
            }
            if (parseSuccess && !refsConsistent) {
                add("Unresolved refs found")
            }
            if (parseSuccess && !actionsValid) {
                add("Invalid or missing actions on btn nodes")
            }
            if (parser.warnings.isNotEmpty()) {
                add("Warnings: ${parser.warnings.size}")
            }
        }

        return TestResult(
            promptIndex = index,
            promptLabel = label,
            rawResponse = rawResponse,
            extractedAme = extractedAme,
            parseSuccess = parseSuccess,
            structureValid = structureValid,
            refsConsistent = refsConsistent,
            actionsValid = actionsValid,
            parserErrors = parser.errors,
            parserWarnings = parser.warnings,
            notes = notes.joinToString("; ")
        )
    }

    // ── Tree Walkers ────────────────────────────────────────────────────

    private fun hasUnresolvedRefs(node: AmeNode): Boolean = when (node) {
        is AmeNode.Ref -> true
        is AmeNode.Col -> node.children.any { hasUnresolvedRefs(it) }
        is AmeNode.Row -> node.children.any { hasUnresolvedRefs(it) }
        is AmeNode.Card -> node.children.any { hasUnresolvedRefs(it) }
        is AmeNode.DataList -> node.children.any { hasUnresolvedRefs(it) }
        is AmeNode.Accordion -> node.children.any { hasUnresolvedRefs(it) }
        is AmeNode.Carousel -> node.children.any { hasUnresolvedRefs(it) }
        is AmeNode.Timeline -> node.children.any { hasUnresolvedRefs(it) }
        else -> false
    }

    /**
     * Validates that all Btn nodes have well-formed actions with required fields.
     * Returns true if the tree has NO btn nodes or ALL btn nodes have valid actions.
     */
    private fun validateActions(node: AmeNode): Boolean = when (node) {
        is AmeNode.Btn -> validateSingleAction(node.action)
        is AmeNode.Col -> node.children.all { validateActions(it) }
        is AmeNode.Row -> node.children.all { validateActions(it) }
        is AmeNode.Card -> node.children.all { validateActions(it) }
        is AmeNode.DataList -> node.children.all { validateActions(it) }
        is AmeNode.Accordion -> node.children.all { validateActions(it) }
        is AmeNode.Carousel -> node.children.all { validateActions(it) }
        is AmeNode.Timeline -> node.children.all { validateActions(it) }
        else -> true
    }

    private fun validateSingleAction(action: AmeAction): Boolean = when (action) {
        is AmeAction.CallTool -> action.name.isNotBlank()
        is AmeAction.OpenUri -> action.uri.isNotBlank()
        is AmeAction.Navigate -> action.route.isNotBlank()
        is AmeAction.CopyText -> action.text.isNotBlank()
        is AmeAction.Submit -> action.toolName.isNotBlank()
    }

    // ── Output Formatting ───────────────────────────────────────────────

    private fun printResultsTable(results: List<TestResult>) {
        println()
        println("| # | Prompt | Parse | Structure | Refs | Actions | Notes |")
        println("|---|--------|-------|-----------|------|---------|-------|")
        for (r in results) {
            val parse = if (r.parseSuccess) "PASS" else "FAIL"
            val structure = if (r.structureValid) "PASS" else "FAIL"
            val refs = if (r.refsConsistent) "PASS" else "FAIL"
            val actions = if (r.actionsValid) "PASS" else "FAIL"
            val notes = r.notes.take(50)
            println("| ${r.promptIndex} | ${r.promptLabel} | $parse | $structure | $refs | $actions | $notes |")
        }
        println()

        val parseCount = results.count { it.parseSuccess }
        val structureCount = results.count { it.structureValid }
        val refsCount = results.count { it.refsConsistent }
        val actionsCount = results.count { it.actionsValid }
        val fullValidity = results.count { it.parseSuccess && it.structureValid && it.refsConsistent && it.actionsValid }
        val total = results.size

        println("Parse success: $parseCount/$total (${parseCount * 100 / total}%)")
        println("Structure valid: $structureCount/$total")
        println("Refs consistent: $refsCount/$total")
        println("Actions valid: $actionsCount/$total")
        println("Full validity (all 4): $fullValidity/$total (${fullValidity * 100 / total}%)")
    }

    private fun printFailedResponses(results: List<TestResult>, modelName: String) {
        val parseFailures = results.filter { !it.parseSuccess }
        val refFailures = results.filter { it.parseSuccess && !it.refsConsistent }

        if (parseFailures.isEmpty()) {
            println("\nNo parse failures for $modelName.")
        } else {
            println("\n--- PARSE FAILURES ($modelName) ---")
            for (f in parseFailures) {
                println("\n### Prompt ${f.promptIndex}: ${f.promptLabel}")
                println("Parser errors: ${f.parserErrors}")
                println("Extracted AME:")
                println("```")
                println(f.extractedAme.take(500))
                println("```")
                println("Raw response (first 500 chars):")
                println(f.rawResponse.take(500))
            }
        }

        if (refFailures.isNotEmpty()) {
            println("\n--- REF FAILURES ($modelName) ---")
            for (f in refFailures) {
                println("\n### Prompt ${f.promptIndex}: ${f.promptLabel}")
                println("Extracted AME (first 400 chars):")
                println(f.extractedAme.take(400))
            }
        }
    }

    private fun printSummaryTable(geminiResults: List<TestResult>, claudeResults: List<TestResult>) {
        println("\n${"=".repeat(60)}")
        println("SUMMARY")
        println("=".repeat(60))
        println()
        println("| Metric | Gemini | Claude |")
        println("|--------|--------|--------|")

        fun stat(label: String, gCount: Int, cCount: Int, total: Int) {
            println("| $label | $gCount/$total (${gCount * 100 / total}%) | $cCount/$total (${cCount * 100 / total}%) |")
        }

        val gTotal = geminiResults.size
        val cTotal = claudeResults.size
        stat("Parse success", geminiResults.count { it.parseSuccess }, claudeResults.count { it.parseSuccess }, gTotal)
        stat("Structure valid", geminiResults.count { it.structureValid }, claudeResults.count { it.structureValid }, gTotal)
        stat("Refs consistent", geminiResults.count { it.refsConsistent }, claudeResults.count { it.refsConsistent }, gTotal)
        stat("Actions valid", geminiResults.count { it.actionsValid }, claudeResults.count { it.actionsValid }, gTotal)

        val gFull = geminiResults.count { it.parseSuccess && it.structureValid && it.refsConsistent && it.actionsValid }
        val cFull = claudeResults.count { it.parseSuccess && it.structureValid && it.refsConsistent && it.actionsValid }
        stat("Full validity", gFull, cFull, gTotal)

        val gParse = geminiResults.count { it.parseSuccess }
        val cParse = claudeResults.count { it.parseSuccess }
        val gPct = gParse * 100 / gTotal
        val cPct = cParse * 100 / cTotal

        fun fullCount(results: List<TestResult>): Int =
            results.count { it.parseSuccess && it.structureValid && it.refsConsistent && it.actionsValid }

        val gV10Full = fullCount(geminiResults.take(20))
        val cV10Full = fullCount(claudeResults.take(20))
        val gV11Full = fullCount(geminiResults.drop(20))
        val cV11Full = fullCount(claudeResults.drop(20))

        println()
        println("v1.0 vs v1.1 Breakdown:")
        println("  v1.0 prompts (1-20):  Gemini $gV10Full/20, Claude $cV10Full/20")
        println("  v1.1 prompts (21-32): Gemini $gV11Full/12, Claude $cV11Full/12")

        val v10Regression = gV10Full < 20 || cV10Full < 20
        if (v10Regression) {
            println("  WARNING: v1.0 prompt regression detected! Was 20/20 in GATE 2.")
        }

        val gate3 = when {
            gPct >= 95 && cPct >= 95 -> "PASS"
            gPct >= 85 && cPct >= 85 -> "CONDITIONAL"
            else -> "FAIL"
        }

        println()
        println("GATE 3 Result: $gate3")
        println("  Gemini ($GEMINI_MODEL): $gParse/$gTotal ($gPct%) parse success, $gFull/$gTotal full validity")
        println("  Claude ($CLAUDE_MODEL): $cParse/$cTotal ($cPct%) parse success, $cFull/$cTotal full validity")
    }

    companion object {
        private const val GEMINI_MODEL = "gemini-3-flash-preview"
        private const val CLAUDE_MODEL = "claude-sonnet-4-6"
        private const val MAX_OUTPUT_TOKENS = 4096
    }
}
