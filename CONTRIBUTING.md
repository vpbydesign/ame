# Contributing to AME

AME is an open-source specification for LLM-generated native mobile UI.
Contributions are welcome — bug fixes, new renderers, benchmark data, and
spec improvements.

## How to Propose a Spec Change

1. Open an issue with the prefix **"RFC:"** in the title.
2. Include: what you want to change, why, one or more examples showing
   the current and proposed behavior.
3. Spec changes require discussion before implementation. Do not open a
   PR that modifies `specification/` without a corresponding RFC issue.

## How to Add a New Primitive

New primitives are significant spec changes. The process:

1. Open an RFC issue describing the primitive: name, arguments, rendering
   behavior, accessibility, and at least two realistic usage examples.
2. After approval, implement in this order:
   - `specification/v1.0/primitives.md` — add the primitive definition
   - `ame-core/.../AmeNode.kt` — add the sealed subtype
   - `ame-core/.../AmeParser.kt` — add the builder function
   - `ame-core/.../AmeParserTest.kt` — add parse tests
   - `ame-compose/.../AmeRenderer.kt` — add Compose rendering
   - `ame-swiftui/.../AmeNode.swift` — add the enum case
   - `ame-swiftui/.../AmeParser.swift` — add the builder function
   - `ame-swiftui/.../AmeParserTests.swift` — add parse tests
   - `ame-swiftui/.../AmeRenderer.swift` — add SwiftUI rendering
   - `conformance/` — add a conformance test input + expected output
3. Run `conformance/check-parity.sh` and verify zero diffs.
4. Open a PR referencing the RFC issue.

## How to Contribute a Renderer for a New Platform

AME is platform-neutral. Renderers for Flutter, React Native, Kotlin/XML,
or any other framework are welcome as separate repositories or as
subdirectories in this repo.

A conformant renderer must:

1. Handle all 17 `AmeNode` types (15 visual + Ref + Each)
2. Pass the conformance test suite (parse + render equivalence)
3. Follow the accessibility guidance in `specification/v1.0/primitives.md`

## Code Style

- Kotlin: follow the existing code style in `ame-core/`
- Swift: follow the existing code style in `ame-swiftui/`
- Spec documents: use RFC 2119 normative language (MUST/SHOULD/MAY)

## Testing

Before submitting a PR:

```bash
# Kotlin tests
./gradlew :ame-core:test

# Swift tests
cd ame-swiftui && swift test

# Conformance parity check
./conformance/check-parity.sh
```

## License

By contributing, you agree that your contributions will be licensed under
the Apache 2.0 license.
