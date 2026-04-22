# AME Syntax Specification — v1.0

## Introduction

AME (Agentic Mobile Elements) is a line-oriented, streaming-first syntax for
describing interactive user interfaces. It is designed for Large Language Models
to generate and for native mobile renderers (Jetpack Compose, SwiftUI) to
consume. Each line in an AME document is independently parseable, enabling
progressive rendering as tokens stream from the model. The renderer can display
partial UI with skeleton placeholders before the full document has arrived.

This document defines the complete AME syntax rules and formal grammar. For the
catalog of available primitives, see [primitives.md](primitives.md). For action
types, see [actions.md](actions.md). For the streaming rendering model, see
[streaming.md](streaming.md). For data binding, see
[data-binding.md](data-binding.md).

### Notation Conventions

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD",
"SHOULD NOT", "RECOMMENDED", "MAY", and "OPTIONAL" in this document are to be
interpreted as described in [RFC 2119](https://www.ietf.org/rfc/rfc2119.txt).

---

## Core Rules

### Rule 1: One Statement Per Line

Every AME statement occupies exactly one line. A statement binds an identifier
to an expression.

```
identifier = expression
```

A conforming parser MUST treat each newline (`\n`) as a statement boundary.
Statements MUST NOT span multiple lines.

### Rule 2: Root Entry Point

The first statement in an AME document MUST assign to the identifier `root`.
If the first statement uses a different identifier, a conforming renderer
SHOULD treat the document as invalid and MAY fall back to plain text rendering.

```
root = col([header, content])
```

### Rule 3: Identifiers

Identifiers are lowercase names used to label elements. An identifier MUST
start with a letter (`a-z`) and MAY contain letters, digits (`0-9`), and
underscores (`_`).

Valid: `header`, `p1_name`, `card2`, `submit_btn`
Invalid: `1card` (starts with digit), `my-card` (contains hyphen), `Card` (uppercase)

Identifiers are unique within a document. If a duplicate identifier appears,
the later definition MUST replace the earlier one, and a conforming parser
SHOULD log a warning.

### Rule 4: Component Calls

A component call creates a UI element. It consists of a component name followed
by parentheses containing zero or more arguments.

```
header = txt("Hello World", title)
```

The component name MUST be one of the 22 standard primitives defined in
[primitives.md](primitives.md), or a custom component name registered in the
host app's catalog. See [Custom Components](#custom-components) below.

### Rule 5: Positional Arguments

Arguments to standard primitives are positional. Their meaning is determined
by position, not by name. Required arguments come first; optional arguments
follow and MAY be omitted from the right.

```
// txt(text, style?, max_lines?)
title = txt("Welcome")                    // text only, style defaults to body
title = txt("Welcome", headline)          // text + style
title = txt("Welcome", headline, max_lines=2)  // text + style + named optional
```

### Rule 6: Named Arguments

Named arguments use `key=value` syntax. They MAY appear after all positional
arguments. Named arguments are REQUIRED for optional parameters that follow
other optional parameters to avoid ambiguity, and for custom component
properties.

```
email_input = input("email", "Email Address", email)
guest_input = input("guests", "Number of Guests", number, options=["1","2","3","4"])
```

### Rule 7: Children Arrays

Layout components accept a children array as their first positional argument.
Children arrays use square brackets and contain comma-separated identifier
references.

```
root = col([header, body, footer])
header = row([logo, title, menu_btn])
```

Each identifier in the array references another statement in the document.
If the referenced statement has not yet been defined, it is treated as a
forward reference (see [Rule 14](#rule-14-forward-references)).

### Rule 8: Strings

String literals are enclosed in double quotes. The following escape sequences
are supported within strings:

| Escape | Character |
|--------|-----------|
| `\"` | Double quote |
| `\\` | Backslash |
| `\n` | Newline |
| `\t` | Tab |

```
msg = txt("She said \"hello\"")
multiline = txt("Line one\nLine two")
```

Strings MUST NOT contain unescaped newlines. A conforming parser encountering
an unclosed string at the end of a line SHOULD close the string implicitly
and log a warning.

### Rule 9: Numbers

Numeric literals are integers or decimals. A leading negative sign is permitted.

```
bar = progress(0.75)
space = spacer(16)
temp = txt("-5°C", display)
```

### Rule 10: Booleans

Boolean literals are the unquoted keywords `true` and `false`.

```
terms = toggle("agree", "I agree to the terms", false)
item_list = list([item1, item2], true)
```

### Rule 11: Enum Values

Style, variant, alignment, and input type values are unquoted lowercase
identifiers. The valid values for each enum are defined in
[primitives.md](primitives.md).

```
title = txt("Hello", headline)          // TxtStyle enum
cta = btn("Submit", tool(save), primary) // BtnStyle enum
tag = badge("New", success)              // BadgeVariant enum
```

A conforming parser encountering an unknown enum value SHOULD treat it as
the enum's default value and log a warning.

### Rule 12: Inline Actions

Actions are expressed as inline function calls within component arguments.
Five action types are defined in [actions.md](actions.md):

```
save_btn = btn("Save", tool(add_note, title="Meeting Notes"))
map_btn = btn("Directions", uri("geo:40.72,-73.99"))
home_btn = btn("Home", nav("home"))
copy_btn = btn("Copy Address", copy("119 Mulberry St"))
book_btn = btn("Confirm", submit(create_event, location="Luigi's"))
```

Action calls MUST appear only as arguments to interactive primitives (`btn`,
`card` with `actionOnTap`). They MUST NOT appear as standalone statements.

### Rule 13: Data Binding References

A `$` prefix denotes a reference to a value in the data model. The data model
is a JSON object defined after the `---` separator (see [Rule 15](#rule-15-data-separator)).

```
name_label = txt($name, title)           // top-level key
city_label = txt($address/city, caption)  // nested key
```

Inside an `each()` template (see [data-binding.md](data-binding.md)), `$`
references resolve relative to the current array item.

A conforming renderer encountering a `$` reference that cannot be resolved
MUST render an empty string and SHOULD log a warning.

### Rule 14: Forward References

An identifier MAY be used in a children array before it is defined by a
statement later in the document. This is called a forward reference.

```
root = col([header, body])     // "body" is used here
header = txt("Title", title)   // "header" is defined — resolves immediately
body = card([content])         // "body" is defined — resolves now
content = txt("Details", body) // "content" is defined — resolves now
```

A conforming renderer MUST show a placeholder (skeleton) for any forward
reference that has not yet been resolved. When the defining statement arrives,
the renderer MUST replace the placeholder with the rendered component. See
[streaming.md](streaming.md) for the full streaming rendering model.

### Rule 15: Data Separator

The `---` token on its own line separates the component structure section
from the data model section. Everything after `---` is a single JSON object
that provides values for `$` references.

```
root = col([name_label, rating_label])
name_label = txt($name, title)
rating_label = badge($rating, info)
---
{"name": "Luigi's", "rating": "★4.5"}
```

The `---` separator is OPTIONAL. Documents without it have no data model,
and any `$` references will resolve to empty strings.

The data model MUST be a single valid JSON object. It MUST NOT be a JSON
array or primitive.

See [data-binding.md](data-binding.md) for complete data binding semantics
including `each()` template rendering.

### Rule 16: Comments

Lines beginning with `//` (optionally preceded by whitespace) are comments.
A conforming parser MUST skip comment lines.

```
// This is a comment
root = col([header, body])
// header section
header = txt("Welcome", headline)
```

Comments are intended for human documentation. LLMs SHOULD NOT generate
comments in their output, as they consume tokens without rendering benefit.

---

## Formal Grammar (EBNF)

The following Extended Backus–Naur Form grammar defines the complete AME syntax.

```ebnf
(* === Document Structure === *)
document       = { line } ;
line           = ( statement | data_separator | comment | empty_line ) , newline ;
statement      = identifier , "=" , expression ;
data_separator = "---" ;
comment        = "//" , { any_char } ;
empty_line     = { whitespace } ;

(* === Expressions === *)
expression     = component_call
               | action_call
               | array
               | string
               | number
               | boolean
               | data_ref
               | identifier ;

component_call = component_name , "(" , [ arg_list ] , ")" ;
action_call    = action_name , "(" , [ arg_list ] , ")" ;
arg_list       = argument , { "," , argument } ;
argument       = named_arg | expression ;
named_arg      = identifier , "=" , expression ;

(* === Literals === *)
array          = "[" , [ expression , { "," , expression } ] , "]" ;
string         = '"' , { string_char } , '"' ;
string_char    = any_char_except_quote_or_backslash
               | "\\" , escape_char ;
escape_char    = '"' | "\\" | "n" | "t" ;
number         = [ "-" ] , digit , { digit } , [ "." , digit , { digit } ] ;
boolean        = "true" | "false" ;
data_ref       = "$" , identifier , { "/" , identifier } ;

(* === Names === *)
component_name = standard_primitive | identifier ;
standard_primitive = "col" | "row" | "txt" | "btn" | "card" | "badge"
                   | "icon" | "img" | "input" | "toggle" | "list"
                   | "list_item" | "table" | "divider" | "spacer"
                   | "progress" | "chart" | "code" | "accordion"
                   | "carousel" | "callout" | "timeline" | "timeline_item" ;
action_name    = "tool" | "uri" | "nav" | "copy" | "submit" ;

(* === Tokens === *)
identifier     = letter , { letter | digit | "_" } ;
letter         = "a" | "b" | ... | "z" ;
digit          = "0" | "1" | ... | "9" ;
whitespace     = " " | "\t" ;
newline        = "\n" ;
any_char       = ? any Unicode character except newline ? ;
```

### Grammar Notes

1. Whitespace between tokens is ignored (spaces and tabs). Newlines are
   significant — they terminate statements.

2. The grammar is intentionally unambiguous about `identifier` vs
   `component_name` vs `action_name` vs enum values. A conforming parser
   resolves this by priority:
   - If followed by `(`, it is a component call or action call
   - If preceded by `$`, it is a data reference
   - If it appears as a value in an argument position and matches a known
     enum value for that parameter, it is an enum
   - Otherwise, it is an identifier reference (forward or resolved)

3. The data section after `---` is NOT parsed by the AME grammar. It is
   passed to a standard JSON parser.

4. `each` is NOT a component name. It is a structural construct documented
   in [data-binding.md](data-binding.md). In the grammar, it is parsed as
   a `component_call` with `component_name = "each"`, but the renderer
   treats it as a control flow directive rather than a visual element.

---

## Complete Examples

Each example below is a valid AME document. Line numbers and annotations
are provided for clarity; they are not part of the syntax.

### Example 1: Weather Card

A single card displaying current weather conditions.

```
root = card([weather_header, temp, condition, details])
weather_header = row([city, weather_icon], space_between)
city = txt("San Francisco", title)
weather_icon = icon("partly_cloudy_day", 28)
temp = txt("62°", display)
condition = txt("Partly Cloudy", body)
details = row([high_low, humidity], space_between)
high_low = txt("H:68°  L:55°", caption)
humidity = txt("Humidity: 72%", caption)
```

**Parse trace:** `root` is assigned a `card` with 4 children. Each child is
defined on subsequent lines. No forward references are unresolved at end.
No data binding. No actions. 9 lines.

### Example 2: Place Search Results

Three restaurant cards with ratings and action buttons.

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

**Parse trace:** `root` is a `col` with 2 children. `results` is a `list`
with 3 children. Each place card contains a row (name + badge), address text,
and a row of buttons. Button actions use `tool()` and `uri()`. 27 lines.

### Example 3: Email Inbox

Five email previews with unread indicators.

```
root = col([inbox_header, email_list])
inbox_header = row([inbox_title, inbox_count], space_between)
inbox_title = txt("Inbox", headline)
inbox_count = badge("3 unread", info)
email_list = list([e1, e2, e3, e4, e5])
e1 = row([e1_info, e1_badge])
e1_info = col([e1_from, e1_subj])
e1_from = txt("Sarah Chen", title)
e1_subj = txt("Meeting tomorrow at 3pm", caption)
e1_badge = badge("New", success)
e2 = row([e2_info, e2_badge])
e2_info = col([e2_from, e2_subj])
e2_from = txt("Dev Team", title)
e2_subj = txt("Sprint review notes", caption)
e2_badge = badge("New", success)
e3 = row([e3_info, e3_badge])
e3_info = col([e3_from, e3_subj])
e3_from = txt("Alex Rivera", title)
e3_subj = txt("Updated design files", caption)
e3_badge = badge("New", success)
e4 = row([e4_info])
e4_info = col([e4_from, e4_subj])
e4_from = txt("Newsletter", body)
e4_subj = txt("Weekly digest - March 28", caption)
e5 = row([e5_info])
e5_info = col([e5_from, e5_subj])
e5_from = txt("AWS", body)
e5_subj = txt("Your monthly invoice is ready", caption)
```

**Parse trace:** `root` is a `col` with header row and list. Each email is a
`row` with an info column and optional badge. Read emails (e4, e5) have no
badge. 28 lines.

### Example 4: Booking Form

A dinner reservation form with inputs and a submit button.

```
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
```

**Parse trace:** `root` is a `card` with title, field column, and action row.
Four `input` primitives with different types. `confirm_btn` uses `submit()`
which collects all input values (date, time, guests, notes) and merges with
the static `restaurant` arg before dispatching. 10 lines.

### Example 5: Side-by-Side Comparison

Two options displayed in parallel columns with key-value details.

```
root = col([comp_title, comp_row, comp_note])
comp_title = txt("Compare Plans", headline)
comp_row = row([plan_a, plan_b], 12)
plan_a = card([pa_name, pa_price, pa_details, pa_btn])
pa_name = txt("Basic Plan", title)
pa_price = txt("$15/month", display)
pa_details = col([pa_d1, pa_d2, pa_d3])
pa_d1 = row([pa_d1_k, pa_d1_v], space_between)
pa_d1_k = txt("Storage", caption)
pa_d1_v = txt("50 GB", body)
pa_d2 = row([pa_d2_k, pa_d2_v], space_between)
pa_d2_k = txt("Users", caption)
pa_d2_v = txt("1", body)
pa_d3 = row([pa_d3_k, pa_d3_v], space_between)
pa_d3_k = txt("Support", caption)
pa_d3_v = txt("Email only", body)
pa_btn = btn("Select Basic", tool(select_plan, plan="basic"), outline)
plan_b = card([pb_name, pb_price, pb_details, pb_badge, pb_btn])
pb_name = txt("Pro Plan", title)
pb_price = txt("$45/month", display)
pb_details = col([pb_d1, pb_d2, pb_d3])
pb_d1 = row([pb_d1_k, pb_d1_v], space_between)
pb_d1_k = txt("Storage", caption)
pb_d1_v = txt("500 GB", body)
pb_d2 = row([pb_d2_k, pb_d2_v], space_between)
pb_d2_k = txt("Users", caption)
pb_d2_v = txt("10", body)
pb_d3 = row([pb_d3_k, pb_d3_v], space_between)
pb_d3_k = txt("Support", caption)
pb_d3_v = txt("24/7 Priority", body)
pb_badge = badge("Recommended", success)
pb_btn = btn("Select Pro", tool(select_plan, plan="pro"), primary)
comp_note = txt("All plans include a 14-day free trial.", caption)
```

**Parse trace:** `root` is a `col` with title, row of two cards, and a note.
Each card contains name, price, detail rows (key-value pairs), and a select
button. Plan B has an additional badge. Buttons use `tool()` actions. 33 lines.

---

## Error Handling

A conforming parser MUST handle malformed input gracefully. AME is designed
to be generated by LLMs, which may produce syntactically imperfect output.
The parser MUST NOT crash or throw unrecoverable exceptions on any input.

### Unknown Component Name

If the parser encounters a component name that is not a standard primitive
and is not registered as a custom component, it MUST:
1. Log a warning with the unknown name
2. Render a text element displaying the warning (e.g., `txt("⚠ Unknown: foo")`)
3. Continue parsing subsequent lines

### Unclosed Parenthesis

If a line contains an opening `(` without a matching `)`, the parser SHOULD:
1. Implicitly close the parenthesis at end of line
2. Log a warning
3. Produce a best-effort parse of the arguments seen so far

### Unclosed String

If a line contains an opening `"` without a matching `"`, the parser SHOULD:
1. Implicitly close the string at end of line
2. Log a warning
3. Use the partial string as the value

### Malformed Line

If a line cannot be parsed at all (no `=` sign, completely garbled), the
parser MUST:
1. Skip the line entirely
2. Log an error with the raw line content
3. Continue parsing subsequent lines

A single malformed line MUST NOT invalidate the rest of the document.

### Duplicate Identifier

If the same identifier appears in two statements, the later definition
MUST replace the earlier one. The parser SHOULD log a warning. Any components
already rendered from the earlier definition SHOULD update to reflect the
new definition.

### Invalid Number

If a value in a numeric position cannot be parsed as a number, the parser
SHOULD treat it as a string and log a warning.

### Invalid Enum Value

If a value in an enum position does not match any valid enum member, the
parser SHOULD use the enum's default value and log a warning.

---

## Reserved Keywords

The following identifiers have special meaning in AME and MUST NOT be used
as user-defined identifiers. The reserved set is intentionally narrow: only
tokens that the parser cannot disambiguate from a user identifier by
position alone.

### Standard Primitive Names

`col`, `row`, `txt`, `btn`, `card`, `badge`, `icon`, `img`, `input`,
`toggle`, `list`, `list_item`, `table`, `divider`, `spacer`, `progress`,
`chart`, `code`, `accordion`, `carousel`, `callout`, `timeline`,
`timeline_item`

### Action Names

`tool`, `uri`, `nav`, `copy`, `submit`

### Structural Keywords

`each`, `root`

### Boolean Literals

`true`, `false`

### Data Separator

`---` (three hyphens on a line by themselves)

### Enum Value Tokens Are NOT Reserved

Enum value tokens (for example `title`, `headline`, `primary`, `done`,
`success`, `info`, `line`, `pie`) MAY appear as user-defined identifiers
without restriction. The parser disambiguates by argument position:

- The slot before `=` on a line is always a registry key (the LHS
  identifier).
- A bare token at a positional argument slot of a primitive call is
  evaluated against that primitive's enum first, then falls back to a
  registry lookup if no enum value matches.

For example, `title = txt("Welcome", title)` is unambiguous: the LHS
`title` is the registry key for the resulting txt node, while the second
argument `title` resolves to `TxtStyle.title`. Both uses can co-exist in
the same document because the parser knows which slot it is reading.

This rule was intentionally narrowed in v1.2. Earlier drafts of the spec
listed every enum value as reserved; in practice this rejected common
LLM-emitted identifiers like `title` and `label` for a benefit (reader
clarity) that the parser already provides through positional
disambiguation. See `AUDIT_VERDICTS.md` Bug 9 for the audit trail.

### `error` Token Disambiguation

The token `error` appears in three different enums (`CalloutType`,
`TimelineStatus`, `SemanticColor`). The parser disambiguates by argument
position. In a callout's first argument it is `CalloutType.error`; in a
timeline_item's third argument it is `TimelineStatus.error`; as a `color=`
named argument it is `SemanticColor.error`. As a left-hand identifier it
is a user-defined registry key with no enum semantics.

---

## Custom Components

Host applications MAY register custom component names beyond the 22 standard
primitives. Custom components are rendered by the host app's renderer, not by
the AME standard library.

Custom components SHOULD be declared in the host app's system prompt or
capability announcement so the LLM knows they are available:

```
AME_CATALOG: col, row, txt, btn, card, badge, icon, img, input, toggle,
  list, table, divider, spacer, progress, chart, code, accordion, carousel,
  callout, timeline, MapView, PlaceCard, AudioPlayer
```

Custom component arguments are always named (not positional), since the AME
parser has no built-in knowledge of their parameter order:

```
map = MapView(pins=$places, height=200, show_route=true)
player = AudioPlayer(track_url="https://example.com/song.mp3", autoplay=false)
```

The AME specification does not define how custom component catalogs are
structured or negotiated. This is left to the host application and the
agent framework in use. For a formal way to declare custom component
parameter types, see the `AME_CUSTOM` declaration in
[integration.md](integration.md).

---

## Recommendations

### Maximum Nesting Depth

AME documents SHOULD NOT exceed 8 levels of nesting depth (a `col` containing
a `card` containing a `row` containing a `txt` is 4 levels). Deeply nested
structures are harder for LLMs to generate correctly and may cause rendering
performance issues on mobile devices.

A conforming renderer MAY enforce a maximum depth and render a text fallback
for elements exceeding the limit.

### Maximum Document Length

AME documents SHOULD NOT exceed 60 lines (excluding comments and empty lines).
Documents exceeding this length indicate a UI that is likely too complex for
an inline chat card and SHOULD be rendered as a dedicated screen instead.

### Identifier Naming

Identifiers SHOULD be descriptive and short. The following conventions are
RECOMMENDED:

- Use prefixes to group related elements: `p1_name`, `p1_addr`, `p1_btns`
- Use semantic names: `header`, `results`, `submit_btn`
- Avoid single-character names except for trivial cases

### Generation Order

LLMs generating AME documents SHOULD emit statements in top-down order:
root first, then layout containers, then leaf content, then data. This
maximizes progressive rendering performance because the renderer can show
the overall structure as skeletons while content fills in.

---

## Differences from OpenUI Lang

AME's line-oriented, streaming-first design is inspired by
[OpenUI Lang](https://www.openui.com/docs/openui-lang). Both use the
`identifier = Component(args)` assignment syntax, forward references
with placeholder rendering, and top-down generation for progressive display.

AME differs from OpenUI Lang in the following ways:

| Aspect | AME | OpenUI Lang |
|--------|-----|-------------|
| Target platform | Mobile (Compose, SwiftUI) | Web (React) |
| Schema dependency | None | Zod schemas define argument order |
| Component catalog | 22 built-in primitives + custom | Defined entirely by app's Zod schemas |
| Actions | Inline `tool()`, `uri()`, `nav()`, `copy()`, `submit()` | Component callbacks |
| Data binding | `$path` references + `---` separator | JavaScript variable references |
| Template rendering | `each($array, template_id)` | Array `.map()` in JavaScript |
| Form state | Built-in `input()` + `submit()` with `$input.fieldId` resolution | Not specified |
| Tier 0 rendering | Tool-result shape matching (zero LLM tokens) | Not specified |

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-04-05 | Initial specification — 15 standard primitives, EBNF grammar, error handling rules |
| 1.1 | 2026-04-08 | Updated EBNF grammar to 21 standard primitives. Added ChartType, CalloutType, TimelineStatus, SemanticColor to reserved keywords. Maximum document length increased from 50 to 60 lines. AME_CUSTOM cross-reference added to Custom Components section. |
| 1.4 | 2026-04-21 | Added `list_item` to standard primitives (22 total). Added `top` and `bottom` to the Align enum (valid for `crossAlign` on `row`/`col` only). |
