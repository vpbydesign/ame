# AME Primitives Specification — v1.0

## Introduction

This document defines the 15 standard AME primitives — the built-in UI elements
that every conforming AME renderer MUST support. Each primitive is a composable
building block that maps to a native platform widget.

Primitives are organized into five categories:

| Category | Primitives | Purpose |
|----------|-----------|---------|
| Layout | `col`, `row` | Arrange children vertically or horizontally |
| Content | `txt`, `img`, `icon`, `divider`, `spacer` | Display text, images, icons, and whitespace |
| Semantic | `card`, `badge`, `progress` | Meaningful containers, labels, and indicators |
| Interactive | `btn`, `input`, `toggle` | User actions and form data entry |
| Data | `list`, `table` | Structured data display |

For the syntax rules governing how primitives are called, see
[syntax.md](syntax.md). For action types used by interactive primitives, see
[actions.md](actions.md).

### How to Read This Document

Each primitive entry includes:

- **Signature** — the call syntax with argument positions
- **Arguments** — table with position, name, type, required/optional, default
- **Example** — minimal valid AME syntax using this primitive
- **Compose Mapping** — the Jetpack Compose composable this maps to (informative, not normative — other platforms map to their own widgets)
- **Accessibility** — guidance for screen reader support

Argument positions matter. Required arguments come first. Optional arguments
follow and MAY be omitted from the right. Named arguments (`key=value`) MAY
appear after all positional arguments.

---

## Layout Primitives

### `col` — Vertical Column

Arranges children in a vertical stack, top to bottom.

**Signature:**
```
identifier = col([children], align?)
```

**Arguments:**

| Pos | Name | Type | Required | Default | Description |
|-----|------|------|----------|---------|-------------|
| 0 | children | Array of identifiers | Yes | — | Child elements to arrange vertically |
| 1 | align | Align enum | No | `start` | Horizontal alignment of children |

**Align enum values:** `start`, `center`, `end`

**Example:**
```
content = col([title, body, footer])
centered = col([logo, tagline], center)
```

**Compose Mapping:**
```kotlin
Column(
    horizontalAlignment = when (align) {
        Align.START -> Alignment.Start
        Align.CENTER -> Alignment.CenterHorizontally
        Align.END -> Alignment.End
    },
    verticalArrangement = Arrangement.spacedBy(8.dp)
) {
    children.forEach { child -> AmeRenderer(child) }
}
```

**Accessibility:** `col` is a structural container. It SHOULD NOT have its own
`contentDescription`. Children provide their own semantics.

---

### `row` — Horizontal Row

Arranges children in a horizontal line, left to right.

**Signature:**
```
identifier = row([children], align?, gap?)
```

**Arguments:**

| Pos | Name | Type | Required | Default | Description |
|-----|------|------|----------|---------|-------------|
| 0 | children | Array of identifiers | Yes | — | Child elements to arrange horizontally |
| 1 | align | Align enum | No | `start` | Horizontal distribution of children |
| 2 | gap | Integer (dp) | No | `8` | Spacing between children in dp |

**Align enum values:** `start`, `center`, `end`, `space_between`, `space_around`

When a numeric literal appears as the second argument (position 1), the parser
MUST interpret it as `gap`, not `align`. This is because `align` values are
always enum identifiers (non-numeric), so there is no ambiguity.

```
// gap=12, align defaults to start
buttons = row([save_btn, cancel_btn], 12)

// align=space_between, gap defaults to 8
header = row([title, menu], space_between)

// align=space_between, gap=16
toolbar = row([back, title, action], space_between, 16)
```

**Compose Mapping:**
```kotlin
Row(
    horizontalArrangement = when (align) {
        Align.START -> Arrangement.spacedBy(gap.dp)
        Align.CENTER -> Arrangement.spacedBy(gap.dp, Alignment.CenterHorizontally)
        Align.END -> Arrangement.spacedBy(gap.dp, Alignment.End)
        Align.SPACE_BETWEEN -> Arrangement.SpaceBetween
        Align.SPACE_AROUND -> Arrangement.SpaceAround
    },
    verticalAlignment = Alignment.CenterVertically
) {
    children.forEach { child -> AmeRenderer(child) }
}
```

**Accessibility:** `row` is a structural container. It SHOULD NOT have its own
`contentDescription`. Children provide their own semantics.

---

## Content Primitives

### `txt` — Text

Displays a text string with a typographic style.

**Signature:**
```
identifier = txt("text", style?, max_lines?)
```

**Arguments:**

| Pos | Name | Type | Required | Default | Description |
|-----|------|------|----------|---------|-------------|
| 0 | text | String | Yes | — | The text content to display |
| 1 | style | TxtStyle enum | No | `body` | Typographic style |
| — | max_lines | Integer (named only) | No | unlimited | Maximum number of visible lines before truncation |

**TxtStyle enum values:**

| Value | Semantic | Typical Use |
|-------|----------|-------------|
| `display` | Largest, most prominent | Hero numbers (temperature, price) |
| `headline` | Section heading | Page titles, section headers |
| `title` | Item title | Card titles, list item names |
| `body` | Standard body text | Paragraphs, descriptions |
| `caption` | Small secondary text | Timestamps, addresses, metadata |
| `mono` | Monospaced | Code, technical values, IDs |
| `label` | Small medium-weight | Form labels, button-adjacent text |
| `overline` | Smallest, uppercase | Category labels, section prefixes |

**Example:**
```
heading = txt("Search Results", headline)
name = txt("Luigi's Restaurant", title)
addr = txt("119 Mulberry St, New York", caption)
temp = txt("62°", display)
code = txt("ORDER-4829", mono)
long_text = txt("This is a very long description that might overflow", body, max_lines=3)
```

**Compose Mapping:**
```kotlin
Text(
    text = node.text,
    style = AmeTheme.textStyle(node.style),
    maxLines = node.maxLines ?: Int.MAX_VALUE,
    overflow = TextOverflow.Ellipsis
)
```

**Accessibility:** The text content is automatically readable by screen readers.
No additional `contentDescription` is needed.

---

### `img` — Image

Displays an image loaded from a URL.

**Signature:**
```
identifier = img("url", height?)
```

**Arguments:**

| Pos | Name | Type | Required | Default | Description |
|-----|------|------|----------|---------|-------------|
| 0 | url | String (URL) | Yes | — | HTTP(S) URL of the image |
| 1 | height | Integer (dp) | No | intrinsic | Fixed height in dp. Width fills available space. |

**Example:**
```
hero = img("https://example.com/restaurant.jpg", 180)
avatar = img("https://example.com/avatar.png", 48)
```

**Compose Mapping:**
```kotlin
AsyncImage(
    model = node.url,
    contentDescription = null,
    modifier = Modifier
        .fillMaxWidth()
        .then(if (node.height != null) Modifier.height(node.height.dp) else Modifier),
    contentScale = ContentScale.Crop
)
```

A conforming renderer SHOULD show a shimmer or placeholder while the image
loads, and an error placeholder if loading fails.

**Accessibility:** Images rendered by `img` are decorative by default (no
`contentDescription`). If the image conveys essential information, the host
app SHOULD wrap it in a semantics modifier with an appropriate description.

---

### `icon` — Material Icon

Displays a named icon from the Material Icons set.

**Signature:**
```
identifier = icon("name", size?)
```

**Arguments:**

| Pos | Name | Type | Required | Default | Description |
|-----|------|------|----------|---------|-------------|
| 0 | name | String | Yes | — | Material icon name (e.g., `"star"`, `"email"`, `"phone"`) |
| 1 | size | Integer (dp) | No | `20` | Icon size in dp |

**Example:**
```
star = icon("star", 24)
weather = icon("partly_cloudy_day", 28)
check = icon("check_circle")
```

**Icon name reference:** Use names from the
[Material Icons catalog](https://fonts.google.com/icons). Use the
snake_case variant (e.g., `partly_cloudy_day`, not `PartlyCloudyDay`).

A conforming renderer MUST maintain a lookup table mapping icon name strings
to platform icon objects. If the name is not found, the renderer MUST display
a fallback icon (e.g., a question mark) and SHOULD log a warning.

**Compose Mapping:**
```kotlin
Icon(
    imageVector = materialIconByName(node.name) ?: Icons.Default.HelpOutline,
    contentDescription = node.name.replace("_", " "),
    modifier = Modifier.size(node.size.dp)
)
```

**Accessibility:** The renderer SHOULD derive a `contentDescription` from the
icon name by replacing underscores with spaces (e.g., `"check_circle"` →
`"check circle"`).

---

### `divider` — Horizontal Line

Renders a thin horizontal line to visually separate content.

**Signature:**
```
identifier = divider()
```

**Arguments:** None.

**Example:**
```
sep = divider()
```

**Compose Mapping:**
```kotlin
HorizontalDivider()
```

**Accessibility:** Dividers are decorative. A conforming renderer SHOULD
exclude them from the accessibility tree.

---

### `spacer` — Empty Space

Adds vertical whitespace between elements.

**Signature:**
```
identifier = spacer(height?)
```

**Arguments:**

| Pos | Name | Type | Required | Default | Description |
|-----|------|------|----------|---------|-------------|
| 0 | height | Integer (dp) | No | `8` | Height of the space in dp |

**Example:**
```
gap = spacer(16)
small_gap = spacer()
```

**Compose Mapping:**
```kotlin
Spacer(modifier = Modifier.height(node.height.dp))
```

**Accessibility:** Spacers are invisible. They MUST be excluded from the
accessibility tree.

---

## Semantic Primitives

### `card` — Elevated Container

A visually distinct container with elevation or border that groups related
content. Children are arranged vertically inside the card.

**Signature:**
```
identifier = card([children], elevation?)
```

**Arguments:**

| Pos | Name | Type | Required | Default | Description |
|-----|------|------|----------|---------|-------------|
| 0 | children | Array of identifiers | Yes | — | Child elements, rendered in a vertical column |
| 1 | elevation | Integer (dp) | No | `1` | Shadow elevation in dp |

**Example:**
```
info_card = card([title, description, action_row])
flat_card = card([content], 0)
```

**Compose Mapping:**
```kotlin
Card(
    elevation = CardDefaults.cardElevation(defaultElevation = node.elevation.dp),
    modifier = Modifier.fillMaxWidth()
) {
    Column(
        modifier = Modifier.padding(12.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        children.forEach { child -> AmeRenderer(child) }
    }
}
```

**Accessibility:** `card` is a structural container. The card itself SHOULD
be grouped as a single semantics node so screen readers treat the card as a
unit. Interactive children (buttons) within the card remain individually
focusable.

---

### `badge` — Label Tag

A small colored label used for status indicators, counts, or categories.

**Signature:**
```
identifier = badge("label", variant?)
```

**Arguments:**

| Pos | Name | Type | Required | Default | Description |
|-----|------|------|----------|---------|-------------|
| 0 | label | String | Yes | — | Text displayed in the badge |
| 1 | variant | BadgeVariant enum | No | `default` | Color variant |

**BadgeVariant enum values:**

| Value | Semantic | Typical Color |
|-------|----------|--------------|
| `default` | Neutral | Surface variant / gray |
| `success` | Positive outcome | Green |
| `warning` | Caution | Orange / amber |
| `error` | Negative outcome | Red |
| `info` | Informational | Primary / blue |

**Example:**
```
rating = badge("★4.5", info)
status = badge("Active", success)
count = badge("3 unread", warning)
tag = badge("New", success)
```

**Compose Mapping:**
```kotlin
Surface(
    shape = RoundedCornerShape(4.dp),
    color = AmeTheme.badgeColor(node.variant),
    modifier = Modifier.padding(horizontal = 2.dp)
) {
    Text(
        text = node.label,
        style = MaterialTheme.typography.labelSmall,
        modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp)
    )
}
```

**Accessibility:** The badge text MUST be readable by screen readers. The
variant SHOULD be conveyed through the `contentDescription` (e.g., "3 unread,
warning").

---

### `progress` — Progress Indicator

A horizontal progress bar with an optional label.

**Signature:**
```
identifier = progress(value, "label"?)
```

**Arguments:**

| Pos | Name | Type | Required | Default | Description |
|-----|------|------|----------|---------|-------------|
| 0 | value | Float (0.0 – 1.0) | Yes | — | Progress fraction. 0.0 = empty, 1.0 = full. |
| 1 | label | String | No | none | Text displayed above or beside the bar |

A conforming parser MUST clamp `value` to the range [0.0, 1.0]. Values
outside this range SHOULD be clamped silently.

**Example:**
```
reading = progress(0.67, "67% complete")
upload = progress(0.3)
done = progress(1.0, "Complete")
```

**Compose Mapping:**
```kotlin
Column {
    if (node.label != null) {
        Text(
            text = node.label,
            style = MaterialTheme.typography.labelSmall
        )
        Spacer(Modifier.height(4.dp))
    }
    LinearProgressIndicator(
        progress = { node.value.coerceIn(0f, 1f) },
        modifier = Modifier.fillMaxWidth()
    )
}
```

**Accessibility:** The renderer MUST provide a `contentDescription` combining
the label (if present) and the percentage value (e.g., "67% complete, 67
percent").

---

## Interactive Primitives

### `btn` — Button

A tappable button that triggers an action when pressed.

**Signature:**
```
identifier = btn("label", action, style?, icon?)
```

**Arguments:**

| Pos | Name | Type | Required | Default | Description |
|-----|------|------|----------|---------|-------------|
| 0 | label | String | Yes | — | Button text |
| 1 | action | Action expression | Yes | — | What happens on tap. See [actions.md](actions.md). |
| 2 | style | BtnStyle enum | No | `primary` | Visual style |
| — | icon | String (named only) | No | none | Material icon name shown before label |

**BtnStyle enum values:**

| Value | Appearance | Typical Use |
|-------|-----------|-------------|
| `primary` | Filled, prominent | Main call-to-action |
| `secondary` | Tonal fill, less prominent | Secondary actions |
| `outline` | Bordered, no fill | Alternative options |
| `text` | No fill, no border, just text | Tertiary actions, links |
| `destructive` | Error-colored fill | Delete, remove, cancel with consequence |

**Example:**
```
save = btn("Save", tool(add_note, title="Meeting Notes"), primary)
directions = btn("Directions", uri("geo:40.72,-73.99"), text)
go_home = btn("Home", nav("home"), outline)
copy_addr = btn("Copy", copy("119 Mulberry St"), text)
confirm = btn("Book Now", submit(create_reservation, restaurant="Luigi's"), primary)
delete = btn("Delete", tool(delete_item, id="42"), destructive)
call = btn("Call", uri("tel:+15551234567"), primary, icon="phone")
```

**Compose Mapping:**
```kotlin
val onClick = {
    when (val action = node.action) {
        is AmeAction.Submit -> {
            val collected = formState.collectValues()
            val resolved = formState.resolveInputReferences(action.staticArgs)
            onAction(AmeAction.CallTool(action.toolName, resolved + collected))
        }
        else -> onAction(action)
    }
}

when (node.style) {
    BtnStyle.PRIMARY -> Button(onClick = onClick) {
        if (node.icon != null) {
            Icon(materialIconByName(node.icon), null, Modifier.size(16.dp))
            Spacer(Modifier.width(4.dp))
        }
        Text(node.label)
    }
    BtnStyle.SECONDARY -> FilledTonalButton(onClick = onClick) { Text(node.label) }
    BtnStyle.OUTLINE -> OutlinedButton(onClick = onClick) { Text(node.label) }
    BtnStyle.TEXT -> TextButton(onClick = onClick) { Text(node.label) }
    BtnStyle.DESTRUCTIVE -> Button(
        onClick = onClick,
        colors = ButtonDefaults.buttonColors(
            containerColor = MaterialTheme.colorScheme.error
        )
    ) { Text(node.label) }
}
```

**Accessibility:** The button MUST have a `contentDescription` matching the
label text. If an `icon` is present, the icon is decorative — the label
provides the accessible name.

**Security:** Actions dispatched from buttons MUST be routed through the host
app's trust and confirmation pipeline. The AME renderer MUST NOT execute
tool calls directly — it dispatches them to the `AmeActionHandler` interface,
and the host app decides whether to execute, confirm, or block. See
[actions.md](actions.md).

---

### `input` — Form Input Field

A text entry field for collecting user data. The `id` argument provides a
unique key for form data binding — see `submit()` action in
[actions.md](actions.md).

**Signature:**
```
identifier = input(id, "label", type?, options?)
```

**Arguments:**

| Pos | Name | Type | Required | Default | Description |
|-----|------|------|----------|---------|-------------|
| 0 | id | String | Yes | — | Unique key for form data binding |
| 1 | label | String | Yes | — | Visible label above the field |
| 2 | type | InputType enum | No | `text` | Input field type |
| — | options | Array of strings (named only) | No | none | Choices for `select` type |

**InputType enum values:**

| Value | Behavior | Platform Widget |
|-------|----------|----------------|
| `text` | Free-form text entry | Text field |
| `number` | Numeric keyboard | Text field with number keyboard |
| `email` | Email keyboard | Text field with email keyboard |
| `phone` | Phone number keyboard | Text field with phone keyboard |
| `date` | Date picker | Platform date picker dialog |
| `time` | Time picker | Platform time picker dialog |
| `select` | Dropdown selection | Dropdown menu (requires `options`) |

When `type` is `select`, the `options` named argument is REQUIRED. It MUST
be an array of strings representing the available choices.

**Example:**
```
name_field = input("name", "Your Name")
email_field = input("email", "Email Address", email)
date_field = input("date", "Date", date)
time_field = input("time", "Time", time)
guests = input("guests", "Party Size", select, options=["1","2","3","4","5","6"])
notes = input("notes", "Special Requests", text)
```

**Compose Mapping:**
```kotlin
val value by formState.registerInput(node.id, node.defaultValue ?: "")

when (node.type) {
    InputType.TEXT, InputType.EMAIL, InputType.PHONE, InputType.NUMBER ->
        OutlinedTextField(
            value = value,
            onValueChange = { value = it },
            label = { Text(node.label) },
            keyboardOptions = KeyboardOptions(keyboardType = node.type.toKeyboardType()),
            modifier = Modifier.fillMaxWidth()
        )
    InputType.DATE -> { /* Platform DatePicker dialog trigger */ }
    InputType.TIME -> { /* Platform TimePicker dialog trigger */ }
    InputType.SELECT -> { /* ExposedDropdownMenuBox with node.options */ }
}
```

**Accessibility:** The `label` MUST be associated with the input field for
screen readers. When `type` is `select`, the currently selected option MUST
be announced.

---

### `toggle` — On/Off Switch

A labeled toggle switch for boolean choices.

**Signature:**
```
identifier = toggle(id, "label", default?)
```

**Arguments:**

| Pos | Name | Type | Required | Default | Description |
|-----|------|------|----------|---------|-------------|
| 0 | id | String | Yes | — | Unique key for form data binding |
| 1 | label | String | Yes | — | Visible label next to the switch |
| 2 | default | Boolean | No | `false` | Initial checked state |

**Example:**
```
agree = toggle("agree", "I agree to the terms")
notify = toggle("notifications", "Enable notifications", true)
```

**Compose Mapping:**
```kotlin
val checked by formState.registerToggle(node.id, node.default)

Row(
    modifier = Modifier.fillMaxWidth(),
    horizontalArrangement = Arrangement.SpaceBetween,
    verticalAlignment = Alignment.CenterVertically
) {
    Text(text = node.label, style = MaterialTheme.typography.bodyMedium)
    Switch(checked = checked, onCheckedChange = { checked = it })
}
```

**Accessibility:** The `label` MUST be associated with the switch. The
current state (on/off) MUST be announced by screen readers.

---

## Data Primitives

### `list` — Vertical List

A vertical list of children, optionally separated by dividers. Unlike `col`,
`list` is semantically a data container — it communicates that the children
are items in a collection.

**Signature:**
```
identifier = list([children], dividers?)
```

**Arguments:**

| Pos | Name | Type | Required | Default | Description |
|-----|------|------|----------|---------|-------------|
| 0 | children | Array of identifiers | Yes | — | List items |
| 1 | dividers | Boolean | No | `true` | Show divider lines between items |

**Example:**
```
results = list([item1, item2, item3])
clean_list = list([a, b, c], false)
```

**Compose Mapping:**
```kotlin
Column(modifier = Modifier.fillMaxWidth()) {
    children.forEachIndexed { index, child ->
        if (node.dividers && index > 0) {
            HorizontalDivider()
        }
        AmeRenderer(child)
    }
}
```

**Accessibility:** The renderer SHOULD mark the list as a semantic collection
so screen readers announce "list, X items" when entering.

---

### `table` — Data Table

A grid of text values with a header row. Suitable for structured data like
specifications, comparisons, or key-value summaries.

**Signature:**
```
identifier = table(headers, rows)
```

**Arguments:**

| Pos | Name | Type | Required | Default | Description |
|-----|------|------|----------|---------|-------------|
| 0 | headers | Array of strings | Yes | — | Column header labels |
| 1 | rows | Array of arrays of strings | Yes | — | Data rows. Each row is an array of cell values matching header count. |

The number of values in each row SHOULD match the number of headers. If a
row has fewer values, remaining cells SHOULD render as empty. If a row has
more values, extra values SHOULD be silently ignored.

**Example:**
```
specs = table(["Feature", "Basic", "Pro"], [["Storage", "50 GB", "500 GB"], ["Users", "1", "10"], ["Support", "Email", "24/7"]])
```

**Compose Mapping:**
```kotlin
Column(modifier = Modifier.fillMaxWidth()) {
    // Header row
    Row(modifier = Modifier.fillMaxWidth()) {
        headers.forEach { header ->
            Text(
                text = header,
                style = MaterialTheme.typography.labelMedium,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.weight(1f)
            )
        }
    }
    HorizontalDivider()
    // Data rows
    rows.forEach { row ->
        Row(modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp)) {
            headers.indices.forEach { i ->
                Text(
                    text = row.getOrElse(i) { "" },
                    style = MaterialTheme.typography.bodySmall,
                    modifier = Modifier.weight(1f)
                )
            }
        }
    }
}
```

**Accessibility:** The renderer SHOULD use semantic table annotations so
screen readers can navigate by row and column. Each cell SHOULD announce
its column header (e.g., "Storage: 500 GB").

---

## Summary: All Primitives at a Glance

| # | Primitive | Category | Required Args | Optional Args | Has Actions |
|---|-----------|----------|---------------|---------------|-------------|
| 1 | `col` | Layout | `[children]` | `align` | No |
| 2 | `row` | Layout | `[children]` | `align`, `gap` | No |
| 3 | `txt` | Content | `"text"` | `style`, `max_lines` | No |
| 4 | `img` | Content | `"url"` | `height` | No |
| 5 | `icon` | Content | `"name"` | `size` | No |
| 6 | `divider` | Content | — | — | No |
| 7 | `spacer` | Content | — | `height` | No |
| 8 | `card` | Semantic | `[children]` | `elevation` | No |
| 9 | `badge` | Semantic | `"label"` | `variant` | No |
| 10 | `progress` | Semantic | `value` | `"label"` | No |
| 11 | `btn` | Interactive | `"label"`, `action` | `style`, `icon` | Yes |
| 12 | `input` | Interactive | `id`, `"label"` | `type`, `options` | No (data) |
| 13 | `toggle` | Interactive | `id`, `"label"` | `default` | No (data) |
| 14 | `list` | Data | `[children]` | `dividers` | No |
| 15 | `table` | Data | `headers`, `rows` | — | No |

---

## All Enum Types

### TxtStyle

| Value | Description |
|-------|-------------|
| `display` | Largest, most prominent text |
| `headline` | Section heading |
| `title` | Item or card title |
| `body` | Standard body text (default) |
| `caption` | Small secondary text |
| `mono` | Monospaced text |
| `label` | Small medium-weight text |
| `overline` | Smallest, uppercase text |

### BtnStyle

| Value | Description |
|-------|-------------|
| `primary` | Filled, prominent (default) |
| `secondary` | Tonal fill, less prominent |
| `outline` | Bordered, no fill |
| `text` | No fill, no border |
| `destructive` | Error-colored fill |

### BadgeVariant

| Value | Description |
|-------|-------------|
| `default` | Neutral (default) |
| `success` | Positive / green |
| `warning` | Caution / amber |
| `error` | Negative / red |
| `info` | Informational / blue |

### InputType

| Value | Description |
|-------|-------------|
| `text` | Free-form text (default) |
| `number` | Numeric input |
| `email` | Email address |
| `phone` | Phone number |
| `date` | Date picker |
| `time` | Time picker |
| `select` | Dropdown (requires `options`) |

### Align

| Value | Description |
|-------|-------------|
| `start` | Left-aligned / top-aligned (default) |
| `center` | Center-aligned |
| `end` | Right-aligned / bottom-aligned |
| `space_between` | Even spacing, no edge padding (row only) |
| `space_around` | Even spacing with edge padding (row only) |

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-04-05 | Initial specification |
