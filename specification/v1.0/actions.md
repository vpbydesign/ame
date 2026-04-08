# AME Actions Specification — v1.0

## Introduction

Actions define what happens when a user interacts with an AME element. They
are inline function-call expressions that appear as arguments to interactive
primitives — primarily `btn` (see [primitives.md](primitives.md)).

AME defines five action types. Each action is dispatched to the host
application via the `AmeActionHandler` interface. The AME renderer MUST NOT
execute actions directly — it delegates all action handling to the host app,
which decides whether to execute, confirm, or block the action based on its
own trust and safety policies.

For the syntax rules governing action expressions, see
[syntax.md](syntax.md), Rule 12.

### Notation Conventions

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD",
"SHOULD NOT", "RECOMMENDED", "MAY", and "OPTIONAL" in this document are to be
interpreted as described in [RFC 2119](https://www.ietf.org/rfc/rfc2119.txt).

---

## Action Types

### 1. `tool` — Invoke a Tool

Requests the host app to execute a named tool with the provided arguments.
This is the primary mechanism for AME elements to trigger side effects —
creating calendar events, sending messages, saving notes, searching, etc.

**Syntax:**
```
tool(name, key1=val1, key2=val2, ...)
```

**Arguments:**

| Position | Name | Type | Required | Description |
|----------|------|------|----------|-------------|
| 0 | name | Identifier | Yes | The tool name to invoke (unquoted) |
| 1+ | (named) | `key=value` pairs | No | Arguments passed to the tool |

The tool name is an unquoted identifier (not a string). Argument values MAY
be strings, numbers, booleans, or `$input.fieldId` references.

**Examples:**
```
// Create a calendar event with fixed arguments
schedule_btn = btn("Schedule", tool(create_calendar_event, title="Team Lunch", date="2026-04-15", location="Cafe Roma"))

// Search with a query parameter
search_btn = btn("Search", tool(search_places, query="Italian restaurants nearby"))

// Delete with a single ID
delete_btn = btn("Delete", tool(delete_item, id="item-42"), destructive)

// Tool with a $input reference (resolved from form state at dispatch time)
save_btn = btn("Save", tool(add_note, title="${input.title}", content="${input.body}"))
```

**Routing Semantics:**

When a `tool` action is dispatched:

1. The renderer constructs an `AmeAction.CallTool` object with the tool
   `name` and `args` map.
2. Any `${input.fieldId}` references in argument values are resolved against
   the current form state (see [Form Data Resolution](#form-data-resolution)
   below).
3. The resolved action is passed to the host app's `AmeActionHandler`.
4. The host app MUST route the tool call through its own trust and
   confirmation pipeline before executing. A tool call from an AME button
   MUST receive the same safety treatment as a tool call from the LLM.

**Error Handling:**

- Unknown tool name → the host app SHOULD display an error message to the
  user (e.g., "This action is not available") and MUST NOT crash.
- Missing required tool argument → the host app SHOULD display a validation
  error and MUST NOT execute the tool with incomplete arguments.

---

### 2. `uri` — Open a URI

Opens a URI using the platform's default handler. This is the standard
mechanism for launching external apps — maps, dialer, email client, web
browser.

**Syntax:**
```
uri("scheme:path")
```

**Arguments:**

| Position | Name | Type | Required | Description |
|----------|------|------|----------|-------------|
| 0 | uri | String | Yes | A fully-qualified URI |

The URI MUST be a quoted string containing a valid URI with a scheme.

**Common URI schemes:**

| Scheme | Purpose | Example |
|--------|---------|---------|
| `geo:` | Map location / navigation | `geo:40.72,-73.99?q=Luigi's` |
| `tel:` | Phone dialer | `tel:+15551234567` |
| `mailto:` | Email compose | `mailto:hello@example.com?subject=Hello` |
| `https:` | Web page | `https://example.com/menu` |
| `sms:` | SMS compose | `sms:+15551234567?body=Hello` |

**Examples:**
```
// Open maps with coordinates and label
directions_btn = btn("Directions", uri("geo:40.72,-73.99?q=Luigi's Restaurant"), text)

// Open phone dialer
call_btn = btn("Call", uri("tel:+15551234567"), primary, icon="phone")

// Open web link
website_btn = btn("Visit Website", uri("https://example.com/menu"), outline)

// Compose email
email_btn = btn("Email", uri("mailto:info@example.com?subject=Reservation"), text, icon="email")
```

**Routing Semantics:**

When a `uri` action is dispatched:

1. The renderer constructs an `AmeAction.OpenUri` object with the URI string.
2. The action is passed to the host app's `AmeActionHandler`.
3. The host app SHOULD open the URI using the platform's standard mechanism:
   - **Android:** `Intent(Intent.ACTION_VIEW, Uri.parse(uri))`
   - **iOS:** `UIApplication.shared.open(URL(string: uri))`
4. If no app can handle the URI scheme, the host app SHOULD display an error
   message and MUST NOT crash.

**Security:**

The host app MAY restrict which URI schemes are allowed. For example, a host
app MAY block `file:` and `javascript:` schemes while allowing `geo:`,
`tel:`, `mailto:`, `https:`, and `sms:`.

---

### 3. `nav` — Navigate Within App

Navigates to a screen or route within the host application. Route names are
app-defined — the AME spec does not prescribe any standard routes.

**Syntax:**
```
nav("route")
```

**Arguments:**

| Position | Name | Type | Required | Description |
|----------|------|------|----------|-------------|
| 0 | route | String | Yes | App-defined route identifier |

**Examples:**
```
// Navigate to the calendar screen
calendar_btn = btn("View Calendar", nav("calendar"), outline)

// Navigate to home
home_btn = btn("Home", nav("home"), text)

// Navigate to a specific item
note_btn = btn("Open Note", nav("notes/note-42"), text)
```

**Routing Semantics:**

When a `nav` action is dispatched:

1. The renderer constructs an `AmeAction.Navigate` object with the route
   string.
2. The action is passed to the host app's `AmeActionHandler`.
3. The host app SHOULD navigate to the corresponding screen using its own
   navigation framework.
4. If the route is unrecognized, the host app SHOULD log a warning and
   MUST NOT crash. The app MAY display a "Screen not found" message or
   silently ignore the navigation.

**Notes:**

Route strings are opaque to the AME renderer. The renderer does not validate
or interpret them — it passes them through to the host app. This allows each
host app to define its own route structure.

---

### 4. `copy` — Copy to Clipboard

Copies a text string to the system clipboard. The host app SHOULD provide
brief visual feedback (e.g., a toast or snackbar) to confirm the copy.

**Syntax:**
```
copy("text")
```

**Arguments:**

| Position | Name | Type | Required | Description |
|----------|------|------|----------|-------------|
| 0 | text | String | Yes | The text to copy to clipboard |

**Examples:**
```
// Copy an address
copy_addr = btn("Copy Address", copy("119 Mulberry St, New York, NY 10013"), text)

// Copy a phone number
copy_phone = btn("Copy Number", copy("+1 (555) 123-4567"), text)

// Copy an order ID
copy_id = btn("Copy ID", copy("ORDER-4829-XK"), text, icon="content_copy")
```

**Routing Semantics:**

When a `copy` action is dispatched:

1. The renderer constructs an `AmeAction.CopyText` object with the text
   string.
2. The action is passed to the host app's `AmeActionHandler`.
3. The host app MUST copy the text to the system clipboard using the
   platform's clipboard API:
   - **Android:** `ClipboardManager.setPrimaryClip(ClipData.newPlainText(...))`
   - **iOS:** `UIPasteboard.general.string = text`
4. The host app SHOULD show a brief confirmation (toast, snackbar, or
   haptic feedback) so the user knows the copy succeeded.

---

### 5. `submit` — Collect Form Data and Invoke Tool

Collects all `input` and `toggle` values from the current card's subtree,
merges them with static arguments, and dispatches the result as a `tool`
call. This is the primary mechanism for multi-field forms in AME.

**Syntax:**
```
submit(tool_name, key1=val1, key2=val2, ...)
```

**Arguments:**

| Position | Name | Type | Required | Description |
|----------|------|------|----------|-------------|
| 0 | tool_name | Identifier | Yes | The tool to invoke after collecting form data (unquoted) |
| 1+ | (named) | `key=value` pairs | No | Static arguments merged with collected form data |

**Examples:**
```
// Simple form: submit collects date, time, guests from input fields
confirm = btn("Confirm Booking", submit(create_reservation, restaurant="Luigi's"), primary)

// With input reference in static args
send = btn("Send", submit(send_message, to="${input.recipient}", body="${input.message}"), primary)
```

**Complete Form Example:**

```
root = card([form_title, fields, actions])
form_title = txt("Book a Table", headline)
fields = col([date_field, time_field, guests_field])
date_field = input("date", "Date", date)
time_field = input("time", "Time", time)
guests_field = input("guests", "Party Size", select, options=["1","2","3","4","5","6"])
actions = row([cancel, confirm], space_between)
cancel = btn("Cancel", nav("home"), text)
confirm = btn("Confirm", submit(create_reservation, restaurant="Luigi's"), primary)
```

When the user fills in date = "2026-04-15", time = "19:00", guests = "4"
and taps "Confirm":

1. The renderer walks the card's subtree and finds three form elements:
   - `input("date", ...)` → current value: `"2026-04-15"`
   - `input("time", ...)` → current value: `"19:00"`
   - `input("guests", ...)` → current value: `"4"`
2. It collects their values into a map keyed by `id`:
   ```
   {"date": "2026-04-15", "time": "19:00", "guests": "4"}
   ```
3. It takes the static arguments from `submit()`:
   ```
   {"restaurant": "Luigi's"}
   ```
4. It resolves any `${input.fieldId}` references in the static args (none in
   this case).
5. It merges the two maps (collected values + static args):
   ```
   {"restaurant": "Luigi's", "date": "2026-04-15", "time": "19:00", "guests": "4"}
   ```
6. It dispatches as `AmeAction.CallTool(name = "create_reservation", args = merged)`.
7. The host app receives this as a standard tool call and routes it through
   its trust/confirmation pipeline.

**Routing Semantics:**

When a `submit` action is dispatched:

1. The renderer identifies all `input` and `toggle` primitives in the current
   card's subtree (the nearest ancestor `card` element, or the `root` if no
   card ancestor exists).
2. For each `input`, it reads the current text value keyed by the input's `id`.
3. For each `toggle`, it reads the current boolean value (as string `"true"`
   or `"false"`) keyed by the toggle's `id`.
4. It resolves `${input.fieldId}` references in the static `key=value`
   arguments (see [Form Data Resolution](#form-data-resolution) below).
5. It merges the collected values with the resolved static arguments. If a
   key appears in both, the static argument takes precedence.
6. The merged map is dispatched as `AmeAction.CallTool(name = tool_name, args = merged)`.
7. The host app's `AmeActionHandler` receives this as a standard `CallTool`
   action.

**Conflict Resolution:**

If a collected input `id` conflicts with a static argument key name, the
static argument MUST take precedence. This allows the AME author to override
or fix specific values while still collecting the rest from the form.

---

## Form Data Resolution

Both `tool` and `submit` actions support `${input.fieldId}` references in
their argument values. These references are resolved at dispatch time (when
the user taps the button), not at parse time.

### Syntax

```
${input.fieldId}
```

Where `fieldId` is the `id` argument of an `input` or `toggle` primitive.

### Resolution Rules

1. The renderer maintains a `FormState` object that tracks the current value
   of every `input` and `toggle` in the rendered AME document.

2. When an action is dispatched, the renderer scans all string values in the
   action's arguments for the pattern `${input.IDENTIFIER}`.

3. For each match, the renderer looks up `IDENTIFIER` in the form state:
   - If found, the `${input.IDENTIFIER}` token is replaced with the current
     value.
   - If not found, the token is left as-is (unreplaced), and a warning
     SHOULD be logged.

4. The regex pattern for matching is: `\$\{input\.(\w+)\}`

### Examples

Given this document:

```
root = card([name_field, msg_field, send_btn])
name_field = input("recipient", "To")
msg_field = input("body", "Message")
send_btn = btn("Send", tool(send_message, to="${input.recipient}", body="${input.body}"))
```

If the user types "Alice" in the recipient field and "Hello!" in the body
field, then taps "Send":

1. The renderer finds `${input.recipient}` → looks up `"recipient"` in form
   state → resolves to `"Alice"`.
2. The renderer finds `${input.body}` → looks up `"body"` in form state →
   resolves to `"Hello!"`.
3. The dispatched action is:
   ```
   AmeAction.CallTool(
       name = "send_message",
       args = {"to": "Alice", "body": "Hello!"}
   )
   ```

### Difference Between `tool` and `submit` with References

Both can use `${input.fieldId}`, but they differ in form data collection:

| Aspect | `tool` with `${input.fieldId}` | `submit` |
|--------|-------------------------------|----------|
| Explicit references | Yes — only referenced fields are included | N/A — all fields collected automatically |
| Unreferenced fields | Not included in args | Included (collected by `id`) |
| Static args | Only what's in the `tool()` call | Merged with collected fields |
| Use case | When you need specific fields from a form | When you want all form fields sent to a tool |

**Guidance:** Use `submit` when a form has 2+ fields and you want all of them
sent to the tool. Use `tool` with `${input.fieldId}` when you need to compose
a specific argument from form data (e.g., building a message string).

---

## Action Handler Interface

The AME renderer dispatches all actions to a host-app-provided handler. The
handler interface has a single method:

```kotlin
fun interface AmeActionHandler {
    fun handleAction(action: AmeAction)
}
```

Where `AmeAction` is a sealed interface with one variant per action type:

```kotlin
sealed interface AmeAction {
    data class CallTool(val name: String, val args: Map<String, String>) : AmeAction
    data class OpenUri(val uri: String) : AmeAction
    data class Navigate(val route: String) : AmeAction
    data class CopyText(val text: String) : AmeAction
}
```

Note: `Submit` does not appear in `AmeAction` because the renderer resolves
it into a `CallTool` before dispatching. The host app never sees a `Submit`
action — it only sees the resulting `CallTool` with the merged arguments.

---

## Security Model

### Trust Pipeline Requirement

Every `tool` action (whether from a `tool()` call or a `submit()` resolution)
MUST be routed through the host app's trust and confirmation pipeline. The
AME specification does not define what this pipeline looks like — it is the
host app's responsibility.

Examples of trust pipeline behaviors:

- **Auto-execute:** Low-risk tools (create note, search) may execute
  immediately without user confirmation.
- **Confirm:** High-risk tools (send message, delete item) may show a
  confirmation dialog before executing.
- **Block:** Certain tools may be blocked entirely based on user preferences.

The AME renderer MUST NOT bypass the host app's trust pipeline. It MUST NOT
execute tool calls directly, even if the tool name and arguments are known.

### URI Scheme Restrictions

Host apps MAY restrict which URI schemes are allowed in `uri()` actions.

**RECOMMENDED allowed schemes:** `geo:`, `tel:`, `mailto:`, `https:`, `http:`, `sms:`

**RECOMMENDED blocked schemes:** `file:`, `javascript:`, `data:`, `blob:`,
`content:`, any custom scheme the host app does not recognize.

A conforming host app SHOULD validate the URI scheme before opening it and
SHOULD display an error if the scheme is blocked.

### Clipboard Safety

The `copy()` action is low-risk. Host apps SHOULD execute it immediately
without confirmation. The copied text SHOULD be exactly what was specified
in the action argument — the renderer MUST NOT modify or sanitize the text
(the host app MAY sanitize if needed by its security policy).

---

## Summary: All Actions at a Glance

| Action | Syntax | Dispatches As | Risk Level |
|--------|--------|--------------|------------|
| `tool` | `tool(name, key=val, ...)` | `AmeAction.CallTool` | Depends on tool — host app decides |
| `uri` | `uri("scheme:path")` | `AmeAction.OpenUri` | Low (scheme-restricted) |
| `nav` | `nav("route")` | `AmeAction.Navigate` | Low (app-internal) |
| `copy` | `copy("text")` | `AmeAction.CopyText` | Low |
| `submit` | `submit(tool_name, key=val, ...)` | `AmeAction.CallTool` (after form collection) | Depends on tool — host app decides |

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-04-05 | Initial specification |
