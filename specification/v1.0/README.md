# AME Specification — Version 1.3

> Directory name `v1.0` is the layout version, retained for backlink stability across releases. Spec contents reflect the current AME version (see Version History at the bottom of this page).

The AME v1.3 specification defines a compact, streaming-first syntax for
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
| [conformance.md](conformance.md) | Conformance levels, test catalog, self-verification procedure |
| [regression-protocol.md](regression-protocol.md) | Defect lifecycle, conformance impact, BREAKING-CONFORMANCE workflow |

## Conformance

AME defines three conformance levels: Core, Streaming, and Strict.
The complete conformance methodology, including the 57-case test catalog,
self-verification procedure, the multi-runtime extension procedure, and
rules for adding or changing conformance tests, is consolidated in
[conformance.md](conformance.md).

AME has reference implementations in Kotlin (Compose), Swift (SwiftUI),
and Dart (Flutter). Additional runtime ports follow the procedure in
[conformance.md](conformance.md) §5; the multi-runtime parity script
[`conformance/check-parity.sh`](../../conformance/check-parity.sh) accepts
new runtimes via a one-line configuration entry.

Implementations claiming AME support MUST state the highest level they
conform to. See `conformance.md` §1 for full requirements per level and
§3 for the self-verification procedure.

## Quality and Defect Discipline

The AME project enforces a normative process for finding, verifying, and
fixing defects, documented in
[regression-protocol.md](regression-protocol.md). Highlights:

- Every claimed defect MUST become a failing test before any fix is scoped.
- Every fix MUST leave the failing test passing AND keep it as a
  permanent regression in CI.
- Changes to conformance JSON output that affect existing test cases MUST
  carry the `BREAKING-CONFORMANCE` PR label and trigger a minimum minor
  version bump on the next release.

The canonical record of every claim and its verdict (REAL / NOT REAL /
INCONCLUSIVE) lives at
[`AUDIT_VERDICTS.md`](../../AUDIT_VERDICTS.md) at the repository root.

## Version History

| Version | Date | Status |
|---------|------|--------|
| 1.0 | 2026-04-05 | Superseded by v1.1 |
| 1.1 | 2026-04-11 | Superseded by v1.2 |
| 1.2 | 2026-04-18 | Superseded by v1.3 |
| 1.3 | 2026-04-XX | Current. Flutter joins as third reference runtime; Flutter port aligned with v1.2 audit history; one architectural Flutter-specific finding fixed; one phantom audit claim refuted. |
