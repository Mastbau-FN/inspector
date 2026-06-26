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
    DateTime? editedAt,
  }) {
    final key = checkpointKey(
      pjNr: pjNr,
      categoryIndex: categoryIndex,
      checkpointIndex: checkpointIndex,
    );
    _editedCheckpointAtByKey[key] = editedAt ?? DateTime.now();
    revision.value++;
  }

  bool checkpointEditedRecently(String checkpointKey, {DateTime? now}) {
    final editedAt = _editedCheckpointAtByKey[checkpointKey];
    if (editedAt == null) return false;
    final cutoff = (now ?? DateTime.now()).subtract(recentWindow);
    return !editedAt.isBefore(cutoff);
  }

  CategoryProgressEntry? _recentEntryFor(String categoryId, {DateTime? now}) {
    final entry = _entriesByCategoryId[categoryId];
    if (entry == null) return null;

    final cutoff = (now ?? DateTime.now()).subtract(recentWindow);
    if (entry.updatedAt.isBefore(cutoff)) return null;
    return entry;
  }
}
