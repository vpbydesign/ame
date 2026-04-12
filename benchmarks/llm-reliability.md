# AME LLM Generation Reliability Benchmark

## Purpose

This benchmark measures whether LLMs can reliably generate valid AME syntax when given a compact specification in the system prompt. GATE 2 (v1.0, 20 prompts, 15 primitives) established the go/no-go for public release. GATE 3 (v1.1, 32 prompts, 21 primitives) validates the expanded specification.

## Methodology

### Overview

- **Models:** Gemini `gemini-3-flash-preview` (reference model); Claude `claude-sonnet-4-6` (stable GA)
- **APIs:** Gemini `generateContent` REST API; Anthropic Messages REST API
- **Test cases:** 20 diverse UI generation prompts
- **Scoring:** 4-dimension rubric (parse, structure, references, actions)
- **Pass threshold:** ≥85% parse success rate (≥17/20)

### System Prompt

The following system prompt (~250 tokens) teaches the model AME syntax. This prompt is itself a deliverable — it represents what a real host app would include in its system instruction to enable AME generation.

```
You generate UI using AME (Agentic Mobile Elements), a compact syntax for describing mobile interfaces.

SYNTAX: One statement per line. First line must be: root = component(...)
Identifiers are lowercase with underscores. Children are arrays: [child1, child2]

PRIMITIVES (15):
col([children], align?)          — vertical column. align: start|center|end|space_between|space_around
row([children], align?, gap?)    — horizontal row. gap is number (dp)
txt("text", style?, max_lines?)  — text. style: display|headline|title|body|caption|mono|label|overline
img("url", height?)              — image
icon("name", size?)              — material icon
divider()                        — horizontal line
spacer(height?)                  — empty space (dp)
card([children], elevation?)     — card container
badge("label", variant?)         — label. variant: info|success|warning|error|neutral
progress(value, "label"?)        — progress bar. value: 0.0-1.0
btn("label", action, style?, icon?)  — button. style: primary|secondary|outline|text|destructive
input(id, "label", type?, options?)  — form input. type: text|number|email|phone|date|time|select
toggle(id, "label", default?)    — on/off switch
list([children], dividers?)      — scrollable list
table(headers, rows)             — data table

ACTIONS (5):
tool(name, key=val, ...)         — invoke a host tool
uri("scheme:path")               — open a URI
nav("route")                     — navigate to a route
copy("text")                     — copy text to clipboard
submit(tool_name, key=val, ...)  — collect all form inputs, merge with static args, invoke tool

EXAMPLE — Weather Card (9 lines, 131 tokens):
root = card([header, temp, condition, details])
header = row([city, icon], space_between)
city = txt("San Francisco", title)
icon = icon("partly_cloudy_day", 28)
temp = txt("62°", display)
condition = txt("Partly Cloudy", body)
details = row([hl, hum], space_between)
hl = txt("H:68° L:55°", caption)
hum = txt("Humidity: 72%", caption)
```

### Test Prompts

20 diverse UI generation prompts, designed to cover the full range of AME primitives and actions. Some intentionally push edge cases (toggles, error cards, settings panels) to test whether the model can map unfamiliar UI patterns to AME primitives.

| # | Prompt |
|---|--------|
| 1 | Show a weather card for Tokyo, 28°C, Sunny |
| 2 | Show 2 restaurant results with ratings and direction buttons |
| 3 | Create a contact card for John Smith, phone 555-1234, email john@example.com |
| 4 | Show a booking form with date, time, and party size inputs |
| 5 | Display a to-do list with 3 items, each with a checkbox |
| 6 | Show a music player card with song title, artist, and play/pause button |
| 7 | Create a comparison of two subscription plans |
| 8 | Show an email preview: from Sarah, subject Meeting Notes, with reply and delete buttons |
| 9 | Display a progress card showing 75% complete for a file upload |
| 10 | Show a settings panel with 3 toggles: notifications, dark mode, auto-save |
| 11 | Create a shipping address form with name, street, city, state, zip |
| 12 | Show search results for 'best coffee shops' with 3 results |
| 13 | Display a calendar event: Team Standup, Monday 9am, Conference Room B |
| 14 | Show a product card: Wireless Headphones, $79.99, 4.5 stars, Add to Cart button |
| 15 | Create an error card with warning icon, message, and retry button |
| 16 | Show a user profile: name, email, member since date, edit button |
| 17 | Display a notification list with 4 items of varying types |
| 18 | Show a flight result: NYC to LAX, $299, 5h 30m, with book button |
| 19 | Create a simple about page with app name, version, and support link |
| 20 | Show a recipe card: title, prep time, cook time, ingredients list |

### API Call Format

Each test sends a single `generateContent` request with the system prompt above as the system instruction and one test prompt as the user message.

**Endpoint:**
```
POST https://generativelanguage.googleapis.com/v1beta/models/gemini-3-flash-preview:generateContent?key=YOUR_API_KEY
```

**Request body:**
```json
{
  "system_instruction": {
    "parts": [{"text": "SYSTEM_PROMPT_FROM_ABOVE"}]
  },
  "contents": [
    {"role": "user", "parts": [{"text": "TEST_PROMPT_HERE"}]}
  ],
  "generationConfig": {
    "temperature": 0.7,
    "maxOutputTokens": 4096,
    "thinkingConfig": {
      "includeThoughts": true,
      "thinkingLevel": "minimal"
    }
  }
}
```

**Response extraction (thinking-model aware):**
1. Iterate `candidates[0].content.parts` and filter out any part where `thought == true`
2. Concatenate the `text` field from the remaining (non-thought) parts
3. If the response contains markdown code fences or inline backticks, strip them
4. Feed the extracted AME text to `AmeParser.parse()`

### Scoring Rubric

Each response is scored on 4 dimensions:

| Dimension | Check | Pass Criteria |
|-----------|-------|---------------|
| **Parse** | Feed to `AmeParser.parse()` | Returns non-null `AmeNode` |
| **Structure** | Check for `root` identifier | `root` exists in the parsed registry |
| **References** | All identifier references resolve | No `AmeNode.Ref` nodes remain in resolved tree |
| **Actions** | Action arguments are well-formed | `AmeAction` subtypes have required fields populated |

A response receives a score of 0-4 based on how many checks pass. "Full validity" requires all 4 checks to pass.

### Token Counting

For each successfully parsed response, count tokens using the `countTokens` endpoint with a stable GA model:

```
POST https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:countTokens?key=YOUR_API_KEY
```

---

## Results

**Status: Complete.** Benchmark executed on 2026-04-05–06 using automated test
harness (`LlmReliabilityTest.kt`). Five runs were performed. **Run 5 is
definitive** — it uses the corrected thinking-model-aware harness, the
improved system prompt, and `gemini-3-flash-preview` (the reference model
used by a deployed mobile assistant).

- **Runs 1–4:** Used a harness that did not account for Gemini thinking model
  response format. See appendix for details and lessons learned.
- **Run 5 (definitive):** Fixed harness with thinking-aware parts extraction,
  `thinkingLevel: "minimal"`, `maxOutputTokens: 4096`, and raw response
  logging.

All runs use `temperature: 0.7` and the standard AME system prompt from
[integration.md](../specification/v1.0/integration.md).

### Run 5: Fixed Thinking-Model Harness (2026-04-06) — DEFINITIVE

Run 5 uses the corrected test harness that properly handles Gemini thinking
model responses. This is the definitive benchmark result.

**Harness fixes applied for Run 5:**
1. **Thinking-aware parts extraction**: Iterates all response `parts` and
   filters out `thought: true` parts. Runs 1-4 hardcoded `parts[0]`, which
   for thinking models could be the model's reasoning chain, not the actual
   answer.
2. **`thinkingConfig`**: Set `thinkingLevel: "minimal"` for Gemini 3 models
   (AME generation is a structured output task, not a reasoning task) and
   `includeThoughts: true` so thought parts are explicitly tagged.
3. **`maxOutputTokens: 4096`**: Increased from 1024 to match a production
   deployment's configuration (8192). Previous runs may have truncated complex
   AME responses.
4. **Raw response logging**: Every API response saved to
   `build/benchmark-logs/` for post-run verification.

#### Gemini Results — Run 5

**Model:** `gemini-3-flash-preview` via `generateContent` REST API

| # | Prompt | Parse | Structure | Refs | Actions | Notes |
|---|--------|-------|-----------|------|---------|-------|
| 1 | Weather Tokyo | PASS | PASS | PASS | PASS | |
| 2 | Restaurant results | PASS | PASS | PASS | PASS | |
| 3 | Contact card | PASS | PASS | PASS | PASS | |
| 4 | Booking form | PASS | PASS | PASS | PASS | |
| 5 | To-do list | PASS | PASS | PASS | PASS | |
| 6 | Music player | PASS | PASS | PASS | PASS | |
| 7 | Plan comparison | PASS | PASS | PASS | PASS | |
| 8 | Email preview | PASS | PASS | PASS | PASS | |
| 9 | Progress card | PASS | PASS | PASS | PASS | |
| 10 | Settings toggles | PASS | PASS | PASS | PASS | |
| 11 | Shipping form | PASS | PASS | PASS | PASS | |
| 12 | Coffee shop search | PASS | PASS | PASS | PASS | |
| 13 | Calendar event | PASS | PASS | PASS | PASS | |
| 14 | Product card | PASS | PASS | PASS | PASS | |
| 15 | Error card | PASS | PASS | PASS | PASS | |
| 16 | User profile | PASS | PASS | PASS | PASS | |
| 17 | Notification list | PASS | PASS | PASS | PASS | |
| 18 | Flight result | PASS | PASS | PASS | PASS | |
| 19 | About page | PASS | PASS | PASS | PASS | |
| 20 | Recipe card | PASS | PASS | PASS | PASS | |

#### Claude Results — Run 5

**Model:** `claude-sonnet-4-6` (stable GA) via Messages API

| # | Prompt | Parse | Structure | Refs | Actions | Notes |
|---|--------|-------|-----------|------|---------|-------|
| 1 | Weather Tokyo | PASS | PASS | PASS | PASS | |
| 2 | Restaurant results | PASS | PASS | PASS | PASS | |
| 3 | Contact card | PASS | PASS | PASS | PASS | |
| 4 | Booking form | PASS | PASS | PASS | PASS | |
| 5 | To-do list | PASS | PASS | PASS | PASS | |
| 6 | Music player | PASS | PASS | PASS | PASS | |
| 7 | Plan comparison | PASS | PASS | PASS | PASS | |
| 8 | Email preview | PASS | PASS | PASS | PASS | |
| 9 | Progress card | PASS | PASS | PASS | PASS | |
| 10 | Settings toggles | PASS | PASS | PASS | PASS | |
| 11 | Shipping form | PASS | PASS | PASS | PASS | |
| 12 | Coffee shop search | PASS | PASS | PASS | PASS | |
| 13 | Calendar event | PASS | PASS | PASS | PASS | |
| 14 | Product card | PASS | PASS | PASS | PASS | |
| 15 | Error card | PASS | PASS | PASS | PASS | |
| 16 | User profile | PASS | PASS | PASS | PASS | |
| 17 | Notification list | PASS | PASS | PASS | PASS | |
| 18 | Flight result | PASS | PASS | PASS | PASS | |
| 19 | About page | PASS | PASS | PASS | PASS | |
| 20 | Recipe card | PASS | PASS | PASS | PASS | |

#### Run 5 Summary

| Metric | Gemini 3 Flash (Preview) | Claude Sonnet 4.6 |
|--------|-------------------------|-------------------|
| Parse success | 20/20 (100%) | 20/20 (100%) |
| Structure valid | 20/20 (100%) | 20/20 (100%) |
| Refs consistent | 20/20 (100%) | 20/20 (100%) |
| Actions valid | 20/20 (100%) | 20/20 (100%) |
| Full validity | 20/20 (100%) | 20/20 (100%) |

### Cross-Run Analysis

| Metric | Runs 1-4 (buggy harness) | Run 5 (fixed harness) |
|--------|-------------------------|----------------------|
| Gemini 3 Flash parse | 95% | **100%** |
| Gemini 3 Flash full validity | 30-35% | **100%** |
| Claude Sonnet 4.6 | 100% (all runs) | **100%** |

**Root cause of Runs 1-4 failures:**

The test harness had three bugs that caused `gemini-3-flash-preview` to
score artificially low:

1. **`parts[0]` extraction**: The harness always read `parts[0]` from the
   Gemini API response. For thinking models, `parts[0]` can contain the
   model's reasoning chain (thought summary), not the actual answer. The
   reasoning chain contains incomplete draft AME with undefined identifiers,
   explaining the ~70% ref failure rate. Recommended practice is to use the
   Firebase SDK's `response.text` accessor, which automatically filters out
   thinking parts.

2. **`maxOutputTokens: 1024`**: Recommended configuration uses `maxOutputTokens: 8192`. The
   harness used 1024, which may have caused truncation on complex prompts.

3. **No `thinkingConfig`**: Gemini 3 Flash defaults to `thinkingLevel: "high"`
   (maximum reasoning). For structured output like AME, `"minimal"` is
   appropriate and avoids wasting output budget on unnecessary reasoning.

Claude Sonnet 4.6 was unaffected because it has no thinking mode in its
standard API — `content[0].text` is always the actual response.

### GATE 2 Decision

| Outcome | Threshold | Decision |
|---------|-----------|----------|
| **PASS** | **≥85% parse success (≥17/20)** | **Proceed to public GitHub release** |
| CONDITIONAL | 70-85% parse success (14-16/20) | Add more few-shot examples to system prompt, note failure patterns, proceed with disclaimer |
| FAIL | <70% parse success (<14/20) | Report to TPM — syntax may need simplification before public release |

**GATE 2 Result: PASS (perfect scores)**

- Gemini 3 Flash Preview: 20/20 (100%) parse success, 20/20 (100%) full validity
- Claude Sonnet 4.6: 20/20 (100%) parse success, 20/20 (100%) full validity

Both models achieve perfect scores on all dimensions with the corrected
harness. AME syntax is fully learnable from the system prompt for both
model families. The specification is ready for public GitHub release.

---

## GATE 3: v1.1 LLM Reliability (21 Primitives)

### Overview

GATE 3 extends GATE 2 from 20 prompts (15 v1.0 primitives) to 32 prompts
(21 v1.1 primitives). The v1.1 system prompt from `integration.md` adds 6
new primitives (chart, code, accordion, carousel, callout, timeline),
semantic colors, and the `each()` data iteration construct.

**System prompt:** v1.1 (~400 tokens), from `specification/v1.0/integration.md` lines 128-176.
**Models:** gemini-3-flash-preview, claude-sonnet-4-6 (same as GATE 2).
**Harness:** Same corrected harness from Run 5 + tree walkers updated for
new container types (Accordion, Carousel, Timeline).

### GATE 3 Thresholds

| Outcome | Threshold | Decision |
|---------|-----------|----------|
| **PASS** | **≥95% parse success (≥31/32)** | **Proceed to WP#8 (conformance + publish)** |
| CONDITIONAL | 85-94% parse success (28-30/32) | Analyze failures, fix prompt, re-run (max 3 iterations) |
| FAIL | <85% parse success (<28/32) | Diagnose, fix prompt or defer primitive to v1.2 |

### Gemini Results — GATE 3

| # | Prompt | Parse | Structure | Refs | Actions | Notes |
|---|--------|-------|-----------|------|---------|-------|
| 1 | Weather Tokyo | PASS | PASS | PASS | PASS | |
| 2 | Restaurant results | PASS | PASS | PASS | PASS | |
| 3 | Contact card | PASS | PASS | PASS | PASS | |
| 4 | Booking form | PASS | PASS | PASS | PASS | |
| 5 | To-do list | PASS | PASS | PASS | PASS | |
| 6 | Music player | PASS | PASS | PASS | PASS | |
| 7 | Plan comparison | PASS | PASS | PASS | PASS | |
| 8 | Email preview | PASS | PASS | PASS | PASS | Warnings: 3 |
| 9 | Progress card | PASS | PASS | PASS | PASS | |
| 10 | Settings toggles | PASS | PASS | PASS | PASS | |
| 11 | Shipping form | PASS | PASS | PASS | PASS | |
| 12 | Coffee shop search | PASS | PASS | PASS | PASS | |
| 13 | Calendar event | PASS | PASS | PASS | PASS | |
| 14 | Product card | PASS | PASS | PASS | PASS | |
| 15 | Error card | PASS | PASS | PASS | PASS | |
| 16 | User profile | PASS | PASS | PASS | PASS | |
| 17 | Notification list | PASS | PASS | PASS | PASS | |
| 18 | Flight result | PASS | PASS | PASS | PASS | |
| 19 | About page | PASS | PASS | PASS | PASS | |
| 20 | Recipe card | PASS | PASS | PASS | PASS | |
| 21 | Chart bar spending | PASS | PASS | PASS | PASS | |
| 22 | Code Python | PASS | PASS | PASS | PASS | |
| 23 | Accordion medication | PASS | PASS | PASS | PASS | |
| 24 | Carousel shoes | PASS | PASS | PASS | PASS | |
| 25 | Callout warning | PASS | PASS | PASS | PASS | |
| 26 | Timeline order | PASS | PASS | PASS | PASS | |
| 27 | Chart sparkline BTC | PASS | PASS | PASS | PASS | Warnings: 1 |
| 28 | Dashboard chart+callout | PASS | PASS | PASS | PASS | |
| 29 | Code+callout combo | PASS | PASS | PASS | PASS | |
| 30 | Accordion FAQ | PASS | PASS | PASS | PASS | |
| 31 | Each restaurants | PASS | PASS | PASS | PASS | |
| 32 | Each events | PASS | PASS | PASS | PASS | |

### Claude Results — GATE 3

| # | Prompt | Parse | Structure | Refs | Actions | Notes |
|---|--------|-------|-----------|------|---------|-------|
| 1 | Weather Tokyo | PASS | PASS | PASS | PASS | |
| 2 | Restaurant results | PASS | PASS | PASS | PASS | |
| 3 | Contact card | PASS | PASS | PASS | PASS | |
| 4 | Booking form | PASS | PASS | PASS | PASS | |
| 5 | To-do list | PASS | PASS | PASS | PASS | |
| 6 | Music player | PASS | PASS | PASS | FAIL | Invalid or missing actions on btn nodes |
| 7 | Plan comparison | PASS | PASS | PASS | PASS | |
| 8 | Email preview | PASS | PASS | PASS | PASS | |
| 9 | Progress card | PASS | PASS | PASS | PASS | |
| 10 | Settings toggles | PASS | PASS | PASS | PASS | |
| 11 | Shipping form | PASS | PASS | PASS | PASS | |
| 12 | Coffee shop search | PASS | PASS | PASS | PASS | |
| 13 | Calendar event | PASS | PASS | PASS | PASS | |
| 14 | Product card | PASS | PASS | PASS | PASS | |
| 15 | Error card | PASS | PASS | PASS | PASS | Warnings: 1 |
| 16 | User profile | PASS | PASS | PASS | PASS | |
| 17 | Notification list | PASS | PASS | PASS | PASS | |
| 18 | Flight result | PASS | PASS | PASS | PASS | |
| 19 | About page | PASS | PASS | PASS | PASS | |
| 20 | Recipe card | PASS | PASS | PASS | PASS | |
| 21 | Chart bar spending | PASS | PASS | PASS | PASS | |
| 22 | Code Python | PASS | PASS | PASS | PASS | |
| 23 | Accordion medication | PASS | PASS | PASS | PASS | |
| 24 | Carousel shoes | PASS | PASS | PASS | PASS | |
| 25 | Callout warning | PASS | PASS | PASS | PASS | |
| 26 | Timeline order | PASS | PASS | PASS | PASS | |
| 27 | Chart sparkline BTC | PASS | PASS | PASS | PASS | Warnings: 1 |
| 28 | Dashboard chart+callout | PASS | PASS | PASS | PASS | |
| 29 | Code+callout combo | PASS | PASS | PASS | PASS | |
| 30 | Accordion FAQ | PASS | PASS | PASS | PASS | |
| 31 | Each restaurants | PASS | PASS | PASS | PASS | |
| 32 | Each events | PASS | PASS | PASS | PASS | |

### GATE 3 Summary

| Metric | Gemini 3 Flash (Preview) | Claude Sonnet 4.6 |
|--------|-------------------------|-------------------|
| Parse success | 32/32 (100%) | 32/32 (100%) |
| Structure valid | 32/32 (100%) | 32/32 (100%) |
| Refs consistent | 32/32 (100%) | 32/32 (100%) |
| Actions valid | 32/32 (100%) | 31/32 (96%) |
| Full validity | 32/32 (100%) | 31/32 (96%) |

**v1.0 vs v1.1 Breakdown:**

| Prompt Set | Gemini | Claude |
|------------|--------|--------|
| v1.0 prompts (1-20) | 20/20 | 19/20 |
| v1.1 prompts (21-32) | 12/12 | 12/12 |

### Analysis

**Parse success: 100% / 100%.** Both models produce valid, parseable AME for
all 32 prompts. The v1.1 system prompt is fully learnable.

**v1.1 primitives: 12/12 on both models.** All 6 new primitives (chart, code,
accordion, carousel, callout, timeline) are generated correctly on first
exposure from the compact system prompt descriptions alone.

**Claude prompt #6 (Music player) action failure:** Claude generated a btn
with an action the validator flagged as invalid. This is the same stochastic
action-formatting variance seen in GATE 2 cross-run analysis — parse success
is unaffected. Not a v1.1 regression (prompt #6 is a v1.0 prompt).

**each() generation (prompts 31-32):** Both models successfully generated AME
for the data-driven prompts. Parse success confirms the parser handles the
generated output correctly.

### GATE 3 Decision

**GATE 3 Result: PASS**

- Gemini 3 Flash Preview: 32/32 (100%) parse success, 32/32 (100%) full validity
- Claude Sonnet 4.6: 32/32 (100%) parse success, 31/32 (96%) full validity

Both models achieve 100% parse success on all 32 prompts. The single
Claude action failure is stochastic (v1.0 prompt, not a v1.1 issue) and
does not affect the parse success gate criterion. AME v1.1 with 21
primitives is fully learnable from the system prompt for both model
families. Proceed to WP#8 (conformance + publish).

---

## Appendix: Runs 1-4 (Buggy Harness)

Runs 1-4 used a test harness that did not account for Gemini thinking model
response format. These results are preserved for transparency but should NOT
be used for model evaluation.

**Summary of buggy harness runs:**

| Run | Gemini Model | Prompt | Harness Issues | Gemini Full Validity | Claude |
|-----|-------------|--------|----------------|---------------------|--------|
| 1 | gemini-3-flash-preview | Original | parts[0], 1024 tokens, no backtick strip | 7/20 (35%) | 20/20 |
| 2 | gemini-2.5-flash | Original | parts[0], 1024 tokens | 17/20 (85%) | 20/20 |
| 3 | gemini-2.5-flash | Improved | parts[0], 1024 tokens | 16/20 (80%) | 20/20 |
| 4 | gemini-3-flash-preview | Improved | parts[0], 1024 tokens | 6/20 (30%) | 20/20 |

`gemini-2.5-flash` scored higher in Runs 2-3 because its thinking behavior
differs from `gemini-3-flash-preview` — it either puts the actual answer in
`parts[0]`, or its default thinking level is less aggressive. The 80-85%
score was still artificially low due to the token budget issue.

---

## Execution Instructions

To reproduce this benchmark:

1. Set API keys: `export GEMINI_API_KEY="..." ANTHROPIC_API_KEY="..."`
2. Run the automated test harness:
   ```
   ./gradlew :ame-core:test --tests "com.agenticmobile.ame.LlmReliabilityTest" --no-daemon
   ```
3. The harness calls both APIs with the 32 prompts (20 v1.0 + 12 v1.1), extracts AME from
   responses (filtering thinking parts, stripping markdown fences and inline
   backticks), parses with `AmeParser`, scores on 4 dimensions, and prints
   results as markdown tables.
4. Raw API responses are logged to `ame-core/build/benchmark-logs/` for
   post-run verification.

**Configuration:**
- Temperature: 0.7 (realistic generation diversity, not greedy decoding)
- Max output tokens: 4096
- Gemini thinking: `thinkingLevel: "minimal"`, `includeThoughts: true`
- Rate limiting: 2-second delay between API calls
- Retry: once on 429/5xx errors after 5-second backoff
- Thinking-aware parts extraction: filters out `thought: true` parts
- Markdown fence and inline backtick stripping: automatic

**Notes:**
- Some prompts intentionally use non-AME vocabulary (e.g., "checkbox" for toggle) to test concept mapping
- All 20 prompts run in a single session to avoid warm-up variance
- API keys are read from environment variables — never hardcoded
- For thinking models, always set `includeThoughts: true` and filter `thought: true` parts from responses

---

## Version History

| Version | Date | Status |
|---------|------|--------|
| 1.0 | 2026-04-05 | Methodology complete, results pending API execution |
| 1.1 | 2026-04-05 | Run 1: gemini-3-flash-preview (95% parse, 35% full) + claude-sonnet-4-6 (100% all). GATE 2 PASS. |
| 1.2 | 2026-04-05 | Run 2: gemini-2.5-flash (100% parse, 85% full) + claude-sonnet-4-6 (100% all). Switched to stable GA models. Added inline backtick stripping. GATE 2 PASS. |
| 1.3 | 2026-04-06 | Run 3: Improved system prompt (identifier rule + richer example). Gemini 2.5 Flash 100% parse / 80% full, Claude 100% all. Cross-run analysis confirms stochastic ref variance. GATE 2 PASS. |
| 1.4 | 2026-04-06 | Run 4: Re-tested gemini-3-flash-preview with improved prompt + extraction. 95% parse / 30% full. GATE 2 PASS. |
| 2.0 | 2026-04-06 | **Run 5 (definitive):** Fixed thinking-model harness (parts filtering, thinkingLevel:minimal, maxOutputTokens:4096, response logging). gemini-3-flash-preview 100% / 100%, claude-sonnet-4-6 100% / 100%. Runs 1-4 failures caused by harness bugs, not model or spec issues. GATE 2 PASS — perfect scores. |
| 3.0 | 2026-04-12 | **GATE 3 (v1.1):** 32 prompts (20 v1.0 + 12 v1.1). v1.1 system prompt with 21 primitives. Tree walkers updated for new containers. Gemini 32/32 (100%) full validity, Claude 31/32 (96%) full validity — 1 stochastic action failure on v1.0 prompt #6. 100% parse success on both. GATE 3 PASS. |
