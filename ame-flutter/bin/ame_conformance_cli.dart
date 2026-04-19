import 'dart:io';

import 'package:ame_flutter/ame_flutter.dart';

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('Usage: dart run ame_flutter:ame_conformance_cli <file.ame>');
    exit(1);
  }

  final input = File(args[0]).readAsStringSync();
  final parser = AmeParser();
  final tree = parser.parse(input);

  if (tree == null) {
    stderr.writeln('Parse returned null');
    exit(2);
  }

  print(AmeSerializer.toJson(tree));
}
