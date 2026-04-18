# AME Tier Zero Specification — v1.0

## Introduction

Tier 0 is AME's zero-token UI rendering mode. When a tool executes and returns
structured data, the host app generates an `AmeNode` tree locally, without
any LLM involvement in UI decisions. The LLM calls a tool, the tool returns
data, the app builds UI from that data, and the renderer displays it. Zero
extra tokens are consumed for UI generation.

This is AME's primary differentiator from every other generative UI
specification. A2UI, OpenUI Lang, and MCP Apps all require the agent to
generate UI descriptions for every interaction. AME Tier 0 eliminates the
agent from the rendering path entirely for the most common case: displaying
structured tool results.

This document defines the Tier 0 concept, the Tier 1 layout hint mechanism,
the three-tier rendering model, the shape matching pattern, and provides
generic examples that illustrate how host apps can implement Tier 0 and Tier 1
rendering. For the primitives that builders produce, see
[primitives.md](primitives.md). For actions attached to rendered UI, see
[actions.md](actions.md). For how host apps declare AME support to agents, see
[integration.md](integration.md).

### Notation Conventions

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD",
"SHOULD NOT", "RECOMMENDED", "MAY", and "OPTIONAL" in this document are to be
interpreted as described in [RFC 2119](https://www.ietf.org/rfc/rfc2119.txt).

---

## The Three Tiers of AME Rendering

AME supports three tiers of UI generation, ranging from zero LLM involvement
to full LLM-generated layouts. The tiers are not mutually exclusive; a single
conversation may use all three depending on context.

| Tier | How UI Is Created | Token Cost | Latency Impact | Use Case |
|------|-------------------|-----------|----------------|----------|
| **Tier 0** | Host app builds `AmeNode` tree from tool result data | **0** (zero) | None — no LLM round-trip for UI | Tool results with known data shapes (analyzed across 50 tools in a deployed mobile assistant with 3M+ users — 65-75% of user-facing tool interactions, rising to ~85% including confirmation cards) |
| **Tier 1** | LLM provides a layout hint keyword alongside tool result | 1 token | Negligible | When the default Tier 0 template is not the best fit (e.g., "comparison" instead of list) |
| **Tier 2** | LLM generates a complete AME document in compact notation | 50–200 tokens | Proportional to document length | Truly custom layouts, dashboards, novel visualizations |

**Tier 0** is the primary focus of this document and is fully specified below
in the [Shape Matching](#shape-matching) and
[Generic Shape Examples](#generic-shape-examples) sections.

**Tier 1** is specified in the [Tier 1: Layout Hints](#tier-1-layout-hints)
section below. It extends Tier 0 by letting the LLM influence which template
the shape matcher selects, at a cost of 1 token.

**Tier 2** is the full AME syntax documented in [syntax.md](syntax.md),
[primitives.md](primitives.md), [actions.md](actions.md),
[streaming.md](streaming.md), and [data-binding.md](data-binding.md).

### Why Three Tiers Matter

The three-tier model means AME has a graceful cost curve. Most interactions
(tool result displays) cost zero tokens. Rare customizations cost 1–5 tokens.
Only truly novel UIs require full generation at 50–200 tokens. Compare this
to protocols where every interaction costs 200–500 tokens for UI generation
regardless of complexity.

At scale, the impact is significant. Consider an app with 1 million daily
active users, averaging 10 interactions per day, where the majority of
interactions involve tool calls with structured data:

- Tier 0 interactions cost zero tokens for UI.
- Tier 1 interactions cost ~1 token each for the layout hint.
- Tier 2 interactions cost ~50–200 tokens each for the full AME document.

The exact proportion handled by each tier depends on the host app's tool
suite and shape matcher coverage. Apps with comprehensive tool coverage and
shape matchers for common data types (places, events, contacts, media) will
see higher Tier 0 rates. Apps with more open-ended, conversational
interactions will see more Tier 2 usage.

In an analysis of a deployed mobile assistant with 50 tools, 24
tools return structured data suitable for Tier 0 shape matching. The 7
highest-frequency tools (places, events, contacts, conversations, search
results, notes, books) are responsible for an estimated 65-75% of user-facing
tool interactions, all of which render as zero-token rich cards. Including
simple confirmation cards (event created, email sent, note added), the
coverage rises to approximately 85%.

For comparison, protocols that require full UI generation for every
interaction typically consume 200–500 tokens per interaction regardless of
data shape. AME's tiered model ensures that the most common interactions
(structured tool results) consume zero UI tokens, with generation costs
reserved for the uncommon cases that genuinely need custom layouts.

---

## Tier 1: Layout Hints

Tier 1 extends Tier 0 by allowing the LLM to influence which template the
shape matcher selects, without generating any AME syntax. The mechanism is
a single keyword string, called a **layout hint**, that accompanies the tool
result. The host app's shape matcher reads the hint and selects an alternate
builder function for the same data shape.

### How Layout Hints Work

In Tier 0, the shape matcher inspects the tool result data and always produces
the same `AmeNode` tree for a given data shape. For example, place results
always render as a vertical list of cards. In Tier 1, the shape matcher also
receives a layout hint keyword and MAY select a different template based on it.

The flow is:

1. The LLM calls a tool and receives structured data (same as Tier 0).
2. Alongside the tool result, the LLM provides a layout hint — a single
   keyword string such as `"comparison"`, `"map"`, `"compact"`, or
   `"timeline"`.
3. The host app's shape matcher receives both the data and the hint.
4. If the hint matches a known layout variant for this data shape, the
   matcher selects the corresponding builder. If the hint is not recognized,
   the matcher falls back to the default Tier 0 template.
5. The selected builder produces an `AmeNode` tree. The renderer renders it
   identically to any other `AmeNode` tree.

### Layout Hint Delivery

How the layout hint is delivered from the LLM to the shape matcher depends
on the host app's integration layer (see
[integration.md](integration.md)). Common patterns include:

**In a JSON tool response:**
```json
{
  "tool_result": {"places": [...]},
  "ame_layout": "comparison"
}
```

**In an LLM text response alongside a tool call:**
```
I found 3 restaurants. Let me show you a comparison.
[tool_call: search_places, layout: comparison]
```

**As metadata on an MCP tool result:**
```json
{"_meta": {"ame_layout": "comparison"}}
```

The AME spec defines the CONCEPT of layout hints and the shape matcher
behavior. It does NOT prescribe a specific delivery mechanism. That is
determined by the integration layer.

### Shape Matcher with Layout Hint Support

A shape matcher supporting Tier 1 receives an optional `layout` parameter:

```kotlin
fun matchShape(
    data: JsonObject,
    layout: String? = null
): AmeNode? {
    return when {
        data.containsKey("places") -> when (layout) {
            "comparison" -> buildPlaceComparison(data)
            "map" -> buildPlaceMap(data)
            "compact" -> buildPlaceCompact(data)
            else -> buildPlaceList(data)  // default Tier 0 template
        }
        data.containsKey("events") -> when (layout) {
            "timeline" -> buildEventTimeline(data)
            "agenda" -> buildEventAgenda(data)
            else -> buildEventList(data)  // default Tier 0 template
        }
        // ... other data shapes
        else -> null
    }
}
```

The `layout` parameter is OPTIONAL. When null, the matcher behaves exactly
as Tier 0, selecting the default template. This means Tier 1 is a strict
superset of Tier 0: any Tier 0 shape matcher becomes a Tier 1 shape matcher
by adding a `layout` parameter with default `null`.

### Layout Hint Vocabulary

Layout hint values are **app-defined**. The AME specification does NOT
prescribe a fixed set of hint values. Each host app defines which hints its
shape matchers recognize based on the templates it has built.

The following are RECOMMENDED hint patterns for common use cases. Host apps
are free to use these, define their own, or ignore hints entirely.

| Hint | Meaning | Example |
|------|---------|---------|
| `"comparison"` | Side-by-side layout for comparing items | Two restaurant cards in a row |
| `"map"` | Map-centric layout with location pins | Map view with place markers |
| `"compact"` | Minimal, space-efficient layout | Single-line items without cards |
| `"detailed"` | Expanded layout with additional fields | Cards with descriptions, hours, reviews |
| `"timeline"` | Chronological vertical layout | Events arranged by time |
| `"grid"` | Grid layout for visual items | Image thumbnails in columns |

### Unrecognized Hints

If a shape matcher receives a layout hint it does not recognize, it MUST
fall back to the default Tier 0 template. It SHOULD log a warning indicating
the unrecognized hint value. It MUST NOT return null (failing to render) solely
because of an unrecognized hint. The data is still valid and the default
template still applies.

### Token Cost

A layout hint is a single keyword string. In most tokenizers, this costs
exactly **1 token**. This is the cost difference between Tier 0 (0 tokens for
UI) and Tier 1 (1 token for UI). The tool call itself costs the same in both
tiers; only the hint keyword is additional.

### When to Use Tier 1 vs Tier 2

Tier 1 is appropriate when:
- The data shape is known (a shape matcher exists)
- The desired layout is a predictable variant (comparison, map, compact)
- The host app has pre-built templates for the variant

Tier 2 (full AME generation) is appropriate when:
- No shape matcher exists for the data
- The layout is truly novel (not a variant of a known template)
- The LLM needs to compose UI from multiple data sources

If a host app has invested in comprehensive Tier 0 templates with Tier 1
variants, most interactions will be Tier 0 or Tier 1, and Tier 2 generation
will be rare.

---

## Shape Matching

Shape matching is the pattern that enables Tier 0 rendering. The host app
inspects the structured data returned by a tool call and dispatches to a
builder function that produces an appropriate `AmeNode` tree.

### The Pattern

1. **Tool execution** — the LLM calls a tool (e.g., a search API, calendar
   lookup, or contact query). The tool executes and returns structured data
   as a JSON object.

2. **Shape inspection** — the host app examines the data's top-level keys to
   determine its "shape." For example, does the data contain a `places` key
   with an array of objects? A `contacts` key? An `events` key?

3. **Builder dispatch** — if the shape matches a known pattern, the app calls
   a builder function that constructs an `AmeNode` tree from the data. Each
   builder is a pure function: data in, `AmeNode` tree out.

4. **Rendering** — the `AmeNode` tree is passed to `AmeRenderer` — the same
   renderer used for Tier 2 (LLM-generated) documents. The renderer does not
   know or care whether the tree came from a shape matcher or from the AME
   parser. Both paths produce identical `AmeNode` trees.

5. **Fallback** — if no shape is recognized, the host app falls back to plain
   text rendering of the tool's text output. The user still sees useful
   information; it simply lacks rich card formatting.

### Implementation Approach

Shape matching is **app-specific code**; it is not part of the AME library.
Each host app defines its own shape matchers based on the tools it supports.
The implementation is typically a simple `when` / `if-else` chain that checks
for known data keys:

```kotlin
fun buildTierZeroUi(toolName: String, data: JsonObject): AmeNode? {
    return when {
        data.containsKey("places") -> buildPlaceCards(data)
        data.containsKey("contacts") -> buildContactCards(data)
        data.containsKey("events") -> buildEventCards(data)
        data.containsKey("items") && data["items"]?.jsonArray
            ?.firstOrNull()?.jsonObject?.containsKey("artist") == true
            -> buildMediaCards(data)
        data.containsKey("results") -> buildSearchResults(data)
        else -> null
    }
}
```

This is intentionally simple. No complex pattern matching frameworks, no
schema validation, no reflection. A developer reading the shape matcher
immediately understands what data shapes are supported and what UI each
produces.

---

## Generic Shape Examples

The following examples illustrate the Tier 0 pattern for five common data
shapes. Each example shows the input data shape (as a JSON object), the AME
node tree the builder produces (in AME syntax from [syntax.md](syntax.md)),
and a brief description of the rendered result.

These examples are **generic and app-agnostic**. They do not reference
specific tool names, API endpoints, or app features. A host app implementing
Tier 0 SHOULD use these as starting points and customize the layouts to match
its own design language.

### Shape 1: Place / Business Results

Data returned by a location search or business directory tool.

**Input data shape:**

```json
{
  "places": [
    {
      "name": "Luigi's",
      "rating": "★4.5",
      "address": "119 Mulberry St, New York",
      "lat": 40.72,
      "lng": -73.99
    },
    {
      "name": "Joe's Pizza",
      "rating": "★4.3",
      "address": "375 Canal St, New York",
      "lat": 40.72,
      "lng": -74.00
    }
  ]
}
```

**AME node tree produced by the builder:**

```
root = col([header, results])
header = txt("Places", headline)
results = list([p1, p2])
p1 = card([p1_top, p1_addr, p1_btns])
p1_top = row([p1_name, p1_rating], space_between)
p1_name = txt("Luigi's", title)
p1_rating = badge("★4.5", info)
p1_addr = txt("119 Mulberry St, New York", caption)
p1_btns = row([p1_sched, p1_dir], 8)
p1_sched = btn("Schedule", tool(create_event, title="Visit Luigi's", location="119 Mulberry St, New York"), primary)
p1_dir = btn("Directions", uri("geo:40.72,-73.99?q=Luigi's"), text)
p2 = card([p2_top, p2_addr, p2_btns])
p2_top = row([p2_name, p2_rating], space_between)
p2_name = txt("Joe's Pizza", title)
p2_rating = badge("★4.3", info)
p2_addr = txt("375 Canal St, New York", caption)
p2_btns = row([p2_sched, p2_dir], 8)
p2_sched = btn("Schedule", tool(create_event, title="Visit Joe's Pizza", location="375 Canal St, New York"), primary)
p2_dir = btn("Directions", uri("geo:40.72,-74.00?q=Joe's Pizza"), text)
```

**Rendered result:** A list of cards, each showing the business name (title
style), star rating (badge), street address (caption), and two action buttons.
"Schedule" dispatches a tool call to create a calendar event; "Directions"
opens a map URI.

**Token cost:** Zero. The LLM called a search tool. The app built this UI
from the tool result data. No AME syntax was generated by the LLM.

---

### Shape 2: Media Library

Data returned by a music, podcast, or audiobook library tool.

**Input data shape:**

```json
{
  "items": [
    {
      "title": "Morning Jazz",
      "artist": "Blue Note Trio",
      "progress": 0.72
    },
    {
      "title": "Deep Focus",
      "artist": "Ambient Works",
      "progress": 0.0
    },
    {
      "title": "Running Mix",
      "artist": "Workout Radio",
      "progress": 1.0
    }
  ]
}
```

**AME node tree produced by the builder:**

```
root = col([lib_header, lib_list])
lib_header = txt("Your Library", headline)
lib_list = list([m1, m2, m3])
m1 = card([m1_info, m1_prog, m1_btns])
m1_info = col([m1_title, m1_artist])
m1_title = txt("Morning Jazz", title)
m1_artist = txt("Blue Note Trio", caption)
m1_prog = progress(0.72, "72%")
m1_btns = row([m1_play], 8)
m1_play = btn("Continue", tool(play_media, track="Morning Jazz"), primary)
m2 = card([m2_info, m2_btns])
m2_info = col([m2_title, m2_artist])
m2_title = txt("Deep Focus", title)
m2_artist = txt("Ambient Works", caption)
m2_btns = row([m2_play], 8)
m2_play = btn("Play", tool(play_media, track="Deep Focus"), primary)
m3 = card([m3_info, m3_prog, m3_btns])
m3_info = col([m3_title, m3_artist])
m3_title = txt("Running Mix", title)
m3_artist = txt("Workout Radio", caption)
m3_prog = progress(1.0, "Complete")
m3_btns = row([m3_replay], 8)
m3_replay = btn("Replay", tool(play_media, track="Running Mix"), outline)
```

**Rendered result:** A list of media cards. Each shows title (title style),
artist (caption), an optional progress bar (shown when progress is between
0 exclusive and 1 inclusive), and a play/continue/replay button. The builder
adapts button label and style based on progress: 0 → "Play" (primary),
0 < progress < 1 → "Continue" (primary) with progress bar,
progress = 1.0 → "Replay" (outline) with completed progress bar.

**Token cost:** Zero.

---

### Shape 3: Calendar Events

Data returned by a calendar or scheduling tool.

**Input data shape:**

```json
{
  "events": [
    {
      "title": "Team Standup",
      "date": "2026-04-07",
      "time": "09:00",
      "location": "Conference Room B"
    },
    {
      "title": "Lunch with Sarah",
      "date": "2026-04-07",
      "time": "12:30",
      "location": null
    },
    {
      "title": "Design Review",
      "date": "2026-04-07",
      "time": "15:00",
      "location": "Zoom"
    }
  ]
}
```

**AME node tree produced by the builder:**

```
root = col([cal_header, cal_list])
cal_header = txt("April 7, 2026", headline)
cal_list = list([ev1, ev2, ev3])
ev1 = card([ev1_top, ev1_time, ev1_loc])
ev1_top = row([ev1_icon, ev1_title], 8)
ev1_icon = icon("event", 20)
ev1_title = txt("Team Standup", title)
ev1_time = txt("09:00", caption)
ev1_loc = txt("Conference Room B", caption)
ev2 = card([ev2_top, ev2_time])
ev2_top = row([ev2_icon, ev2_title], 8)
ev2_icon = icon("event", 20)
ev2_title = txt("Lunch with Sarah", title)
ev2_time = txt("12:30", caption)
ev3 = card([ev3_top, ev3_time, ev3_loc])
ev3_top = row([ev3_icon, ev3_title], 8)
ev3_icon = icon("event", 20)
ev3_title = txt("Design Review", title)
ev3_time = txt("15:00", caption)
ev3_loc = txt("Zoom", caption)
```

**Rendered result:** A list of event cards. Each shows a calendar icon, event
title, time, and optional location (omitted when null). The builder
conditionally includes the location line only when the value is non-null.

**Token cost:** Zero.

---

### Shape 4: Contact List

Data returned by a contacts search or address book tool.

**Input data shape:**

```json
{
  "contacts": [
    {
      "name": "Sarah Chen",
      "phone": "+1-555-0101",
      "email": "sarah@example.com"
    },
    {
      "name": "Alex Rivera",
      "phone": "+1-555-0202",
      "email": "alex@example.com"
    }
  ]
}
```

**AME node tree produced by the builder:**

```
root = col([ct_header, ct_list])
ct_header = txt("Contacts", headline)
ct_list = list([c1, c2])
c1 = card([c1_name, c1_details, c1_btns])
c1_name = txt("Sarah Chen", title)
c1_details = col([c1_phone, c1_email])
c1_phone = txt("+1-555-0101", caption)
c1_email = txt("sarah@example.com", caption)
c1_btns = row([c1_call, c1_msg, c1_mail], 8)
c1_call = btn("Call", uri("tel:+15550101"), primary)
c1_msg = btn("Message", uri("sms:+15550101"), outline)
c1_mail = btn("Email", uri("mailto:sarah@example.com"), text)
c2 = card([c2_name, c2_details, c2_btns])
c2_name = txt("Alex Rivera", title)
c2_details = col([c2_phone, c2_email])
c2_phone = txt("+1-555-0202", caption)
c2_email = txt("alex@example.com", caption)
c2_btns = row([c2_call, c2_msg, c2_mail], 8)
c2_call = btn("Call", uri("tel:+15550202"), primary)
c2_msg = btn("Message", uri("sms:+15550202"), outline)
c2_mail = btn("Email", uri("mailto:alex@example.com"), text)
```

**Rendered result:** A list of contact cards. Each shows the contact name
(title), phone number and email (captions), and three action buttons. "Call"
opens the phone dialer via `tel:` URI; "Message" opens SMS via `sms:` URI;
"Email" opens the mail client via `mailto:` URI. All actions use `uri()`, so
they invoke standard platform handlers without any tool calls.

**Token cost:** Zero.

---

### Shape 5: Search Results

Data returned by a web search or knowledge base query tool.

**Input data shape:**

```json
{
  "results": [
    {
      "title": "AME Specification — GitHub",
      "snippet": "Agentic Mobile Elements: a token-efficient, streaming-first generative UI specification for mobile agents.",
      "url": "https://github.com/example/ame-spec"
    },
    {
      "title": "Generative UI for Mobile — Blog Post",
      "snippet": "How AME reduces token consumption by 99% compared to traditional generative UI protocols.",
      "url": "https://example.com/blog/generative-ui"
    },
    {
      "title": "A2UI vs AME Token Comparison",
      "snippet": "Benchmark results showing AME's compact syntax uses significantly fewer tokens than A2UI JSON.",
      "url": "https://example.com/benchmarks"
    }
  ]
}
```

**AME node tree produced by the builder:**

```
root = col([sr_header, sr_list])
sr_header = txt("Search Results", headline)
sr_list = list([r1, r2, r3])
r1 = card([r1_title, r1_snippet, r1_btns])
r1_title = txt("AME Specification — GitHub", title)
r1_snippet = txt("Agentic Mobile Elements: a token-efficient, streaming-first generative UI specification for mobile agents.", caption, max_lines=2)
r1_btns = row([r1_open], 8)
r1_open = btn("Open", uri("https://github.com/example/ame-spec"), primary)
r2 = card([r2_title, r2_snippet, r2_btns])
r2_title = txt("Generative UI for Mobile — Blog Post", title)
r2_snippet = txt("How AME reduces token consumption by 99% compared to traditional generative UI protocols.", caption, max_lines=2)
r2_btns = row([r2_open], 8)
r2_open = btn("Open", uri("https://example.com/blog/generative-ui"), primary)
r3 = card([r3_title, r3_snippet, r3_btns])
r3_title = txt("A2UI vs AME Token Comparison", title)
r3_snippet = txt("Benchmark results showing AME's compact syntax uses significantly fewer tokens than A2UI JSON.", caption, max_lines=2)
r3_btns = row([r3_open], 8)
r3_open = btn("Open", uri("https://example.com/benchmarks"), primary)
```

**Rendered result:** A list of search result cards. Each shows the result
title (title style), a snippet preview truncated to 2 lines (caption with
`max_lines=2`), and an "Open" button that navigates to the URL via `uri()`.

**Token cost:** Zero.

---

## Why Tier 0 Is Unique

No other generative UI specification has an equivalent to Tier 0. Every
existing protocol requires the agent to generate a UI description for every
interaction:

| Protocol | UI Generation Requirement | Token Cost Per Interaction |
|----------|--------------------------|---------------------------|
| **A2UI** | Agent generates `updateComponents` JSON message with full component tree | 200–500 tokens |
| **OpenUI Lang** | LLM generates OpenUI syntax with component calls | 100–300 tokens |
| **MCP Apps** | Server generates and serves HTML for every UI | N/A (server-side cost, but adds latency) |
| **AME Tier 0** | Host app builds `AmeNode` from tool result data locally | **0 tokens** |

The fundamental insight is that most tool results have predictable data shapes.
A restaurant search always returns places with names, ratings, and addresses.
A calendar query always returns events with titles, dates, and times. A contact
lookup always returns names, phone numbers, and emails. For these predictable
shapes, generating UI descriptions from the LLM is wasteful, because the app
already knows what the UI should look like.

AME Tier 0 makes this insight explicit and systematic. Instead of paying the
LLM to describe UI that the app could build itself, the app builds it directly
from the data.

---

## Implementation Guidance

This section provides informative guidance for host app developers
implementing Tier 0 rendering. These are RECOMMENDED practices, not normative
requirements.

### Shape Matcher Architecture

The shape matcher is a function that takes tool result data and returns either
an `AmeNode` tree or null (no match → fallback to text). It is
RECOMMENDED to structure the matcher as a single dispatch point:

```kotlin
fun matchShape(data: JsonObject): AmeNode? = when {
    data.containsKey("places") -> PlaceShapeBuilder.build(data)
    data.containsKey("contacts") -> ContactShapeBuilder.build(data)
    data.containsKey("events") -> EventShapeBuilder.build(data)
    // ... add more shapes as needed ...
    else -> null
}
```

Each builder is a separate class or function that constructs an `AmeNode`
tree from the data. This keeps the matcher simple and each builder
self-contained.

### Builder Functions

Builder functions produce `AmeNode` trees using the same Kotlin sealed classes
that the AME parser produces. There is no separate data model for Tier 0; the
output is the same `AmeNode` sealed interface used by the parser and renderer.

```kotlin
object PlaceShapeBuilder {
    fun build(data: JsonObject): AmeNode {
        val places = data["places"]?.jsonArray ?: return AmeNode.Txt("No results")
        val cards = places.mapIndexed { i, place ->
            val obj = place.jsonObject
            val name = obj["name"]?.jsonPrimitive?.content ?: ""
            val rating = obj["rating"]?.jsonPrimitive?.content ?: ""
            val address = obj["address"]?.jsonPrimitive?.content ?: ""
            buildPlaceCard(i, name, rating, address)
        }
        return AmeNode.Col(children = listOf(
            AmeNode.Txt(text = "Places", style = TxtStyle.HEADLINE),
            AmeNode.List(children = cards)
        ))
    }
}
```

### Renderer Agnosticism

The `AmeRenderer` composable does not know whether the `AmeNode` tree it
receives came from Tier 0 (shape matcher), Tier 2 (AME parser), or any
other source. It renders all trees identically. This is by design: it means
Tier 0 and Tier 2 produce visually consistent results, and the renderer
never needs to be modified to support new shapes.

### Adding New Shapes

Adding a new Tier 0 shape requires:

1. Identify the data keys that characterize the new shape.
2. Write a builder function that maps the data to an `AmeNode` tree.
3. Add a case to the shape matcher's `when` block.

No changes to the AME library, parser, or renderer are needed. Tier 0 shapes
are purely host app code.

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-04-05 | Initial specification |
