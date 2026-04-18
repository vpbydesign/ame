# AME Data Binding Specification — v1.0

## Introduction

AME separates component structure from data. The structure section defines the
UI layout and component hierarchy using AME statements. The data section
provides a JSON object that supplies dynamic values to those components through
`$path` references. This separation enables a powerful pattern: the structure
is defined once and remains stable, while the data can be updated independently,
enabling live search filtering, real-time data updates, and pagination
without regenerating the UI layout.

This document defines the `$path` reference system, the `---` data separator,
the `each()` template rendering construct, and the resolution timing rules that
govern when data values are bound to components. For the syntax-level
definitions that underpin data binding, see [syntax.md](syntax.md) Rules 13
and 15. For form data resolution using `${input.fieldId}`, see
[actions.md](actions.md). For streaming behavior of data-bound documents, see
[streaming.md](streaming.md).

### Notation Conventions

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD",
"SHOULD NOT", "RECOMMENDED", "MAY", and "OPTIONAL" in this document are to be
interpreted as described in [RFC 2119](https://www.ietf.org/rfc/rfc2119.txt).

---

## `$path` References

A `$path` reference is a `$`-prefixed identifier path that resolves to a value
in the data model. See [syntax.md](syntax.md) Rule 13 for the syntax
definition (`data_ref = "$" , identifier , { "/" , identifier }`).

### Syntax

| Form | Example | Resolves To |
|------|---------|-------------|
| `$identifier` | `$name` | Top-level key `"name"` in the data model |
| `$identifier/subkey` | `$address/city` | Key `"city"` inside the `"address"` object |
| `$identifier/subkey/subsubkey` | `$user/profile/avatar` | Key `"avatar"` inside `"profile"` inside `"user"` |

Path segments are separated by `/`. Each segment is an object key lookup. The
renderer navigates into nested JSON objects following the path segments
left to right.

### Resolution Rules

1. The renderer MUST resolve `$path` references against the data model — the
   JSON object provided after the `---` separator.

2. If the resolved value is a **string**, the renderer MUST use it directly.

3. If the resolved value is a **number**, the renderer MUST convert it to its
   string representation (e.g., `42` → `"42"`, `3.14` → `"3.14"`).

4. If the resolved value is a **boolean**, the renderer MUST convert it to
   `"true"` or `"false"`.

5. If the resolved value is **null**, the renderer MUST treat it as an empty
   string.

6. If the resolved value is an **object** or **array**, the renderer MUST
   treat it as an empty string and SHOULD log a warning. Objects and arrays
   are not directly renderable as text — use `each()` for arrays (see below).

7. If the path does not exist in the data model (a key is missing at any
   level of the path), the renderer MUST render an empty string and SHOULD
   log a warning identifying the unresolved path.

8. A conforming implementation MAY resolve `$path` references at parse time
   (when the data section is present in the same document) or at render time.
   The observable output MUST be identical regardless of when resolution
   occurs.

### Example

```
root = col([name_label, city_label])
name_label = txt($name, title)
city_label = txt($address/city, caption)
---
{"name": "Luigi's", "address": {"city": "New York", "state": "NY"}}
```

Resolution:

- `$name` → looks up `"name"` in root object → `"Luigi's"`
- `$address/city` → looks up `"address"` → `{"city": "New York", "state": "NY"}` → looks up `"city"` → `"New York"`

Renders: `txt("Luigi's", title)` and `txt("New York", caption)`.

---

## The `---` Separator

The `---` token on its own line separates the component structure section from
the data model section. See [syntax.md](syntax.md) Rule 15 for the syntax
definition.

### Rules

1. The separator is exactly three hyphen characters on a line by themselves:
   `---`. There MUST NOT be any other characters on the line (except optional
   leading or trailing whitespace, which SHOULD be ignored).

2. Everything before `---` is AME component statements, parsed by the AME
   parser.

3. Everything after `---` is a single JSON value, parsed by a standard JSON
   parser.

4. The `---` separator is OPTIONAL. Documents without it have no data model.
   Any `$path` references in such documents resolve to empty strings.

5. The data model MUST be valid JSON. It MUST be a JSON object (not an array,
   string, number, boolean, or null). A conforming parser encountering a
   non-object JSON value after `---` MUST log an error and treat the document
   as having no data model.

6. There MUST be at most one `---` separator per document. If multiple `---`
   lines appear, the parser MUST recognize only the first one. Everything after
   the second `---` is ignored, and the parser SHOULD log a warning.

7. The JSON data model MAY span multiple lines after `---`. The parser MUST
   collect all content after the first `---` until the end of the document and
   pass it to the JSON parser as a single string.

### Example

```
root = card([greeting])
greeting = txt($message, headline)
---
{"message": "Welcome back, Alex!"}
```

The structure section has 2 statements. The data model is
`{"message": "Welcome back, Alex!"}`. The `$message` reference resolves to
`"Welcome back, Alex!"`.

---

## `each()` — Template Rendering

The `each()` construct renders a dynamic-length list of components from a
JSON array in the data model. It is the mechanism for displaying collections
of items (search results, email lists, calendar events) where the number of
items is determined by the data, not by the structure.

### Syntax

```
identifier = each($arrayPath, templateId)
```

- `$arrayPath` — a `$path` reference that MUST resolve to a JSON array in the
  data model.
- `templateId` — the identifier of a component defined elsewhere in the
  document. This component serves as the template that is instantiated once
  per array item.

### Instantiation

The implementation iterates over each element in the resolved array. For each
element, it creates a new instance of the template component. The template
instance receives the current array element as its local data scope.

### Scoping Rules

Inside a template instantiated by `each()`, `$path` references resolve
**relative to the current array item**, not against the root data model. This
is the critical scoping rule that makes `each()` work:

- Outside `each()`: `$name` resolves against the root data model object.
- Inside an `each()` template: `$name` resolves against the current array
  item object.

### Complete Example

```
root = col([title, results])
title = txt("Italian Restaurants", headline)
results = each($places, place_tpl)
place_tpl = card([place_row, place_addr])
place_row = row([txt($name, title), badge($rating, info)], space_between)
place_addr = txt($address, caption)
---
{"places": [
  {"name": "Luigi's", "rating": "★4.5", "address": "119 Mulberry St"},
  {"name": "Joe's Pizza", "rating": "★4.3", "address": "375 Canal St"},
  {"name": "Carbone", "rating": "★4.7", "address": "181 Thompson St"}
]}
```

Resolution:

1. `$places` resolves to a 3-element array.
2. `each()` instantiates `place_tpl` three times.
3. In the first instance, `$name` → `"Luigi's"`, `$rating` → `"★4.5"`,
   `$address` → `"119 Mulberry St"`.
4. In the second instance, `$name` → `"Joe's Pizza"`, `$rating` → `"★4.3"`,
   `$address` → `"375 Canal St"`.
5. In the third instance, `$name` → `"Carbone"`, `$rating` → `"★4.7"`,
   `$address` → `"181 Thompson St"`.

The result is visually identical to defining three separate cards manually
(as in [syntax.md](syntax.md) Example 2), but with the data factored out.

### `each()` Is Not a Visual Primitive

`each()` does NOT appear in [primitives.md](primitives.md). It is a
**control-flow construct**, not a visual component. It does not render any UI
of its own. It produces a sequence of instantiated templates that replace it
in the parent's children list.

In the grammar ([syntax.md](syntax.md) Grammar Note 4), `each` is parsed as a
`component_call` with `component_name = "each"`, but the renderer treats it as
a directive rather than a component.

### Implementation Timing

A conforming implementation MAY expand `each()` at parse time or defer
expansion to render time. The observable output MUST be identical regardless
of when expansion occurs:

- **Parse-time expansion**: When the data section is present in the document,
  the parser resolves `$arrayPath`, iterates over the array, and replaces
  each `each()` node with the instantiated template copies. The resulting
  tree contains no `each()` nodes — only the expanded primitives. `$path`
  references within each template instance are resolved against the
  corresponding array element's scope during expansion.

- **Deferred expansion**: When streaming without a data section, the parser
  preserves `each()` nodes in the tree. The renderer is responsible for
  expansion once the data model becomes available (e.g. via a data-only
  update).

### Edge Cases

- If `$arrayPath` does not resolve to an array (e.g., it resolves to a string,
  number, object, or the path does not exist), the implementation MUST produce
  nothing for this `each()` node and SHOULD log a warning.
- If the resolved array is empty (`[]`), the implementation MUST produce
  nothing. This is not an error.
- If `templateId` references an identifier that does not exist, the
  implementation MUST produce nothing and SHOULD log a warning.

### Nesting

`each()` constructs MAY be nested: a template used by one `each()` may itself
contain another `each()`. However, nested `each()` SHOULD be avoided in
practice. A single level of `each()` covers all common use cases (flat lists,
card lists, table rows). Nested `each()` increases template complexity and may
cause performance issues on mobile devices with large data sets.

When nested, the inner `each()` resolves its `$arrayPath` relative to the
current item of the outer `each()`, following the standard scoping rules.

---

## Resolution Timing

AME has two distinct reference mechanisms with different resolution timing.
Understanding when each resolves is critical for correct behavior.

### `$path` — Data-Available Resolution

`$path` references resolve when the data model is available, either at parse
time (if the data section is present) or at render time (if data arrives later,
e.g. during streaming). They produce static values that do not change unless
the data model itself is updated.

`$path` references are valid in both content and action argument positions:

**In content arguments** (displaying data):

```
name = txt($name, title)
city = txt($address/city, caption)
```

The implementation resolves `$name` and `$address/city` when the data model is
available. The text components display the resolved string values.

**In action arguments** (constructing actions from data):

```
dir_btn = btn("Directions", uri($map_url), text)
call_btn = btn("Call", uri($phone_uri), outline)
```

The implementation resolves `$map_url` and `$phone_uri` when the data model is
available, producing concrete action objects. By the time the user taps the
button, the action already contains the resolved literal string (e.g.,
`AmeAction.OpenUri(uri = "geo:40.72,-73.99")`). No further resolution occurs
at tap time.

### `${input.fieldId}` — Dispatch-Time Resolution

`${input.fieldId}` references resolve at **dispatch time**, the moment the
user taps a button. They read the current live value from the form state
(the values the user has typed into `input` or `toggle` components).

```
send_btn = btn("Send", tool(send_message, to="${input.recipient}"))
```

When the user taps "Send", the renderer looks up `"recipient"` in the form
state at that instant and substitutes the current value. This means the action
reflects whatever the user has typed, even if they changed the field after the
UI was rendered.

See [actions.md](actions.md) Form Data Resolution for the complete
`${input.fieldId}` specification.

### Summary

| Mechanism | Syntax | Resolves From | Resolves When | Use Case |
|-----------|--------|---------------|---------------|----------|
| `$path` | `$identifier` or `$a/b/c` | Data model (JSON after `---`) | When data model is available (parse time or render time) | Displaying data, constructing actions from data |
| `${input.fieldId}` | `${input.IDENTIFIER}` | Form state (current `input`/`toggle` values) | Dispatch time (when user taps button) | Sending user input to tools |

These two mechanisms MUST NOT be confused. They use different syntax, resolve
from different sources, and resolve at different times.

---

## Why Two `$` Syntaxes?

AME uses two `$`-prefixed syntaxes that serve different purposes at different
times. They are intentionally distinct, not an inconsistency.

### `$path` — Whole-Value Substitution (Render-Time)

`$path` replaces the ENTIRE argument value with a value from the data model.
No braces are needed because the reference IS the whole value; there is
nothing else in the string to delimit it from.

```
name_label = txt($name, title)       // $name IS the entire text content
addr_label = txt($address, caption)  // $address IS the entire text content
dir_btn = btn("Go", uri($map_url))   // $map_url IS the entire URI
```

Resolution happens when the data model (after `---`) is available, either at
parse time or render time. Once resolved, the value is static.

### `${input.fieldId}` — String Interpolation (Dispatch-Time)

`${input.fieldId}` inserts a form value INTO a larger string. Braces are
required to delimit the reference within the surrounding text.

```
send_btn = btn("Send", tool(send_msg, body="Dinner on ${input.date} at ${input.time}"))
```

Here, `${input.date}` and `${input.time}` are embedded within the string
`"Dinner on ... at ..."`. Without braces, the parser could not determine
where the reference ends and the literal text resumes.

Resolution happens at **dispatch time**, when the user taps the button.
The values come from the live form state (current contents of `input` and
`toggle` fields), not from the data model.

### The `input.` Prefix

The `input.` prefix inside `${...}` explicitly identifies the source as
form state. `$name` is always a data model reference. `${input.name}` is
always a form state reference. There is no ambiguity between the two because
they use different syntax:

| Syntax | Source | Resolution Time | Example |
|--------|--------|----------------|---------|
| `$path` | Data model (JSON after `---`) | When data is available | `txt($city, title)` |
| `${input.fieldId}` | Form state (input/toggle values) | Dispatch time (button tap) | `tool(send, msg="${input.body}")` |

This pattern mirrors Unix shell variable syntax: `$VAR` for simple
substitution, `${VAR}` for interpolation within strings.

---

## Data-Only Updates

For live and dynamic scenarios, a host app MAY update the data model without
re-sending or re-parsing the structure section.

### Mechanism

1. The host app provides a new JSON object to the renderer.
2. The renderer MUST re-resolve all `$path` references against the new data
   model.
3. The renderer MUST re-instantiate all `each()` constructs with the new
   array contents. If the array length changes, the number of rendered
   template instances MUST change accordingly.
4. The component structure (all statements before `---`) remains unchanged.
   No re-parsing of AME statements occurs.

### Use Cases

- **Live search filtering** — the user types a query, the app filters results
  and provides a new data model with fewer items. The `each()` construct
  re-instantiates with the filtered array.
- **Real-time data updates** — prices, scores, or status values change. The
  app provides a new data model and affected `$path` references update.
- **Pagination** — the user scrolls to the end of a list. The app provides a
  new data model with additional items appended to the array.

### Constraints

- The new data model MUST be a complete JSON object. Partial updates (deltas)
  are not supported in v1.0.
- The renderer SHOULD perform the re-resolution efficiently, only updating
  components whose resolved values actually changed. However, a conforming
  renderer MAY re-render all data-bound components on every update.

---

## Error Handling

### Missing `$path`

If a `$path` reference cannot be resolved because a key does not exist at any
level of the path:

- The renderer MUST render an empty string for the unresolved reference.
- The renderer SHOULD log a warning identifying the path that could not be
  resolved and the data model context.

### Non-Array in `each()`

If the `$arrayPath` in an `each()` construct resolves to a value that is not a
JSON array:

- The renderer MUST render nothing for this `each()` node.
- The renderer SHOULD log a warning indicating the expected array was not found
  and what type was found instead.

### Invalid JSON After `---`

If the content after `---` cannot be parsed as valid JSON:

- The renderer MUST log an error with the raw content.
- All `$path` references MUST resolve to empty strings.
- All `each()` constructs MUST render nothing.
- The structure section (everything before `---`) MUST still render with its
  static content intact.

### Non-Object JSON After `---`

If the JSON after `---` parses successfully but is not an object (e.g., it is
an array `[1, 2, 3]` or a primitive `"hello"`):

- The renderer MUST log an error.
- The renderer MUST treat the document as having no data model (same behavior
  as invalid JSON).

### Multiple `---` Separators

If the document contains more than one `---` line:

- The parser MUST recognize only the first `---` as the data separator.
- Everything between the first `---` and the second `---` is treated as the
  JSON data model content.
- Everything after the second `---` is ignored.
- The parser SHOULD log a warning about the extra separator.

---

## Non-Normative Recommendations

### Data Model Size

Data models SHOULD be kept under 10KB (approximately 10,000 characters of
JSON). Larger data models may cause rendering performance issues on mobile
devices, particularly when `each()` constructs instantiate many templates
simultaneously. For large data sets, host apps SHOULD paginate and use
data-only updates to load additional items incrementally.

### Array Indexing

Version 1.0 of AME does **not** support array indexing in `$path` references.
A path like `$items/0/name` (accessing index 0 of an array) is not valid.
The `0` segment is treated as an object key lookup, which will fail on an
array value and resolve to an empty string.

To access individual array elements, use `each()` for iteration. A future
version of AME MAY introduce array indexing syntax if demand warrants it.

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-04-05 | Initial specification |
