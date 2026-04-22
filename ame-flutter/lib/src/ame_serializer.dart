import 'dart:convert';

import 'ame_action.dart';
import 'ame_node.dart';

/// Diagnostic outcome of [AmeSerializer.fromJsonOrError].
///
/// The legacy nullable [AmeSerializer.fromJson] swallows every failure into
/// a single `null` return, so hosts cannot distinguish invalid JSON, schema
/// mismatch, missing root, or unexpected runtime failures. This API is
/// additive; the legacy nullable APIs stay unchanged.
sealed class AmeDecodeResult {
  const AmeDecodeResult();

  /// Returns the decoded [AmeNode] on success, or `null` on failure.
  /// Convenience for callers that only need the legacy null-or-node shape.
  AmeNode? get nodeOrNull;
}

final class AmeDecodeSuccess extends AmeDecodeResult {
  final AmeNode node;
  const AmeDecodeSuccess(this.node);

  @override
  AmeNode? get nodeOrNull => node;
}

final class AmeDecodeFailure extends AmeDecodeResult {
  /// Human-readable diagnostic of the failure mode (e.g., invalid JSON,
  /// schema mismatch, unknown `_type`).
  final String message;

  /// Underlying cause (e.g., [FormatException] for invalid JSON,
  /// [TypeError] for schema mismatch). `null` when the failure was
  /// detected at the AME layer (e.g., unrecognized `_type` discriminator).
  final Object? cause;

  const AmeDecodeFailure(this.message, [this.cause]);

  @override
  AmeNode? get nodeOrNull => null;
}

/// Symmetric diagnostic outcome of [AmeSerializer.actionFromJsonOrError].
sealed class AmeActionDecodeResult {
  const AmeActionDecodeResult();

  /// Returns the decoded [AmeAction] on success, or `null` on failure.
  AmeAction? get actionOrNull;
}

final class AmeActionDecodeSuccess extends AmeActionDecodeResult {
  final AmeAction action;
  const AmeActionDecodeSuccess(this.action);

  @override
  AmeAction? get actionOrNull => action;
}

final class AmeActionDecodeFailure extends AmeActionDecodeResult {
  final String message;
  final Object? cause;
  const AmeActionDecodeFailure(this.message, [this.cause]);

  @override
  AmeAction? get actionOrNull => null;
}

/// Serializes and deserializes AmeNode trees and AmeAction objects to/from JSON.
///
/// Key ordering: all JSON output uses sorted keys (alphabetical) to produce
/// canonical output per RFC 8785 (JSON Canonicalization Scheme).
///
/// Default values are omitted from output (matching canonical behavior).
///
/// Diagnostic APIs ([fromJsonOrError], [actionFromJsonOrError]) return a
/// sealed [AmeDecodeResult] / [AmeActionDecodeResult] so hosts can
/// distinguish invalid JSON, schema mismatch, and unexpected runtime
/// failures. Legacy nullable APIs delegate to the diagnostic versions.
class AmeSerializer {
  AmeSerializer._();

  static String toJson(AmeNode node) {
    final map = node.toJson();
    final sorted = _sortKeys(map);
    return jsonEncode(sorted);
  }

  static String treeToJson(AmeNode node, {bool prettyPrint = false}) {
    final map = node.toJson();
    final sorted = _sortKeys(map);
    if (prettyPrint) {
      return const JsonEncoder.withIndent('    ').convert(sorted);
    }
    return jsonEncode(sorted);
  }

  /// Decodes [jsonString] into an [AmeNode]. Returns `null` on any
  /// failure for backward compatibility. Hosts that need failure
  /// diagnostics should call [fromJsonOrError] instead.
  ///
  /// Implementation note: delegates to [fromJsonOrError] so the
  /// diagnostic and legacy paths share a single source of truth.
  static AmeNode? fromJson(String jsonString) =>
      fromJsonOrError(jsonString).nodeOrNull;

  /// Diagnostic-bearing counterpart to [fromJson]. Returns
  /// [AmeDecodeSuccess] with the decoded [AmeNode] on success, or
  /// [AmeDecodeFailure] naming the failure mode and carrying the
  /// original cause (when available).
  static AmeDecodeResult fromJsonOrError(String jsonString) {
    final dynamic raw;
    try {
      raw = jsonDecode(jsonString);
    } on FormatException catch (e) {
      return AmeDecodeFailure('AME JSON decoding failed: ${e.message}', e);
    } catch (e) {
      return AmeDecodeFailure(
          'Unexpected error during AME JSON decoding: $e', e);
    }
    if (raw is! Map<String, dynamic>) {
      return AmeDecodeFailure(
        'AME JSON root must be an object; got ${raw.runtimeType}',
      );
    }
    try {
      final node = AmeNode.fromJson(raw);
      if (node == null) {
        return AmeDecodeFailure(
          'AME JSON has unrecognized or missing _type discriminator: '
          '${raw['_type']}',
        );
      }
      return AmeDecodeSuccess(node);
    } catch (e) {
      return AmeDecodeFailure('Unexpected error during AME decoding: $e', e);
    }
  }

  static String actionToJson(AmeAction action) {
    return jsonEncode(_sortKeys(action.toJson()));
  }

  /// Decodes [jsonString] into an [AmeAction]. Returns `null` on any
  /// failure for backward compatibility. See [actionFromJsonOrError]
  /// for the diagnostic variant.
  static AmeAction? actionFromJson(String jsonString) =>
      actionFromJsonOrError(jsonString).actionOrNull;

  /// Diagnostic-bearing counterpart to [actionFromJson]. Mirrors
  /// [fromJsonOrError] for action payloads so cross-runtime hosts can
  /// use a single failure-handling pattern for both nodes and actions.
  static AmeActionDecodeResult actionFromJsonOrError(String jsonString) {
    final dynamic raw;
    try {
      raw = jsonDecode(jsonString);
    } on FormatException catch (e) {
      return AmeActionDecodeFailure(
          'AME action JSON decoding failed: ${e.message}', e);
    } catch (e) {
      return AmeActionDecodeFailure(
          'Unexpected error during AME action JSON decoding: $e', e);
    }
    if (raw is! Map<String, dynamic>) {
      return AmeActionDecodeFailure(
        'AME action JSON root must be an object; got ${raw.runtimeType}',
      );
    }
    try {
      final action = AmeAction.fromJson(raw);
      if (action == null) {
        return AmeActionDecodeFailure(
          'AME action JSON has unrecognized or missing _type discriminator: '
          '${raw['_type']}',
        );
      }
      return AmeActionDecodeSuccess(action);
    } catch (e) {
      return AmeActionDecodeFailure(
          'Unexpected error during AME action decoding: $e', e);
    }
  }

  /// Recursively sort all map keys alphabetically.
  static dynamic _sortKeys(dynamic value) {
    if (value is Map<String, dynamic>) {
      final entries = value.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      return Map<String, dynamic>.fromEntries(
        entries.map((e) => MapEntry(e.key, _sortKeys(e.value))),
      );
    }
    if (value is List) {
      return value.map(_sortKeys).toList();
    }
    return value;
  }
}
