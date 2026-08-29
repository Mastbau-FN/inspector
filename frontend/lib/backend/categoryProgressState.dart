import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CategoryProgressEntry {
  final int totalCheckpoints;
  final int completedCheckpoints;
  final DateTime updatedAt;

  const CategoryProgressEntry({
    required this.totalCheckpoints,
    required this.completedCheckpoints,
    required this.updatedAt,
  });

  double get progress {
    if (totalCheckpoints <= 0) return 0;
    return (completedCheckpoints / totalCheckpoints).clamp(0.0, 1.0);
  }
}

class CategoryProgressState {
  CategoryProgressState._();

  static const recentWindow = Duration(days: 7);
  static const _storageKey = 'category_progress_state_v1';
  static final CategoryProgressState instance = CategoryProgressState._();

  final ValueNotifier<int> revision = ValueNotifier<int>(0);
  final Map<String, CategoryProgressEntry> _entriesByCategoryId = {};
  final Map<String, int> _totalCheckpointsByCategoryId = {};
  final Map<String, DateTime> _editedCheckpointAtByKey = {};
  final Map<String, String> _categoryIdByCoordinate = {};
  final Map<String, String> _categoryCoordinateById = {};
  final Map<String, String> _categoryCoordinateByCheckpointKey = {};
  final Map<String, String> _categoryIdByCheckpointKey = {};
  Future<void> _persistenceTail = Future<void>.value();

  static String categoryCoordinateKey({
    required int pjNr,
    required int categoryIndex,
  }) =>
      '$pjNr-$categoryIndex';

  static String checkpointKey({
    required int pjNr,
    required int categoryIndex,
    required int checkpointIndex,
  }) =>
      '$pjNr-$categoryIndex-$checkpointIndex';

  void upsert({
    required String categoryId,
    required int totalCheckpoints,
    required int completedCheckpoints,
    DateTime? updatedAt,
  }) {
    final normalizedTotal = totalCheckpoints < 0 ? 0 : totalCheckpoints;
    _totalCheckpointsByCategoryId[categoryId] = normalizedTotal;
    _entriesByCategoryId[categoryId] = CategoryProgressEntry(
      totalCheckpoints: normalizedTotal,
      completedCheckpoints: completedCheckpoints,
      updatedAt: updatedAt ?? DateTime.now(),
    );
    revision.value++;
    _queuePersistence();
  }

  void clear(String categoryId) {
    if (_entriesByCategoryId.remove(categoryId) != null) {
      revision.value++;
      _queuePersistence();
    }
  }

  double progressFor(String categoryId, {DateTime? now}) =>
      _recentEntryFor(categoryId, now: now)?.progress ?? 0;

  CategoryProgressEntry? entryFor(String categoryId, {DateTime? now}) =>
      _recentEntryFor(categoryId, now: now);

  void setTotal({
    required String categoryId,
    required int totalCheckpoints,
  }) {
    final normalizedTotal = totalCheckpoints < 0 ? 0 : totalCheckpoints;
    if (_totalCheckpointsByCategoryId[categoryId] == normalizedTotal) {
      return;
    }
    _totalCheckpointsByCategoryId[categoryId] = normalizedTotal;
    revision.value++;
    _queuePersistence();
  }

  int? totalFor(String categoryId) => _totalCheckpointsByCategoryId[categoryId];

  void registerCategory({
    required String categoryId,
    required int pjNr,
    required int categoryIndex,
    required int totalCheckpoints,
  }) {
    final coordinate = categoryCoordinateKey(
      pjNr: pjNr,
      categoryIndex: categoryIndex,
    );
    _categoryIdByCoordinate[coordinate] = categoryId;
    _categoryCoordinateById[categoryId] = coordinate;
    _totalCheckpointsByCategoryId[categoryId] =
        totalCheckpoints < 0 ? 0 : totalCheckpoints;
    _refreshCategoryEntry(categoryId, coordinate);
    revision.value++;
    _queuePersistence();
  }

  void checkpointAdded({required String categoryId}) {
    final currentTotal = _totalCheckpointsByCategoryId[categoryId];
    if (currentTotal == null) return;

    _totalCheckpointsByCategoryId[categoryId] = currentTotal + 1;
    final categoryCoordinate = _categoryCoordinateById[categoryId];
    if (categoryCoordinate != null) {
      _refreshCategoryEntry(categoryId, categoryCoordinate);
    }
    revision.value++;
    _queuePersistence();
  }

  void checkpointRemoved({
    required String categoryId,
    required String checkpointId,
    required int pjNr,
    required int categoryIndex,
    required int checkpointIndex,
  }) {
    final coordinateCheckpointKey = checkpointKey(
      pjNr: pjNr,
      categoryIndex: categoryIndex,
      checkpointIndex: checkpointIndex,
    );
    final keys = <String>{coordinateCheckpointKey};
    if (checkpointId.trim().isNotEmpty) {
      keys.add(checkpointId.trim());
    }
    for (final key in keys) {
      _editedCheckpointAtByKey.remove(key);
      _categoryCoordinateByCheckpointKey.remove(key);
      _categoryIdByCheckpointKey.remove(key);
    }

    final currentTotal = _totalCheckpointsByCategoryId[categoryId];
    if (currentTotal != null) {
      _totalCheckpointsByCategoryId[categoryId] =
          currentTotal > 0 ? currentTotal - 1 : 0;
    }
    final categoryCoordinate = _categoryCoordinateById[categoryId] ??
        categoryCoordinateKey(
          pjNr: pjNr,
          categoryIndex: categoryIndex,
        );
    _refreshCategoryEntry(categoryId, categoryCoordinate);
    revision.value++;
    _queuePersistence();
  }

  void resetAllInspectionProgress({bool clearPersisted = true}) {
    _clearMemory();
    revision.value++;
    if (clearPersisted) _queuePersistence(clear: true);
  }

  void _clearMemory() {
    _entriesByCategoryId.clear();
    _totalCheckpointsByCategoryId.clear();
    _editedCheckpointAtByKey.clear();
    _categoryIdByCoordinate.clear();
    _categoryCoordinateById.clear();
    _categoryCoordinateByCheckpointKey.clear();
    _categoryIdByCheckpointKey.clear();
  }

  void markCheckpointEdited(
    String checkpointKey, {
    DateTime? editedAt,
  }) {
    _editedCheckpointAtByKey[checkpointKey] = editedAt ?? DateTime.now();
    revision.value++;
    _queuePersistence();
  }

  void markCheckpointEditedByCoordinates({
    required int pjNr,
    required int categoryIndex,
    required int checkpointIndex,
    String? categoryId,
    String? checkpointId,
    DateTime? editedAt,
  }) {
    final key = checkpointId?.trim().isNotEmpty == true
        ? checkpointId!.trim()
        : checkpointKey(
            pjNr: pjNr,
            categoryIndex: categoryIndex,
            checkpointIndex: checkpointIndex,
          );
    final categoryCoordinate = categoryCoordinateKey(
      pjNr: pjNr,
      categoryIndex: categoryIndex,
    );
    _editedCheckpointAtByKey[key] = editedAt ?? DateTime.now();
    _categoryCoordinateByCheckpointKey[key] = categoryCoordinate;
    final explicitCategoryId = categoryId?.trim();
    final effectiveCategoryId =
        explicitCategoryId?.isNotEmpty == true ? explicitCategoryId : null;
    final coordinateCategoryId = _categoryIdByCoordinate[categoryCoordinate];
    final resolvedCategoryId = categoryIndex < 0
        ? effectiveCategoryId ?? coordinateCategoryId
        : coordinateCategoryId ?? effectiveCategoryId;
    if (resolvedCategoryId != null) {
      _categoryIdByCheckpointKey[key] = resolvedCategoryId;
      _refreshCategoryEntry(resolvedCategoryId, categoryCoordinate);
    }
    revision.value++;
    _queuePersistence();
  }

  void markCheckpointPendingByCoordinates({
    required int pjNr,
    required int categoryIndex,
    required int checkpointIndex,
    String? categoryId,
    String? checkpointId,
  }) {
    final coordinateKey = checkpointKey(
      pjNr: pjNr,
      categoryIndex: categoryIndex,
      checkpointIndex: checkpointIndex,
    );
    final keys = <String>{coordinateKey};
    final normalizedCheckpointId = checkpointId?.trim();
    if (normalizedCheckpointId != null && normalizedCheckpointId.isNotEmpty) {
      keys.add(normalizedCheckpointId);
    }

    final affectedCategoryIds = <String>{};
    for (final key in keys) {
      final storedCategoryId = _categoryIdByCheckpointKey.remove(key);
      if (storedCategoryId != null) affectedCategoryIds.add(storedCategoryId);
      _editedCheckpointAtByKey.remove(key);
      _categoryCoordinateByCheckpointKey.remove(key);
    }

    final categoryCoordinate = categoryCoordinateKey(
      pjNr: pjNr,
      categoryIndex: categoryIndex,
    );
    final normalizedCategoryId = categoryId?.trim();
    if (normalizedCategoryId != null && normalizedCategoryId.isNotEmpty) {
      affectedCategoryIds.add(normalizedCategoryId);
    }
    final registeredCategoryId = _categoryIdByCoordinate[categoryCoordinate];
    if (registeredCategoryId != null) {
      affectedCategoryIds.add(registeredCategoryId);
    }
    for (final affectedCategoryId in affectedCategoryIds) {
      final coordinate =
          _categoryCoordinateById[affectedCategoryId] ?? categoryCoordinate;
      _refreshCategoryEntry(affectedCategoryId, coordinate);
    }

    revision.value++;
    _queuePersistence();
  }

  bool checkpointEditedRecently(String checkpointKey, {DateTime? now}) {
    final editedAt = _editedCheckpointAtByKey[checkpointKey];
    if (editedAt == null) return false;
    final cutoff = (now ?? DateTime.now()).subtract(recentWindow);
    return !editedAt.isBefore(cutoff);
  }

  bool checkpointCompleted({
    required String checkpointId,
    required int pjNr,
    required int categoryIndex,
    required int checkpointIndex,
    DateTime? now,
  }) {
    if (checkpointEditedRecently(checkpointId, now: now)) return true;
    return checkpointEditedRecently(
      checkpointKey(
        pjNr: pjNr,
        categoryIndex: categoryIndex,
        checkpointIndex: checkpointIndex,
      ),
      now: now,
    );
  }

  void _refreshCategoryEntry(String categoryId, String categoryCoordinate) {
    final total = _totalCheckpointsByCategoryId[categoryId] ?? 0;
    final cutoff = DateTime.now().subtract(recentWindow);
    final completed = _editedCheckpointAtByKey.entries.where((entry) {
      final explicitCategoryId = _categoryIdByCheckpointKey[entry.key];
      final belongsToCategory = explicitCategoryId != null
          ? explicitCategoryId == categoryId
          : _categoryCoordinateByCheckpointKey[entry.key] == categoryCoordinate;
      return belongsToCategory && !entry.value.isBefore(cutoff);
    }).length;
    if (completed <= 0) {
      _entriesByCategoryId.remove(categoryId);
      return;
    }
    _entriesByCategoryId[categoryId] = CategoryProgressEntry(
      totalCheckpoints: total,
      completedCheckpoints: completed.clamp(0, total),
      updatedAt: DateTime.now(),
    );
  }

  @visibleForTesting
  void reset({bool clearPersisted = true}) {
    resetAllInspectionProgress(clearPersisted: clearPersisted);
  }

  Future<void> restore() async {
    await _persistenceTail;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final map = decoded.cast<String, dynamic>();
      final cutoff = DateTime.now().subtract(recentWindow);

      _clearMemory();
      _readIntMap(map['totals'], _totalCheckpointsByCategoryId);
      _readStringMap(
        map['categoryIdByCoordinate'],
        _categoryIdByCoordinate,
      );
      _readStringMap(
        map['categoryCoordinateById'],
        _categoryCoordinateById,
      );
      _readStringMap(
        map['categoryCoordinateByCheckpointKey'],
        _categoryCoordinateByCheckpointKey,
      );
      _readStringMap(
        map['categoryIdByCheckpointKey'],
        _categoryIdByCheckpointKey,
      );

      final edited = map['editedAt'];
      if (edited is Map) {
        for (final entry in edited.entries) {
          final millis = entry.value is num
              ? (entry.value as num).toInt()
              : int.tryParse(entry.value.toString());
          if (millis == null) continue;
          final editedAt = DateTime.fromMillisecondsSinceEpoch(millis);
          if (!editedAt.isBefore(cutoff)) {
            _editedCheckpointAtByKey[entry.key.toString()] = editedAt;
          }
        }
      }

      final retainedKeys = _editedCheckpointAtByKey.keys.toSet();
      _categoryCoordinateByCheckpointKey
          .removeWhere((key, _) => !retainedKeys.contains(key));
      _categoryIdByCheckpointKey
          .removeWhere((key, _) => !retainedKeys.contains(key));
      for (final entry in _categoryCoordinateById.entries) {
        _refreshCategoryEntry(entry.key, entry.value);
      }
      revision.value++;
      _queuePersistence();
    } catch (error) {
      debugPrint('Could not restore category progress: $error');
      await prefs.remove(_storageKey);
    }
  }

  void _readStringMap(Object? raw, Map<String, String> target) {
    if (raw is! Map) return;
    for (final entry in raw.entries) {
      target[entry.key.toString()] = entry.value.toString();
    }
  }

  void _readIntMap(Object? raw, Map<String, int> target) {
    if (raw is! Map) return;
    for (final entry in raw.entries) {
      final value = entry.value is num
          ? (entry.value as num).toInt()
          : int.tryParse(entry.value.toString());
      if (value != null) target[entry.key.toString()] = value;
    }
  }

  Map<String, dynamic> _snapshot() => {
        'totals': _totalCheckpointsByCategoryId,
        'editedAt': _editedCheckpointAtByKey.map(
          (key, value) => MapEntry(key, value.millisecondsSinceEpoch),
        ),
        'categoryIdByCoordinate': _categoryIdByCoordinate,
        'categoryCoordinateById': _categoryCoordinateById,
        'categoryCoordinateByCheckpointKey': _categoryCoordinateByCheckpointKey,
        'categoryIdByCheckpointKey': _categoryIdByCheckpointKey,
      };

  void _queuePersistence({bool clear = false}) {
    final encoded = clear ? null : jsonEncode(_snapshot());
    _persistenceTail = _persistenceTail.catchError((_) {}).then((_) async {
      final prefs = await SharedPreferences.getInstance();
      if (encoded == null) {
        await prefs.remove(_storageKey);
      } else {
        await prefs.setString(_storageKey, encoded);
      }
    });
    unawaited(_persistenceTail);
  }

  @visibleForTesting
  Future<void> waitForPendingPersistence() => _persistenceTail;

  CategoryProgressEntry? _recentEntryFor(String categoryId, {DateTime? now}) {
    final entry = _entriesByCategoryId[categoryId];
    if (entry == null) return null;

    final cutoff = (now ?? DateTime.now()).subtract(recentWindow);
    if (entry.updatedAt.isBefore(cutoff)) return null;
    return entry;
  }
}
