# AME Streaming Specification — v1.0

## Introduction

AME is designed for progressive rendering — the ability to display partial UI
immediately as tokens stream from a Large Language Model, rather than waiting
for the complete document before rendering anything. On mobile devices, where
perceived performance directly affects user experience, progressive rendering
eliminates the "blank screen" delay that occurs when an LLM generates a full
UI description before any pixels appear. A well-implemented streaming renderer
shows the overall page structure within the first few hundred milliseconds of
generation, with content filling in progressively over the following seconds.

This document defines the streaming rendering model for AME documents. It
specifies how a conforming renderer handles forward references, displays
skeleton placeholders, and transitions to fully rendered UI as statements
arrive. For the syntax rules that enable streaming (line independence, forward
references, data separator), see [syntax.md](syntax.md). For data binding
behavior during streaming, see [data-binding.md](data-binding.md).

### Notation Conventions

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD",
"SHOULD NOT", "RECOMMENDED", "MAY", and "OPTIONAL" in this document are to be
interpreted as described in [RFC 2119](https://www.ietf.org/rfc/rfc2119.txt).

---

## Line Independence

Every line in an AME document is independently parseable. A conforming parser
MUST process each line as a self-contained unit, producing a complete parse
result (identifier + expression) without requiring knowledge of any other line
in the document.

This means:

- The parser MUST NOT buffer multiple lines before producing output.
- The parser MUST NOT perform look-ahead beyond the current line boundary.
- Each newline character (`\n`) terminates the current statement and the parser
  MUST emit its parse result immediately.
- The parser MAY begin processing a new line before the renderer has finished
  handling the previous line's result.

Line independence is the foundational property that enables streaming. Because
each line is self-contained, the renderer can begin displaying UI from the
very first line, updating incrementally as subsequent lines arrive.

---

## Forward References and Placeholders

A forward reference occurs when an identifier appears in a children array
before its defining statement has been parsed. This is the normal case during
streaming — a layout container references children that have not yet arrived.
See [syntax.md](syntax.md) Rule 14 for the syntax-level definition.

### Placeholder Rendering

When a renderer encounters an identifier in a children array that has no
corresponding definition yet, it MUST display a skeleton placeholder in that
child's position. The placeholder visually communicates that content is
expected but has not yet arrived.

A skeleton placeholder:

- MUST occupy the position in the parent layout where the resolved component
  will appear.
- SHOULD render as a shimmer rectangle — a rounded rectangle with a subtle
  animated gradient that sweeps horizontally, matching platform conventions
  (Material 3 shimmer on Android, equivalent on iOS).
- SHOULD use a default height of 48dp and full available width when the
  resolved component's dimensions are unknown.
- MUST NOT be interactive. Skeleton placeholders do not respond to taps.

### Resolution

When the defining statement for a forward-referenced identifier arrives, the
renderer MUST replace the skeleton placeholder with the actual rendered
component. This replacement MUST be immediate — the user sees the skeleton
transition to real content without an explicit refresh or rebuild step.

In Jetpack Compose, this is achieved by maintaining a registry of mutable
state per identifier:

```kotlin
val registry = remember { mutableStateMapOf<String, AmeNode?>() }

@Composable
fun ResolvedOrSkeleton(id: String, registry: Map<String, AmeNode?>) {
    val node = registry[id]
    if (node != null) {
        AmeRenderer(node, registry)
    } else {
        AmeSkeleton(id)
    }
}
```

When the parser processes a new statement (e.g., `header = txt("Title", headline)`),
it updates `registry["header"]` from `null` to the parsed `AmeNode.Txt` value.
Compose observes the state change and recomposes the slot, replacing the
skeleton with the rendered `Text` composable.

### Skeleton Shape Hints

A renderer MAY use contextual hints to choose more appropriate skeleton shapes.
For example, if the parent container is a `row`, child skeletons SHOULD be
narrower and side-by-side rather than full-width stacked blocks. These hints
are OPTIONAL optimizations — a conforming renderer MAY use uniform rectangular
skeletons for all unresolved references.

---

## Resolution Order

AME statements MAY arrive in any order. A conforming renderer MUST handle all
possible orderings correctly.

### Top-Down Order (RECOMMENDED)

Statements arrive from the root to the leaves:

```
root = col([header, body])        // root defined first
header = txt("Title", headline)   // then children
body = card([details])            // then deeper children
details = txt("Content", body)    // then leaves
```

This is the RECOMMENDED generation order because it maximizes progressive
rendering. The user sees the overall structure immediately (root layout with
skeleton children), then content fills in from top to bottom, matching the
natural reading order.

### Bottom-Up Order

Statements arrive from leaves to root:

```
details = txt("Content", body)    // leaf first
body = card([details])            // then parent
header = txt("Title", headline)   // another leaf
root = col([header, body])        // root last
```

This order is valid but suboptimal for user experience. No visual output
appears until the `root` statement arrives, at which point all children may
already be defined and the full UI renders at once. The user experiences a
longer blank period followed by an instant full render.

### Mixed Order

Statements arrive in arbitrary order:

```
root = col([header, body])        // root first
body = card([details])            // skip header, define body
details = txt("Content", body)    // leaf of body
header = txt("Title", headline)   // header arrives last
```

This is valid. The renderer shows skeletons for unresolved references and
replaces them as definitions arrive, regardless of order.

A conforming renderer MUST NOT assume any particular statement order. It MUST
correctly render the final UI regardless of the order in which statements are
received.

---

## Generation Order Recommendation

LLMs generating AME documents SHOULD emit statements in the following order
to maximize progressive rendering performance:

1. **Root statement** — the top-level layout container (`root = col(...)` or
   `root = card(...)`)
2. **Layout containers** — intermediate structural elements (`row`, `col`,
   `card`, `list`) that define the page skeleton
3. **Content elements** — leaf nodes that display data (`txt`, `badge`, `icon`,
   `img`, `progress`, `btn`)
4. **Data section** — the `---` separator followed by the JSON data model
   (if present)

This order ensures:

- The overall page structure appears as skeletons within the first few lines.
- Content fills in top-to-bottom, matching the user's visual scanning pattern.
- Data-bound values (`$path` references) resolve last, filling in concrete
  values after the structure and static content are visible.
- The user perceives continuous progress rather than a blank screen followed
  by an instant full render.

System prompts instructing the LLM to generate AME SHOULD include a directive
such as: "Generate AME statements top-down: root first, then layout containers,
then content leaves, then data."

---

## Worked Streaming Timeline

This section walks through the progressive rendering of Example 2 from
[syntax.md](syntax.md) — the Place Search Results document (27 lines). The
timeline assumes an LLM generating at 60 tokens per second. Each AME
statement is approximately 10–20 tokens, so lines arrive roughly every
170–330 milliseconds.

The full document:

```
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
```

### Timeline

**T=0.00s** — `root = col([header, results])`

The root column is created with two child slots. Both `header` and `results`
are forward references — neither has been defined yet. The user sees a column
containing two shimmer skeleton rectangles stacked vertically.

**T=0.17s** — `header = txt("Italian Restaurants Nearby", headline)`

The `header` skeleton is replaced by the rendered headline text. The user now
sees "Italian Restaurants Nearby" at the top, with a single large skeleton
block below it for the still-unresolved `results`.

**T=0.33s** — `results = list([p1, p2, p3])`

The `results` skeleton is replaced by a `list` container with three child
slots. `p1`, `p2`, and `p3` are all forward references. The user sees the
headline at the top and three card-shaped skeleton placeholders arranged
vertically below it — the page structure is now fully visible.

**T=0.50s** — `p1 = card([p1_top, p1_addr, p1_btns])`

The first skeleton in the list is replaced by a card containing three child
skeletons (for the top row, address, and buttons). The card has visible
elevation/border. The second and third list items remain as flat skeletons.

**T=0.67s** — `p1_top = row([p1_name, p1_rating], space_between)`

Inside the first card, the top skeleton is replaced by a row with two child
skeletons (name and rating), arranged with space between them.

**T=0.83s** — `p1_name = txt("Luigi's", title)`

The left skeleton in the first card's top row is replaced by the text
"Luigi's" in title style. The right skeleton (rating) remains.

**T=1.00s** — `p1_rating = badge("★4.5", info)`

The right skeleton in the first card's top row is replaced by an "★4.5" badge
with info styling. The first card's top row is now fully rendered.

**T=1.17s** — `p1_addr = txt("119 Mulberry St, New York", caption)`

The address skeleton in the first card is replaced by caption text. The first
card now shows: "Luigi's" + "★4.5" on the top row, "119 Mulberry St, New York"
below it, and a skeleton for the button row.

**T=1.33s** — `p1_btns = row([p1_sched, p1_dir], 8)`

The button row skeleton is replaced by a row with two button-shaped skeletons,
separated by 8dp gap.

**T=1.67s** — `p1_sched = btn(...)` and **T=1.83s** — `p1_dir = btn(...)`

The two button skeletons are replaced by "Schedule" (primary style) and
"Directions" (text style) buttons. **The first card is now fully rendered and
interactive** — the user can tap "Schedule" to invoke `tool(create_calendar_event)`
or "Directions" to open `uri("geo:...")`. Total time from first pixel to first
interactive card: ~1.8 seconds.

**T=2.00s–3.50s** — Cards 2 and 3 fill in

The same pattern repeats for `p2` and `p3`. Each card transitions from
skeleton to fully rendered in approximately 1.5 seconds. By T≈3.5s, all three
cards are fully rendered and the document is complete.

### Key Observation

The user sees meaningful content within 170ms (the headline) and an interactive
card within 1.8s, even though the full 27-line document takes ~3.5s to
generate. Without streaming, the user would see nothing for 3.5 seconds, then
the full UI would appear at once.

---

## Data Binding and Streaming Interaction

When an AME document uses data binding (`$path` references and the `---`
data separator), the streaming behavior has additional considerations. The
data section arrives after all component statements, meaning `$path`
references cannot resolve until the end of the stream.

### `$path` References Before Data Arrives

During streaming, a component with a `$path` reference (e.g.,
`name = txt($name, title)`) is parsed and rendered immediately. However,
because the data model (the JSON after `---`) has not yet arrived, the `$path`
reference cannot be resolved. The renderer MUST render the component with an
empty value:

- `txt($unresolved_path, ...)` → renders as an empty `Text` composable
  (zero-width or a subtle placeholder line)
- `badge($unresolved_path, ...)` → renders as a badge with empty label
- `img($unresolved_path, ...)` → renders as an image placeholder

When the `---` separator is encountered and the JSON data model is parsed,
the renderer MUST re-resolve all `$path` references against the data model
and update the rendered components. In Compose, this is achieved by storing
the data model in a `MutableState` — when it updates from `null` to the
parsed JSON object, all composables reading `$path` values recompose.

### `each()` Constructs Before Data Arrives

The `each($arrayPath, templateId)` construct (see
[data-binding.md](data-binding.md)) cannot instantiate templates until
`$arrayPath` resolves to a JSON array from the data model. During streaming,
before the data section arrives:

- The renderer MUST show a single list-shaped skeleton placeholder for the
  `each()` node. The placeholder SHOULD have a height of approximately 120dp
  — enough to suggest "a list of content is loading" without implying a
  specific item count.
- The renderer MUST NOT attempt to instantiate the template with empty data.
- When the data section arrives and `$arrayPath` resolves to an array, the
  renderer MUST replace the single skeleton with the full set of instantiated
  template components — one per array item.

### Worked Example: Data-Bound Document

The following short document uses `each()` and `$path` references with a
data section:

```
root = col([title, results])
title = txt("Nearby Places", headline)
results = each($places, place_tpl)
place_tpl = card([txt($name, title), txt($address, caption)])
---
{"places": [{"name": "Central Cafe", "address": "10 Main St"}, {"name": "Park Deli", "address": "25 Oak Ave"}]}
```

Streaming timeline:

**T=0.00s** — `root = col([title, results])`

Column with two skeleton placeholders.

**T=0.17s** — `title = txt("Nearby Places", headline)`

Headline renders. Below it, a skeleton placeholder for `results`.

**T=0.33s** — `results = each($places, place_tpl)`

The parser recognizes `each()` as a data-binding construct. `$places` cannot
resolve yet (no data section). The renderer replaces the `results` skeleton
with a single list-shaped skeleton placeholder (120dp height).

**T=0.50s** — `place_tpl = card([txt($name, title), txt($address, caption)])`

The template is registered but not instantiated. No visual change — the
list skeleton remains because `each()` is still waiting for data.

**T=0.67s** — `---`

The data separator is recognized. The parser switches to JSON parsing mode.

**T=0.83s** — `{"places": [...]}`

The JSON data model is parsed. `$places` resolves to a 2-element array. The
`each()` construct instantiates `place_tpl` twice — once per array item.
Inside each instance, `$name` and `$address` resolve relative to the current
array item. The list skeleton is replaced by two rendered cards:

- Card 1: "Central Cafe" (title) + "10 Main St" (caption)
- Card 2: "Park Deli" (title) + "25 Oak Ave" (caption)

The document is now fully rendered.

---

## Error Recovery During Streaming

AME is designed to be generated by LLMs, which may produce syntactically
imperfect output. A conforming renderer MUST handle errors gracefully without
interrupting the streaming process.

### Malformed Line

If a line fails to parse during streaming (e.g., missing `=` sign, unclosed
parenthesis, garbled content):

1. The parser MUST skip the malformed line entirely.
2. The parser MUST log an error containing the raw line content.
3. The parser MUST continue processing subsequent lines normally.
4. Any identifiers that were expected to be defined by the malformed line
   remain as skeleton placeholders.

A single malformed line MUST NOT invalidate the rest of the document.

### Permanently Unresolved References

After the stream ends (the LLM finishes generating), some forward references
may remain unresolved — either because the defining line was malformed and
skipped, or because the LLM omitted the definition entirely.

For permanently unresolved references, the renderer:

- MUST keep the skeleton placeholder visible (do not collapse or hide it).
- SHOULD transition the skeleton to an error state — for example, a
  red-tinted or gray-tinted placeholder with a subtle error indicator.
- SHOULD log a warning listing all unresolved identifiers.

### Invalid Data Section

If the JSON after `---` fails to parse:

1. The renderer MUST log an error with the raw JSON content.
2. All `$path` references MUST render as empty strings.
3. All `each()` constructs MUST render nothing (the list skeleton is removed
   and replaced with empty space).
4. The component structure (everything before `---`) remains rendered with
   its static content intact.

---

## Completion

An AME document is fully rendered when all forward references have been
resolved — every identifier used in a children array has a corresponding
defining statement, and all `$path` references have been resolved against the
data model.

A conforming renderer:

- MUST track the count of unresolved forward references.
- MAY fire a "rendering complete" callback or event when the unresolved
  count reaches zero. This callback allows the host app to perform
  post-render actions such as measuring layout, starting animations, or
  logging performance metrics.
- MUST consider `$path` references that resolved to empty strings (due to
  missing data keys) as resolved, not unresolved. The resolution succeeded;
  the value was simply empty.

### Completion with Data Binding

For documents with a `---` data section, completion occurs in two phases:

1. **Structural completion** — all forward references between component
   statements are resolved. This happens as component statements arrive.
2. **Data completion** — the data model is parsed and all `$path` references
   and `each()` constructs are resolved. This happens when the data section
   is fully received.

The document is fully rendered only after both phases are complete. A renderer
MAY provide separate callbacks for structural completion and data completion.

---

## Non-Streaming Mode

AME documents MAY be rendered without streaming — the entire document is
received as a single string and parsed at once. This is the simpler
implementation path for host apps that do not use streaming LLM APIs, or
for rendering cached/stored AME documents.

In non-streaming mode:

- All lines are parsed sequentially before any rendering occurs.
- Forward references are resolved immediately after all statements are
  parsed. By the time the renderer is invoked, every identifier has a
  definition (or is known to be missing).
- Skeleton placeholders are never shown. The user sees the fully rendered
  UI in a single frame.
- `$path` references are resolved immediately against the data model.
- `each()` constructs are instantiated immediately.
- The renderer MUST produce identical visual output regardless of whether
  the document was streamed or parsed at once. The only difference is that
  streaming shows intermediate states (skeletons); non-streaming shows the
  final state directly.

A conforming renderer MUST support non-streaming mode. Streaming mode support
is RECOMMENDED but OPTIONAL — a valid renderer that only supports non-streaming
mode is conforming, provided it produces correct final output.

---

## Differences from OpenUI Lang

AME's streaming rendering model is architecturally based on the same
principles as [OpenUI Lang's](https://www.openui.com/docs/openui-lang/specification)
"Streaming & Hoisting" model. Both specifications share the following
design:

- Line-oriented syntax where each line is independently parseable
- Forward references (identifiers used before they are defined)
- Skeleton/placeholder rendering for unresolved references
- Top-down generation order recommendation for optimal progressive rendering
- Immediate replacement of placeholders when definitions arrive

AME differs from OpenUI Lang's streaming model in the following ways:

| Aspect | AME | OpenUI Lang |
|--------|-----|-------------|
| Data separation | `---` separator divides structure from JSON data model. Data arrives last during streaming, causing a two-phase completion (structure, then data). | No data separation. All data is inline in component arguments. |
| Data binding during streaming | `$path` references render as empty values until the data section arrives, then fill in. Creates a visible "data fill" moment. | No equivalent. Data is always available inline. |
| Dynamic lists during streaming | `each()` shows a single list skeleton until data arrives, then expands to N instantiated templates. | No equivalent. Lists are explicit arrays of component references. |
| Skeleton placeholders | Shimmer rectangles with configurable shape hints. Specified as normative behavior. | Skeleton/placeholder rendering described but implementation details left to the app's Zod schema. |
| Platform target | Compose `MutableState` recomposition for skeleton-to-content transitions. | React state updates and component tree reconciliation. |
| Error recovery | Specified: skip malformed lines, error-state skeletons for permanently unresolved references. | Not specified in detail. |

The two-phase completion model (structure then data) is AME's most significant
streaming difference. It trades a brief "empty content" period for the
benefit of separating structure from data — enabling Tier 0 rendering, data-only
updates, and template reuse. See [tier-zero.md](tier-zero.md) and
[data-binding.md](data-binding.md).

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-04-05 | Initial specification |
