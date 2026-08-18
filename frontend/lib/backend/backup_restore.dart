import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';

import 'incremental_backup.dart';

const int _maximumManifestBytes = 32 * 1024 * 1024;
const int _maximumRestoreFileCount = 200000;
const int _maximumRestoreBytes = 64 * 1024 * 1024 * 1024;

class BackupRestoreException implements Exception {
  final String message;

  const BackupRestoreException(this.message);

  @override
  String toString() => message;
}

class BackupRestorePreview {
  final int selectedBackupCount;
  final int chainLength;
  final int ignoredBackupCount;
  final int fileCount;
  final int totalBytes;
  final DateTime createdAt;
  final List<String> backupChain;
  final List<BackupInspectionPreview> inspections;
  final bool containsFailedRequests;

  const BackupRestorePreview({
    required this.selectedBackupCount,
    required this.chainLength,
    required this.ignoredBackupCount,
    required this.fileCount,
    required this.totalBytes,
    required this.createdAt,
    required this.backupChain,
    this.inspections = const [],
    this.containsFailedRequests = false,
  });

  factory BackupRestorePreview._fromJson(Map<String, dynamic> json) =>
      BackupRestorePreview(
        selectedBackupCount: json['selectedBackupCount'] as int,
        chainLength: json['chainLength'] as int,
        ignoredBackupCount: json['ignoredBackupCount'] as int,
        fileCount: json['fileCount'] as int,
        totalBytes: json['totalBytes'] as int,
        createdAt: DateTime.parse(json['createdAt'] as String),
        backupChain: List<String>.from(json['backupChain'] as List),
        inspections: (json['inspections'] as List? ?? const [])
            .whereType<Map>()
            .map(
              (entry) => BackupInspectionPreview._fromJson(
                Map<String, dynamic>.from(entry),
              ),
            )
            .toList(growable: false),
        containsFailedRequests: json['containsFailedRequests'] == true,
      );

  Map<String, dynamic> _toJson() => {
        'selectedBackupCount': selectedBackupCount,
        'chainLength': chainLength,
        'ignoredBackupCount': ignoredBackupCount,
        'fileCount': fileCount,
        'totalBytes': totalBytes,
        'createdAt': createdAt.toIso8601String(),
        'backupChain': backupChain,
        'inspections': inspections.map((entry) => entry._toJson()).toList(),
        'containsFailedRequests': containsFailedRequests,
      };
}

class BackupInspectionPreview {
  final String selectionId;
  final String localId;
  final String projectNumber;
  final String locationNumber;
  final String name;
  final int fileCount;
  final int totalBytes;
  final int failedRequestCount;
  final bool alreadyOnDevice;

  const BackupInspectionPreview({
    required this.selectionId,
    required this.localId,
    required this.projectNumber,
    required this.locationNumber,
    required this.name,
    required this.fileCount,
    required this.totalBytes,
    required this.failedRequestCount,
    required this.alreadyOnDevice,
  });

  factory BackupInspectionPreview._fromJson(Map<String, dynamic> json) =>
      BackupInspectionPreview(
        selectionId: json['selectionId'] as String,
        localId: json['localId'] as String,
        projectNumber: json['projectNumber'] as String,
        locationNumber: json['locationNumber'] as String,
        name: json['name'] as String,
        fileCount: json['fileCount'] as int,
        totalBytes: json['totalBytes'] as int,
        failedRequestCount: json['failedRequestCount'] as int,
        alreadyOnDevice: json['alreadyOnDevice'] as bool,
      );

  Map<String, dynamic> _toJson() => {
        'selectionId': selectionId,
        'localId': localId,
        'projectNumber': projectNumber,
        'locationNumber': locationNumber,
        'name': name,
        'fileCount': fileCount,
        'totalBytes': totalBytes,
        'failedRequestCount': failedRequestCount,
        'alreadyOnDevice': alreadyOnDevice,
      };
}

class BackupInspectionImportResult {
  final int importedInspectionCount;
  final int importedFileCount;
  final int importedFailedRequestCount;
  final int appliedBackupCount;
  final DateTime backupCreatedAt;

  const BackupInspectionImportResult({
    required this.importedInspectionCount,
    required this.importedFileCount,
    required this.importedFailedRequestCount,
    required this.appliedBackupCount,
    required this.backupCreatedAt,
  });

  factory BackupInspectionImportResult._fromJson(Map<String, dynamic> json) =>
      BackupInspectionImportResult(
        importedInspectionCount: json['importedInspectionCount'] as int,
        importedFileCount: json['importedFileCount'] as int,
        importedFailedRequestCount: json['importedFailedRequestCount'] as int,
        appliedBackupCount: json['appliedBackupCount'] as int,
        backupCreatedAt: DateTime.parse(json['backupCreatedAt'] as String),
      );

  Map<String, dynamic> _toJson() => {
        'importedInspectionCount': importedInspectionCount,
        'importedFileCount': importedFileCount,
        'importedFailedRequestCount': importedFailedRequestCount,
        'appliedBackupCount': appliedBackupCount,
        'backupCreatedAt': backupCreatedAt.toIso8601String(),
      };
}

/// Authoritative server data used by the v270 rescue import.  The snapshot is
/// fetched immediately before the ZIP is applied so the importer can suppress
/// requests for records and photos that have already reached the backend.
class BackupServerInspectionSnapshot {
  final String selectionId;
  final Map<String, dynamic> location;
  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> checkpoints;
  final List<Map<String, dynamic>> defects;
  final Map<String, String> imageContentHashes;

  const BackupServerInspectionSnapshot({
    required this.selectionId,
    required this.location,
    required this.categories,
    required this.checkpoints,
    required this.defects,
    this.imageContentHashes = const {},
  });

  factory BackupServerInspectionSnapshot.fromJson(Map<String, dynamic> json) =>
      BackupServerInspectionSnapshot(
        selectionId: json['selectionId'] as String,
        location: Map<String, dynamic>.from(json['location'] as Map),
        categories: _jsonMapList(json['categories']),
        checkpoints: _jsonMapList(json['checkpoints']),
        defects: _jsonMapList(json['defects']),
        imageContentHashes: (json['imageContentHashes'] as Map? ?? const {})
            .map((key, value) => MapEntry(key.toString(), value.toString())),
      );

  Map<String, dynamic> toJson() => {
        'selectionId': selectionId,
        'location': location,
        'categories': categories,
        'checkpoints': checkpoints,
        'defects': defects,
        'imageContentHashes': imageContentHashes,
      };
}

List<Map<String, dynamic>> _jsonMapList(Object? value) =>
    (value as List? ?? const [])
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList(growable: false);

class BackupRescueImportResult {
  final int importedInspectionCount;
  final int importedFileCount;
  final int reconstructedRequestCount;
  final int alreadySynchronizedRecordCount;
  final int alreadySynchronizedImageCount;
  final int skippedUncertainRecordCount;
  final int appliedBackupCount;
  final DateTime backupCreatedAt;

  const BackupRescueImportResult({
    required this.importedInspectionCount,
    required this.importedFileCount,
    required this.reconstructedRequestCount,
    required this.alreadySynchronizedRecordCount,
    required this.alreadySynchronizedImageCount,
    required this.skippedUncertainRecordCount,
    required this.appliedBackupCount,
    required this.backupCreatedAt,
  });

  factory BackupRescueImportResult._fromJson(Map<String, dynamic> json) =>
      BackupRescueImportResult(
        importedInspectionCount: json['importedInspectionCount'] as int,
        importedFileCount: json['importedFileCount'] as int,
        reconstructedRequestCount: json['reconstructedRequestCount'] as int,
        alreadySynchronizedRecordCount:
            json['alreadySynchronizedRecordCount'] as int,
        alreadySynchronizedImageCount:
            json['alreadySynchronizedImageCount'] as int,
        skippedUncertainRecordCount: json['skippedUncertainRecordCount'] as int,
        appliedBackupCount: json['appliedBackupCount'] as int,
        backupCreatedAt: DateTime.parse(json['backupCreatedAt'] as String),
      );

  Map<String, dynamic> _toJson() => {
        'importedInspectionCount': importedInspectionCount,
        'importedFileCount': importedFileCount,
        'reconstructedRequestCount': reconstructedRequestCount,
        'alreadySynchronizedRecordCount': alreadySynchronizedRecordCount,
        'alreadySynchronizedImageCount': alreadySynchronizedImageCount,
        'skippedUncertainRecordCount': skippedUncertainRecordCount,
        'appliedBackupCount': appliedBackupCount,
        'backupCreatedAt': backupCreatedAt.toIso8601String(),
      };
}

class BackupRestoreResult {
  final int restoredFileCount;
  final int restoredBytes;
  final int appliedBackupCount;
  final DateTime backupCreatedAt;

  const BackupRestoreResult({
    required this.restoredFileCount,
    required this.restoredBytes,
    required this.appliedBackupCount,
    required this.backupCreatedAt,
  });

  factory BackupRestoreResult._fromJson(Map<String, dynamic> json) =>
      BackupRestoreResult(
        restoredFileCount: json['restoredFileCount'] as int,
        restoredBytes: json['restoredBytes'] as int,
        appliedBackupCount: json['appliedBackupCount'] as int,
        backupCreatedAt: DateTime.parse(json['backupCreatedAt'] as String),
      );

  Map<String, dynamic> _toJson() => {
        'restoredFileCount': restoredFileCount,
        'restoredBytes': restoredBytes,
        'appliedBackupCount': appliedBackupCount,
        'backupCreatedAt': backupCreatedAt.toIso8601String(),
      };
}

class _RestoreSignature {
  final int size;
  final int modifiedAtMs;
  final String contentHash;
  final Map<String, dynamic>? metadata;

  const _RestoreSignature({
    required this.size,
    required this.modifiedAtMs,
    required this.contentHash,
    this.metadata,
  });
}

class _InspectionCandidate {
  final BackupInspectionPreview preview;
  final String sourceRootPath;
  final Set<String> dataPaths;
  final Set<String> failedRequestPaths;

  const _InspectionCandidate({
    required this.preview,
    required this.sourceRootPath,
    required this.dataPaths,
    required this.failedRequestPaths,
  });
}

class _RestoreManifest {
  final File sourceFile;
  final String archiveName;
  final DateTime createdAt;
  final List<String> changedFiles;
  final List<String> deletedFiles;
  final Map<String, String> movedFiles;
  final Map<String, _RestoreSignature> snapshot;
  final List<String> backupChain;

  const _RestoreManifest({
    required this.sourceFile,
    required this.archiveName,
    required this.createdAt,
    required this.changedFiles,
    required this.deletedFiles,
    required this.movedFiles,
    required this.snapshot,
    required this.backupChain,
  });
}

class _RestorePlan {
  final List<_RestoreManifest> manifests;
  final int selectedBackupCount;

  const _RestorePlan({
    required this.manifests,
    required this.selectedBackupCount,
  });

  _RestoreManifest get latest => manifests.last;

  BackupRestorePreview get preview {
    final totalBytes = latest.snapshot.values.fold<int>(
      0,
      (sum, signature) => sum + signature.size,
    );
    return BackupRestorePreview(
      selectedBackupCount: selectedBackupCount,
      chainLength: manifests.length,
      ignoredBackupCount: selectedBackupCount - manifests.length,
      fileCount: latest.snapshot.length,
      totalBytes: totalBytes,
      createdAt: latest.createdAt,
      backupChain: List.unmodifiable(latest.backupChain),
      containsFailedRequests: latest.snapshot.keys.any(
        (path) => path.startsWith('failed-requests/'),
      ),
    );
  }
}

Future<BackupRestorePreview> inspectIncrementalBackupChain(
  List<File> backupFiles, {
  Directory? currentDataDirectory,
  String? currentRootId,
  Directory? workingDirectory,
}) async {
  final paths = backupFiles.map((file) => file.absolute.path).toList();
  final currentDataPath = currentDataDirectory?.absolute.path;
  final workingPath = workingDirectory?.absolute.path;
  final response = await Isolate.run(
    () => _guardRestoreOperation(() async {
      final plan = await _buildRestorePlan(paths);
      if (currentDataPath == null) return plan.preview._toJson();
      return _inspectRestorePlan(
        plan: plan,
        currentDataDirectory: Directory(currentDataPath),
        currentRootId: currentRootId,
        workingDirectory: workingPath == null ? null : Directory(workingPath),
      );
    }),
  );
  return BackupRestorePreview._fromJson(_unwrapRestoreResponse(response));
}

Future<BackupInspectionImportResult>
    importInspectionsFromIncrementalBackupChain({
  required List<File> backupFiles,
  required Set<String> selectedInspectionIds,
  required Directory targetDirectory,
  required String targetRootId,
  Directory? workingDirectory,
}) async {
  if (targetRootId.trim().isEmpty || !_isSafePathSegment(targetRootId)) {
    throw const BackupRestoreException(
      'Das lokale Benutzerverzeichnis ist ungültig.',
    );
  }
  final paths = backupFiles.map((file) => file.absolute.path).toList();
  final targetPath = targetDirectory.absolute.path;
  final workingPath = workingDirectory?.absolute.path;
  final response = await Isolate.run(
    () => _guardRestoreOperation(() async {
      final plan = await _buildRestorePlan(paths);
      final result = await _executeInspectionImport(
        plan: plan,
        selectedInspectionIds: selectedInspectionIds,
        targetDirectory: Directory(targetPath),
        targetRootId: targetRootId,
        workingDirectory: workingPath == null ? null : Directory(workingPath),
      );
      return result._toJson();
    }),
  );
  return BackupInspectionImportResult._fromJson(
    _unwrapRestoreResponse(response),
  );
}

/// Recovers the upload state of old backups that contain local records and
/// files but no `failed-requests` directory (notably v270 backups).
///
/// Existing requests from the ZIP are deliberately ignored.  Instead, every
/// selected inspection is reconciled against a fresh server snapshot and only
/// missing creates, differing updates and missing image uploads are queued.
Future<BackupRescueImportResult> recoverInspectionsFromIncrementalBackupChain({
  required List<File> backupFiles,
  required Set<String> selectedInspectionIds,
  required List<BackupServerInspectionSnapshot> serverSnapshots,
  required Directory targetDirectory,
  required String targetRootId,
  Directory? workingDirectory,
}) async {
  if (targetRootId.trim().isEmpty || !_isSafePathSegment(targetRootId)) {
    throw const BackupRestoreException(
      'Das lokale Benutzerverzeichnis ist ungültig.',
    );
  }
  final paths = backupFiles.map((file) => file.absolute.path).toList();
  final targetPath = targetDirectory.absolute.path;
  final workingPath = workingDirectory?.absolute.path;
  final serializedSnapshots = serverSnapshots
      .map((snapshot) => snapshot.toJson())
      .toList(growable: false);
  final response = await Isolate.run(
    () => _guardRestoreOperation(() async {
      final plan = await _buildRestorePlan(paths);
      final result = await _executeRescueImport(
        plan: plan,
        selectedInspectionIds: selectedInspectionIds,
        serverSnapshots: serializedSnapshots
            .map(BackupServerInspectionSnapshot.fromJson)
            .toList(growable: false),
        targetDirectory: Directory(targetPath),
        targetRootId: targetRootId,
        workingDirectory: workingPath == null ? null : Directory(workingPath),
      );
      return result._toJson();
    }),
  );
  return BackupRescueImportResult._fromJson(
    _unwrapRestoreResponse(response),
  );
}

Future<BackupRestoreResult> restoreIncrementalBackupChain({
  required List<File> backupFiles,
  required Directory targetDirectory,
  Directory? workingDirectory,
}) async {
  final paths = backupFiles.map((file) => file.absolute.path).toList();
  final targetPath = targetDirectory.absolute.path;
  final workingPath = workingDirectory?.absolute.path;
  final response = await Isolate.run(
    () => _guardRestoreOperation(() async {
      final plan = await _buildRestorePlan(paths);
      final result = await _executeRestore(
        plan: plan,
        targetDirectory: Directory(targetPath),
        workingDirectory: workingPath == null ? null : Directory(workingPath),
      );
      return result._toJson();
    }),
  );
  return BackupRestoreResult._fromJson(_unwrapRestoreResponse(response));
}

Future<Map<String, dynamic>> _guardRestoreOperation(
  Future<Map<String, dynamic>> Function() operation,
) async {
  try {
    return {'result': await operation()};
  } on BackupRestoreException catch (error) {
    return {'error': error.message};
  } catch (error) {
    return {'error': 'Backup konnte nicht verarbeitet werden: $error'};
  }
}

Map<String, dynamic> _unwrapRestoreResponse(Map<String, dynamic> response) {
  final error = response['error'];
  if (error != null) throw BackupRestoreException(error.toString());
  final result = response['result'];
  if (result is! Map) {
    throw const BackupRestoreException(
      'Die Wiederherstellung lieferte kein gültiges Ergebnis.',
    );
  }
  return Map<String, dynamic>.from(result);
}

Future<_RestorePlan> _buildRestorePlan(List<String> paths) async {
  if (paths.isEmpty) {
    throw const BackupRestoreException(
      'Bitte mindestens eine Backup-ZIP auswählen.',
    );
  }

  final manifestsByName = <String, _RestoreManifest>{};
  for (final path in paths.toSet()) {
    final file = File(path);
    if (!await file.exists()) {
      throw BackupRestoreException('Backup-Datei nicht gefunden: $path');
    }
    final manifest = await _readRestoreManifest(file);
    if (manifestsByName.containsKey(manifest.archiveName)) {
      throw BackupRestoreException(
        'Das Backup ${manifest.archiveName} wurde mehrfach ausgewählt.',
      );
    }
    manifestsByName[manifest.archiveName] = manifest;
  }

  final latest = manifestsByName.values.reduce((left, right) {
    final dateComparison = left.createdAt.compareTo(right.createdAt);
    if (dateComparison != 0) return dateComparison > 0 ? left : right;
    return left.backupChain.length >= right.backupChain.length ? left : right;
  });
  final missing = latest.backupChain
      .where((name) => !manifestsByName.containsKey(name))
      .toList();
  if (missing.isNotEmpty) {
    throw BackupRestoreException(
      'Die Backup-Kette ist unvollständig. Es fehlen: ${missing.join(', ')}',
    );
  }
  for (var index = 0; index < latest.backupChain.length; index++) {
    final name = latest.backupChain[index];
    final chainManifest = manifestsByName[name]!;
    final expectedPrefix = latest.backupChain.sublist(0, index + 1);
    if (!_sameStringList(chainManifest.backupChain, expectedPrefix)) {
      throw const BackupRestoreException(
        'Die ausgewählten ZIPs bilden keine gültige Backup-Kette.',
      );
    }
  }
  final manifests = latest.backupChain
      .map((name) => manifestsByName[name]!)
      .toList(growable: false);

  if (latest.snapshot.length > _maximumRestoreFileCount) {
    throw const BackupRestoreException(
      'Das Backup enthält zu viele Dateien und wird aus Sicherheitsgründen nicht importiert.',
    );
  }
  final totalBytes = latest.snapshot.values.fold<int>(
    0,
    (sum, signature) => sum + signature.size,
  );
  if (totalBytes > _maximumRestoreBytes) {
    throw const BackupRestoreException(
      'Das Backup ist für eine Wiederherstellung auf diesem Gerät zu groß.',
    );
  }
  final changedBytes = manifests.fold<int>(
    0,
    (sum, manifest) =>
        sum +
        manifest.changedFiles.fold<int>(
          0,
          (fileSum, path) => fileSum + manifest.snapshot[path]!.size,
        ),
  );
  if (changedBytes > _maximumRestoreBytes * 2) {
    throw const BackupRestoreException(
      'Die Backup-Kette enthält ungewöhnlich viele Änderungsdaten.',
    );
  }

  return _RestorePlan(
    manifests: manifests,
    selectedBackupCount: manifestsByName.length,
  );
}

Future<_RestoreManifest> _readRestoreManifest(File file) async {
  InputFileStream? input;
  try {
    input = InputFileStream(file.path);
    final archive = ZipDecoder().decodeBuffer(input);
    final manifests = archive.files.where((entry) {
      return entry.isFile &&
          _normalizedArchiveEntryName(entry.name) ==
              incrementalBackupManifestName;
    }).toList();
    if (manifests.length != 1) {
      throw BackupRestoreException(
        '${_basename(file.path)} enthält kein eindeutiges Backup-Manifest.',
      );
    }
    final manifestEntry = manifests.single;
    if (manifestEntry.size > _maximumManifestBytes) {
      throw BackupRestoreException(
        'Das Manifest in ${_basename(file.path)} ist ungewöhnlich groß.',
      );
    }
    final decoded = jsonDecode(
      utf8.decode(List<int>.from(manifestEntry.content as List<int>)),
    );
    if (decoded is! Map) {
      throw BackupRestoreException(
        'Das Manifest in ${_basename(file.path)} ist ungültig.',
      );
    }
    return _parseRestoreManifest(
      file,
      Map<String, dynamic>.from(decoded),
    );
  } on BackupRestoreException {
    rethrow;
  } catch (error) {
    throw BackupRestoreException(
      '${_basename(file.path)} ist keine lesbare Backup-ZIP: $error',
    );
  } finally {
    input?.closeSync();
  }
}

_RestoreManifest _parseRestoreManifest(
  File sourceFile,
  Map<String, dynamic> json,
) {
  if ((json['version'] as num?)?.toInt() != 1) {
    throw BackupRestoreException(
      '${_basename(sourceFile.path)} verwendet ein nicht unterstütztes Backup-Format.',
    );
  }

  final createdAt = DateTime.tryParse(json['createdAt']?.toString() ?? '');
  if (createdAt == null) {
    throw BackupRestoreException(
      '${_basename(sourceFile.path)} enthält kein gültiges Erstellungsdatum.',
    );
  }

  final rawChain = json['backupChain'];
  if (rawChain is! List || rawChain.isEmpty) {
    throw BackupRestoreException(
      '${_basename(sourceFile.path)} enthält keine Backup-Kette.',
    );
  }
  final backupChain = rawChain.map((value) {
    final name = value.toString();
    if (!RegExp(r'^backup-\d+\.zip$').hasMatch(name)) {
      throw BackupRestoreException('Ungültiger Backup-Name im Manifest: $name');
    }
    return name;
  }).toList(growable: false);
  if (backupChain.toSet().length != backupChain.length) {
    throw const BackupRestoreException(
      'Die Backup-Kette enthält doppelte Einträge.',
    );
  }

  final archiveName = backupChain.last;
  final baseBackup = json['baseBackup']?.toString();
  final expectedBase =
      backupChain.length == 1 ? null : backupChain[backupChain.length - 2];
  if (baseBackup != expectedBase) {
    throw BackupRestoreException(
      '$archiveName verweist auf ein falsches Basis-Backup.',
    );
  }

  final changedFiles = _parsePathList(json['changedFiles'], 'changedFiles');
  final deletedFiles = _parsePathList(json['deletedFiles'], 'deletedFiles');
  final movedFiles = <String, String>{};
  final rawMoved = json['movedFiles'];
  if (rawMoved != null && rawMoved is! Map) {
    throw BackupRestoreException(
        '$archiveName enthält ungültige Verschiebungen.');
  }
  if (rawMoved is Map) {
    for (final entry in rawMoved.entries) {
      final from = _validatedBackupPath(entry.key.toString());
      final to = _validatedBackupPath(entry.value.toString());
      if (from == to || movedFiles.containsKey(from)) {
        throw BackupRestoreException(
          '$archiveName enthält eine ungültige Dateiverschiebung.',
        );
      }
      movedFiles[from] = to;
    }
  }

  final rawSnapshot = json['snapshot'];
  if (rawSnapshot is! Map) {
    throw BackupRestoreException('$archiveName enthält keinen Dateisnapshot.');
  }
  final snapshot = <String, _RestoreSignature>{};
  for (final entry in rawSnapshot.entries) {
    final path = _validatedBackupPath(entry.key.toString());
    final rawSignature = entry.value;
    if (rawSignature is! Map) {
      throw BackupRestoreException(
        '$archiveName enthält ungültige Dateiinformationen für $path.',
      );
    }
    final signature = Map<String, dynamic>.from(rawSignature);
    final size = (signature['size'] as num?)?.toInt();
    final modifiedAtMs = (signature['modifiedAtMs'] as num?)?.toInt();
    final contentHash = signature['contentHash']?.toString().toLowerCase();
    if (size == null ||
        size < 0 ||
        modifiedAtMs == null ||
        modifiedAtMs < 0 ||
        contentHash == null ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(contentHash)) {
      throw BackupRestoreException(
        '$archiveName kann $path nicht zuverlässig verifizieren.',
      );
    }
    if (snapshot.containsKey(path)) {
      throw BackupRestoreException('$archiveName enthält $path mehrfach.');
    }
    snapshot[path] = _RestoreSignature(
      size: size,
      modifiedAtMs: modifiedAtMs,
      contentHash: contentHash,
      metadata: signature['metadata'] is Map
          ? Map<String, dynamic>.from(signature['metadata'] as Map)
          : null,
    );
  }

  for (final path in changedFiles) {
    if (!snapshot.containsKey(path)) {
      throw BackupRestoreException(
        '$archiveName enthält keine Prüfsumme für $path.',
      );
    }
  }
  for (final path in deletedFiles) {
    if (snapshot.containsKey(path)) {
      throw BackupRestoreException(
        '$archiveName markiert $path gleichzeitig als vorhanden und gelöscht.',
      );
    }
  }
  for (final target in movedFiles.values) {
    if (!snapshot.containsKey(target)) {
      throw BackupRestoreException(
        '$archiveName enthält keine Prüfsumme für das Verschiebungsziel $target.',
      );
    }
  }

  return _RestoreManifest(
    sourceFile: sourceFile,
    archiveName: archiveName,
    createdAt: createdAt,
    changedFiles: changedFiles,
    deletedFiles: deletedFiles,
    movedFiles: movedFiles,
    snapshot: snapshot,
    backupChain: backupChain,
  );
}

List<String> _parsePathList(Object? raw, String fieldName) {
  if (raw is! List) {
    throw BackupRestoreException('Das Manifest-Feld $fieldName ist ungültig.');
  }
  final paths = raw
      .map((value) => _validatedBackupPath(value.toString()))
      .toList(growable: false);
  if (paths.toSet().length != paths.length) {
    throw BackupRestoreException('$fieldName enthält doppelte Dateipfade.');
  }
  return paths;
}

String _validatedBackupPath(String rawPath) {
  if (rawPath.isEmpty ||
      rawPath.contains('\u0000') ||
      rawPath.startsWith('/') ||
      rawPath.startsWith('\\') ||
      RegExp(r'^[A-Za-z]:').hasMatch(rawPath)) {
    throw BackupRestoreException('Unsicherer Dateipfad im Backup: $rawPath');
  }
  final normalized = rawPath.replaceAll('\\', '/');
  final parts = normalized.split('/');
  if (parts.any((part) => part.isEmpty || part == '.' || part == '..')) {
    throw BackupRestoreException('Unsicherer Dateipfad im Backup: $rawPath');
  }
  if (normalized == incrementalBackupManifestName ||
      normalized == backupContentsIndexName ||
      normalized.startsWith('Backup-Struktur/')) {
    throw BackupRestoreException('Reservierter Dateipfad im Backup: $rawPath');
  }
  if (!_isRestorableDataPath(normalized)) {
    throw BackupRestoreException(
      'Nicht wiederherstellbarer Dateipfad im Backup: $rawPath',
    );
  }
  return normalized;
}

String _normalizedArchiveEntryName(String name) =>
    name.replaceAll('\\', '/').replaceFirst(RegExp(r'^/+'), '');

bool _isRestorableDataPath(String relativePath) {
  final parts = relativePath.split('/');
  final first = parts.first;
  if (first == 'other') {
    return parts.length == 2 && parts.last.startsWith('__sync_maps__');
  }
  const excludedTopLevelPaths = {
    'skipped-requests',
    'image-index',
    'flutter_assets',
  };
  return !excludedTopLevelPaths.contains(first);
}

Future<Map<String, dynamic>> _inspectRestorePlan({
  required _RestorePlan plan,
  required Directory currentDataDirectory,
  required String? currentRootId,
  Directory? workingDirectory,
}) async {
  final workBase = workingDirectory ?? currentDataDirectory.parent;
  await workBase.create(recursive: true);
  final workRoot = await _createUniqueWorkingDirectory(workBase);
  final stageDirectory = Directory('${workRoot.path}/stage');
  await stageDirectory.create(recursive: true);
  try {
    await _reconstructStage(plan, stageDirectory);
    final candidates = await _discoverInspectionCandidates(
      stageDirectory: stageDirectory,
      snapshot: plan.latest.snapshot,
      currentDataDirectory: currentDataDirectory,
      currentRootId: currentRootId,
    );
    final base = plan.preview;
    return BackupRestorePreview(
      selectedBackupCount: base.selectedBackupCount,
      chainLength: base.chainLength,
      ignoredBackupCount: base.ignoredBackupCount,
      fileCount: base.fileCount,
      totalBytes: base.totalBytes,
      createdAt: base.createdAt,
      backupChain: base.backupChain,
      inspections: candidates.map((entry) => entry.preview).toList(),
      containsFailedRequests: base.containsFailedRequests,
    )._toJson();
  } finally {
    try {
      if (await workRoot.exists()) await workRoot.delete(recursive: true);
    } catch (_) {}
  }
}

Future<BackupInspectionImportResult> _executeInspectionImport({
  required _RestorePlan plan,
  required Set<String> selectedInspectionIds,
  required Directory targetDirectory,
  required String targetRootId,
  Directory? workingDirectory,
}) async {
  if (selectedInspectionIds.isEmpty) {
    throw const BackupRestoreException(
      'Bitte mindestens eine Inspektion auswählen.',
    );
  }

  final workBase = workingDirectory ?? targetDirectory.parent;
  await workBase.create(recursive: true);
  final workRoot = await _createUniqueWorkingDirectory(workBase);
  final stageDirectory = Directory('${workRoot.path}/stage');
  final mergedDirectory = Directory('${workRoot.path}/merged');
  final rollbackDirectory = Directory('${workRoot.path}/rollback');
  await stageDirectory.create(recursive: true);

  var committed = false;
  try {
    await _reconstructStage(plan, stageDirectory);
    final candidates = await _discoverInspectionCandidates(
      stageDirectory: stageDirectory,
      snapshot: plan.latest.snapshot,
      currentDataDirectory: targetDirectory,
      currentRootId: targetRootId,
    );
    final byId = {
      for (final candidate in candidates)
        candidate.preview.selectionId: candidate,
    };
    final missing = selectedInspectionIds.difference(byId.keys.toSet());
    if (missing.isNotEmpty) {
      throw const BackupRestoreException(
        'Die ausgewählte Inspektion ist nicht mehr im geprüften Backup-Stand enthalten.',
      );
    }
    final selected =
        selectedInspectionIds.map((id) => byId[id]!).toList(growable: false);
    final alreadyPresent = selected
        .where((candidate) => candidate.preview.alreadyOnDevice)
        .map((candidate) => candidate.preview.projectNumber)
        .toList();
    if (alreadyPresent.isNotEmpty) {
      throw BackupRestoreException(
        'Bereits vorhandene Inspektionen werden nicht importiert und ihre '
        'alten Upload-Aufträge bleiben deaktiviert: '
        '${alreadyPresent.join(', ')}',
      );
    }

    await mergedDirectory.create(recursive: true);
    if (await targetDirectory.exists()) {
      await _copyDirectoryFiles(targetDirectory, mergedDirectory);
    }

    var importedFiles = 0;
    var importedFailedRequests = 0;
    final importedRequestHashes = await _failedRequestHashes(mergedDirectory);
    var nextRequestTimestamp = DateTime.now().millisecondsSinceEpoch;

    for (final candidate in selected) {
      for (final sourcePath in candidate.dataPaths) {
        final destinationPath = sourcePath == candidate.sourceRootPath
            ? '$targetRootId/${candidate.preview.localId}'
            : sourcePath;
        final copied = await _copyImportedFile(
          source: File(_pathIn(stageDirectory, sourcePath)),
          destination: File(_pathIn(mergedDirectory, destinationPath)),
          displayPath: destinationPath,
        );
        if (copied) importedFiles++;
      }

      for (final requestPath in candidate.failedRequestPaths) {
        final source = File(_pathIn(stageDirectory, requestPath));
        final requestBytes = await _sanitizedFailedRequestBytes(source);
        final requestHash = sha256.convert(requestBytes).toString();
        if (!importedRequestHashes.add(requestHash)) continue;

        var requestName = _basename(requestPath);
        var destination =
            File(_pathIn(mergedDirectory, 'failed-requests/$requestName'));
        while (await destination.exists()) {
          requestName = (nextRequestTimestamp++).toRadixString(36);
          destination =
              File(_pathIn(mergedDirectory, 'failed-requests/$requestName'));
        }
        await destination.parent.create(recursive: true);
        await destination.writeAsBytes(requestBytes, flush: true);
        importedFiles++;
        importedFailedRequests++;
      }
    }

    final targetExisted = await targetDirectory.exists();
    if (targetExisted) await targetDirectory.rename(rollbackDirectory.path);
    try {
      await mergedDirectory.rename(targetDirectory.path);
      committed = true;
    } catch (_) {
      if (await targetDirectory.exists()) {
        await targetDirectory.delete(recursive: true);
      }
      if (targetExisted && await rollbackDirectory.exists()) {
        await rollbackDirectory.rename(targetDirectory.path);
      }
      rethrow;
    }

    return BackupInspectionImportResult(
      importedInspectionCount: selected.length,
      importedFileCount: importedFiles,
      importedFailedRequestCount: importedFailedRequests,
      appliedBackupCount: plan.manifests.length,
      backupCreatedAt: plan.latest.createdAt,
    );
  } finally {
    if (!committed &&
        await rollbackDirectory.exists() &&
        !await targetDirectory.exists()) {
      await rollbackDirectory.rename(targetDirectory.path);
    }
    try {
      if (await workRoot.exists()) await workRoot.delete(recursive: true);
    } catch (_) {}
  }
}

class _RescueRecord {
  final String sourcePath;
  final String type;
  final int depth;
  final Map<String, dynamic> data;
  _ServerRescueRecord? serverMatch;

  _RescueRecord({
    required this.sourcePath,
    required this.type,
    required this.depth,
    required this.data,
  });

  String get id => _nonEmptyString(data['local_id']) ?? _basename(sourcePath);
  String? get parentId => _nonEmptyString(data['parent_local_id']);
}

class _ServerRescueRecord {
  final String type;
  final Map<String, dynamic> data;
  bool consumed = false;

  _ServerRescueRecord(this.type, Map<String, dynamic> data)
      : data = Map<String, dynamic>.from(data);

  String? get id => _nonEmptyString(data['local_id']);
  String? get parentId => _nonEmptyString(data['parent_local_id']);
}

class _RescueReconciliation {
  final List<Map<String, dynamic>> requests;
  final Map<String, Map<String, dynamic>> transformedRecords;
  final Map<String, String> destinationPaths;
  final Map<String, String> localIdMap;
  final Map<String, String> imageHashMap;
  final Set<String> alreadySynchronizedFiles;
  final int alreadySynchronizedRecords;
  final int alreadySynchronizedImages;
  final int skippedUncertainRecords;

  const _RescueReconciliation({
    required this.requests,
    required this.transformedRecords,
    required this.destinationPaths,
    required this.localIdMap,
    required this.imageHashMap,
    required this.alreadySynchronizedFiles,
    required this.alreadySynchronizedRecords,
    required this.alreadySynchronizedImages,
    required this.skippedUncertainRecords,
  });
}

Future<BackupRescueImportResult> _executeRescueImport({
  required _RestorePlan plan,
  required Set<String> selectedInspectionIds,
  required List<BackupServerInspectionSnapshot> serverSnapshots,
  required Directory targetDirectory,
  required String targetRootId,
  Directory? workingDirectory,
}) async {
  if (selectedInspectionIds.isEmpty) {
    throw const BackupRestoreException(
      'Bitte mindestens eine Inspektion auswählen.',
    );
  }

  final snapshotsBySelectionId = {
    for (final snapshot in serverSnapshots) snapshot.selectionId: snapshot,
  };
  final missingSnapshots =
      selectedInspectionIds.difference(snapshotsBySelectionId.keys.toSet());
  if (missingSnapshots.isNotEmpty) {
    throw const BackupRestoreException(
      'Der Serverstand konnte nicht für alle ausgewählten Inspektionen geladen werden.',
    );
  }

  final workBase = workingDirectory ?? targetDirectory.parent;
  await workBase.create(recursive: true);
  final workRoot = await _createUniqueWorkingDirectory(workBase);
  final stageDirectory = Directory('${workRoot.path}/stage');
  final mergedDirectory = Directory('${workRoot.path}/merged');
  final rollbackDirectory = Directory('${workRoot.path}/rollback');
  await stageDirectory.create(recursive: true);

  var committed = false;
  try {
    await _reconstructStage(plan, stageDirectory);
    final candidates = await _discoverInspectionCandidates(
      stageDirectory: stageDirectory,
      snapshot: plan.latest.snapshot,
      currentDataDirectory: targetDirectory,
      currentRootId: targetRootId,
    );
    final candidatesById = {
      for (final candidate in candidates)
        candidate.preview.selectionId: candidate,
    };
    final missingCandidates =
        selectedInspectionIds.difference(candidatesById.keys.toSet());
    if (missingCandidates.isNotEmpty) {
      throw const BackupRestoreException(
        'Die ausgewählte Inspektion ist nicht mehr im geprüften Backup-Stand enthalten.',
      );
    }

    await mergedDirectory.create(recursive: true);
    if (await targetDirectory.exists()) {
      await _copyDirectoryFiles(targetDirectory, mergedDirectory);
    }

    var importedFiles = 0;
    var reconstructedRequests = 0;
    var synchronizedRecords = 0;
    var synchronizedImages = 0;
    var uncertainRecords = 0;
    final importedRequestHashes = await _failedRequestHashes(mergedDirectory);
    var nextRequestTimestamp = DateTime.now().millisecondsSinceEpoch;

    for (final selectionId in selectedInspectionIds) {
      final candidate = candidatesById[selectionId]!;
      final snapshot = snapshotsBySelectionId[selectionId]!;
      final reconciliation = await _reconcileCandidateWithServer(
        stageDirectory: stageDirectory,
        candidate: candidate,
        serverSnapshot: snapshot,
        targetRootId: targetRootId,
      );
      synchronizedRecords += reconciliation.alreadySynchronizedRecords;
      synchronizedImages += reconciliation.alreadySynchronizedImages;
      uncertainRecords += reconciliation.skippedUncertainRecords;

      for (final sourcePath in candidate.dataPaths) {
        if (sourcePath.startsWith('other/__sync_maps__')) continue;
        if (reconciliation.alreadySynchronizedFiles.contains(sourcePath)) {
          continue;
        }
        final source = File(_pathIn(stageDirectory, sourcePath));
        if (!await source.exists()) continue;
        final destinationPath = reconciliation.destinationPaths[sourcePath] ??
            (sourcePath == candidate.sourceRootPath
                ? '$targetRootId/${candidate.preview.localId}'
                : sourcePath);
        final destination = File(_pathIn(mergedDirectory, destinationPath));
        final transformed = reconciliation.transformedRecords[sourcePath];
        final copied = transformed == null
            ? await _copyRescueFile(source, destination)
            : await _writeRescueJson(destination, transformed);
        if (copied) importedFiles++;
      }

      if (reconciliation.localIdMap.isNotEmpty ||
          reconciliation.imageHashMap.isNotEmpty) {
        final wroteMap = await _mergeRescueSyncMap(
          mergedDirectory: mergedDirectory,
          projectNumber: candidate.preview.projectNumber,
          localIdMap: reconciliation.localIdMap,
          imageHashMap: reconciliation.imageHashMap,
        );
        if (wroteMap) importedFiles++;
      }

      for (final request in reconciliation.requests) {
        final requestBytes = utf8.encode(jsonEncode(request));
        final requestHash = sha256.convert(requestBytes).toString();
        if (!importedRequestHashes.add(requestHash)) continue;
        var requestName = (nextRequestTimestamp++).toRadixString(36);
        var destination =
            File(_pathIn(mergedDirectory, 'failed-requests/$requestName'));
        while (await destination.exists()) {
          requestName = (nextRequestTimestamp++).toRadixString(36);
          destination =
              File(_pathIn(mergedDirectory, 'failed-requests/$requestName'));
        }
        await destination.parent.create(recursive: true);
        await destination.writeAsBytes(requestBytes, flush: true);
        importedFiles++;
        reconstructedRequests++;
      }
    }

    final targetExisted = await targetDirectory.exists();
    if (targetExisted) await targetDirectory.rename(rollbackDirectory.path);
    try {
      await mergedDirectory.rename(targetDirectory.path);
      committed = true;
    } catch (_) {
      if (await targetDirectory.exists()) {
        await targetDirectory.delete(recursive: true);
      }
      if (targetExisted && await rollbackDirectory.exists()) {
        await rollbackDirectory.rename(targetDirectory.path);
      }
      rethrow;
    }

    return BackupRescueImportResult(
      importedInspectionCount: selectedInspectionIds.length,
      importedFileCount: importedFiles,
      reconstructedRequestCount: reconstructedRequests,
      alreadySynchronizedRecordCount: synchronizedRecords,
      alreadySynchronizedImageCount: synchronizedImages,
      skippedUncertainRecordCount: uncertainRecords,
      appliedBackupCount: plan.manifests.length,
      backupCreatedAt: plan.latest.createdAt,
    );
  } finally {
    if (!committed &&
        await rollbackDirectory.exists() &&
        !await targetDirectory.exists()) {
      await rollbackDirectory.rename(targetDirectory.path);
    }
    try {
      if (await workRoot.exists()) await workRoot.delete(recursive: true);
    } catch (_) {}
  }
}

Future<_RescueReconciliation> _reconcileCandidateWithServer({
  required Directory stageDirectory,
  required _InspectionCandidate candidate,
  required BackupServerInspectionSnapshot serverSnapshot,
  required String targetRootId,
}) async {
  final records = await _readRescueRecords(stageDirectory, candidate);
  if (records.isEmpty || records.first.type != 'location') {
    throw BackupRestoreException(
      'Projekt ${candidate.preview.projectNumber} enthält keine lesbare Inspektionsstruktur.',
    );
  }

  final serverRecords = <_ServerRescueRecord>[
    _ServerRescueRecord('location', serverSnapshot.location),
    ...serverSnapshot.categories
        .map((entry) => _ServerRescueRecord('category', entry)),
    ...serverSnapshot.checkpoints
        .map((entry) => _ServerRescueRecord('checkpoint', entry)),
    ...serverSnapshot.defects
        .map((entry) => _ServerRescueRecord('defect', entry)),
  ];
  final idMap = <String, String>{};
  final imageMap = <String, String>{};
  final requests = <Map<String, dynamic>>[];
  final transformed = <String, Map<String, dynamic>>{};
  final destinations = <String, String>{};
  final synchronizedFiles = <String>{};
  var synchronizedRecords = 0;
  var synchronizedImages = 0;
  var uncertainRecords = 0;

  for (final record in records) {
    final server = _matchServerRecord(record, serverRecords, idMap);
    record.serverMatch = server;
    if (server != null) {
      server.consumed = true;
      final serverId = server.id;
      if (serverId != null && serverId.isNotEmpty) {
        idMap[record.id] = serverId;
      }
    }
  }

  for (final record in records) {
    final server = record.serverMatch;
    var desired = _applyRecordMappings(record.data, idMap);
    if (server != null) {
      desired = _applyServerIdentity(desired, server.data, record.type);
      if (_sameRecordContent(desired, server.data)) {
        synchronizedRecords++;
      } else {
        requests.add(_serializedDataRequest('/update', record.type, desired));
      }
    } else if (_isLocallyCreatedRecord(record)) {
      requests.add(_serializedDataRequest('/set', record.type, desired));
    } else {
      // A positive record that vanished from the server is ambiguous: it may
      // have been deleted intentionally after the backup. Never recreate it
      // blindly and risk resurrecting old server data.
      uncertainRecords++;
    }
    transformed[record.sourcePath] = desired;
    destinations[record.sourcePath] = _rescueRecordDestination(
      record,
      idMap,
      targetRootId,
    );
  }

  for (final record in records) {
    final desired = transformed[record.sourcePath]!;
    final server = record.serverMatch;
    final serverRefs = server == null
        ? const <String>[]
        : _fileReferences(server.data).toList(growable: false);
    final serverHashesByContent = <String, String>{};
    for (final ref in serverRefs) {
      final contentHash = serverSnapshot.imageContentHashes[ref];
      if (contentHash != null) serverHashesByContent[contentHash] = ref;
    }

    final missingFiles = <String>[];
    final seenPaths = <String>{};
    for (final ref in _fileReferences(record.data)) {
      final sourcePath = await _resolveRescueFileReference(
        stageDirectory,
        candidate.dataPaths,
        ref,
      );
      if (sourcePath == null || !seenPaths.add(sourcePath)) continue;
      final localHash =
          await _sha256File(File(_pathIn(stageDirectory, sourcePath)));
      final existingServerRef = serverHashesByContent[localHash];
      if (existingServerRef != null) {
        imageMap[ref] = existingServerRef;
        imageMap[_basename(ref)] = existingServerRef;
        synchronizedFiles.add(sourcePath);
        synchronizedImages++;
      } else {
        missingFiles.add(sourcePath);
      }
    }
    if (imageMap.isNotEmpty) {
      transformed[record.sourcePath] =
          _rewriteImageReferences(desired, imageMap);
    }
    if (missingFiles.isNotEmpty &&
        (server != null || _isLocallyCreatedRecord(record))) {
      final uploadData = _rewriteImageReferences(desired, imageMap)
        ..remove('offline');
      requests.add({
        'route': '/image/set',
        'json': {
          'type': record.type,
          'data': jsonEncode(uploadData),
        },
        'multipartFiles': missingFiles,
        'returnsBinary': false,
      });
    }
  }

  return _RescueReconciliation(
    requests: requests,
    transformedRecords: transformed,
    destinationPaths: destinations,
    localIdMap: idMap,
    imageHashMap: imageMap,
    alreadySynchronizedFiles: synchronizedFiles,
    alreadySynchronizedRecords: synchronizedRecords,
    alreadySynchronizedImages: synchronizedImages,
    skippedUncertainRecords: uncertainRecords,
  );
}

Future<List<_RescueRecord>> _readRescueRecords(
  Directory stageDirectory,
  _InspectionCandidate candidate,
) async {
  final rootData = await _readJsonMap(
    File(_pathIn(stageDirectory, candidate.sourceRootPath)),
  );
  if (rootData == null) return const [];
  final records = <_RescueRecord>[
    _RescueRecord(
      sourcePath: candidate.sourceRootPath,
      type: 'location',
      depth: 0,
      data: rootData,
    ),
  ];
  final unusedPaths = <String>{...candidate.dataPaths}
    ..remove(candidate.sourceRootPath);
  var frontier = <_RescueRecord>[records.first];
  for (var depth = 1; depth <= 3 && frontier.isNotEmpty; depth++) {
    final next = <_RescueRecord>[];
    for (final parent in frontier) {
      final paths = unusedPaths.where((path) {
        final parts = path.split('/');
        return parts.length == 2 && parts.first == parent.id;
      }).toList(growable: false);
      for (final path in paths) {
        final data = await _readJsonMap(File(_pathIn(stageDirectory, path)));
        if (data == null || data['PjNr'] == null) continue;
        data['parent_local_id'] ??= parent.id;
        data['local_id'] ??= _basename(path);
        final record = _RescueRecord(
          sourcePath: path,
          type: const ['location', 'category', 'checkpoint', 'defect'][depth],
          depth: depth,
          data: data,
        );
        unusedPaths.remove(path);
        records.add(record);
        next.add(record);
      }
    }
    frontier = next;
  }
  return records;
}

_ServerRescueRecord? _matchServerRecord(
  _RescueRecord backup,
  List<_ServerRescueRecord> serverRecords,
  Map<String, String> idMap,
) {
  if (backup.type == 'location') {
    final pj = _normalizeIdentifier(backup.data['PjNr']);
    final location = _normalizeIdentifier(backup.data['StONr']);
    final matches = serverRecords.where((server) {
      return !server.consumed &&
          server.type == 'location' &&
          _normalizeIdentifier(server.data['PjNr']) == pj &&
          _normalizeIdentifier(server.data['StONr']) == location;
    }).toList();
    return matches.length == 1 ? matches.single : null;
  }

  final mappedParent = idMap[backup.parentId] ?? backup.parentId;
  final candidates = serverRecords.where((server) {
    return !server.consumed &&
        server.type == backup.type &&
        server.parentId == mappedParent;
  }).toList(growable: false);
  if (candidates.isEmpty) return null;

  _ServerRescueRecord? uniqueWhere(
    bool Function(_ServerRescueRecord server) predicate,
  ) {
    final matches = candidates.where(predicate).toList(growable: false);
    return matches.length == 1 ? matches.single : null;
  }

  final exactId = uniqueWhere((server) => server.id == backup.id);
  if (exactId != null) return exactId;

  if (_hasPositiveTerminalIndex(backup)) {
    final coordinate = uniqueWhere(
      (server) => _sameCoordinates(backup.data, server.data, backup.type),
    );
    if (coordinate != null) return coordinate;
  }

  final semantic = _semanticFingerprint(backup.data);
  final semanticMatch = uniqueWhere(
    (server) => _semanticFingerprint(server.data) == semantic,
  );
  if (semanticMatch != null) return semanticMatch;

  final identity = _creationIdentity(backup.data);
  if (identity != null) {
    final identityMatch = uniqueWhere(
      (server) => _creationIdentity(server.data) == identity,
    );
    if (identityMatch != null) return identityMatch;
  }
  return null;
}

bool _hasPositiveTerminalIndex(_RescueRecord record) {
  final key = switch (record.type) {
    'category' => 'E1',
    'checkpoint' => 'E2',
    'defect' => 'E3',
    _ => null,
  };
  if (key == null) return false;
  return (num.tryParse(record.data[key]?.toString() ?? '') ?? -1) > 0;
}

bool _sameCoordinates(
  Map<String, dynamic> left,
  Map<String, dynamic> right,
  String type,
) {
  final keys = switch (type) {
    'category' => const ['PjNr', 'E1'],
    'checkpoint' => const ['PjNr', 'E1', 'E2'],
    'defect' => const ['PjNr', 'E1', 'E2', 'E3'],
    _ => const ['PjNr', 'StONr'],
  };
  return keys.every(
    (key) =>
        _normalizeIdentifier(left[key]) == _normalizeIdentifier(right[key]),
  );
}

String _semanticFingerprint(Map<String, dynamic> data) =>
    jsonEncode(_normalizedRecord(data, ignoreCoordinates: true));

String? _creationIdentity(Map<String, dynamic> data) {
  final eventId = _normalizeIdentifier(data['EventID']);
  final created = _nonEmptyString(data['ErDat']);
  final author = _nonEmptyString(data['Autor']);
  if (eventId != null && eventId != '-1' && eventId != '0') {
    return 'event:$eventId|${author ?? ''}';
  }
  if (created != null && author != null) return 'created:$created|$author';
  return null;
}

bool _sameRecordContent(
  Map<String, dynamic> left,
  Map<String, dynamic> right,
) =>
    jsonEncode(_normalizedRecord(left)) == jsonEncode(_normalizedRecord(right));

dynamic _normalizedRecord(
  Object? value, {
  bool ignoreCoordinates = false,
}) {
  if (value is Map) {
    const alwaysIgnored = {
      'local_id',
      'parent_local_id',
      'offline',
      'mainhash',
      'images',
    };
    final keys = value.keys
        .map((key) => key.toString())
        .where((key) =>
            !alwaysIgnored.contains(key) &&
            !(ignoreCoordinates && const {'E1', 'E2', 'E3'}.contains(key)) &&
            value[key] != null)
        .toList()
      ..sort();
    return {
      for (final key in keys)
        key: _normalizedRecord(
          value[key],
          ignoreCoordinates: ignoreCoordinates,
        ),
    };
  }
  if (value is List) {
    return value
        .map((entry) =>
            _normalizedRecord(entry, ignoreCoordinates: ignoreCoordinates))
        .toList();
  }
  if (value is num) return value.toString();
  return value;
}

Map<String, dynamic> _applyRecordMappings(
  Map<String, dynamic> source,
  Map<String, String> idMap,
) {
  final result = Map<String, dynamic>.from(source)..remove('offline');
  for (final key in const ['local_id', 'parent_local_id']) {
    final value = _nonEmptyString(result[key]);
    if (value != null && idMap.containsKey(value)) result[key] = idMap[value];
  }
  return result;
}

Map<String, dynamic> _applyServerIdentity(
  Map<String, dynamic> desired,
  Map<String, dynamic> server,
  String type,
) {
  final result = Map<String, dynamic>.from(desired);
  for (final key in const [
    'local_id',
    'parent_local_id',
    'PjNr',
    'StONr',
    'E1',
    'E2',
    'E3',
  ]) {
    if (server.containsKey(key)) result[key] = server[key];
  }
  if (type != 'location') {
    result['parent_local_id'] = server['parent_local_id'];
  }
  result.remove('offline');
  return result;
}

Map<String, dynamic> _serializedDataRequest(
  String route,
  String type,
  Map<String, dynamic> data,
) =>
    {
      'route': route,
      'json': {
        'type': type,
        'data': Map<String, dynamic>.from(data)..remove('offline'),
      },
      'multipartFiles': <String>[],
      'returnsBinary': false,
    };

bool _isLocallyCreatedRecord(_RescueRecord record) =>
    record.id.startsWith('__loc__') ||
    record.id.startsWith('__loc') ||
    !_hasPositiveTerminalIndex(record);

String _rescueRecordDestination(
  _RescueRecord record,
  Map<String, String> idMap,
  String targetRootId,
) {
  final childId = idMap[record.id] ?? record.id;
  if (record.depth == 0) return '$targetRootId/$childId';
  final parentId = idMap[record.parentId] ?? record.parentId;
  return '$parentId/$childId';
}

Future<String?> _resolveRescueFileReference(
  Directory stageDirectory,
  Set<String> candidatePaths,
  String rawReference,
) async {
  final reference = rawReference.replaceAll('\\', '/');
  final exact = File(_pathIn(stageDirectory, reference));
  if (candidatePaths.contains(reference) && await exact.exists()) {
    return reference;
  }
  // A slash denotes a locally stored, scoped filename. Server hashes never
  // contain one. Legacy backups occasionally kept only its basename.
  if (!reference.contains('/') && !reference.startsWith('__loc__')) {
    return null;
  }
  final basename = _basename(reference);
  final matches = <String>[];
  for (final path in candidatePaths) {
    if (_basename(path) != basename) continue;
    final file = File(_pathIn(stageDirectory, path));
    if (await file.exists() && await file.length() >= 5) matches.add(path);
  }
  return matches.length == 1 ? matches.single : null;
}

Map<String, dynamic> _rewriteImageReferences(
  Map<String, dynamic> source,
  Map<String, String> imageMap,
) {
  final result = Map<String, dynamic>.from(source);
  String rewrite(String value) =>
      imageMap[value] ?? imageMap[_basename(value)] ?? value;
  final main = result['mainhash'];
  if (main is String) result['mainhash'] = rewrite(main);
  final images = result['images'];
  if (images is List) {
    result['images'] = images
        .map((value) => value is String ? rewrite(value) : value)
        .toList();
  }
  return result;
}

Future<bool> _copyRescueFile(File source, File destination) async {
  if (await destination.exists() &&
      await source.length() == await destination.length() &&
      await _sha256File(source) == await _sha256File(destination)) {
    return false;
  }
  await destination.parent.create(recursive: true);
  await source.copy(destination.path);
  try {
    await destination.setLastModified((await source.stat()).modified);
  } catch (_) {}
  return true;
}

Future<bool> _writeRescueJson(
  File destination,
  Map<String, dynamic> data,
) async {
  final bytes = utf8.encode(jsonEncode(data));
  if (await destination.exists() &&
      sha256.convert(await destination.readAsBytes()) ==
          sha256.convert(bytes)) {
    return false;
  }
  await destination.parent.create(recursive: true);
  await destination.writeAsBytes(bytes, flush: true);
  return true;
}

Future<bool> _mergeRescueSyncMap({
  required Directory mergedDirectory,
  required String projectNumber,
  required Map<String, String> localIdMap,
  required Map<String, String> imageHashMap,
}) async {
  final file = File(
    _pathIn(mergedDirectory, 'other/__sync_maps__$projectNumber'),
  );
  final existing = await _readJsonMap(file) ?? <String, dynamic>{};
  Map<String, String> stringMap(Object? value) => value is Map
      ? value.map((key, value) => MapEntry(key.toString(), value.toString()))
      : <String, String>{};
  final mergedLocalIds = stringMap(existing['localIdMap'])..addAll(localIdMap);
  final mergedImages = stringMap(existing['imageHashMap'])
    ..addAll(imageHashMap);
  return _writeRescueJson(file, {
    'localIdMap': mergedLocalIds,
    'imageHashMap': mergedImages,
    'ts': DateTime.now().millisecondsSinceEpoch,
  });
}

Future<void> _reconstructStage(
  _RestorePlan plan,
  Directory stageDirectory,
) async {
  for (final manifest in plan.manifests) {
    await _applyManifest(manifest, stageDirectory);
  }
  await _verifySnapshot(stageDirectory, plan.latest.snapshot);
}

Future<List<_InspectionCandidate>> _discoverInspectionCandidates({
  required Directory stageDirectory,
  required Map<String, _RestoreSignature> snapshot,
  required Directory currentDataDirectory,
  required String? currentRootId,
}) async {
  final existingProjectNumbers = await _readExistingProjectNumbers(
    currentDataDirectory,
    currentRootId,
  );
  final failedRequestsByProject = <String, Set<String>>{};
  for (final path in snapshot.keys.where(
    (path) => path.startsWith('failed-requests/'),
  )) {
    final projectNumber = await _projectNumberFromFailedRequest(
      File(_pathIn(stageDirectory, path)),
    );
    if (projectNumber != null) {
      failedRequestsByProject.putIfAbsent(projectNumber, () => {}).add(path);
    }
  }

  final rootPaths = <String>{};
  for (final entry in snapshot.entries) {
    if (entry.key.startsWith('failed-requests/')) continue;
    if (entry.value.metadata?['Typ'] == 'Inspektion') {
      rootPaths.add(entry.key);
    }
  }
  for (final entry in snapshot.entries) {
    final parts = entry.key.split('/');
    if (rootPaths.contains(entry.key) ||
        entry.key.startsWith('failed-requests/') ||
        parts.length != 2 ||
        parts.last.contains('.') ||
        entry.value.size > 2 * 1024 * 1024) {
      continue;
    }
    final json = await _readJsonMap(File(_pathIn(stageDirectory, entry.key)));
    if (json != null && json['PjNr'] != null && json['StONr'] != null) {
      rootPaths.add(entry.key);
    }
  }

  final candidates = <_InspectionCandidate>[];
  for (final rootPath in rootPaths) {
    final rootJson =
        await _readJsonMap(File(_pathIn(stageDirectory, rootPath)));
    if (rootJson == null) continue;
    final projectNumber = _normalizeIdentifier(rootJson['PjNr']);
    if (projectNumber == null) continue;
    final locationNumber = _normalizeIdentifier(rootJson['StONr']) ?? '';
    final localId =
        _nonEmptyString(rootJson['local_id']) ?? _basename(rootPath);
    if (!_isSafePathSegment(localId)) continue;

    final dataPaths = await _inspectionDataPaths(
      stageDirectory: stageDirectory,
      snapshot: snapshot,
      rootPath: rootPath,
      localId: localId,
      projectNumber: projectNumber,
    );
    final failedRequestPaths =
        failedRequestsByProject[projectNumber] ?? <String>{};
    final allPaths = {...dataPaths, ...failedRequestPaths};
    final totalBytes = allPaths.fold<int>(
      0,
      (sum, path) => sum + (snapshot[path]?.size ?? 0),
    );
    final name = _nonEmptyString(rootJson['PjName']) ??
        _nonEmptyString(rootJson['KurzText']) ??
        'Inspektion $projectNumber';
    final preview = BackupInspectionPreview(
      selectionId: rootPath,
      localId: localId,
      projectNumber: projectNumber,
      locationNumber: locationNumber,
      name: name,
      fileCount: allPaths.length,
      totalBytes: totalBytes,
      failedRequestCount: failedRequestPaths.length,
      alreadyOnDevice: existingProjectNumbers.contains(projectNumber),
    );
    candidates.add(
      _InspectionCandidate(
        preview: preview,
        sourceRootPath: rootPath,
        dataPaths: dataPaths,
        failedRequestPaths: failedRequestPaths,
      ),
    );
  }
  candidates.sort((left, right) {
    final projectComparison =
        left.preview.projectNumber.compareTo(right.preview.projectNumber);
    if (projectComparison != 0) return projectComparison;
    return left.preview.name.compareTo(right.preview.name);
  });
  return candidates;
}

Future<Set<String>> _inspectionDataPaths({
  required Directory stageDirectory,
  required Map<String, _RestoreSignature> snapshot,
  required String rootPath,
  required String localId,
  required String projectNumber,
}) async {
  final pathsByTopLevel = <String, List<String>>{};
  for (final path in snapshot.keys) {
    pathsByTopLevel.putIfAbsent(path.split('/').first, () => []).add(path);
  }
  final ownedIds = <String>{localId};
  final recordPaths = <String>{rootPath};
  final pendingIds = <String>[localId];
  while (pendingIds.isNotEmpty) {
    final parentId = pendingIds.removeLast();
    for (final path in pathsByTopLevel[parentId] ?? const <String>[]) {
      final parts = path.split('/');
      if (parts.length != 2 || parts.first != parentId) continue;
      final json = await _readJsonMap(File(_pathIn(stageDirectory, path)));
      if (json == null) continue;
      final childId = _nonEmptyString(json['local_id']) ?? parts.last;
      final declaredParent = _nonEmptyString(json['parent_local_id']);
      if (declaredParent != null && declaredParent != parentId) continue;
      recordPaths.add(path);
      if (ownedIds.add(childId)) pendingIds.add(childId);
    }
  }

  final paths = <String>{...recordPaths};
  for (final path in snapshot.keys) {
    if (path.startsWith('failed-requests/')) continue;
    final first = path.split('/').first;
    if (ownedIds.contains(first) ||
        first == projectNumber ||
        first.startsWith('$projectNumber-')) {
      paths.add(path);
    }
  }
  final syncMapPath = 'other/__sync_maps__$projectNumber';
  if (snapshot.containsKey(syncMapPath)) paths.add(syncMapPath);

  for (final recordPath in recordPaths) {
    final json = await _readJsonMap(File(_pathIn(stageDirectory, recordPath)));
    if (json == null) continue;
    for (final reference in _fileReferences(json)) {
      if (snapshot.containsKey(reference)) paths.add(reference);
      final basename = _basename(reference);
      if (snapshot.containsKey(basename)) paths.add(basename);
    }
  }
  return paths;
}

Iterable<String> _fileReferences(Map<String, dynamic> json) sync* {
  final main = _nonEmptyString(json['mainhash']);
  if (main != null) yield main.replaceAll('\\', '/');
  final images = json['images'];
  if (images is List) {
    for (final image in images) {
      final value = _nonEmptyString(image);
      if (value != null) yield value.replaceAll('\\', '/');
    }
  }
}

Future<Set<String>> _readExistingProjectNumbers(
  Directory currentDataDirectory,
  String? currentRootId,
) async {
  final rootId = currentRootId?.trim();
  if (rootId == null || rootId.isEmpty) return {};
  final rootDirectory = Directory(_pathIn(currentDataDirectory, rootId));
  if (!await rootDirectory.exists()) return {};
  final projectNumbers = <String>{};
  await for (final entity in rootDirectory.list(followLinks: false)) {
    if (entity is! File) continue;
    final json = await _readJsonMap(entity);
    final projectNumber = _normalizeIdentifier(json?['PjNr']);
    if (projectNumber != null && json?['StONr'] != null) {
      projectNumbers.add(projectNumber);
    }
  }
  return projectNumbers;
}

Future<String?> _projectNumberFromFailedRequest(File file) async {
  final request = await _readJsonMap(file);
  if (request == null) return null;
  final requestJson = request['json'];
  if (requestJson is! Map) return _normalizeIdentifier(request['PjNr']);
  final dataField = requestJson['data'];
  Map<String, dynamic>? data;
  if (dataField is Map) {
    data = Map<String, dynamic>.from(dataField);
  } else if (dataField is String) {
    try {
      final decoded = jsonDecode(dataField);
      if (decoded is Map) data = Map<String, dynamic>.from(decoded);
    } catch (_) {}
  }
  final direct = _normalizeIdentifier(data?['PjNr']) ??
      _normalizeIdentifier(requestJson['PjNr']);
  if (direct != null) return direct;
  for (final key in const ['parent_local_id', 'local_id']) {
    final value = _nonEmptyString(data?[key]);
    final first = value?.split('-').first;
    final parsed = int.tryParse(first ?? '');
    if (parsed != null && parsed > 0) return parsed.toString();
  }
  return null;
}

Future<Map<String, dynamic>?> _readJsonMap(File file) async {
  try {
    if (!await file.exists() || await file.length() > 4 * 1024 * 1024) {
      return null;
    }
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
  } catch (_) {}
  return null;
}

String? _nonEmptyString(Object? value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty || text == 'null') return null;
  return text;
}

String? _normalizeIdentifier(Object? value) {
  final text = _nonEmptyString(value);
  if (text == null || text == 'undefined') return null;
  final numeric = num.tryParse(text);
  return numeric == null ? text : numeric.toInt().toString();
}

bool _isSafePathSegment(String value) =>
    value.isNotEmpty &&
    value != '.' &&
    value != '..' &&
    !value.contains('/') &&
    !value.contains('\\') &&
    !value.contains('\u0000');

Future<Set<String>> _failedRequestHashes(Directory directory) async {
  final failedDirectory = Directory(_pathIn(directory, 'failed-requests'));
  if (!await failedDirectory.exists()) return {};
  final hashes = <String>{};
  await for (final entity in failedDirectory.list(followLinks: false)) {
    if (entity is File) {
      hashes.add(
        sha256.convert(await _sanitizedFailedRequestBytes(entity)).toString(),
      );
    }
  }
  return hashes;
}

Future<List<int>> _sanitizedFailedRequestBytes(File file) async {
  final original = await file.readAsBytes();
  try {
    final decoded = jsonDecode(utf8.decode(original));
    if (decoded is! Map) return original;
    final sanitized = Map<String, dynamic>.from(decoded)..remove('user');
    final requestJson = sanitized['json'];
    if (requestJson is Map) {
      sanitized['json'] = Map<String, dynamic>.from(requestJson)
        ..remove('user');
    }
    return utf8.encode(jsonEncode(sanitized));
  } catch (_) {
    return original;
  }
}

Future<bool> _copyImportedFile({
  required File source,
  required File destination,
  required String displayPath,
}) async {
  if (await destination.exists()) {
    if (await source.length() == await destination.length() &&
        await _sha256File(source) == await _sha256File(destination)) {
      return false;
    }
    throw BackupRestoreException(
      'Der Import würde vorhandene lokale Daten überschreiben: $displayPath',
    );
  }
  await destination.parent.create(recursive: true);
  await source.copy(destination.path);
  try {
    await destination.setLastModified((await source.stat()).modified);
  } catch (_) {}
  return true;
}

Future<BackupRestoreResult> _executeRestore({
  required _RestorePlan plan,
  required Directory targetDirectory,
  Directory? workingDirectory,
}) async {
  final workBase = workingDirectory ?? targetDirectory.parent;
  await workBase.create(recursive: true);
  final workRoot = await _createUniqueWorkingDirectory(workBase);
  final stageDirectory = Directory('${workRoot.path}/stage');
  final mergedDirectory = Directory('${workRoot.path}/merged');
  final rollbackDirectory = Directory('${workRoot.path}/rollback');
  await stageDirectory.create(recursive: true);

  var committed = false;
  try {
    for (final manifest in plan.manifests) {
      await _applyManifest(manifest, stageDirectory);
    }
    await _verifySnapshot(stageDirectory, plan.latest.snapshot);

    await mergedDirectory.create(recursive: true);
    if (await targetDirectory.exists()) {
      await _copyPreservedRuntimeFiles(targetDirectory, mergedDirectory);
    }
    await _copyDirectoryFiles(stageDirectory, mergedDirectory);

    final targetExisted = await targetDirectory.exists();
    if (targetExisted) {
      await targetDirectory.rename(rollbackDirectory.path);
    }
    try {
      await mergedDirectory.rename(targetDirectory.path);
      committed = true;
    } catch (_) {
      if (await targetDirectory.exists()) {
        await targetDirectory.delete(recursive: true);
      }
      if (targetExisted && await rollbackDirectory.exists()) {
        await rollbackDirectory.rename(targetDirectory.path);
      }
      rethrow;
    }

    final preview = plan.preview;
    return BackupRestoreResult(
      restoredFileCount: preview.fileCount,
      restoredBytes: preview.totalBytes,
      appliedBackupCount: preview.chainLength,
      backupCreatedAt: preview.createdAt,
    );
  } finally {
    if (!committed &&
        await rollbackDirectory.exists() &&
        !await targetDirectory.exists()) {
      await rollbackDirectory.rename(targetDirectory.path);
    }
    try {
      if (await workRoot.exists()) await workRoot.delete(recursive: true);
    } catch (_) {
      // A successful restore must not be reported as failed only because a
      // temporary rollback directory could not be removed immediately.
    }
  }
}

Future<Directory> _createUniqueWorkingDirectory(Directory parent) async {
  var timestamp = DateTime.now().microsecondsSinceEpoch;
  while (true) {
    final directory = Directory('${parent.path}/.mbg-restore-$timestamp');
    if (!await directory.exists()) return directory.create();
    timestamp++;
  }
}

Future<void> _applyManifest(
  _RestoreManifest manifest,
  Directory stageDirectory,
) async {
  for (final move in manifest.movedFiles.entries) {
    final source = File(_pathIn(stageDirectory, move.key));
    final target = File(_pathIn(stageDirectory, move.value));
    if (await source.exists()) {
      await target.parent.create(recursive: true);
      if (await target.exists()) await target.delete();
      await source.rename(target.path);
      await _deleteEmptyParents(source.parent, stageDirectory);
    } else if (!await target.exists()) {
      throw BackupRestoreException(
        '${manifest.archiveName} kann ${move.key} nicht nach ${move.value} verschieben.',
      );
    }
  }

  for (final path in manifest.deletedFiles) {
    final file = File(_pathIn(stageDirectory, path));
    if (await file.exists()) {
      await file.delete();
      await _deleteEmptyParents(file.parent, stageDirectory);
    }
  }

  InputFileStream? input;
  try {
    input = InputFileStream(manifest.sourceFile.path);
    final archive = ZipDecoder().decodeBuffer(input);
    final entriesByPath = <String, ArchiveFile>{};
    for (final entry in archive.files) {
      final name = _normalizedArchiveEntryName(entry.name);
      if (entry.isSymbolicLink) {
        throw BackupRestoreException(
          '${manifest.archiveName} enthält einen symbolischen Link: $name',
        );
      }
      if (name.isEmpty || !entry.isFile) continue;
      if (name == incrementalBackupManifestName ||
          name == backupContentsIndexName) {
        continue;
      }
      final path = _validatedBackupPath(name);
      if (entriesByPath.containsKey(path)) {
        throw BackupRestoreException(
          '${manifest.archiveName} enthält einen unsicheren oder doppelten Eintrag: $path',
        );
      }
      entriesByPath[path] = entry;
    }

    if (entriesByPath.keys
            .toSet()
            .difference(manifest.changedFiles.toSet())
            .isNotEmpty ||
        manifest.changedFiles
            .toSet()
            .difference(entriesByPath.keys.toSet())
            .isNotEmpty) {
      throw BackupRestoreException(
        '${manifest.archiveName} stimmt nicht mit seinem Dateiverzeichnis überein.',
      );
    }

    for (final path in manifest.changedFiles) {
      final entry = entriesByPath[path]!;
      final signature = manifest.snapshot[path]!;
      if (entry.size != signature.size) {
        throw BackupRestoreException(
          '${manifest.archiveName}: Die Größe von $path stimmt nicht.',
        );
      }
      final destination = File(_pathIn(stageDirectory, path));
      await destination.parent.create(recursive: true);
      final output = OutputFileStream(destination.path);
      try {
        entry.writeContent(output);
      } finally {
        await output.close();
      }
      final actualHash = await _sha256File(destination);
      if (await destination.length() != signature.size ||
          actualHash != signature.contentHash) {
        await destination.delete();
        throw BackupRestoreException(
          '${manifest.archiveName}: Die Prüfsumme von $path stimmt nicht.',
        );
      }
      await destination.setLastModified(
        DateTime.fromMillisecondsSinceEpoch(signature.modifiedAtMs),
      );
    }
  } on BackupRestoreException {
    rethrow;
  } catch (error) {
    throw BackupRestoreException(
      '${manifest.archiveName} konnte nicht entpackt werden: $error',
    );
  } finally {
    input?.closeSync();
  }
}

Future<void> _verifySnapshot(
  Directory stageDirectory,
  Map<String, _RestoreSignature> snapshot,
) async {
  final foundPaths = <String>{};
  await for (final entity
      in stageDirectory.list(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    final path = _relativePath(stageDirectory, entity);
    foundPaths.add(path);
    final signature = snapshot[path];
    if (signature == null ||
        await entity.length() != signature.size ||
        await _sha256File(entity) != signature.contentHash) {
      throw BackupRestoreException(
        'Der rekonstruierte Datenstand ist bei $path nicht vollständig.',
      );
    }
  }
  final missing = snapshot.keys.toSet().difference(foundPaths);
  final unexpected = foundPaths.difference(snapshot.keys.toSet());
  if (missing.isNotEmpty || unexpected.isNotEmpty) {
    throw BackupRestoreException(
      'Der rekonstruierte Datenstand ist unvollständig. '
      'Fehlend: ${missing.length}, unerwartet: ${unexpected.length}.',
    );
  }
}

Future<void> _copyPreservedRuntimeFiles(
  Directory source,
  Directory destination,
) async {
  await _copyDirectoryFiles(
    source,
    destination,
    include: (path) {
      if (path.startsWith('flutter_assets/')) return true;
      if (!path.startsWith('other/')) return false;
      return !_basename(path).startsWith('__sync_maps__');
    },
  );
}

Future<void> _copyDirectoryFiles(
  Directory source,
  Directory destination, {
  bool Function(String path)? include,
}) async {
  if (!await source.exists()) return;
  await for (final entity in source.list(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    final path = _relativePath(source, entity);
    if (include != null && !include(path)) continue;
    final target = File(_pathIn(destination, path));
    await target.parent.create(recursive: true);
    await entity.copy(target.path);
    try {
      await target.setLastModified((await entity.stat()).modified);
    } catch (_) {}
  }
}

Future<void> _deleteEmptyParents(
  Directory directory,
  Directory root,
) async {
  final rootPath = root.absolute.path;
  var current = directory;
  while (current.absolute.path != rootPath &&
      current.absolute.path.startsWith('$rootPath${Platform.pathSeparator}')) {
    if (!await current.exists() || !(await current.list().isEmpty)) return;
    final parent = current.parent;
    await current.delete();
    current = parent;
  }
}

Future<String> _sha256File(File file) async =>
    (await sha256.bind(file.openRead()).first).toString();

String _pathIn(Directory root, String relativePath) => [
      root.path,
      ...relativePath.split('/'),
    ].join(Platform.pathSeparator);

String _relativePath(Directory root, File file) {
  final rootPath = root.absolute.path;
  final prefix = rootPath.endsWith(Platform.pathSeparator)
      ? rootPath
      : '$rootPath${Platform.pathSeparator}';
  return file.absolute.path
      .substring(prefix.length)
      .replaceAll(Platform.pathSeparator, '/');
}

bool _sameStringList(List<String> left, List<String> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

String _basename(String path) => path.split(RegExp(r'[/\\]')).last;
