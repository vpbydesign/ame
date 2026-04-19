@TestOn('vm')
library;

import 'dart:io';
import 'dart:mirrors';

import 'package:ame_flutter/ame_flutter.dart';
import 'package:test/test.dart';

/// Audit regression tests — Flutter parser and serializer.
///
/// Each test corresponds to one row in `AUDIT_VERDICTS.md` at the repo root.
/// Tests are written so that BEFORE a fix is applied the test FAILS
/// (proving the bug), and AFTER the fix is applied the test PASSES
/// (locking in the corrected behavior).
///
/// See `specification/v1.0/regression-protocol.md` for the lifecycle rules
/// that govern this file.
///
/// These tests mirror `ame-core/.../AuditedBugRegressionTest.kt` and
/// `ame-swiftui/.../AuditedBugRegressionTests.swift` exactly so that
/// cross-runtime divergence is also caught. They cover Flutter analogs of
/// v1.2 Bugs 3, 6, 7, 8, 11, 15, 21 (registered as Bugs 26, 27, 29, 30,
/// 31, 32, 35 per the Flutter alignment work package).
///
/// `@TestOn('vm')` keeps the suite on the Dart VM, where `dart:mirrors`
/// is supported (Bug 35's diagnostic-API existence check). The suite
/// contains no Flutter dependencies and is intentionally web-incompatible
/// because reflection is not part of the parser surface.
void main() {
  AmeNode? parse(String input) => AmeParser().parse(input);

  AmeParser parserFor(String input) {
    final parser = AmeParser();
    parser.parse(input);
    return parser;
  }

  // ════════════════════════════════════════════════════════════════════
  // Bug 26 (Flutter analog of v1.2 Bug 3) —
  //   _parseArray and _extractParenContent ignore string literals.
  // ════════════════════════════════════════════════════════════════════

  group('Bug 26 — string-literal-aware parser scan', () {
    /// Audit Bug #26a: parser corrupts component calls when a string literal
    /// contains a literal `)` character.
    ///
    /// Spec section: specification/v1.0/syntax.md (String Literals)
    /// Audit reference: AUDIT_VERDICTS.md#bug-26
    /// Pre-fix expected: FAIL — _extractParenContent stops at the first `)`,
    ///   truncating the string content.
    /// Post-fix expected: PASS — `)` inside `"..."` is preserved verbatim.
    test('paren inside string literal is preserved', () {
      final result = parse(r'root = txt("a)b", body)');
      expect(result, isA<AmeTxt>(),
          reason: 'Parser returned wrong type for valid input');
      expect(
        (result as AmeTxt).text,
        equals('a)b'),
        reason: 'Parenthesis inside a string literal must be preserved verbatim',
      );
    });

    /// Audit Bug #26b: _parseArray scans only for `]`, ignoring strings, so
    /// a `]` inside an array element string ends the array prematurely.
    ///
    /// Spec section: specification/v1.0/syntax.md (Array Literals, String Literals)
    /// Audit reference: AUDIT_VERDICTS.md#bug-26
    /// Pre-fix expected: FAIL — array is truncated at the first `]`.
    /// Post-fix expected: PASS — `]` inside `"..."` is preserved as content.
    test('bracket inside string literal is preserved', () {
      final result = parse(r'root = col([txt("a]b"), txt("c")])');
      expect(result, isA<AmeCol>(), reason: 'Parser must produce a col root');
      final children = (result as AmeCol).children;
      expect(children.length, equals(2),
          reason: 'Array must contain both elements');
      expect(children[0], isA<AmeTxt>());
      expect(
        (children[0] as AmeTxt).text,
        equals('a]b'),
        reason: 'Bracket inside string must be preserved',
      );
    });

    /// Audit Bug #26c (deeper coverage of #26a): an escaped quote inside a
    /// string literal that is followed by a `)` must not terminate the
    /// parenthesized region. Verifies the fix's `escaped` state correctly
    /// keeps `inString` across `\"` so the outer `)` is matched at the
    /// right depth.
    ///
    /// Spec section: specification/v1.0/syntax.md (String Literals, escape sequences)
    /// Audit reference: AUDIT_VERDICTS.md#bug-26
    /// Pre-fix expected: FAIL — _extractParenContent flips out of the string at
    ///   the literal `"` after the backslash and matches the next `)` early.
    /// Post-fix expected: PASS — `\"oops)\"` is preserved verbatim and the
    ///   trailing `body` positional argument is intact.
    test('escaped quote followed by paren is preserved', () {
      final result = parse(r'root = txt("she said \"oops)\" today", body)');
      expect(result, isA<AmeTxt>());
      final txt = result as AmeTxt;
      expect(
        txt.text,
        equals('she said "oops)" today'),
        reason:
            'Escaped quotes around a `)` must be preserved verbatim in string content',
      );
      expect(
        txt.style,
        equals(TxtStyle.body),
        reason:
            'Trailing `body` positional argument must still be parsed as the style',
      );
    });
  });

  // ════════════════════════════════════════════════════════════════════
  // Bug 27 (Flutter analog of v1.2 Bug 11) —
  //   ref recursion has no cycle limit; circular ref crashes parser.
  // ════════════════════════════════════════════════════════════════════

  group('Bug 27 — ref cycle detection', () {
    /// Audit Bug #27: `_resolveTree` follows `AmeRef` nodes recursively
    /// without a visited set or depth limit. A registry containing
    /// `a = b`, `b = a` causes infinite recursion and a StackOverflowError
    /// (Dart's analog of the JVM crash that motivated Kotlin Bug 11).
    ///
    /// Spec section: specification/v1.0/syntax.md (Forward references, depth)
    /// Audit reference: AUDIT_VERDICTS.md#bug-27
    /// Pre-fix expected: FAIL — getResolvedTree() throws StackOverflowError
    ///   or the test exceeds its 5-second timeout.
    /// Post-fix expected: PASS — parser detects the cycle, records a warning,
    ///   and returns within the timeout without crashing.
    test(
      'circular ref does not stack overflow',
      () {
        final parser = AmeParser();
        parser.parseLine('a = b');
        parser.parseLine('b = a');
        parser.parseLine('root = a');
        // Should not throw StackOverflowError; result MAY be a ref-loop
        // placeholder (the unresolved AmeRef) or a partial resolution.
        expect(parser.getResolvedTree, returnsNormally);
      },
      timeout: const Timeout(Duration(seconds: 5)),
    );

    /// Audit Bug #27b (deeper coverage of #27): the diamond ref pattern
    /// (`root = col([a, b])`, `a = c`, `b = c`, `c = txt("shared")`) where
    /// two distinct refs both point at the same node is NOT a cycle and must
    /// resolve correctly. Verifies that the visited set in resolveTree is
    /// scoped per branch (immutable per call), not shared across siblings.
    ///
    /// Spec section: specification/v1.0/syntax.md (Forward references)
    /// Audit reference: AUDIT_VERDICTS.md#bug-27
    /// Pre-fix expected: PASS today (the bug is stack overflow on cycles, not
    ///   on diamonds; this test guards against an over-eager fix that would
    ///   incorrectly flag diamonds as cycles via mutable visited propagation).
    /// Post-fix expected: PASS — both children resolve to the shared txt node.
    test('diamond ref pattern resolves correctly', () {
      final parser = AmeParser();
      parser.parseLine(r'c = txt("shared")');
      parser.parseLine('a = c');
      parser.parseLine('b = c');
      parser.parseLine('root = col([a, b])');

      final resolved = parser.getResolvedTree();
      expect(resolved, isA<AmeCol>(),
          reason: 'Diamond ref pattern should resolve cleanly');
      final children = (resolved as AmeCol).children;
      expect(children.length, equals(2),
          reason: 'Both children must be present');
      expect(children[0], isA<AmeTxt>());
      expect(children[1], isA<AmeTxt>());
      expect(
        (children[0] as AmeTxt).text,
        equals('shared'),
        reason: 'First diamond branch must resolve to the shared txt',
      );
      expect(
        (children[1] as AmeTxt).text,
        equals('shared'),
        reason: 'Second diamond branch must resolve to the shared txt',
      );
    });

    /// Audit Bug #27c (structural belt-and-braces, mirrors Swift WP#3): the
    /// runtime test alone could regress silently if a future engineer
    /// removes the visited set but the bug 27 test happens to escape via
    /// timeout-as-pass. This source-structural assertion documents the
    /// fix shape for grep-based reviewers.
    ///
    /// Spec section: specification/v1.0/syntax.md (Forward references, depth)
    /// Audit reference: AUDIT_VERDICTS.md#bug-27
    /// Pre-fix expected: FAIL — _resolveTree source contains no cycle-detection token.
    /// Post-fix expected: PASS — _resolveTree contains a `visited` parameter or analog.
    test('resolve tree contains visited cycle detection', () {
      final source = File('lib/src/ame_parser.dart').readAsStringSync();
      final cycleDetectionTokens = [
        'visited',
        'depth:',
        'maxDepth',
        'MAX_DEPTH',
        'seenIds',
        'inProgress',
      ];
      final hasCycleDetection =
          cycleDetectionTokens.any(source.contains);
      expect(
        hasCycleDetection,
        isTrue,
        reason:
            'BUG #27: ame_parser.dart must contain cycle-detection state in '
            '_resolveTree (visited Set or depth limit). Add the visited '
            'parameter pattern documented in regression-protocol.md.',
      );
    });
  });

  // ════════════════════════════════════════════════════════════════════
  // Bug 29 (Flutter analog of v1.2 Bug 21) —
  //   Dart jsonEncode strips trailing `.0` from whole-number Doubles,
  //   breaking cross-runtime byte-equality with Kotlin canonical output.
  // ════════════════════════════════════════════════════════════════════

  group('Bug 29 — canonical Double serialization', () {
    /// Audit Bug #29: Dart's stdlib `jsonEncode` may serialize `Double(1.0)`
    /// as `1` (no trailing zero), while Kotlin's kotlinx.serialization emits
    /// `1.0`. Same AmeNode tree therefore would produce divergent JSON
    /// across runtimes for any chart with whole-number Doubles or progress
    /// with a whole-number value. This is suspected because Dart's `num`
    /// JSON encoding is permitted to normalize whole doubles to integer
    /// form, but verification is required (Phase C of WP#7).
    ///
    /// Per `regression-protocol.md` §7 (Kotlin-first), Kotlin's preserve-`.0`
    /// behavior is canonical. Flutter must mirror it if Dart diverges.
    ///
    /// Spec section: specification/v1.0/conformance.md §1.1 (Core Conformance,
    ///   canonical JSON output matches AmeSerializer.kt)
    /// Audit reference: AUDIT_VERDICTS.md#bug-29
    /// Pre-fix expected: FAIL or PASS depending on Dart encoder behavior;
    ///   Phase C verification gates whether Bug 29 is REAL.
    /// Post-fix expected: PASS — Flutter JSON contains `[1.0,2.0,3.0]` for
    ///   `chart.values`, `[[1.0,2.0,3.0],[4.0,5.0,6.0]]` for `chart.series`,
    ///   and `1.0` for `progress.value`.
    test('chart values serialize with kotlin canonical form', () {
      final chart = const AmeChart(
        type: ChartType.bar,
        values: [1.0, 2.0, 3.0],
      );
      final json = AmeSerializer.toJson(chart);
      expect(
        json.contains('"values":[1.0,2.0,3.0]'),
        isTrue,
        reason:
            'BUG #29: chart.values must serialize whole-number Doubles with `.0` '
            'to match Kotlin canonical output. JSON was: $json',
      );
    });

    /// Companion to Bug 29 covering chart.series (the field that fixture 57
    /// actually exposes).
    test('chart series serialize with kotlin canonical form', () {
      final chart = const AmeChart(
        type: ChartType.line,
        series: [
          [1.0, 2.0, 3.0],
          [4.0, 5.0, 6.0],
        ],
      );
      final json = AmeSerializer.toJson(chart);
      expect(
        json.contains('"series":[[1.0,2.0,3.0],[4.0,5.0,6.0]]'),
        isTrue,
        reason:
            'BUG #29: chart.series must serialize whole-number Doubles with `.0` '
            'to match Kotlin canonical output. JSON was: $json',
      );
    });

    /// Companion to Bug 29 covering Progress.value (the only other Float/Double
    /// field in the AME ecosystem that affects cross-runtime parity).
    test('progress value serializes with kotlin canonical form', () {
      final prog = const AmeProgress(value: 1.0);
      final json = AmeSerializer.toJson(prog);
      expect(
        json.contains('"value":1.0'),
        isTrue,
        reason:
            'BUG #29: progress.value must serialize whole-number Doubles with `.0` '
            'to match Kotlin canonical output. JSON was: $json',
      );
    });
  });

  // ════════════════════════════════════════════════════════════════════
  // Bug 30 (Flutter analog of v1.2 Bug 6) —
  //   AmeCallout AST does not carry the spec-promised color field.
  // ════════════════════════════════════════════════════════════════════

  group('Bug 30 — Callout.color', () {
    /// Audit Bug #30: primitives.md documents `callout(... color=)` for
    /// SemanticColor override. The Flutter `AmeCallout` class has no
    /// `color` field, so the parser silently drops the named arg.
    ///
    /// Spec section: specification/v1.0/primitives.md (Callout, SemanticColor)
    /// Audit reference: AUDIT_VERDICTS.md#bug-30
    /// Pre-fix expected: FAIL — encoded JSON does not contain "color":"success".
    /// Post-fix expected: PASS — the `color` round-trips through serialize/deserialize.
    test('callout accepts color parameter', () {
      final result = parse(r'root = callout(info, "msg", color=success)');
      expect(result, isA<AmeCallout>(),
          reason: 'Parse returned wrong type for valid input');
      final json = AmeSerializer.toJson(result!);
      expect(
        json.contains('"color":"success"'),
        isTrue,
        reason:
            'BUG #30: callout color must be preserved through parse and serialize. '
            'JSON was: $json',
      );
    });
  });

  // ════════════════════════════════════════════════════════════════════
  // Bug 31 (Flutter analog of v1.2 Bug 7) —
  //   chart series does not support an array of $path refs.
  // ════════════════════════════════════════════════════════════════════

  group('Bug 31 — Chart.seriesPaths', () {
    /// Audit Bug #31: primitives.md example
    /// `chart(line, series=[$revenue, $expenses])` implies multi-series via
    /// an array of `$path` references. Parser only supports a single
    /// `seriesPath` or a literal numeric matrix.
    ///
    /// Spec section: specification/v1.0/primitives.md (Chart series)
    /// Audit reference: AUDIT_VERDICTS.md#bug-31
    /// Pre-fix expected: FAIL — series is null because `$path` array
    ///   elements are not resolved.
    /// Post-fix expected: PASS — series resolves to two lists, one per `$path`.
    test('chart series array of path refs', () {
      final result = parse(
        'root = chart(line, series=[\$a, \$b])\n'
        '---\n'
        '{"a":[1,2,3],"b":[4,5,6]}',
      );
      expect(result, isA<AmeChart>());
      final chart = result as AmeChart;
      expect(chart.type, equals(ChartType.line));
      expect(chart.series, isNotNull,
          reason: 'series must resolve from array of \$path refs');
      expect(chart.series!.length, equals(2),
          reason: 'series must contain two paths\' data');
      expect(chart.series![0], equals(<double>[1.0, 2.0, 3.0]));
      expect(chart.series![1], equals(<double>[4.0, 5.0, 6.0]));
    });

    /// Audit Bug #31b (deeper coverage of #31): when an array of $path refs
    /// resolves to series of unequal length (e.g., $a=[1,2,3] and $b=[4,5]),
    /// the chart must preserve both series verbatim. Mirrors existing
    /// behavior for literal-array series (`series=[[1,2,3],[4,5]]`) and lets
    /// the renderer decide how to align the X-axis (per Bug 28).
    ///
    /// Spec section: specification/v1.0/primitives.md (Chart series)
    /// Audit reference: AUDIT_VERDICTS.md#bug-31
    /// Pre-fix expected: FAIL — series is null/empty because $path array
    ///   elements are not resolved.
    /// Post-fix expected: PASS — series resolves to [[1,2,3],[4,5]].
    test('chart series array of paths allows mismatched lengths', () {
      final result = parse(
        'root = chart(line, series=[\$a, \$b])\n'
        '---\n'
        '{"a":[1,2,3],"b":[4,5]}',
      );
      expect(result, isA<AmeChart>());
      final chart = result as AmeChart;
      expect(chart.type, equals(ChartType.line));
      expect(chart.series, isNotNull,
          reason: 'Mismatched-length series must still resolve');
      expect(chart.series!.length, equals(2),
          reason: 'Both paths must produce a series');
      expect(chart.series![0], equals(<double>[1.0, 2.0, 3.0]),
          reason: 'First series preserved verbatim');
      expect(chart.series![1], equals(<double>[4.0, 5.0]),
          reason: 'Second series preserved verbatim (no padding)');
    });
  });

  // ════════════════════════════════════════════════════════════════════
  // Bug 32 (Flutter analog of v1.2 Bug 8) —
  //   streaming parseLine() does not apply --- + JSON data section.
  // ════════════════════════════════════════════════════════════════════

  group('Bug 32 — streaming `---` + JSON data section', () {
    /// Audit Bug #32: streaming.md describes streaming with `---` followed
    /// by a JSON data block. `parseLine()` returns null for `---` and never
    /// accumulates subsequent JSON lines, so streaming consumers cannot
    /// resolve `$path` references.
    ///
    /// Spec section: specification/v1.0/streaming.md (Data section)
    /// Audit reference: AUDIT_VERDICTS.md#bug-32
    /// Pre-fix expected: FAIL — getResolvedTree() cannot resolve `$x`
    ///   because the data section was never ingested via parseLine.
    /// Post-fix expected: PASS — streaming a `---` line followed by JSON
    ///   lines stores the data model and `$x` resolves to its value.
    test('streaming mode applies data section', () {
      final parser = AmeParser();
      parser.parseLine('---');
      parser.parseLine(r'{"greeting":"hello"}');
      parser.parseLine(r'root = txt($greeting)');

      final resolved = parser.getResolvedTree();
      expect(resolved, isNotNull,
          reason: 'Streaming parse should produce a tree');
      expect(resolved, isA<AmeTxt>());
      expect(
        (resolved as AmeTxt).text,
        equals('hello'),
        reason:
            r'$path references emitted via parseLine must resolve against the data section',
      );
    });

    /// Audit Bug #32b (deeper coverage of #32): JSON content MAY span
    /// multiple `parseLine()` calls. The buffer is parsed once at
    /// `getResolvedTree()` time, so any whitespace introduced between
    /// chunks (parsers append a newline per call) does not affect the
    /// result.
    ///
    /// Spec section: specification/v1.0/streaming.md (Streaming Data Sections)
    /// Audit reference: AUDIT_VERDICTS.md#bug-32
    /// Pre-fix expected: FAIL — `$x` would not resolve under any chunking.
    /// Post-fix expected: PASS — chunked JSON reassembles correctly.
    test('streaming mode handles chunked json', () {
      final parser = AmeParser();
      parser.parseLine(r'root = txt($greeting)');
      parser.parseLine('---');
      parser.parseLine(r'{"greeting":');
      parser.parseLine(r'    "hello"');
      parser.parseLine('}');

      final resolved = parser.getResolvedTree();
      expect(resolved, isNotNull,
          reason: 'Chunked-JSON streaming parse should produce a tree');
      expect(resolved, isA<AmeTxt>());
      expect(
        (resolved as AmeTxt).text,
        equals('hello'),
        reason:
            'JSON spanning multiple parseLine() calls must reassemble before resolution',
      );
    });
  });

  // ════════════════════════════════════════════════════════════════════
  // Bug 35 (Flutter analog of v1.2 Bug 15) —
  //   AmeSerializer.fromJson swallows decode failures into null.
  // ════════════════════════════════════════════════════════════════════

  group('Bug 35 — diagnostic decoding API', () {
    /// Audit Bug #35: `AmeSerializer.fromJson(invalidJson)` returns null
    /// with no diagnostic. Hosts cannot distinguish invalid JSON from
    /// schema mismatch from missing root.
    ///
    /// Spec section: specification/v1.0/integration.md (Serialization)
    /// Audit reference: AUDIT_VERDICTS.md#bug-35
    /// Pre-fix expected: FAIL — `fromJsonOrError` API does not exist on
    ///   AmeSerializer; the mirror lookup returns no matching declaration.
    /// Post-fix expected: PASS — a diagnostic API exists on AmeSerializer
    ///   that returns either the decoded node or a structured failure
    ///   describing why decoding failed.
    ///
    /// Uses `dart:mirrors` to check for the API surface without requiring
    /// the test file to compile-time reference a future symbol. This
    /// mirrors Kotlin's reflection-based approach (see
    /// `AuditedBugRegressionTest.testSerializerReturnsDistinguishableErrorOnInvalidJson`).
    test('serializer returns distinguishable error on invalid json', () {
      // Today: only `fromJson(String): AmeNode?` exists. Both `null` and a
      // valid decoding fall on the same return type with no diagnostic.
      final nullResult = AmeSerializer.fromJson('{');
      expect(nullResult, isNull,
          reason: 'Invalid JSON must not produce a node');

      final classMirror = reflectClass(AmeSerializer);
      final hasDiagnosticApi = classMirror.declarations.keys.any((symbol) {
        final name = MirrorSystem.getName(symbol);
        return name == 'fromJsonOrError' || name == 'fromJsonResult';
      });
      expect(
        hasDiagnosticApi,
        isTrue,
        reason: 'AmeSerializer must expose a diagnostic decoding API per Bug 35',
      );
    });
  });
}
