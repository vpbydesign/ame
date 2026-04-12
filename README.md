# AME — Agentic Mobile Elements

> A compact syntax for LLMs to generate native mobile UI on the fly

AME is a line-oriented markup that LLMs stream token-by-token. A mobile
renderer turns each line into a native component the moment it arrives —
no JSON parsing, no WebView, no round-trip.

## How AME Works

An LLM returns AME text instead of plain prose when the user needs a rich,
interactive answer. Each line defines one UI element — the renderer builds
the screen progressively as tokens arrive.

**LLM output (8 lines, 188 tokens):**

```
root = col([title, form, submit_btn])
title = txt("Book a Table", headline)
form = col([name_in, date_in, size_in, note_in])
name_in = input("name", "Your name")
date_in = input("date", "Date")
size_in = input("party_size", "Party size")
note_in = input("notes", "Special requests")
submit_btn = btn("Reserve", submit(book_table))
```

**What the user sees:** a native Material 3 form with four text inputs and a
"Reserve" button. Tapping the button collects form values and routes them
through the host app's tool-call pipeline — same confirmation flow as any
other LLM-initiated action.

[More examples →](examples/)

## Why AME?

- **Compact.** 1.77x fewer tokens than comparable UI syntaxes on average.
  Every token saved reduces latency and cost at scale.
  [Benchmark →](benchmarks/token-comparison.md)

- **Streaming-first.** Line-oriented syntax enables progressive rendering —
  skeleton placeholders appear instantly, content fills in as each line
  arrives. First visible content in ~0.10s.
  [Benchmark →](benchmarks/streaming-latency.md)

- **LLM-reliable.** Zero parse failures across 32 prompts on both Gemini 3
  Flash Preview and Claude Sonnet 4.6 with the standard system prompt.
  [Benchmark →](benchmarks/llm-reliability.md)

- **Native mobile.** Jetpack Compose and SwiftUI renderers. Material 3
  theming on Android, SF Symbols and system fonts on iOS. No WebView.

- **Action safety.** Button taps route through the host app's trust
  pipeline — same confirmation and risk system as LLM-initiated tool calls.
  The renderer never executes actions directly.

- **Zero-token templates.** The majority of tool-result interactions render
  as rich native UI through shape-matched templates — no LLM tokens needed
  for UI generation. The LLM only produces AME for novel or complex layouts.
  [Spec →](specification/v1.0/tier-zero.md)

## Quick Start

```kotlin
// 1. Parse AME text into a node tree
val parser = AmeParser()
val tree = parser.parse(ameString)

// 2. Render with Compose
tree?.let {
    AmeRenderer(
        node = it,
        onAction = { action -> handleAction(action) }
    )
}

// 3. Handle actions from the host app
fun handleAction(action: AmeAction) {
    when (action) {
        is AmeAction.CallTool -> toolSystem.execute(action.name, action.args)
        is AmeAction.OpenUri -> startActivity(Intent(ACTION_VIEW, Uri.parse(action.uri)))
        is AmeAction.Navigate -> navController.navigate(action.route)
        is AmeAction.CopyText -> clipboard.setText(action.text)
        is AmeAction.Submit -> { /* Resolved to CallTool by renderer before dispatch */ }
    }
}

// 4. Customize theme (optional)
CompositionLocalProvider(LocalAmeTheme provides myThemeConfig) {
    AmeRenderer(node = tree, onAction = ::handleAction)
}
```

## Comparison

| Dimension | AME | A2UI v0.9 | Raw JSON | MCP Apps | OpenUI Lang |
|-----------|-----|-----------|----------|----------|-------------|
| Token cost (avg) | 1x (baseline) | 1.77x | ~0.87x † | N/A (HTML) | ~0.95x \* |
| Streaming | Line-by-line | Flat list | Not streamable | Pre-built | Line-by-line |
| Zero-token rendering | Yes | No | No | No | No |
| Mobile-native renderer | Compose + SwiftUI | Flutter | Custom code | WebView | React |
| Typed AST + error recovery | Yes | No | No | No | No |
| Action safety | Host trust pipeline | Event-based | N/A | iframe sandbox | Callbacks |

\* *OpenUI Lang token cost is estimated from syntax comparison, not measured
via tokenizer. All other AME and A2UI numbers are measured.*

† *Raw JSON is ~13% fewer tokens than AME on average, but is not
incrementally parseable (no streaming), has no typed AST or error recovery,
and requires custom rendering code per schema. AME's overhead pays for
streaming progressiveness, a typed node tree with error recovery, and
platform-native rendering from a single format.*

AME is an independent open-source project. Comparisons are based on public
documentation and measured token counts.

## Specification

The complete AME v1.1 specification: [specification/v1.0/](specification/v1.0/README.md)

| Document | Description |
|----------|-------------|
| [syntax.md](specification/v1.0/syntax.md) | Line-oriented syntax rules and EBNF grammar |
| [primitives.md](specification/v1.0/primitives.md) | 21 standard UI primitives with argument tables |
| [actions.md](specification/v1.0/actions.md) | 5 action types (tool, uri, nav, copy, submit) |
| [streaming.md](specification/v1.0/streaming.md) | Progressive rendering with forward references |
| [data-binding.md](specification/v1.0/data-binding.md) | $path references, --- separator, each() templates |
| [tier-zero.md](specification/v1.0/tier-zero.md) | Zero-token tool-driven rendering |
| [integration.md](specification/v1.0/integration.md) | Host app capability declaration and system prompt guidance |

## Benchmarks

### Token Efficiency

Measured with Gemini `gemini-2.0-flash` tokenizer. Every number below is a
measured integer from the `countTokens` API — no estimates, no rounding.

| UI Scenario | AME | A2UI v0.9 | Savings |
|-------------|-----|-----------|---------|
| Weather Card | 131 | 203 | 1.55x |
| Place Search (3 cards) | 581 | 1,014 | 1.75x |
| Email Inbox (5 items) | 420 | 605 | 1.44x |
| Booking Form (4 inputs) | 188 | 412 | 2.19x |
| Comparison (2 cards) | 604 | 889 | 1.47x |
| Medical Dashboard (chart + timeline) | 218 | 743 | 3.41x |
| Code Tutorial (code + accordion) | 294 | 554 | 1.88x |
| Product Gallery (carousel + chart) | 436 | 664 | 1.52x |
| **Average** | **359** | **636** | **1.77x** |

[Full benchmark with methodology and reproducible strings →](benchmarks/token-comparison.md)

### Streaming Latency

First visible content in ~0.10s vs ~10.1s for batch-rendered JSON alternatives
(simulated at 100 tokens/s). A2UI streaming JSON parsers can narrow the
first-content gap to ~0.5s, but AME retains structural advantages (skeleton
placeholders, simpler parser, 1.75x fewer tokens).
[Full benchmark →](benchmarks/streaming-latency.md)

### LLM Reliability

Zero parse failures across 32 prompts (20 v1.0 + 12 v1.1) on both
Gemini 3 Flash Preview and Claude Sonnet 4.6.
[Full benchmark →](benchmarks/llm-reliability.md)

## Project Structure

```
ame-spec/
├── specification/v1.0/   # 7 spec documents (syntax, primitives, actions, streaming, data-binding, tier-zero, integration)
├── ame-core/              # Kotlin data model + parser (AmeNode, AmeAction, AmeParser, AmeSerializer)
├── ame-compose/           # Jetpack Compose renderer (AmeRenderer, AmeTheme, AmeFormState, AmeIcons, AmeChartRenderer)
├── ame-swiftui/           # SwiftUI renderer (AmeRenderer, AmeTheme, AmeFormState, AmeIcons)
├── conformance/           # 55 conformance tests with Kotlin-Swift parity check
├── benchmarks/            # Token comparison, streaming latency, LLM reliability
└── examples/              # 9 standalone .ame files
```

## Known Limitations

The following limitations are known and planned for future versions:

1. **Single tokenizer benchmark.** All token measurements in
   [token-comparison.md](benchmarks/token-comparison.md) use the Gemini
   `gemini-2.0-flash` tokenizer. GPT-4o and Claude tokenizers have different
   vocabulary tables and BPE merge rules. The 1.77x ratio is specific to
   the Gemini tokenizer and may vary on other tokenizers. Community
   contributions of cross-tokenizer benchmarks are welcome.

2. **Grammar disambiguation.** The EBNF grammar in
   [syntax.md](specification/v1.0/syntax.md) relies on a prose
   disambiguation rule for `row()`'s second positional argument (numeric
   literal = `gap`, enum identifier = `align`). This rule is specified in
   [primitives.md](specification/v1.0/primitives.md) but is not expressible
   in EBNF alone. Parser implementors MUST read the `row` section in
   primitives.md for the complete disambiguation rule.

3. **Custom component catalog schema.** The spec defines how to declare
   custom components in `AME_CATALOG`
   ([integration.md](specification/v1.0/integration.md)) but does not define
   a schema format for describing custom component parameters to agents.
   Host apps document their custom components in their system prompts. A
   formal custom catalog schema is planned for a future version.

4. **Two independent parsers.** The reference implementation includes
   independent Kotlin and Swift parsers that must produce identical output.
   Parser parity is enforced by the conformance test suite
   (`conformance/check-parity.sh`) with 55 test cases covering all 21
   primitives. Both parsers implement `each()` expansion at parse time — in
   streaming mode, `each()` nodes show a shimmer placeholder until the data
   section arrives.

## License

Apache 2.0 — see [LICENSE](LICENSE)
