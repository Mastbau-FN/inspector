import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

final inspectionDownloadWarningsRevision = ValueNotifier<int>(0);

class InspectionDownloadWarning {
  final String hash;
  final String filename;
  final List<String> locations;

  InspectionDownloadWarning({
    required this.hash,
    required this.filename,
    required List<String> locations,
  }) : locations = List.unmodifiable(locations);

  Map<String, dynamic> toJson() => {
        'hash': hash,
        'filename': filename,
        'locations': locations,
      };

  factory InspectionDownloadWarning.fromJson(Map<String, dynamic> json) =>
      InspectionDownloadWarning(
        hash: json['hash'] as String,
        filename: json['filename'] as String,
        locations: (json['locations'] as List).cast<String>(),
      );
}

String _storageKey(String inspectionKey) =>
    'inspection_download_warnings:$inspectionKey';

String _reviewedKey(String inspectionKey) =>
    '${_storageKey(inspectionKey)}:reviewed';

Future<List<InspectionDownloadWarning>> loadInspectionDownloadWarnings(
  String inspectionKey,
) async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_storageKey(inspectionKey));
  if (raw == null) return [];
  final reviewed =
      (prefs.getStringList(_reviewedKey(inspectionKey)) ?? []).toSet();
  try {
    return (jsonDecode(raw) as List)
        .map((value) => InspectionDownloadWarning.fromJson(
              Map<String, dynamic>.from(value as Map),
            ))
        .where((warning) => !reviewed.contains(warning.hash))
        .toList();
  } on FormatException {
    return [];
  } on TypeError {
    return [];
  }
}

Future<void> acknowledgeInspectionDownloadWarnings(
  String inspectionKey,
  List<InspectionDownloadWarning> shownWarnings,
) async {
  final pending = await loadInspectionDownloadWarnings(inspectionKey);
  final pendingHashes = pending.map((warning) => warning.hash).toSet();
  final prefs = await SharedPreferences.getInstance();
  final key = _reviewedKey(inspectionKey);
  final reviewed = {
    ...?prefs.getStringList(key),
    for (final warning in shownWarnings)
      if (pendingHashes.contains(warning.hash)) warning.hash,
  };
  if (!await prefs.setStringList(key, reviewed.toList())) {
    throw StateError(
        'Geprüfte Download-Hinweise konnten nicht gespeichert werden');
  }
  inspectionDownloadWarningsRevision.value++;
}

Future<void> saveInspectionDownloadWarnings(
  String inspectionKey,
  List<InspectionDownloadWarning> warnings,
) async {
  // A file may be referenced by several inspection entries. Show its name
  // once while retaining every place where the original needs checking.
  final byHash = <String, InspectionDownloadWarning>{};
  for (final warning in warnings) {
    byHash[warning.hash] = InspectionDownloadWarning(
      hash: warning.hash,
      filename: warning.filename,
      locations: {
        ...?byHash[warning.hash]?.locations,
        ...warning.locations,
      }.toList(),
    );
  }
  final prefs = await SharedPreferences.getInstance();
  final key = _storageKey(inspectionKey);
  final saved = byHash.isEmpty
      ? await prefs.remove(key)
      : await prefs.setString(
          key,
          jsonEncode(byHash.values.map((warning) => warning.toJson()).toList()),
        );
  if (!saved)
    throw StateError('Download-Hinweise konnten nicht gespeichert werden');

  // A successfully repaired file starts a new incident if it becomes empty
  // again later. Keep acknowledgements only for still-present source issues.
  final reviewedKey = _reviewedKey(inspectionKey);
  final reviewed = prefs.getStringList(reviewedKey);
  if (reviewed != null) {
    final retained = reviewed.where(byHash.containsKey).toList();
    if (retained.length != reviewed.length) {
      final saved = retained.isEmpty
          ? await prefs.remove(reviewedKey)
          : await prefs.setStringList(reviewedKey, retained);
      if (!saved) {
        throw StateError(
            'Geprüfte Download-Hinweise konnten nicht aktualisiert werden');
      }
    }
  }
  inspectionDownloadWarningsRevision.value++;
}
