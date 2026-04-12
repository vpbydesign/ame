# AME Specification — Version 1.1

The AME v1.1 specification defines a compact, streaming-first syntax for
describing interactive user interfaces, designed for LLM generation and
native mobile rendering.

## Documents

| Document | Description |
|----------|-------------|
| [syntax.md](syntax.md) | Line-oriented syntax rules and EBNF grammar |
| [primitives.md](primitives.md) | 21 standard UI primitives with argument tables |
| [actions.md](actions.md) | 5 action types (tool, uri, nav, copy, submit) |
| [streaming.md](streaming.md) | Progressive rendering with forward references |
| [data-binding.md](data-binding.md) | $path references, --- separator, each() templates |
| [tier-zero.md](tier-zero.md) | Zero-token and layout-hint rendering (Tier 0 and Tier 1) |
| [integration.md](integration.md) | Capability declaration, system prompts, MCP/A2A integration |

## Conformance

AME defines two conformance levels. Implementations claiming AME support
SHOULD state which level they conform to.

### AME Core Conformance

An implementation claims AME Core Conformance when:

1. **Parser** handles all 21 standard primitives defined in
   [primitives.md](primitives.md), plus `each()` from
   [data-binding.md](data-binding.md), plus `Ref` for forward references.
2. **Parser** handles the `---` data separator and resolves `$path`
   references against the data model.
3. **Parser** implements all error recovery rules from
   [syntax.md](syntax.md) (unknown component, unclosed parenthesis,
   unclosed string, malformed line, duplicate identifier, invalid number,
   invalid enum value). The parser MUST NOT crash on any input.
4. **Renderer** displays all 21 standard primitives as native platform
   widgets.
5. **Renderer** dispatches all actions through the `AmeActionHandler`
   interface (or platform equivalent).
6. All 9 example `.ame` files in the `examples/` directory parse and
   render without errors.

### AME Streaming Conformance

An implementation claims AME Streaming Conformance when it meets all
AME Core Conformance requirements AND:

1. **Parser** supports incremental parsing via a `parseLine()` method
   (or equivalent) that processes one line at a time.
2. **Renderer** shows skeleton placeholders for unresolved `Ref` nodes.
3. **Renderer** replaces skeletons with rendered components when the
   defining statement arrives.
4. Forward references resolve correctly regardless of emission order
   (top-down, bottom-up, or mixed).

Streaming Conformance is OPTIONAL. Implementations that only support
batch parsing (entire document at once) claim Core Conformance only.

## Version History

| Version | Date | Status |
|---------|------|--------|
| 1.0 | 2026-04-05 | Superseded by v1.1 |
| 1.1 | 2026-04-11 | Current |
