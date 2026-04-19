/// Actions define what happens when a user interacts with an AME element.
/// They appear as arguments to interactive primitives (primarily btn).
///
/// The renderer dispatches all actions to the host app via an action handler.
/// The renderer MUST NOT execute actions directly.
sealed class AmeAction {
  const AmeAction();

  Map<String, dynamic> toJson();

  static AmeAction? fromJson(Map<String, dynamic> json) {
    switch (json['_type']) {
      case 'tool':
        return AmeCallTool.fromJson(json);
      case 'uri':
        return AmeOpenUri.fromJson(json);
      case 'nav':
        return AmeNavigate.fromJson(json);
      case 'copy':
        return AmeCopyText.fromJson(json);
      case 'submit':
        return AmeSubmit.fromJson(json);
      default:
        return null;
    }
  }
}

/// Invoke a named tool through the host app's tool execution pipeline.
/// [args] values may contain `${input.fieldId}` references as literal strings —
/// these are resolved by the renderer at dispatch time, NOT by the parser.
final class AmeCallTool extends AmeAction {
  final String name;
  final Map<String, String> args;

  const AmeCallTool({required this.name, this.args = const {}});

  factory AmeCallTool.fromJson(Map<String, dynamic> json) {
    final rawArgs = json['args'];
    final Map<String, String> args;
    if (rawArgs is Map<String, dynamic>) {
      args = rawArgs.map((k, v) => MapEntry(k, v.toString()));
    } else {
      args = const {};
    }
    return AmeCallTool(
      name: json['name'] as String? ?? '',
      args: args,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'_type': 'tool', 'name': name};
    if (args.isNotEmpty) map['args'] = args;
    return map;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AmeCallTool &&
          name == other.name &&
          _mapsEqual(args, other.args);

  @override
  int get hashCode => Object.hash(name, Object.hashAll(args.entries));

  @override
  String toString() => 'AmeCallTool(name: $name, args: $args)';
}

/// Open a URI using the platform's default handler.
final class AmeOpenUri extends AmeAction {
  final String uri;

  const AmeOpenUri({required this.uri});

  factory AmeOpenUri.fromJson(Map<String, dynamic> json) {
    return AmeOpenUri(uri: json['uri'] as String? ?? '');
  }

  @override
  Map<String, dynamic> toJson() => {'_type': 'uri', 'uri': uri};

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is AmeOpenUri && uri == other.uri;

  @override
  int get hashCode => uri.hashCode;

  @override
  String toString() => 'AmeOpenUri(uri: $uri)';
}

/// Navigate to a screen/route within the host application.
final class AmeNavigate extends AmeAction {
  final String route;

  const AmeNavigate({required this.route});

  factory AmeNavigate.fromJson(Map<String, dynamic> json) {
    return AmeNavigate(route: json['route'] as String? ?? '');
  }

  @override
  Map<String, dynamic> toJson() => {'_type': 'nav', 'route': route};

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is AmeNavigate && route == other.route;

  @override
  int get hashCode => route.hashCode;

  @override
  String toString() => 'AmeNavigate(route: $route)';
}

/// Copy a text string to the system clipboard.
final class AmeCopyText extends AmeAction {
  final String text;

  const AmeCopyText({required this.text});

  factory AmeCopyText.fromJson(Map<String, dynamic> json) {
    return AmeCopyText(text: json['text'] as String? ?? '');
  }

  @override
  Map<String, dynamic> toJson() => {'_type': 'copy', 'text': text};

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is AmeCopyText && text == other.text;

  @override
  int get hashCode => text.hashCode;

  @override
  String toString() => 'AmeCopyText(text: $text)';
}

/// Collect all input/toggle values from the current card's subtree,
/// merge with [staticArgs], and dispatch as a CallTool action.
final class AmeSubmit extends AmeAction {
  final String toolName;
  final Map<String, String> staticArgs;

  const AmeSubmit({required this.toolName, this.staticArgs = const {}});

  factory AmeSubmit.fromJson(Map<String, dynamic> json) {
    final rawArgs = json['staticArgs'];
    final Map<String, String> staticArgs;
    if (rawArgs is Map<String, dynamic>) {
      staticArgs = rawArgs.map((k, v) => MapEntry(k, v.toString()));
    } else {
      staticArgs = const {};
    }
    return AmeSubmit(
      toolName: json['toolName'] as String? ?? '',
      staticArgs: staticArgs,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'_type': 'submit', 'toolName': toolName};
    if (staticArgs.isNotEmpty) map['staticArgs'] = staticArgs;
    return map;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AmeSubmit &&
          toolName == other.toolName &&
          _mapsEqual(staticArgs, other.staticArgs);

  @override
  int get hashCode => Object.hash(toolName, Object.hashAll(staticArgs.entries));

  @override
  String toString() =>
      'AmeSubmit(toolName: $toolName, staticArgs: $staticArgs)';
}

bool _mapsEqual(Map<String, String> a, Map<String, String> b) {
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (b[entry.key] != entry.value) return false;
  }
  return true;
}
