import 'dart:convert';

import 'package:MBG_Inspektionen/backend/api.dart';
import 'package:MBG_Inspektionen/backend/offlineProvider.dart' as OP;
import 'package:MBG_Inspektionen/classes/data/inspection_location.dart';
import 'package:MBG_Inspektionen/classes/requestData.dart';
import 'package:flutter/foundation.dart';

const _hiddenInspectionsDoc = '__hidden_inspections_v1__';

class HiddenInspectionEntry {
  final String pjNr;
  final String? localId;
  final String? title;
  final int hiddenAtMs;

  const HiddenInspectionEntry({
    required this.pjNr,
    this.localId,
    this.title,
    required this.hiddenAtMs,
  });

  factory HiddenInspectionEntry.fromJson(Map<String, dynamic> json) =>
      HiddenInspectionEntry(
        pjNr: json['pjNr']?.toString() ?? '',
        localId: json['localId']?.toString(),
        title: json['title']?.toString(),
        hiddenAtMs: (json['hiddenAtMs'] is int)
            ? json['hiddenAtMs'] as int
            : int.tryParse(json['hiddenAtMs']?.toString() ?? '') ??
                DateTime.now().millisecondsSinceEpoch,
      );

  Map<String, dynamic> toJson() => {
        'pjNr': pjNr,
        if (localId != null) 'localId': localId,
        if (title != null) 'title': title,
        'hiddenAtMs': hiddenAtMs,
      };
}

class InspectionVisibility {
  static final InspectionVisibility _instance =
      InspectionVisibility._internal();
  factory InspectionVisibility() => _instance;
  InspectionVisibility._internal();

  Map<String, HiddenInspectionEntry>? _cache;

  String? _normalizePjNr(dynamic value) {
    final raw = value?.toString().trim();
    if (raw == null ||
        raw.isEmpty ||
        raw == 'null' ||
        raw == 'undefined' ||
        raw == 'Unbekannt') {
      return null;
    }
    return raw;
  }

  String? _extractPjNrFromScopedId(String? scopedId) {
    final raw = scopedId?.trim();
    if (raw == null || raw.isEmpty) return null;
    final prefix = raw.split('-').first.trim();
    final parsed = int.tryParse(prefix);
    if (parsed == null || parsed <= 0) return null;
    return parsed.toString();
  }

  Map<String, dynamic>? _extractDataMap(RequestData rd) {
    final jsonData = rd.json;
    if (jsonData == null) return null;
    final dataField = jsonData['data'];
    if (dataField is Map<String, dynamic>) {
      return Map<String, dynamic>.from(dataField);
    }
    if (dataField is Map) {
      return Map<String, dynamic>.from(dataField.cast<String, dynamic>());
    }
    if (dataField is String && dataField.trim().isNotEmpty) {
      try {
        final decoded = json.decode(dataField);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded.cast<String, dynamic>());
        }
      } catch (_) {}
    }
    return null;
  }

  Future<Map<String, HiddenInspectionEntry>> _loadHiddenInspections() async {
    if (_cache != null) return _cache!;

    final raw = await OP.getJson(_hiddenInspectionsDoc);
    final parsed = <String, HiddenInspectionEntry>{};
    if (raw == null) {
      _cache = parsed;
      return parsed;
    }

    final itemsRaw = raw['items'] ?? raw;
    if (itemsRaw is Map) {
      for (final entry in itemsRaw.entries) {
        final key = entry.key.toString();
        final value = entry.value;
        if (value is Map<String, dynamic>) {
          final hidden = HiddenInspectionEntry.fromJson(value);
          final normalized = _normalizePjNr(hidden.pjNr);
          if (normalized != null) parsed[normalized] = hidden;
        } else if (value is Map) {
          final hidden = HiddenInspectionEntry.fromJson(
            Map<String, dynamic>.from(value.cast<String, dynamic>()),
          );
          final normalized = _normalizePjNr(hidden.pjNr);
          if (normalized != null) parsed[normalized] = hidden;
        } else {
          final normalized = _normalizePjNr(key);
          if (normalized != null) {
            parsed[normalized] = HiddenInspectionEntry(
              pjNr: normalized,
              hiddenAtMs: DateTime.now().millisecondsSinceEpoch,
            );
          }
        }
      }
    }

    _cache = parsed;
    return parsed;
  }

  Future<void> _persistHiddenInspections(
      Map<String, HiddenInspectionEntry> entries) async {
    await OP.storeJson(_hiddenInspectionsDoc, {
      'items': entries.map((k, v) => MapEntry(k, v.toJson())),
    });
    _cache = Map<String, HiddenInspectionEntry>.from(entries);
  }

  Future<Map<String, HiddenInspectionEntry>> getHiddenInspections() async {
    final entries = await _loadHiddenInspections();
    return Map<String, HiddenInspectionEntry>.from(entries);
  }

  Future<Set<String>> getHiddenPjNrs() async =>
      (await _loadHiddenInspections()).keys.toSet();

  Future<bool> isHiddenPjNr(String? pjNr) async {
    final normalized = _normalizePjNr(pjNr);
    if (normalized == null) return false;
    final hidden = await getHiddenPjNrs();
    return hidden.contains(normalized);
  }

  Future<void> hideInspection(InspectionLocation inspection) async {
    final pjNr = _normalizePjNr(inspection.pjNr);
    if (pjNr == null) return;

    final entries = await _loadHiddenInspections();
    entries[pjNr] = HiddenInspectionEntry(
      pjNr: pjNr,
      localId: inspection.id,
      title: inspection.pjName ?? inspection.title,
      hiddenAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    await _persistHiddenInspections(entries);
  }

  Future<void> restoreInspection(String pjNr) async {
    final normalized = _normalizePjNr(pjNr);
    if (normalized == null) return;
    final entries = await _loadHiddenInspections();
    entries.remove(normalized);
    await _persistHiddenInspections(entries);
  }

  String? extractPjNrFromRequest(RequestData? rd) {
    if (rd == null) return null;
    try {
      final data = _extractDataMap(rd);
      final fromData = _normalizePjNr(data?['PjNr']);
      if (fromData != null) return fromData;

      final fromParent = _extractPjNrFromScopedId(
        data?['parent_local_id']?.toString(),
      );
      if (fromParent != null) return fromParent;

      final fromLocalId =
          _extractPjNrFromScopedId(data?['local_id']?.toString());
      if (fromLocalId != null) return fromLocalId;

      final fromTopLevel = _normalizePjNr(rd.json?['PjNr']);
      if (fromTopLevel != null) return fromTopLevel;
    } catch (e) {
      debugPrint('extractPjNrFromRequest failed: $e');
    }
    return null;
  }

  Future<List<(String, RequestData?)>> filterVisibleFailedRequests(
    List<(String, RequestData?)> requests,
  ) async {
    final hidden = await getHiddenPjNrs();
    if (hidden.isEmpty) return requests;
    return requests.where((entry) {
      final pjNr = extractPjNrFromRequest(entry.$2);
      if (pjNr == null) return true;
      return !hidden.contains(pjNr);
    }).toList();
  }

  Future<void> removeFailedRequestsForInspection(String pjNr) async {
    final normalized = _normalizePjNr(pjNr);
    if (normalized == null) return;

    final requests = await API().local.getAllFailedRequests() ?? [];
    for (final (id, requestData) in requests) {
      final reqPjNr = extractPjNrFromRequest(requestData);
      if (reqPjNr == normalized) {
        API().local.failedRequestWasSuccessful(id, wasntTho: true);
      }
    }
  }

  Future<void> removeFailedRequestsForHiddenInspections() async {
    final hidden = await getHiddenPjNrs();
    if (hidden.isEmpty) return;

    final requests = await API().local.getAllFailedRequests() ?? [];
    for (final (id, requestData) in requests) {
      final reqPjNr = extractPjNrFromRequest(requestData);
      if (reqPjNr != null && hidden.contains(reqPjNr)) {
        API().local.failedRequestWasSuccessful(id, wasntTho: true);
      }
    }
  }
}
