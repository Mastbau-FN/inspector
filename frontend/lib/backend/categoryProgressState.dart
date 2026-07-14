import 'package:flutter/foundation.dart';

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
  static final CategoryProgressState instance = CategoryProgressState._();

  final ValueNotifier<int> revision = ValueNotifier<int>(0);
  final Map<String, CategoryProgressEntry> _entriesByCategoryId = {};
  final Map<String, int> _totalCheckpointsByCategoryId = {};
  final Map<String, DateTime> _editedCheckpointAtByKey = {};
  final Map<String, String> _categoryIdByCoordinate = {};
  final Map<String, String> _categoryCoordinateById = {};
  final Map<String, String> _categoryCoordinateByCheckpointKey = {};
  final Map<String, String> _categoryIdByCheckpointKey = {};

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
  }

  void clear(String categoryId) {
    if (_entriesByCategoryId.remove(categoryId) != null) {
      revision.value++;
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
  }

  void resetAllInspectionProgress() {
    _entriesByCategoryId.clear();
    _totalCheckpointsByCategoryId.clear();
    _editedCheckpointAtByKey.clear();
    _categoryIdByCoordinate.clear();
    _categoryCoordinateById.clear();
    _categoryCoordinateByCheckpointKey.clear();
    _categoryIdByCheckpointKey.clear();
    revision.value++;
  }

  void markCheckpointEdited(
    String checkpointKey, {
    DateTime? editedAt,
  }) {
    _editedCheckpointAtByKey[checkpointKey] = editedAt ?? DateTime.now();
    revision.value++;
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
  void reset() {
    resetAllInspectionProgress();
  }

  CategoryProgressEntry? _recentEntryFor(String categoryId, {DateTime? now}) {
    final entry = _entriesByCategoryId[categoryId];
    if (entry == null) return null;

    final cutoff = (now ?? DateTime.now()).subtract(recentWindow);
    if (entry.updatedAt.isBefore(cutoff)) return null;
    return entry;
  }
}
