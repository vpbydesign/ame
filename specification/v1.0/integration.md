# AME Integration Specification — v1.0

## Introduction

AME is a UI description language, not a transport protocol. It defines what an
LLM outputs (the syntax) and how a renderer behaves (the rendering contract),
but it does not define how the AME document travels from the LLM to the
renderer. This is intentional — AME is designed to ride on top of existing
protocols (MCP, A2A, direct API calls) rather than replacing them.

This document defines the integration layer: how host applications declare
AME support, how agents discover that a client speaks AME, how AME documents
are delivered across different protocol stacks, and how versions are
negotiated. These are the minimal conventions needed for interoperability
between independently developed agents and host applications.

For the syntax that agents generate, see [syntax.md](syntax.md). For the
primitives available, see [primitives.md](primitives.md). For how rendered UI
dispatches actions back to the host, see [actions.md](actions.md). For
zero-token rendering from tool results, see [tier-zero.md](tier-zero.md).

### Notation Conventions

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD",
"SHOULD NOT", "RECOMMENDED", "MAY", and "OPTIONAL" in this document are to be
interpreted as described in [RFC 2119](https://www.ietf.org/rfc/rfc2119.txt).

---

## AME Capability Declaration

A host application that supports AME rendering declares two pieces of
information:

1. **`AME_SUPPORT`** — the AME specification version the host supports.
2. **`AME_CATALOG`** — the list of primitive names the host's renderer can
   display, including both standard primitives and any custom components.

These declarations enable agents to determine whether they can generate AME
for a given client and which primitives they may use.

### Declaration Format

The declaration format is intentionally simple — two key-value fields that
can be embedded in any capability context.

**As plain text** (for system prompts, documentation, or human-readable
capability lists):

```
AME_SUPPORT: v1.0
AME_CATALOG: col, row, txt, btn, card, badge, icon, img, input, toggle, list, table, divider, spacer, progress
```

**As JSON** (for structured capability responses, agent cards, or metadata):

```json
{
  "ame": {
    "version": "1.0",
    "catalog": [
      "col", "row", "txt", "btn", "card", "badge", "icon", "img",
      "input", "toggle", "list", "table", "divider", "spacer", "progress"
    ]
  }
}
```

### Rules

1. `AME_SUPPORT` MUST contain a version string matching a published AME
   specification version (e.g., `v1.0`). Agents MUST NOT generate AME
   syntax for a version higher than the client's declared version.

2. `AME_CATALOG` MUST list every primitive the host's renderer supports.
   Agents MUST NOT use primitives not listed in the catalog. If an agent
   generates a primitive not in the catalog, the renderer SHOULD render a
   text fallback (per [syntax.md](syntax.md) error handling rules) and
   SHOULD log a warning.

3. The 15 standard primitives (`col`, `row`, `txt`, `btn`, `card`, `badge`,
   `icon`, `img`, `input`, `toggle`, `list`, `table`, `divider`, `spacer`,
   `progress`) SHOULD be listed if the host supports AME Core Conformance
   (see [specification README](README.md)). A host MAY list a subset if it
   does not implement all 15 primitives, but this reduces what agents can
   generate.

4. Custom components (defined by the host app, not by the AME spec) MAY be
   appended to the catalog. Custom component names MUST NOT collide with
   standard primitive names or reserved keywords (see
   [syntax.md](syntax.md) Reserved Keywords).

**Example with custom components:**

```
AME_SUPPORT: v1.0
AME_CATALOG: col, row, txt, btn, card, badge, icon, img, input, toggle, list, table, divider, spacer, progress, MapView, AudioPlayer, VideoCard
```

### When No Declaration Is Present

If an agent does not see an `AME_SUPPORT` declaration from the client, the
agent MUST NOT generate AME syntax. It SHOULD fall back to plain text,
markdown, or whatever UI format the client does support.

This rule prevents AME output from being sent to clients that cannot render
it. A client that does not declare AME support will receive AME syntax as
gibberish — there is no graceful degradation without the declaration.

---

## System Prompt Integration

The primary integration mechanism for LLM-based agents. The host application
includes an AME instruction section in its system prompt, teaching the LLM
the AME syntax and listing the available primitives.

### Standard AME Prompt Section

The following is the RECOMMENDED system prompt section for host apps that
support AME v1.0 with the standard 15 primitives. It is designed to be
compact (~250 tokens) while being sufficient for the LLM to generate valid
AME syntax.

```
--- AME UI Generation ---
When you want to show rich interactive UI (cards, forms, lists, buttons),
generate an AME document. AME is a line-oriented syntax where each line
binds an identifier to a component.

AME_SUPPORT: v1.0
AME_CATALOG: col, row, txt, btn, card, badge, icon, img, input, toggle, list, table, divider, spacer, progress

Rules:
- One statement per line: identifier = Component(args)
- First line MUST be: root = ...
- Identifiers: lowercase with underscores (e.g., p1_name, header)
- Children arrays: [child1, child2, child3]
- IMPORTANT: Every identifier in a children array MUST be defined on its own line

Primitives:
col([children]) row([children], align?) txt("text", style?) btn("label", action, style?)
card([children]) badge("label", variant?) icon("name") img("url", height?)
input(id, "label", type?) toggle(id, "label") list([children]) table(headers, rows)
divider() spacer(height?) progress(value, "label"?)

Styles: display, headline, title, body, caption, mono, label
Button styles: primary, secondary, outline, text, destructive
Badge variants: default, success, warning, error, info

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
```

### Prompt Section Rules

1. The prompt section SHOULD be placed in the system instruction (not in
   individual user messages). This ensures the LLM has AME capability
   throughout the conversation.

2. The prompt section MUST include `AME_SUPPORT` and `AME_CATALOG` fields.
   These are the declaration the agent reads to confirm AME is available.

3. The prompt section SHOULD include at least one complete example that
   parses successfully. This serves as a few-shot learning anchor. The
   weather card example above is RECOMMENDED because it demonstrates
   explicit identifier definitions for every child in children arrays,
   multiple action types, and multiple component styles.

4. Host apps MAY extend the prompt section with descriptions of custom
   components. Each custom component SHOULD include its name, arguments,
   and a brief description:

   ```
   Custom components:
   MapView(pins=$data, height=200) - interactive map with location pins
   AudioPlayer(track="url") - music playback controls
   ```

5. Host apps SHOULD instruct the LLM on when to generate AME versus plain
   text. A RECOMMENDED instruction: "Use AME when showing structured results
   (search results, forms, comparisons, data cards). Use plain text for
   conversational responses, explanations, and simple answers."

### Detecting AME in LLM Output

When the LLM generates AME in response to a user message, the host app
needs to detect it in the response text and separate it from conversational
content. The RECOMMENDED detection approach:

1. Look for a line starting with `root = ` in the LLM's response text.
2. If found, extract all subsequent lines until a blank line, end of
   response, or a line that does not match the AME statement pattern
   (`identifier = expression`).
3. Pass the extracted block to `AmeParser.parse()`.
4. If parsing succeeds (non-null root), render the resulting `AmeNode` tree.
5. Any text before the `root = ` line is conversational content — display
   it as regular text above the rendered AME UI.

This approach allows the LLM to mix conversational text with AME output
naturally:

```
I found 3 Italian restaurants near you. Here are the results:

root = col([header, results])
header = txt("Italian Restaurants", headline)
results = list([p1, p2, p3])
...
```

The host app renders "I found 3 Italian restaurants near you. Here are the
results:" as text, and everything from `root = ` onward as AME UI.

---

## MCP Integration

For host applications using the
[Model Context Protocol](https://modelcontextprotocol.io/) (MCP) as their
agent-to-tool communication layer, AME integrates as a rendering format for
tool results — not as a replacement for MCP.

### Architecture

```
┌──────────────────┐     ┌──────────────────────┐     ┌──────────────────┐
│   LLM / Agent    │────▶│   Host Application   │────▶│   MCP Server     │
│                  │     │                      │     │                  │
│ • Calls tools    │     │ • AME renderer       │     │ • Tool provider  │
│ • Generates AME  │     │ • Shape matcher      │     │ • Data source    │
│   (Tier 2 only)  │     │ • Action router      │     │ • No UI logic    │
└──────────────────┘     └──────────────────────┘     └──────────────────┘
```

**MCP servers provide tools (data backends). They do NOT generate UI.**

The host app is the integration point:
- It discovers tools from MCP servers via `tools/list`.
- When the LLM calls a tool, the host routes it to the appropriate MCP
  server via `tools/call`.
- When the tool returns data, the host's shape matcher (Tier 0) or the LLM
  (Tier 2) generates the `AmeNode` tree.
- When a user taps an AME button with a `tool()` action, the host routes it
  back to the MCP server via `tools/call`.

### Declaring AME Support in MCP

A host application MAY declare AME support in its MCP client capabilities
during the `initialize` handshake:

```json
{
  "capabilities": {
    "ame": {
      "version": "1.0",
      "catalog": ["col", "row", "txt", "btn", "card", "badge", "icon",
                   "img", "input", "toggle", "list", "table", "divider",
                   "spacer", "progress"]
    }
  }
}
```

MCP servers MAY read this capability to determine whether the client can
render AME. However, since MCP servers typically provide tools (not UI),
this capability is primarily informational — it tells the server that tool
result data MAY be rendered as rich UI by the client.

### AME vs MCP Apps

AME and MCP Apps solve different problems and are not mutually exclusive:

| Aspect | AME | MCP Apps |
|--------|-----|----------|
| UI format | Native (Compose, SwiftUI) | HTML in WebView/iframe |
| Who generates UI | LLM (Tier 2) or host app (Tier 0/1) | MCP server |
| Transport | LLM response text or in-memory | MCP `ui://` resource fetch |
| Rendering | Host app's AME renderer | Sandboxed iframe |
| Token cost | 0 (Tier 0), 1 (Tier 1), or 50-200 (Tier 2) | 0 (server-rendered HTML) |
| Interactivity | Action dispatch via `AmeActionHandler` | `postMessage` JSON-RPC |

A host application MAY support both AME (for LLM-generated native UI) and
MCP Apps (for server-provided web applications). They serve different use
cases and coexist without conflict.

---

## A2A Integration

For multi-agent systems using the
[Agent-to-Agent Protocol](https://google.github.io/A2A/) (A2A), AME can be
declared as a supported UI format in an agent's capabilities.

### Agent Card Declaration

An agent or client that supports AME rendering MAY include it in the A2A
agent card's capabilities:

```json
{
  "name": "MyAssistant",
  "capabilities": {
    "ui_formats": [
      {
        "name": "ame",
        "version": "1.0",
        "catalog": ["col", "row", "txt", "btn", "card", "badge", "icon",
                     "img", "input", "toggle", "list", "table", "divider",
                     "spacer", "progress"]
      }
    ]
  }
}
```

### Agent-Generated AME

When an A2A agent generates a response for a client that supports AME, it
MAY include an AME document in its message payload. The receiving client
parses the AME document and renders it using its local renderer.

The A2A message carrying AME SHOULD include a content type indicator so the
client knows to parse it as AME rather than plain text:

```json
{
  "message": {
    "parts": [
      {
        "type": "text",
        "content": "Here are the restaurants I found:"
      },
      {
        "type": "ame",
        "content": "root = col([header, results])\nheader = txt(\"Restaurants\", headline)\n..."
      }
    ]
  }
}
```

The exact message structure depends on the A2A protocol version. The key
requirement is that AME content is distinguishable from plain text content
so the client can route it to the AME parser.

---

## Standalone Integration

For host applications with direct LLM integration (no MCP, no A2A), AME
integrates through the system prompt alone.

### Minimal Integration Steps

1. **Declare AME support** — include the AME prompt section (from
   [System Prompt Integration](#system-prompt-integration) above) in the
   LLM's system instruction.

2. **Detect AME output** — when the LLM responds, check for `root = ` in
   the response text (see [Detecting AME in LLM Output](#detecting-ame-in-llm-output) above).

3. **Parse** — extract the AME block and feed it to `AmeParser.parse()`.

4. **Render** — pass the resulting `AmeNode` tree to `AmeRenderer`.

5. **Handle actions** — implement `AmeActionHandler` to route `tool()`,
   `uri()`, `nav()`, `copy()`, and resolved `submit()` actions to the
   appropriate app systems.

This is the simplest integration path — no protocol, no capability
negotiation, no server. The LLM learns AME from the system prompt and
generates it when appropriate. The host app parses and renders it locally.

### Tier 0 in Standalone Mode

For Tier 0 rendering (zero-token UI), the host app does not need the LLM
to generate AME at all:

1. The LLM calls a tool (via function calling, text-based tool protocol, or
   any other mechanism).
2. The tool returns structured data.
3. The host app's shape matcher builds an `AmeNode` tree from the data
   (see [tier-zero.md](tier-zero.md)).
4. The renderer displays the tree.

No AME syntax is generated by the LLM. The system prompt's AME section is
only needed for Tier 2 (LLM-generated layouts). Tier 0 and Tier 1 work
without any LLM awareness of AME syntax.

---

## Version Negotiation

AME uses a simple version negotiation model. There is no handshake — the
client declares its version, and agents respect it.

### Rules

1. The `AME_SUPPORT` version string follows semantic versioning: `v{major}.{minor}`.
   Example: `v1.0`, `v1.1`, `v2.0`.

2. **Minor version compatibility:** A client declaring `v1.0` can render
   any AME document that uses only v1.0 primitives and syntax. A document
   using v1.1 features (e.g., new primitives added in v1.1) MAY fail on a
   v1.0 client — the unknown primitives will render as text fallbacks per
   the error handling rules in [syntax.md](syntax.md).

3. **Major version compatibility:** A major version change (e.g., v1.x to
   v2.0) MAY include breaking changes to syntax, primitive semantics, or
   the rendering contract. Agents MUST NOT generate v2.x AME for a client
   declaring v1.x support.

4. **No version declared:** If the client does not declare `AME_SUPPORT`,
   the agent MUST NOT generate AME. This prevents unintelligible output
   from reaching clients that don't have an AME renderer.

5. **Agent version:** Agents do not declare their own AME version. They
   read the client's declared version and generate compatible output. An
   agent that knows AME v1.1 syntax MUST restrict itself to v1.0 primitives
   when communicating with a v1.0 client.

### Forward Compatibility

AME v1.0 is designed for forward compatibility within the v1.x line:

- New primitives added in v1.1 will be unknown to v1.0 renderers. Per the
  error handling rules in [syntax.md](syntax.md), the renderer will display
  a text fallback for unknown primitives. The document remains partially
  renderable.

- New action types added in v1.1 will be unknown to v1.0 renderers. Per
  [actions.md](actions.md), the `AmeActionHandler` interface is implemented
  by the host app, which can choose to ignore unknown action types.

- New enum values (e.g., a new `TxtStyle` variant) will be treated as the
  enum's default value by v1.0 parsers, per the error handling rules.

This means a v1.1 agent can CAUTIOUSLY generate v1.1 features for a v1.0
client if it is willing to accept graceful degradation (unknown primitives
become text fallbacks). Whether to do this is an agent-level decision, not
a spec-level requirement.

---

## AME's Relationship to Other Specifications

AME is a UI description language — it defines the syntax (what to write) and
the rendering contract (how to display it). It is not a transport protocol,
not an agent communication protocol, and not an application hosting model.

### Comparison

| | AME | A2UI | MCP Apps | MCP | A2A |
|---|---|---|---|---|---|
| **Category** | UI description language | UI message format | App hosting model | Tool protocol | Agent protocol |
| **Defines** | Syntax + rendering | JSON message shape | HTML app lifecycle | Wire format + tools | Agent communication |
| **Transport** | None (rides on others) | None (rides on others) | Built on MCP | stdio / HTTP+SSE | HTTP |
| **UI format** | AME syntax (compact) | JSON (adjacency list) | HTML/JS/CSS | N/A | N/A |
| **Renders as** | Native (Compose, etc.) | Native (per renderer) | WebView/iframe | N/A | N/A |
| **Capability negotiation** | `AME_SUPPORT` declaration | Surface ID | MCP initialize | MCP initialize | Agent card |
| **Can coexist with AME?** | — | Yes (different format) | Yes (different paradigm) | Yes (tool backend) | Yes (agent transport) |

AME can coexist with all of the above:
- **MCP** provides the tools that AME buttons invoke.
- **A2A** provides the agent-to-agent communication that carries AME payloads.
- **A2UI** is an alternative UI format — a client could support both AME and
  A2UI, choosing based on the agent's capability.
- **MCP Apps** serve rich web applications — AME serves native mobile UI.
  They solve different problems for different platforms.

---

## Security Considerations

### AME Declaration Trust

The `AME_SUPPORT` and `AME_CATALOG` declarations are informational — they
tell agents what the client can render. They do not grant permissions or
authorize actions. All security enforcement happens at the action dispatch
layer (see [actions.md](actions.md) Security Model):

- `tool()` actions MUST be routed through the host app's trust pipeline.
- `uri()` actions SHOULD be validated against an allowed-scheme list.
- The AME renderer MUST NOT execute any action directly.

### System Prompt Injection

The AME system prompt section is included in the LLM's system instruction,
which is controlled by the host app. There is no risk of external parties
injecting AME capability declarations — the host app decides whether to
include the AME prompt section.

### Malicious AME Output

An LLM (or a compromised agent) could generate AME documents containing
malicious action arguments — for example, `tool(delete_all_data)` or
`uri("javascript:alert(1)")`. The AME spec addresses this through two
mechanisms:

1. **Action routing:** All `tool()` and `submit()` actions go through the
   host app's `AmeActionHandler`, which MUST apply its own trust and
   confirmation policies before executing any tool call. AME does not
   bypass the host app's safety checks.

2. **URI scheme restrictions:** Host apps SHOULD validate URI schemes in
   `uri()` actions against an allowed list (see [actions.md](actions.md)
   Security Model). Dangerous schemes (`javascript:`, `file:`, `data:`)
   SHOULD be blocked.

3. **Catalog enforcement:** If an agent generates a primitive not in the
   declared `AME_CATALOG`, the renderer renders a text fallback, not the
   requested component. This prevents agents from using capabilities the
   host did not advertise.

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-04-05 | Initial specification |
