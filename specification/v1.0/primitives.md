# AME Primitives Specification — v1.0

## Introduction

This document defines the 21 standard AME primitives: the built-in UI elements
that every conforming AME renderer MUST support. Each primitive is a composable
building block that maps to a native platform widget.

Primitives are organized into ten categories:

| Category | Primitives | Purpose |
|----------|-----------|---------|
| Layout | `col`, `row` | Arrange children vertically or horizontally |
| Content | `txt`, `img`, `icon`, `divider`, `spacer` | Display text, images, icons, and whitespace |
| Semantic | `card`, `badge`, `progress` | Meaningful containers, labels, and indicators |
| Interactive | `btn`, `input`, `toggle` | User actions and form data entry |
| Data | `list`, `table` | Structured data display |
| Visualization | `chart` | Data charts (line, bar, pie, sparkline) |
| Rich Content | `code` | Syntax-highlighted code display |
| Disclosure | `accordion`, `carousel` | Collapsible and scrollable containers |
| Alert | `callout` | Alerts, tips, warnings, and info boxes |
| Sequence | `timeline`, `timeline_item` | Ordered event sequences with status |

For the syntax rules governing how primitives are called, see
[syntax.md](syntax.md). For action types used by interactive primitives, see
[actions.md](actions.md).

### How to Read This Document

Each primitive entry includes:

- **Signature** — the call syntax with argument positions
- **Arguments** — table with position, name, type, required/optional, default
- **Example** — minimal valid AME syntax using this primitive
- **Compose Mapping** — the Jetpack Compose composable this maps to (informative, not normative)
- **SwiftUI Mapping** — the SwiftUI view this maps to (informative, not normative)
- **Accessibility** — guidance for screen reader support
- **Error Handling** — how renderers handle malformed or missing arguments

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

**SwiftUI Mapping:**
```swift
VStack(alignment: mapAlignment(align), spacing: 8) {
    ForEach(children) { child in
        AmeRenderer(node: child, formState: formState, onAction: onAction)
    }
}
```

**Accessibility:** `col` is a structural container. It SHOULD NOT have its own
`contentDescription`. Children provide their own semantics.

**Error Handling:**

- Empty children array renders an empty column (not an error).
- Unknown `align` value defaults to `start` and logs a warning.

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

**SwiftUI Mapping:**
```swift
HStack(spacing: CGFloat(gap)) {
    ForEach(children) { child in
        AmeRenderer(node: child, formState: formState, onAction: onAction)
    }
}
// space_between: children separated by Spacer()
// space_around: Spacer() at edges and between children
```

**Accessibility:** `row` is a structural container. It SHOULD NOT have its own
`contentDescription`. Children provide their own semantics.

**Error Handling:**

- Empty children array renders an empty row (not an error).
- When a numeric literal appears at position 1, it is interpreted as `gap`,
  not `align`.
- Unknown `align` value defaults to `start` and logs a warning.

---

## Content Primitives

### `txt` — Text

Displays a text string with a typographic style.

**Signature:**
```
identifier = txt("text", style?, max_lines?, color?)
```

**Arguments:**

| Pos | Name | Type | Required | Default | Description |
|-----|------|------|----------|---------|-------------|
| 0 | text | String | Yes | — | The text content to display |
| 1 | style | TxtStyle enum | No | `body` | Typographic style |
| — | max_lines | Integer (named only) | No | unlimited | Maximum number of visible lines before truncation |
| — | color | SemanticColor enum (named only) | No | none (theme default) | Text color override using semantic tokens |

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
order_id = txt("ORDER-4829", mono)
long_text = txt("This is a very long description that might overflow", body, max_lines=3)
alert = txt("3 items expiring soon", body, color=warning)
error_msg = txt("Payment failed", body, color=error)
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

**SwiftUI Mapping:**
```swift
Text(text)
    .font(AmeTheme.font(style))
    .lineLimit(maxLines)
// overline style adds .textCase(.uppercase)
```

**Accessibility:** The text content is automatically readable by screen readers.
No additional `contentDescription` is needed.

**Error Handling:**

- Missing text uses an empty string.
- Unknown `style` value defaults to `body` and logs a warning.
- Non-integer `max_lines` value is silently ignored.

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

**SwiftUI Mapping:**
```swift
AsyncImage(url: URL(string: url)) { phase in
    switch phase {
    case .success(let image):
        image.resizable().scaledToFill()
    case .failure:
        Image(systemName: "photo").foregroundColor(.secondary)
    case .empty:
        RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.2))
    @unknown default:
        EmptyView()
    }
}
.frame(maxWidth: .infinity)
.frame(height: height.map { CGFloat($0) })
.clipped()
```

A conforming renderer SHOULD show a shimmer or placeholder while the image
loads, and an error placeholder if loading fails.

**Accessibility:** Images rendered by `img` are decorative by default (no
`contentDescription`). If the image conveys essential information, the host
app SHOULD wrap it in a semantics modifier with an appropriate description.

**Error Handling:**

- Missing or malformed URL renders an error placeholder image.
- Missing `height` uses the image's intrinsic height.

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

**SwiftUI Mapping:**
```swift
Image(systemName: AmeIcons.resolve(name))
    .font(.system(size: CGFloat(size)))
    .accessibilityLabel(AmeIcons.contentDescription(name))
```

**Accessibility:** The renderer SHOULD derive a `contentDescription` from the
icon name by replacing underscores with spaces (e.g., `"check_circle"` →
`"check circle"`).

**Error Handling:**

- Unknown icon name renders a fallback icon (question mark) and logs a
  warning.
- Missing `size` defaults to `20`.

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

**SwiftUI Mapping:**
```swift
Divider()
```

**Accessibility:** Dividers are decorative. A conforming renderer SHOULD
exclude them from the accessibility tree.

**Error Handling:**

- No arguments. Extra arguments, if provided, are silently ignored.

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

**SwiftUI Mapping:**
```swift
Spacer().frame(height: CGFloat(height))
```

**Accessibility:** Spacers are invisible. They MUST be excluded from the
accessibility tree.

**Error Handling:**

- Missing `height` defaults to `8`. Non-numeric value is silently ignored,
  defaults to `8`.

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

**SwiftUI Mapping:**
```swift
VStack(alignment: .leading, spacing: 8) {
    ForEach(children) { child in
        AmeRenderer(node: child, formState: formState, onAction: onAction)
    }
}
.padding(12)
.background(Color(.systemBackground))
.cornerRadius(12)
.shadow(color: .black.opacity(0.1), radius: CGFloat(elevation * 2), y: CGFloat(elevation))
```

**Accessibility:** `card` is a structural container. The card itself SHOULD
be grouped as a single semantics node so screen readers treat the card as a
unit. Interactive children (buttons) within the card remain individually
focusable.

**Error Handling:**

- Empty children array renders an empty card container (not an error).
- Missing `elevation` defaults to `1`.
- Negative elevation values are treated as `0`.

---

### `badge` — Label Tag

A small colored label used for status indicators, counts, or categories.

**Signature:**
```
identifier = badge("label", variant?, color?)
```

**Arguments:**

| Pos | Name | Type | Required | Default | Description |
|-----|------|------|----------|---------|-------------|
| 0 | label | String | Yes | — | Text displayed in the badge |
| 1 | variant | BadgeVariant enum | No | `default` | Color variant |
| — | color | SemanticColor enum (named only) | No | none (variant color) | Color override. When set, overrides the variant's default color. |

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
live = badge("Live", success, color=success)
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

**SwiftUI Mapping:**
```swift
Text(label)
    .font(.caption2)
    .foregroundColor(AmeTheme.badgeTextColor(variant))
    .padding(.horizontal, 6)
    .padding(.vertical, 2)
    .background(AmeTheme.badgeColor(variant))
    .cornerRadius(4)
```

**Accessibility:** The badge text MUST be readable by screen readers. The
variant SHOULD be conveyed through the `contentDescription` (e.g., "3 unread,
warning").

**Error Handling:**

- Missing `label` uses an empty string.
- Unknown `variant` value defaults to `default` and logs a warning.

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

**SwiftUI Mapping:**
```swift
VStack(alignment: .leading, spacing: 4) {
    if let label {
        Text(label).font(.caption)
    }
    ProgressView(value: Double(value))
}
.accessibilityValue("\(Int(value * 100)) percent")
```

**Accessibility:** The renderer MUST provide a `contentDescription` combining
the label (if present) and the percentage value (e.g., "67% complete, 67
percent").

**Error Handling:**

- Missing `value` defaults to `0.0`.
- Value outside [0.0, 1.0] is clamped silently.

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

**SwiftUI Mapping:**
```swift
Button {
    handleBtnAction(action)
} label: {
    HStack(spacing: 4) {
        if let iconName = icon {
            Image(systemName: AmeIcons.resolve(iconName)).font(.system(size: 14))
        }
        Text(label)
    }
}
.applyBtnStyle(style)
// primary: .buttonStyle(.borderedProminent)
// secondary: .buttonStyle(.bordered).tint(.secondary)
// outline: .buttonStyle(.bordered)
// text: .buttonStyle(.plain)
// destructive: .buttonStyle(.borderedProminent).tint(.red)
```

**Accessibility:** The button MUST have a `contentDescription` matching the
label text. If an `icon` is present, the icon is decorative. The label
provides the accessible name.

**Security:** Actions dispatched from buttons MUST be routed through the host
app's trust and confirmation pipeline. The AME renderer MUST NOT execute
tool calls directly. Instead, it dispatches them to the `AmeActionHandler`
interface, and the host app decides whether to execute, confirm, or block. See
[actions.md](actions.md).

**Error Handling:**

- Missing `action` renders a non-functional button and logs a warning.
- Unknown `style` value defaults to `primary` and logs a warning.
- Unknown `icon` name renders a fallback icon (question mark).

---

### `input` — Form Input Field

A text entry field for collecting user data. The `id` argument provides a
unique key for form data binding. See `submit()` action in
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

**SwiftUI Mapping:**
```swift
switch type {
case .text, .email, .phone, .number:
    TextField(label, text: formState.binding(for: id))
        .textFieldStyle(.roundedBorder)
        .keyboardType(type.toKeyboardType())
case .date:
    DatePicker(label, selection: formState.dateBinding(for: id), displayedComponents: .date)
case .time:
    DatePicker(label, selection: formState.dateBinding(for: id), displayedComponents: .hourAndMinute)
case .select:
    Picker(label, selection: formState.binding(for: id)) {
        ForEach(options ?? [], id: \.self) { Text($0).tag($0) }
    }.pickerStyle(.menu)
}
```

**Accessibility:** The `label` MUST be associated with the input field for
screen readers. When `type` is `select`, the currently selected option MUST
be announced.

**Error Handling:**

- Unknown `type` value defaults to `text` and logs a warning.
- Missing `options` for `select` type renders an empty dropdown.
- Missing `id` uses an empty string (form data binding will not work).

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

**SwiftUI Mapping:**
```swift
Toggle(label, isOn: formState.toggleBinding(for: id, default: defaultValue))
```

**Accessibility:** The `label` MUST be associated with the switch. The
current state (on/off) MUST be announced by screen readers.

**Error Handling:**

- Missing `default` defaults to `false`.
- Non-boolean `default` value is treated as `false`.

---

## Data Primitives

### `list` — Vertical List

A vertical list of children, optionally separated by dividers. Unlike `col`,
`list` is semantically a data container: it communicates that the children
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

**SwiftUI Mapping:**
```swift
VStack(spacing: 0) {
    ForEach(Array(children.enumerated()), id: \.offset) { index, child in
        if dividers && index > 0 {
            Divider()
        }
        AmeRenderer(node: child, formState: formState, onAction: onAction)
    }
}
```

**Accessibility:** The renderer SHOULD mark the list as a semantic collection
so screen readers announce "list, X items" when entering.

**Error Handling:**

- Empty children array renders an empty list (not an error).
- Missing `dividers` defaults to `true`.

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

**SwiftUI Mapping:**
```swift
Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 4) {
    GridRow {
        ForEach(headers, id: \.self) { header in
            Text(header).font(.caption).fontWeight(.bold)
        }
    }
    Divider()
    ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
        GridRow {
            ForEach(0..<headers.count, id: \.self) { i in
                Text(i < row.count ? row[i] : "").font(.caption)
            }
        }
    }
}
```

**Accessibility:** The renderer SHOULD use semantic table annotations so
screen readers can navigate by row and column. Each cell SHOULD announce
its column header (e.g., "Storage: 500 GB").

**Error Handling:**

- Row with fewer values than headers: remaining cells render as empty.
- Row with more values than headers: extra values are silently ignored.
- Empty headers or rows renders an empty table (not an error).

---

## Visualization Primitives

### `chart` — Data Visualization

A data visualization element that renders line, bar, pie, or sparkline charts
from numeric array data. Charts are read-only static snapshots: no touch
interactions, zooming, or animations. They are designed for inline data
summaries in chat cards, not interactive dashboards.

**Signature:**
```
identifier = chart(type, values, labels?, height?, color?)
```

**Arguments:**

| Pos | Name | Type | Required | Default | Description |
|-----|------|------|----------|---------|-------------|
| 0 | type | ChartType enum | Yes | — | Visualization type |
| 1 | values | Array of numbers OR `$path` | Yes | — | Primary data series |
| — | labels | Array of strings OR `$path` (named) | No | none | X-axis labels for `bar`/`line`; slice names for `pie` (Compose: drawn on segment; SwiftUI: shown in legend — see AUDIT_VERDICTS.md Bug 23 for v1.3 visual parity work). Ignored for `sparkline` (axes hidden) |
| — | series | Array of arrays OR `$path` (named) | No | none | Multiple data series (overrides `values` when present) |
| — | height | Integer dp (named) | No | `200` | Chart height in dp |
| — | color | SemanticColor enum (named) | No | `null` | Primary series color (renderer falls back to platform primary/accentColor when null) |

**ChartType enum values:**

| Value | Axes | Labels | Multi-series | Legend | Use Case |
|-------|------|--------|-------------|--------|----------|
| `line` | X + Y | Below x-axis | Yes — separate colored lines | Auto if series > 1 | Trends, time series |
| `bar` | X + Y | Below x-axis | Yes — grouped bars | Auto if series > 1 | Comparisons, distributions |
| `pie` | None | Segment labels | No — single values array | Auto-labeled segments | Proportions, breakdowns |
| `sparkline` | None | None | No | None — minimal inline | Inline trend indicator |

`values` and `labels` accept both inline array literals and `$path` references
to arrays in the data section. When using `$path`, the array is resolved per
the standard `$path` resolution rules in data-binding.md.

`series` provides multiple data series for `line` and `bar` charts. When
`series` is present, `values` is ignored. Each inner array is one series.

**Example:**

Bar chart with data binding:
```
root = col([title, spending])
title = txt("Monthly Spending", headline)
spending = chart(bar, values=$amounts, labels=$months, height=180)
---
{"months": ["Jan", "Feb", "Mar", "Apr"], "amounts": [420, 580, 510, 670]}
```

Multi-series line chart:
```
root = col([title, comparison])
title = txt("Revenue vs Expenses", headline)
comparison = chart(line, series=[$revenue, $expenses], labels=$quarters)
---
{"quarters": ["Q1", "Q2", "Q3", "Q4"], "revenue": [42, 58, 51, 67], "expenses": [38, 41, 45, 52]}
```

Inline sparkline:
```
trend = row([label, spark])
label = txt("BTC", body)
spark = chart(sparkline, values=$prices, height=32, color=success)
```

Pie chart:
```
breakdown = chart(pie, values=$amounts, labels=$categories, height=200)
```

**Compose Mapping:**

The chart renderer is pluggable via the `AmeChartRenderer` interface. The
default implementation uses pure Compose `Canvas` with zero external
dependencies:

```kotlin
fun interface AmeChartRenderer {
    @Composable
    fun RenderChart(chart: AmeNode.Chart, modifier: Modifier)
}

val LocalAmeChartRenderer = staticCompositionLocalOf<AmeChartRenderer> {
    CanvasChartRenderer()
}
```

Default `CanvasChartRenderer`:
- `bar`: `Canvas` + `drawRect()` per bar + x-axis labels + y-axis grid
- `line`: `Canvas` + `drawPath()` with `lineTo()` + optional area fill + grid
- `pie`: `Canvas` + `drawArc()` per segment + percentage labels + legend
- `sparkline`: `Canvas` + `drawPath()`, no axes, no labels, inline height

Colors via `MaterialTheme.colorScheme`. Multi-series uses a 5-color palette
derived from the primary color.

Host apps MAY override:
```kotlin
CompositionLocalProvider(LocalAmeChartRenderer provides MyChartRenderer()) {
    AmeRenderer(node = tree, onAction = ::handleAction)
}
```

**SwiftUI Mapping:**

Swift Charts framework (iOS 16+):
```swift
Chart {
    ForEach(data.enumerated(), id: \.offset) { index, value in
        switch chartType {
        case .line: LineMark(x: .value("X", label), y: .value("Y", value))
        case .bar: BarMark(x: .value("X", label), y: .value("Y", value))
        case .pie: SectorMark(angle: .value("Value", value))
        case .sparkline: LineMark(x: .value("X", index), y: .value("Y", value))
        }
    }
}
.frame(height: CGFloat(node.height))
// sparkline: .chartXAxis(.hidden).chartYAxis(.hidden)
```

**Accessibility:** Chart MUST provide a content description summarizing the
data. Example: "Bar chart showing monthly spending: January 420, February
580, March 510, April 670." Screen readers SHOULD read the summary, not
individual data points.

**Error Handling:**

- If `values` resolves to a non-array or empty array, render a text fallback:
  `txt("No chart data", caption)`
- If `labels` length does not match `values` length, use numeric indices
  ("1", "2", "3") as labels
- If `type` is unrecognized, fall back to `bar` and log a warning
- If `series` contains arrays of different lengths, truncate all to the
  shortest length

**Token Cost:** A single `chart()` call costs ~10-15 tokens. The equivalent
built from v1.0 primitives (a `table` of numbers + text descriptions) costs
~30-80 tokens and provides no visual insight. Net savings: 2-5x for data
visualization scenarios.

**Data Size Guidance:** LLMs SHOULD use `$path` references for datasets over
10 data points. Inline array literals (`values=[1,2,3,...]`) cost
approximately 2 tokens per value; `$path` references (`values=$amounts`)
cost 1 token regardless of dataset size. This guidance is non-normative.
Renderers MUST handle arrays of any length.

---

## Rich Content Primitives

### `code` — Code Block

A syntax-highlighted code block with language identification and a copy
affordance. Designed for displaying code snippets, configuration files, API
responses, and technical output in chat cards.

**Signature:**
```
identifier = code(language, content, title?)
```

**Arguments:**

| Pos | Name | Type | Required | Default | Description |
|-----|------|------|----------|---------|-------------|
| 0 | language | String | Yes | — | Language identifier for syntax highlighting |
| 1 | content | String | Yes | — | Source code text. Newlines encoded as `\n` per syntax.md Rule 8. |
| 2 | title | String | No | none | Optional header text (filename, description) |

**Supported language identifiers (minimum set; renderers MAY support more):**

`kotlin`, `swift`, `java`, `python`, `javascript`, `typescript`, `json`,
`xml`, `html`, `css`, `bash`, `sql`, `rust`, `go`, `c`, `cpp`, `ruby`,
`yaml`, `toml`, `markdown`, `text`

If the language identifier is unrecognized, the renderer MUST fall back to
plain monospace text with no highlighting.

**Example:**

```
snippet = code("kotlin", "val items = listOf(1, 2, 3)\nval sum = items.sum()\nprintln(\"Sum: $sum\")")
```

With title:
```
config = code("yaml", "server:\n  port: 8080\n  host: 0.0.0.0", "application.yml")
```

In context:
```
root = col([title, explanation, example])
title = txt("Quick Sort in Python", headline)
explanation = txt("A divide-and-conquer sorting algorithm:", body)
example = code("python", "def quicksort(arr):\n    if len(arr) <= 1:\n        return arr\n    pivot = arr[0]\n    left = [x for x in arr[1:] if x < pivot]\n    right = [x for x in arr[1:] if x >= pivot]\n    return quicksort(left) + [pivot] + quicksort(right)")
```

**String Escaping:** The `content` argument uses standard AME string escaping
(per syntax.md Rule 8). Newlines are `\n`. Quotes are `\"`. Backslashes are
`\\`. Tabs are `\t`. Multi-line code is encoded as a single string with
embedded `\n` characters. AME is line-oriented and each statement must be
on one line.

**Compose Mapping:**
```kotlin
Surface(
    color = Color(0xFF1E1E1E),
    shape = RoundedCornerShape(8.dp)
) {
    Column {
        if (node.title != null) {
            Row(
                modifier = Modifier.fillMaxWidth().padding(8.dp),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Text(node.title, style = typography.labelSmall, color = Color.Gray)
                IconButton(onClick = { clipboard.setText(node.content) }) {
                    Icon(Icons.Default.ContentCopy, "Copy", tint = Color.Gray)
                }
            }
        }
        SelectionContainer {
            Text(
                text = highlightSyntax(node.content, node.language),
                fontFamily = FontFamily.Monospace,
                style = typography.bodySmall,
                modifier = Modifier.horizontalScroll(rememberScrollState()).padding(12.dp)
            )
        }
    }
}
```

**SwiftUI Mapping:**
```swift
VStack(alignment: .leading, spacing: 0) {
    if let title = node.title {
        HStack {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Spacer()
            Button { UIPasteboard.general.string = node.content } label: {
                Image(systemName: "doc.on.doc").font(.caption)
            }
        }.padding(8)
    }
    ScrollView(.horizontal, showsIndicators: false) {
        Text(highlightSyntax(node.content, node.language))
            .font(.system(.body, design: .monospaced))
            .padding(12)
    }
}
.background(Color(.systemGray6))
.clipShape(RoundedRectangle(cornerRadius: 8))
```

**Syntax Highlighting Strategy:** Renderers MUST support at least keyword +
string + comment highlighting for the 5 most common languages (kotlin, swift,
python, javascript, json). Additional language support is RECOMMENDED but not
REQUIRED. A conforming renderer MAY render all code as plain monospace if
syntax highlighting is not available. The code MUST still be readable and
copyable.

**Copy Affordance:** The renderer MUST provide a mechanism to copy the code
content to the system clipboard. This is typically a small icon button in the
header or corner of the code block. The copy action is NOT dispatched through
the host app's action handler. It is an intrinsic renderer behavior (like
text selection), not an AME action.

**Accessibility:** The code block MUST be readable by screen readers. The
content description SHOULD include the language and title if present:
"Kotlin code block: application.yml". The code text MUST be selectable.

**Error Handling:**

- If `content` is empty, render an empty code block with the language header.
- If `language` is unrecognized, render as plain monospace text (no
  highlighting) — do not render a fallback txt node.

**Token Cost:** A `code()` call costs the code content tokens + ~4 tokens for
the wrapper (language string, parentheses, identifier). The equivalent v1.0
approach (`txt(content, mono)`) costs the same tokens but provides no syntax
highlighting, no language label, no copy button. Token cost is identical; UX
is dramatically better.

**Content Length Guidance:** LLMs SHOULD limit code content to approximately
30 lines per `code()` block. Longer code SHOULD be split into multiple blocks
with explanatory text, or the LLM SHOULD offer to display the full code via
a tool call rather than inlining it. This guidance is non-normative.
Renderers MUST handle code of any length.

---

## Disclosure Primitives

### `accordion` — Collapsible Section

A collapsible section with a header that toggles visibility of its children.
The header is always visible; the children are shown or hidden when the user
taps the header. Designed for FAQ lists, expandable details, and dense
information layouts where not all content needs to be visible simultaneously.

**Signature:**
```
identifier = accordion(title, [children], expanded?)
```

**Arguments:**

| Pos | Name | Type | Required | Default | Description |
|-----|------|------|----------|---------|-------------|
| 0 | title | String | Yes | — | Header text (always visible, toggles children) |
| 1 | children | Array of identifiers | Yes | — | Content shown/hidden on toggle |
| 2 | expanded | Boolean | No | `false` | Initial expanded state. v1.2+ runtimes track external updates: if the host re-renders with a changed `expanded` value the UI follows. Local user toggles take effect immediately and persist until the next external change. |

**Example:**

```
root = col([summary, side_effects, interactions])
summary = txt("Ibuprofen is a nonsteroidal anti-inflammatory drug.", body)
side_effects = accordion("Side Effects", [se1, se2, se3])
se1 = txt("Nausea — Common, usually mild", body)
se2 = txt("Dizziness — Uncommon", body)
se3 = txt("Stomach bleeding — Rare, seek medical attention", body)
interactions = accordion("Drug Interactions", [di1, di2], true)
di1 = txt("Aspirin — increased bleeding risk", body)
di2 = txt("Warfarin — significantly increased bleeding risk", body)
```

FAQ pattern:
```
root = col([title, q1, q2, q3])
title = txt("Frequently Asked Questions", headline)
q1 = accordion("What is AME?", [a1])
a1 = txt("AME is a compact syntax for LLMs to generate native mobile UI.", body)
q2 = accordion("How many primitives are there?", [a2])
a2 = txt("AME v1.2 has 21 built-in primitives.", body)
q3 = accordion("Is AME open source?", [a3])
a3 = txt("Yes, AME is Apache 2.0 licensed.", body)
```

**Compose Mapping:**
```kotlin
var isExpanded by remember { mutableStateOf(node.expanded) }
Column(modifier = modifier.fillMaxWidth()) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { isExpanded = !isExpanded }
            .padding(12.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(node.title, style = MaterialTheme.typography.titleMedium)
        Icon(
            imageVector = if (isExpanded) Icons.Filled.ExpandLess
                          else Icons.Filled.ExpandMore,
            contentDescription = if (isExpanded) "Collapse" else "Expand"
        )
    }
    AnimatedVisibility(visible = isExpanded) {
        Column(modifier = Modifier.padding(start = 12.dp, end = 12.dp, bottom = 12.dp)) {
            children.forEach { child -> AmeRenderer(child) }
        }
    }
}
```

**SwiftUI Mapping:**
```swift
DisclosureGroup(node.title, isExpanded: $isExpanded) {
    ForEach(Array(children.enumerated()), id: \.offset) { _, child in
        AmeRenderer(node: child, formState: formState, onAction: onAction)
    }
}
```

**Accessibility:** The header row MUST be announced as "button, collapsed" or
"button, expanded" by screen readers. When expanded, children MUST be
accessible in the standard reading order. The expand/collapse toggle MUST be
operable via switch access and keyboard navigation.

**Nesting:** Accordions MAY contain other accordions (nested collapsible
sections). Renderers SHOULD support at least 3 levels of nested accordions.
Deeper nesting is OPTIONAL and MAY be rendered flat. This is enforced by the
existing `MAX_DEPTH` limit (12) shared with all container primitives.

**Error Handling:**

- If `children` is empty, render the header with the toggle affordance but
  nothing expands — this is not an error.
- If `expanded` is not a valid boolean, default to `false`.

**Token Cost:** An `accordion()` call costs ~8-10 tokens (title + children
reference + identifier). Without accordion, the LLM would either dump all
content as visible text (more tokens, worse UX) or omit detail (less useful).
Accordion enables information density at lower token cost.

---

### `carousel` — Horizontal Scrollable Container

A horizontally scrollable container for browsing a set of items. Designed for
product cards, image galleries, option selection, and any pattern where the
user swipes through a set of peers. Items are clipped at the container edge
with a configurable peek affordance showing a sliver of the next item.

**Signature:**
```
identifier = carousel([children], peek?)
```

**Arguments:**

| Pos | Name | Type | Required | Default | Description |
|-----|------|------|----------|---------|-------------|
| 0 | children | Array of identifiers | Yes | — | Items to display horizontally |
| — | peek | Integer dp (named) | No | `24` | dp of the next item visible at the trailing edge |

The `peek` value creates a visual affordance that more items exist beyond the
visible area. Setting `peek=0` hides the next item entirely.

**Example:**

```
root = col([title, products])
title = txt("Running Shoes Under $100", headline)
products = carousel([shoe1, shoe2, shoe3, shoe4])
shoe1 = card([img1, name1, price1, buy1])
img1 = img("https://example.com/shoe1.jpg", 120)
name1 = txt("Air Zoom Pegasus", title)
price1 = txt("$89.99", body)
buy1 = btn("Add to Cart", tool(add_to_cart, product_id="shoe1"))
shoe2 = card([img2, name2, price2, buy2])
img2 = img("https://example.com/shoe2.jpg", 120)
name2 = txt("React Infinity", title)
price2 = txt("$94.99", body)
buy2 = btn("Add to Cart", tool(add_to_cart, product_id="shoe2"))
```

**Compose Mapping:**
```kotlin
LazyRow(
    horizontalArrangement = Arrangement.spacedBy(12.dp),
    contentPadding = PaddingValues(start = 16.dp, end = node.peek.dp)
) {
    items(node.children) { child ->
        Box(modifier = Modifier.fillParentMaxWidth(0.85f)) {
            AmeRenderer(child)
        }
    }
}
```

**SwiftUI Mapping:**
```swift
ScrollView(.horizontal, showsIndicators: false) {
    LazyHStack(spacing: 12) {
        ForEach(Array(children.enumerated()), id: \.offset) { _, child in
            AmeRenderer(node: child, formState: formState, onAction: onAction)
                .frame(width: UIScreen.main.bounds.width * 0.85)
        }
    }
    .padding(.horizontal, 16)
}
```

**Accessibility:** The carousel MUST be navigable via swipe gestures in
VoiceOver/TalkBack. Each item MUST be individually focusable. The container
SHOULD announce the total item count: "Carousel, 4 items."

**Error Handling:**

- If `children` is empty, render nothing (collapsed to zero height).
- If `children` has exactly 1 item, render it at full width without
  horizontal scroll affordance.
- If `peek` is negative, clamp to `0`. If `peek` exceeds half the
  container width, clamp to `container_width / 2`.

**Token Cost:** A `carousel()` call costs ~5 tokens (same as `col()`). The
children cost the same whether in a carousel or a column. Net token
difference: 0. The value is UX. Horizontal browsing is the standard mobile
pattern for item discovery.

---

## Alert Primitives

### `callout` — Alert / Info Box

A visually distinct box for alerts, tips, warnings, and informational
messages. Each callout type has a specific icon, background tint, and
semantic meaning. Designed for safety warnings, pro tips, error messages,
and success confirmations embedded within longer content.

**Signature:**
```
identifier = callout(type, content, title?)
```

**Arguments:**

| Pos | Name | Type | Required | Default | Description |
|-----|------|------|----------|---------|-------------|
| 0 | type | CalloutType enum | Yes | — | Visual style, icon, and semantic meaning |
| 1 | content | String | Yes | — | Message text |
| 2 | title | String | No | none | Optional header text above the message |

**CalloutType enum values:**

| Value | Icon (Material / SF Symbol) | Background | Use Case |
|-------|----------------------------|------------|----------|
| `info` | `info` / `info.circle` | Blue tint | Neutral information, did-you-know |
| `warning` | `warning` / `exclamationmark.triangle` | Amber tint | Caution, potential issues |
| `error` | `error` / `xmark.circle` | Red tint | Errors, critical problems |
| `success` | `check_circle` / `checkmark.circle` | Green tint | Confirmations, positive outcomes |
| `tip` | `lightbulb` / `lightbulb` | Purple tint | Suggestions, best practices |

**Example:**

Simple warning:
```
caution = callout(warning, "Do not take ibuprofen on an empty stomach.")
```

With title:
```
note = callout(tip, "You can also use Ctrl+Shift+P to open the command palette.", "Pro Tip")
```

In context:
```
root = col([recipe_title, ingredients, caution, steps])
recipe_title = txt("Thai Green Curry", headline)
ingredients = txt("2 tbsp curry paste, 400ml coconut milk, ...", body)
caution = callout(warning, "Coconut milk splatters when added to hot oil. Reduce heat before adding.", "Safety")
steps = txt("1. Heat oil on medium. 2. Add curry paste...", body)
```

**Compose Mapping:**
```kotlin
Surface(
    shape = RoundedCornerShape(8.dp),
    color = calloutBackgroundColor(node.type),
    modifier = modifier.fillMaxWidth()
) {
    Row(modifier = Modifier.padding(12.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Icon(
            imageVector = calloutIcon(node.type),
            contentDescription = null,
            tint = calloutTintColor(node.type),
            modifier = Modifier.size(24.dp)
        )
        Column {
            if (node.title != null) {
                Text(node.title, style = MaterialTheme.typography.labelLarge)
                Spacer(Modifier.height(4.dp))
            }
            Text(node.content, style = MaterialTheme.typography.bodyMedium)
        }
    }
}
```

**SwiftUI Mapping:**
```swift
HStack(alignment: .top, spacing: 12) {
    Image(systemName: calloutSFSymbol(node.type))
        .foregroundStyle(calloutColor(node.type))
        .font(.title3)
    VStack(alignment: .leading, spacing: 4) {
        if let title = node.title {
            Text(title).font(.headline)
        }
        Text(node.content).font(.body)
    }
}
.padding(12)
.background(
    RoundedRectangle(cornerRadius: 8)
        .fill(calloutColor(node.type).opacity(0.1))
)
```

**Accessibility:** The callout MUST be announced with its type prefix:
"Warning: Do not take ibuprofen on an empty stomach." The icon is
decorative. The type is conveyed through the spoken prefix, not the icon's
content description.

**Error Handling:**

- If `type` is unrecognized, fall back to `info` and log a warning.
- If `content` is empty, render the callout box with the icon and type label
  only.

**Token Cost:** A `callout()` call costs ~8-10 tokens. The equivalent v1.0
approach (a `card` with a `row` containing an `icon` and `txt`) costs ~25-30
tokens for the same visual. Net savings: 2.5-3x.

---

## Sequence Primitives

### `timeline` — Event Sequence

An ordered vertical sequence of events with status indicators and connecting
lines. Each child MUST be a `timeline_item`. Designed for order tracking,
process steps, historical sequences, and workflow status displays.

**Signature:**
```
identifier = timeline([children])
```

**Arguments:**

| Pos | Name | Type | Required | Default | Description |
|-----|------|------|----------|---------|-------------|
| 0 | children | Array of identifiers | Yes | — | `timeline_item` nodes rendered vertically with connectors |

Children SHOULD be `timeline_item` nodes. Non-`timeline_item` children are
rendered as plain content without timeline decoration (circle + connector
line).

**Example:**

Order tracking:
```
root = col([title, tracker])
title = txt("Order #4521", headline)
tracker = timeline([s1, s2, s3, s4])
s1 = timeline_item("Ordered", "Apr 3, 2:15 PM", done)
s2 = timeline_item("Shipped", "Apr 4, 9:30 AM", done)
s3 = timeline_item("In Transit", "Expected Apr 6", active)
s4 = timeline_item("Delivered", "", pending)
```

Historical sequence:
```
root = col([title, events])
title = txt("Key Events of 1969", headline)
events = timeline([e1, e2, e3])
e1 = timeline_item("Jan 20 — Nixon Inaugurated", "37th President of the United States", done)
e2 = timeline_item("Jul 20 — Moon Landing", "Apollo 11, Neil Armstrong and Buzz Aldrin", done)
e3 = timeline_item("Aug 15 — Woodstock", "3-day music festival in Bethel, New York", done)
```

Error state:
```
pipeline = timeline([build, test, deploy])
build = timeline_item("Build", "2m 31s", done)
test = timeline_item("Unit Tests", "Failed: 3 assertions", error)
deploy = timeline_item("Deploy", "", pending)
```

**Compose Mapping:**
```kotlin
Column(modifier = modifier) {
    node.children.forEachIndexed { index, child ->
        if (child is AmeNode.TimelineItem) {
            Row {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Box(
                        modifier = Modifier
                            .size(12.dp)
                            .clip(CircleShape)
                            .background(timelineStatusColor(child.status))
                    )
                    if (index < node.children.lastIndex) {
                        Box(
                            modifier = Modifier
                                .width(2.dp)
                                .height(48.dp)
                                .background(timelineLineColor(child.status))
                        )
                    }
                }
                Spacer(Modifier.width(12.dp))
                Column {
                    Text(child.title, style = typography.titleSmall)
                    if (!child.subtitle.isNullOrEmpty()) {
                        Text(child.subtitle, style = typography.bodySmall, color = Color.Gray)
                    }
                }
            }
        } else {
            AmeRenderer(child)
        }
    }
}
```

**SwiftUI Mapping:**
```swift
VStack(alignment: .leading, spacing: 0) {
    ForEach(Array(children.enumerated()), id: \.offset) { index, child in
        if case .timelineItem(let title, let subtitle, let status) = child {
            HStack(alignment: .top, spacing: 12) {
                VStack(spacing: 0) {
                    Circle()
                        .fill(timelineColor(status))
                        .frame(width: 12, height: 12)
                    if index < children.count - 1 {
                        Rectangle()
                            .fill(timelineLineColor(status))
                            .frame(width: 2, height: 48)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.subheadline).fontWeight(.medium)
                    if let sub = subtitle, !sub.isEmpty {
                        Text(sub).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
```

**Accessibility:** Each timeline item MUST be announced with its status:
"Done: Ordered, April 3, 2:15 PM." The timeline as a whole SHOULD announce
the total step count and current active step: "Order tracking, step 3 of 4,
In Transit."

**Error Handling:**

- If `children` is empty, render nothing.
- If `children` contains non-`timeline_item` nodes, render them as plain
  content without circle/connector decoration.

---

### `timeline_item` — Timeline Step

A single step in a `timeline`. Not rendered standalone; MUST be a child of
a `timeline` container. Contains a title, optional subtitle, and a status
that controls the visual indicator (filled/outlined circle, line style).

**Signature:**
```
identifier = timeline_item(title, subtitle?, status?)
```

**Arguments:**

| Pos | Name | Type | Required | Default | Description |
|-----|------|------|----------|---------|-------------|
| 0 | title | String | Yes | — | Event title |
| 1 | subtitle | String | No | none | Secondary text (date, duration, description) |
| 2 | status | TimelineStatus enum | No | `pending` | Visual state of this step |

**TimelineStatus enum values:**

| Value | Circle | Connector Line | Color | Description |
|-------|--------|---------------|-------|-------------|
| `done` | Filled | Solid | Primary | Completed step |
| `active` | Filled with ring | Dashed below | Primary | Current step |
| `pending` | Outlined | Dashed | Muted gray | Future step |
| `error` | Filled | Solid | Error red | Failed step |

**Example:**
```
step = timeline_item("Shipped", "Apr 4, 9:30 AM", done)
current = timeline_item("In Transit", "Expected Apr 6", active)
failed = timeline_item("Deploy", "Connection timeout", error)
future = timeline_item("Delivered")
```

**Compose Mapping:** Rendered by the parent `timeline` composable. See
`timeline` Compose Mapping above.

**SwiftUI Mapping:** Rendered by the parent `timeline` view. See
`timeline` SwiftUI Mapping above.

**Accessibility:** Announced with status prefix: "Done: Shipped, April 4,
9:30 AM." Status MUST be conveyed through the spoken text, not only through
color.

**Error Handling:**

- If `status` is unrecognized, fall back to `pending`.
- If `title` is empty, render an empty step with the status indicator.

**Token Cost:** A timeline with 4 steps costs ~40 tokens. The equivalent v1.0
approach (a `col` with `row` per step using `icon` + `txt` pairs) costs
~60-80 tokens and lacks the connecting line visual. Net savings: 1.5-2x with
significantly better visual clarity.

---

## Summary: All Primitives at a Glance

| # | Primitive | Category | Required Args | Optional Args | Has Actions |
|---|-----------|----------|---------------|---------------|-------------|
| 1 | `col` | Layout | `[children]` | `align` | No |
| 2 | `row` | Layout | `[children]` | `align`, `gap` | No |
| 3 | `txt` | Content | `"text"` | `style`, `max_lines`, `color` | No |
| 4 | `img` | Content | `"url"` | `height` | No |
| 5 | `icon` | Content | `"name"` | `size` | No |
| 6 | `divider` | Content | — | — | No |
| 7 | `spacer` | Content | — | `height` | No |
| 8 | `card` | Semantic | `[children]` | `elevation` | No |
| 9 | `badge` | Semantic | `"label"` | `variant`, `color` | No |
| 10 | `progress` | Semantic | `value` | `"label"` | No |
| 11 | `btn` | Interactive | `"label"`, `action` | `style`, `icon` | Yes |
| 12 | `input` | Interactive | `id`, `"label"` | `type`, `options` | No (data) |
| 13 | `toggle` | Interactive | `id`, `"label"` | `default` | No (data) |
| 14 | `list` | Data | `[children]` | `dividers` | No |
| 15 | `table` | Data | `headers`, `rows` | — | No |
| 16 | `chart` | Visualization | `type`, `values` | `labels`, `series`, `height`, `color` | No |
| 17 | `code` | Rich Content | `"language"`, `"content"` | `"title"` | No (copy is intrinsic) |
| 18 | `accordion` | Disclosure | `"title"`, `[children]` | `expanded` | No |
| 19 | `carousel` | Disclosure | `[children]` | `peek` | No |
| 20 | `callout` | Alert | `type`, `"content"` | `"title"` | No |
| 21 | `timeline` | Sequence | `[children]` | — | No |
| — | `timeline_item` | (Sequence child) | `"title"` | `"subtitle"`, `status` | No |

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

### ChartType

| Value | Description |
|-------|-------------|
| `line` | Line chart with connected data points |
| `bar` | Vertical bar chart |
| `pie` | Circular pie/donut chart |
| `sparkline` | Minimal inline trend indicator (no axes, no labels) |

### CalloutType

| Value | Description |
|-------|-------------|
| `info` | Neutral information (blue) |
| `warning` | Caution, potential issues (amber) |
| `error` | Errors, critical problems (red) |
| `success` | Confirmations, positive outcomes (green) |
| `tip` | Suggestions, best practices (purple) |

### TimelineStatus

| Value | Description |
|-------|-------------|
| `done` | Completed step (filled circle, solid line) |
| `active` | Current step (filled circle with ring, dashed line below) |
| `pending` | Future step (outlined circle, dashed line) |
| `error` | Failed step (error-colored filled circle, solid line) |

Note: `error` is a valid value in `CalloutType`, `TimelineStatus`, and
`SemanticColor`. The parser disambiguates by argument position. See
each primitive's Arguments table for the expected type at each position.

### SemanticColor

| Value | Android (Material 3) | iOS (SwiftUI) | Use Case |
|-------|---------------------|---------------|----------|
| `primary` | `colorScheme.primary` | `.tint` | Default branded color |
| `secondary` | `colorScheme.secondary` | `.secondary` | De-emphasized content |
| `error` | `colorScheme.error` | `.red` | Errors, destructive states |
| `success` | Custom green from extended palette | `.green` | Positive outcomes, confirmations |
| `warning` | Custom amber from extended palette | `.orange` | Caution, expiring, attention needed |

SemanticColor is supported as a named `color=` argument on `txt`, `badge`,
`chart`, and `callout`. When not specified, the primitive uses its default
theme color. Renderers MUST map these tokens to platform-appropriate colors,
never to hardcoded hex values.

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-04-05 | Initial specification — 15 primitives, 5 enum types |
| 1.1 | 2026-04-08 | Added 6 new primitives (chart, code, accordion, carousel, callout, timeline/timeline_item), SemanticColor enum, 3 new enum types (ChartType, CalloutType, TimelineStatus), color= argument on txt/badge. Total: 21 primitives, 10 categories. |
