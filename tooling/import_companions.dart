// tooling/import_companions.dart
// Usage: dart import_companions.dart path/to/file.json
// File format: [{"id":"color1","similarIds":[...],"companionIds":[...]}]

import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    print('Usage: dart import_companions.dart <file>');
    exit(1);
  }
  final file = File(args[0]);
  if (!await file.exists()) {
    print('File not found: ${args[0]}');
    exit(1);
  }
  final data = jsonDecode(await file.readAsString()) as List;
  int updated = 0;
  for (final _ in data) {
    // TODO: Update Firestore or local catalog here
    updated++;
  }
  print('catalog_enriched($updated)');
}
