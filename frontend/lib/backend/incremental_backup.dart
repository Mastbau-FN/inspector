import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

const String incrementalBackupManifestName = '.mbg-backup-manifest.json';
const String backupContentsIndexName = 'Backup-Inhalt.json';
const String _incrementalBackupStateName = '.mbg-backup-state-v1.json';
const String _forceFullBackupMarkerName = '.mbg-force-full-backup';
const Duration _backupIoPause = Duration(milliseconds: 20);
const double _archiveProgressLimit = 0.97;
const double _byteProgressWeight = 0.60;
const double _fileProgressWeight = 0.40;

class BackupProgress {
  final double progress;
  final String currentFile;
  final String eta;
  final int processedFiles;
  final int totalFiles;

  const BackupProgress({
    required this.progress,
    required this.currentFile,
    required this.eta,
    required this.processedFiles,
    required this.totalFiles,
  });
}

class BackupWorkEstimate {
  final double progress;
  final Duration remaining;

  const BackupWorkEstimate({
    required this.progress,
    required this.remaining,
  });
}

BackupWorkEstimate estimateBackupWork({
  required Duration elapsed,
  required int processedBytes,
  required int totalBytes,
  required int processedFiles,
  required int totalFiles,
}) {
  final byteFraction =
      totalBytes <= 0 ? 1.0 : (processedBytes / totalBytes).clamp(0.0, 1.0);
  final fileFraction =
      totalFiles <= 0 ? 1.0 : (processedFiles / totalFiles).clamp(0.0, 1.0);
  final workFraction = (_byteProgressWeight * byteFraction) +
      (_fileProgressWeight * fileFraction);
  final progress =
      (workFraction * _archiveProgressLimit).clamp(0.0, _archiveProgressLimit);

  if (elapsed.inMilliseconds <= 0 || workFraction <= 0) {
    return BackupWorkEstimate(
      progress: progress,
      remaining: const Duration(seconds: 10),
    );
  }

  final estimatedWorkMs = elapsed.inMilliseconds / workFraction;
  final processingRemainingMs =
      (estimatedWorkMs - elapsed.inMilliseconds).clamp(0, double.infinity);
  final finalizationMs =
      (estimatedWorkMs * (1 - _archiveProgressLimit)).clamp(1500, 30000);
  return BackupWorkEstimate(
    progress: progress,
    remaining: Duration(
      milliseconds: (processingRemainingMs + finalizationMs).round(),
    ),
  );
}

class IncrementalBackupResult {
  final File? backupFile;
  final int changedFileCount;
  final int deletedFileCount;

  const IncrementalBackupResult({
    required this.backupFile,
    required this.changedFileCount,
    required this.deletedFileCount,
  });

  bool get created => backupFile != null;
}

class BackupCoordinator extends ChangeNotifier {
  static final BackupCoordinator instance = BackupCoordinator._();

  BackupCoordinator._();

  Future<IncrementalBackupResult>? _activeBackup;
  bool _isRunning = false;
  double _progress = 0;
  String _currentFile = '';
  String _eta = '';
  int _processedFiles = 0;
  int _totalFiles = 0;
  bool? _success;

  bool get isRunning => _isRunning;
  double get progress => _progress;
  String get currentFile => _currentFile;
  String get eta => _eta;
  int get processedFiles => _processedFiles;
  int get totalFiles => _totalFiles;
  bool? get success => _success;

  Future<IncrementalBackupResult> runBackup({
    required Directory sourceDirectory,
    required Directory backupDirectory,
    Future<void> Function(BackupProgress progress)? onProgress,
  }) async {
    final activeBackup = _activeBackup;
    if (activeBackup != null) return activeBackup;

    final operation = _executeBackup(
      sourceDirectory: sourceDirectory,
      backupDirectory: backupDirectory,
      onProgress: onProgress,
    );
    _activeBackup = operation;
    try {
      return await operation;
    } finally {
      if (identical(_activeBackup, operation)) {
        _activeBackup = null;
      }
    }
  }

  Future<IncrementalBackupResult> _executeBackup({
    required Directory sourceDirectory,
    required Directory backupDirectory,
    Future<void> Function(BackupProgress progress)? onProgress,
  }) async {
    _isRunning = true;
    _progress = 0;
    _currentFile = 'Backup wird vorbereitet';
    _eta = 'wird berechnet';
    _processedFiles = 0;
    _totalFiles = 0;
    _success = null;
    notifyListeners();

    try {
      final result = await createIncrementalBackup(
        sourceDirectory: sourceDirectory,
        backupDirectory: backupDirectory,
        onProgress: (progress) async {
          _progress = progress.progress;
          _currentFile = progress.currentFile;
          _eta = progress.eta;
          _processedFiles = progress.processedFiles;
          _totalFiles = progress.totalFiles;
          notifyListeners();
          await onProgress?.call(progress);
        },
      );
      _progress = 1;
      _eta = '0 s';
      _success = true;
      return result;
    } catch (_) {
      _success = false;
      rethrow;
    } finally {
      _isRunning = false;
      notifyListeners();
    }
  }
}

class _FileSignature {
  final int size;
  final int modifiedAtMs;
  final String? contentHash;
  final String? comparisonHash;
  final Map<String, dynamic>? metadata;

  const _FileSignature({
    required this.size,
    required this.modifiedAtMs,
    required this.contentHash,
    this.comparisonHash,
    this.metadata,
  });

  factory _FileSignature.fromJson(Map<String, dynamic> json) => _FileSignature(
        size: (json['size'] as num?)?.toInt() ?? -1,
        modifiedAtMs: (json['modifiedAtMs'] as num?)?.toInt() ?? -1,
        contentHash: json['contentHash']?.toString(),
        comparisonHash: json['comparisonHash']?.toString(),
        metadata: json['metadata'] is Map
            ? Map<String, dynamic>.from(json['metadata'] as Map)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'size': size,
        'modifiedAtMs': modifiedAtMs,
        if (contentHash != null) 'contentHash': contentHash,
        if (comparisonHash != null) 'comparisonHash': comparisonHash,
        if (metadata != null) 'metadata': metadata,
      };

  @override
  bool operator ==(Object other) {
    if (other is! _FileSignature) return false;
    if (comparisonHash != null && other.comparisonHash != null) {
      return comparisonHash == other.comparisonHash;
    }
    if (other.size != size) return false;
    if (contentHash != null && other.contentHash != null) {
      return contentHash == other.contentHash;
    }
    return other.modifiedAtMs == modifiedAtMs;
  }

  @override
  int get hashCode =>
      comparisonHash?.hashCode ??
      Object.hash(size, contentHash ?? modifiedAtMs);
}

class _BackupState {
  final Map<String, _FileSignature> files;
  final List<String> backupChain;
  final Map<String, String> pendingMovedFiles;

  const _BackupState({
    required this.files,
    required this.backupChain,
    this.pendingMovedFiles = const {},
  });

  factory _BackupState.fromJson(Map<String, dynamic> json) {
    final rawFiles = json['files'];
    final files = <String, _FileSignature>{};
    if (rawFiles is Map) {
      for (final entry in rawFiles.entries) {
        final value = entry.value;
        if (value is Map) {
          files[entry.key.toString()] = _FileSignature.fromJson(
            Map<String, dynamic>.from(value),
          );
        }
      }
    }

    final rawChain = json['backupChain'];
    final backupChain = rawChain is List
        ? rawChain.map((value) => value.toString()).toList()
        : <String>[];
    final rawPendingMoves = json['pendingMovedFiles'];
    final pendingMovedFiles = rawPendingMoves is Map
        ? rawPendingMoves.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          )
        : <String, String>{};
    return _BackupState(
      files: files,
      backupChain: backupChain,
      pendingMovedFiles: pendingMovedFiles,
    );
  }

  Map<String, dynamic> toJson() => {
        'version': 4,
        'files':
            files.map((path, signature) => MapEntry(path, signature.toJson())),
        'backupChain': backupChain,
        if (pendingMovedFiles.isNotEmpty)
          'pendingMovedFiles': pendingMovedFiles,
      };
}

class _SourceSnapshot {
  final Map<String, _FileSignature> signatures;

  const _SourceSnapshot({
    required this.signatures,
  });
}

class _RemappedBackupState {
  final _BackupState state;
  final Map<String, String> movedFiles;

  const _RemappedBackupState({
    required this.state,
    required this.movedFiles,
  });
}

bool isManagedLocalBackup(FileSystemEntity entity) {
  if (entity is! File) return false;
  return RegExp(r'^backup-\d+\.zip$').hasMatch(_basename(entity.path));
}

Future<List<File>> listManagedLocalBackups(Directory backupDirectory) async {
  if (!await backupDirectory.exists()) return [];

  final backups = await backupDirectory
      .list(followLinks: false)
      .where(isManagedLocalBackup)
      .cast<File>()
      .toList();
  backups.sort((left, right) {
    final modifiedComparison =
        right.statSync().modified.compareTo(left.statSync().modified);
    return modifiedComparison != 0
        ? modifiedComparison
        : right.path.compareTo(left.path);
  });
  return backups;
}

Future<void> invalidateIncrementalBackupState(
  Directory backupDirectory,
) async {
  await backupDirectory.create(recursive: true);
  final stateFile =
      File('${backupDirectory.path}/$_incrementalBackupStateName');
  if (await stateFile.exists()) {
    await stateFile.delete();
  }
  await File('${backupDirectory.path}/$_forceFullBackupMarkerName')
      .writeAsString('1', flush: true);
}

Future<IncrementalBackupResult> createIncrementalBackup({
  required Directory sourceDirectory,
  required Directory backupDirectory,
  Future<void> Function(BackupProgress progress)? onProgress,
}) async {
  await backupDirectory.create(recursive: true);
  final existingBackups = await listManagedLocalBackups(backupDirectory);
  final stateFile =
      File('${backupDirectory.path}/$_incrementalBackupStateName');
  final stateFileExists = await stateFile.exists();
  var forceFullBackup =
      await File('${backupDirectory.path}/$_forceFullBackupMarkerName')
          .exists();
  var previousState =
      forceFullBackup ? null : await _readState(backupDirectory);

  if (!forceFullBackup && stateFileExists && previousState == null) {
    forceFullBackup = true;
  }
  if (previousState != null &&
      !_isBackupChainComplete(previousState.backupChain, existingBackups)) {
    previousState = null;
    forceFullBackup = true;
  }

  final snapshot = await _readSourceSnapshot(
    sourceDirectory,
    reusableSignatures: previousState?.files,
  );
  previousState ??= forceFullBackup
      ? const _BackupState(files: {}, backupChain: [])
      : await _stateFromLegacyBackup(snapshot, existingBackups);
  previousState = await _recoverMissingContentHashes(
    previousState,
    snapshot,
    backupDirectory,
  );
  previousState = await _recoverMissingComparisonHashes(
    previousState,
    backupDirectory,
  );
  previousState = _withoutOperationalBackupFiles(previousState);
  final localIdMappings = await _readLocalIdMappings(sourceDirectory);
  final remappedState = _remapBackupState(
    previousState,
    localIdMappings,
    snapshot.signatures.keys.toSet(),
  );
  previousState = remappedState.state;
  final equivalentImageRemap = _remapEquivalentImagePaths(
    previousState,
    snapshot,
  );
  previousState = equivalentImageRemap.state;
  final movedFiles = <String, String>{
    ...previousState.pendingMovedFiles,
    ...remappedState.movedFiles,
    ...equivalentImageRemap.movedFiles,
  };

  final changedPaths = snapshot.signatures.keys
      .where((path) => previousState!.files[path] != snapshot.signatures[path])
      .toList()
    ..sort();
  final deletedPaths = previousState.files.keys
      .where((path) => !snapshot.signatures.containsKey(path))
      .toList()
    ..sort();

  debugPrint(
    'Incremental backup plan: ${snapshot.signatures.length} files, '
    '${changedPaths.length} changed, ${deletedPaths.length} deleted',
  );

  if (changedPaths.isEmpty && deletedPaths.isEmpty) {
    await _writeState(
      backupDirectory,
      _BackupState(
        files: snapshot.signatures,
        backupChain: previousState.backupChain,
        pendingMovedFiles: movedFiles,
      ),
    );
    return const IncrementalBackupResult(
      backupFile: null,
      changedFileCount: 0,
      deletedFileCount: 0,
    );
  }

  final backupFile = await _nextBackupFile(backupDirectory);
  final temporaryFile = File('${backupFile.path}.partial');
  File? completedBackup;

  try {
    final manifest = {
      'version': 1,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'baseBackup': previousState.backupChain.isEmpty
          ? null
          : previousState.backupChain.last,
      'changedFiles': changedPaths,
      'deletedFiles': deletedPaths,
      'movedFiles': movedFiles,
      'snapshot': snapshot.signatures.map(
        (path, signature) => MapEntry(path, signature.toJson()),
      ),
      'backupChain': [
        ...previousState.backupChain,
        _basename(backupFile.path),
      ],
    };
    await _writeArchiveInBackground(
      sourceDirectory: sourceDirectory,
      temporaryFile: temporaryFile,
      changedPaths: changedPaths,
      manifestJson: jsonEncode(manifest),
      readableStructure: _buildReadableBackupStructure(snapshot),
      onProgress: onProgress,
    );

    completedBackup = await temporaryFile.rename(backupFile.path);
    final nextState = _BackupState(
      files: snapshot.signatures,
      backupChain: [
        ...previousState.backupChain,
        _basename(completedBackup.path),
      ],
    );
    await _writeState(backupDirectory, nextState);

    final forceMarker =
        File('${backupDirectory.path}/$_forceFullBackupMarkerName');
    if (await forceMarker.exists()) {
      await forceMarker.delete();
    }

    if (changedPaths.isEmpty) {
      await onProgress?.call(
        const BackupProgress(
          progress: _archiveProgressLimit,
          currentFile: 'Gelöschte Dateien',
          eta: 'weniger als 10 s',
          processedFiles: 0,
          totalFiles: 0,
        ),
      );
    }

    await onProgress?.call(
      BackupProgress(
        progress: 1,
        currentFile: 'Backup abgeschlossen',
        eta: '0 s',
        processedFiles: changedPaths.length,
        totalFiles: changedPaths.length,
      ),
    );

    return IncrementalBackupResult(
      backupFile: completedBackup,
      changedFileCount: changedPaths.length,
      deletedFileCount: deletedPaths.length,
    );
  } catch (_) {
    if (await temporaryFile.exists()) {
      await temporaryFile.delete();
    }
    if (completedBackup != null && await completedBackup.exists()) {
      await completedBackup.delete();
    }
    rethrow;
  }
}

Future<void> _writeArchiveInBackground({
  required Directory sourceDirectory,
  required File temporaryFile,
  required List<String> changedPaths,
  required String manifestJson,
  required ({String? indexJson, List<String> directories}) readableStructure,
  Future<void> Function(BackupProgress progress)? onProgress,
}) async {
  final messages = ReceivePort();
  final isolate = await Isolate.spawn<Map<String, Object?>>(
    _archiveWorker,
    {
      'sendPort': messages.sendPort,
      'sourcePath': sourceDirectory.path,
      'targetPath': temporaryFile.path,
      'changedPaths': changedPaths,
      'manifestJson': manifestJson,
      'readableIndexJson': readableStructure.indexJson,
      'readableDirectories': readableStructure.directories,
    },
    onError: messages.sendPort,
    onExit: messages.sendPort,
    errorsAreFatal: true,
  );

  var completed = false;
  try {
    await for (final message in messages) {
      if (message == null) {
        if (!completed) {
          throw StateError('Backup worker exited before completion');
        }
        break;
      }
      if (message is List && message.length >= 2) {
        throw StateError('Backup worker failed: ${message[0]}\n${message[1]}');
      }
      if (message is! Map) continue;

      switch (message['type']) {
        case 'progress':
          await onProgress?.call(
            BackupProgress(
              progress: (message['progress'] as num).toDouble(),
              currentFile: message['currentFile']?.toString() ?? '',
              eta: message['eta']?.toString() ?? '',
              processedFiles: (message['processedFiles'] as num?)?.toInt() ?? 0,
              totalFiles: (message['totalFiles'] as num?)?.toInt() ?? 0,
            ),
          );
          break;
        case 'done':
          completed = true;
          return;
        case 'error':
          throw StateError(
            'Backup worker failed: ${message['error']}\n${message['stackTrace']}',
          );
      }
    }
  } finally {
    isolate.kill(priority: Isolate.immediate);
    messages.close();
  }
}

@pragma('vm:entry-point')
Future<void> _archiveWorker(Map<String, Object?> input) async {
  final sendPort = input['sendPort'] as SendPort;
  final sourcePath = input['sourcePath'] as String;
  final targetPath = input['targetPath'] as String;
  final changedPaths = (input['changedPaths'] as List).cast<String>();
  final manifestJson = input['manifestJson'] as String;
  final readableIndexJson = input['readableIndexJson'] as String?;
  final readableDirectories =
      (input['readableDirectories'] as List).cast<String>();
  final encoder = ZipFileEncoder();
  var encoderOpen = false;

  try {
    final files = changedPaths
        .map((path) => (
              path: path,
              file: File(
                '$sourcePath${Platform.pathSeparator}${path.replaceAll('/', Platform.pathSeparator)}',
              ),
            ))
        .toList();
    final totalSize =
        files.fold<int>(0, (sum, entry) => sum + entry.file.lengthSync());
    var processedSize = 0;
    var processedFiles = 0;
    final startedAt = DateTime.now();
    var lastProgressAt = DateTime.fromMillisecondsSinceEpoch(0);
    double? smoothedRemainingMs;

    encoder.create(targetPath);
    encoderOpen = true;

    if (files.isNotEmpty) {
      sendPort.send({
        'type': 'progress',
        'progress': 0.0,
        'currentFile': files.first.path,
        'eta': 'wird berechnet',
        'processedFiles': 0,
        'totalFiles': files.length,
      });
    }

    for (final entry in files) {
      await encoder.addFile(
        entry.file,
        entry.path,
        _compressionLevelFor(entry.path),
      );
      processedSize += entry.file.lengthSync();
      processedFiles++;
      final now = DateTime.now();
      final completed = processedFiles >= files.length;
      if (completed ||
          now.difference(lastProgressAt) >= const Duration(milliseconds: 200)) {
        lastProgressAt = now;
        final estimate = estimateBackupWork(
          elapsed: now.difference(startedAt),
          processedBytes: processedSize,
          totalBytes: totalSize,
          processedFiles: processedFiles,
          totalFiles: files.length,
        );
        final estimatedRemainingMs =
            estimate.remaining.inMilliseconds.toDouble();
        smoothedRemainingMs = smoothedRemainingMs == null
            ? estimatedRemainingMs
            : (smoothedRemainingMs * 0.7) + (estimatedRemainingMs * 0.3);
        sendPort.send({
          'type': 'progress',
          'progress': estimate.progress,
          'currentFile':
              completed ? 'ZIP wird abgeschlossen' : files[processedFiles].path,
          'eta': _formatEta(
            Duration(milliseconds: smoothedRemainingMs.round()),
          ),
          'processedFiles': processedFiles,
          'totalFiles': files.length,
        });
      }
      await Future<void>.delayed(_backupIoPause);
    }

    for (final directory in readableDirectories) {
      final archiveDirectory = ArchiveFile('$directory/', 0, null)
        ..isFile = false;
      encoder.addArchiveFile(archiveDirectory);
    }
    if (readableIndexJson != null) {
      encoder.addArchiveFile(
        ArchiveFile.string(backupContentsIndexName, readableIndexJson),
      );
    }
    encoder.addArchiveFile(
      ArchiveFile.string(incrementalBackupManifestName, manifestJson),
    );
    await encoder.close();
    encoderOpen = false;
    sendPort.send({'type': 'done'});
  } catch (error, stackTrace) {
    if (encoderOpen) {
      try {
        await encoder.close();
      } catch (_) {}
    }
    sendPort.send({
      'type': 'error',
      'error': error.toString(),
      'stackTrace': stackTrace.toString(),
    });
  }
}

int _compressionLevelFor(String relativePath) {
  final extension = relativePath.toLowerCase().split('.').last;
  const alreadyCompressed = {
    'jpg',
    'jpeg',
    'png',
    'webp',
    'heic',
    'gif',
    'pdf',
    'zip',
    'mp4',
    'mov',
  };
  return alreadyCompressed.contains(extension)
      ? ZipFileEncoder.STORE
      : ZipFileEncoder.GZIP;
}

Future<_SourceSnapshot> _readSourceSnapshot(
  Directory sourceDirectory, {
  Map<String, _FileSignature>? reusableSignatures,
}) async {
  final reusable = (reusableSignatures ?? const <String, _FileSignature>{}).map(
    (path, signature) => MapEntry(path, signature.toJson()),
  );
  final rawSignatures = await Isolate.run(
    () => _scanSourceSignatures(sourceDirectory.path, reusable),
  );
  return _SourceSnapshot(
    signatures: rawSignatures.map(
      (path, signature) => MapEntry(
        path,
        _FileSignature.fromJson(signature),
      ),
    ),
  );
}

Future<Map<String, Map<String, dynamic>>> _scanSourceSignatures(
  String sourcePath,
  Map<String, Map<String, dynamic>> reusableSignatures,
) async {
  final sourceDirectory = Directory(sourcePath);
  final signatures = <String, Map<String, dynamic>>{};
  if (!await sourceDirectory.exists()) return signatures;

  await for (final entity
      in sourceDirectory.list(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    final relativePath = _relativePath(sourceDirectory, entity);
    if (!_isBackupSourcePath(relativePath)) continue;
    final stat = await entity.stat();
    final reusable = reusableSignatures[relativePath];
    final reusableSize = (reusable?['size'] as num?)?.toInt();
    final reusableModifiedAt = (reusable?['modifiedAtMs'] as num?)?.toInt();
    final reusableHash = reusable?['contentHash']?.toString();
    final reusableComparisonHash = reusable?['comparisonHash']?.toString();
    final reusableMetadata = reusable?['metadata'];
    final canReuseHash = reusableHash != null &&
        reusableSize == stat.size &&
        reusableModifiedAt == stat.modified.millisecondsSinceEpoch;
    String contentHash;
    String? comparisonHash;
    Map<String, dynamic>? metadata;
    if (canReuseHash) {
      contentHash = reusableHash;
      comparisonHash = reusableComparisonHash;
      if (reusableMetadata is Map) {
        metadata = Map<String, dynamic>.from(reusableMetadata);
      }
    } else if (stat.size <= 2 * 1024 * 1024) {
      final bytes = await entity.readAsBytes();
      contentHash = sha256.convert(bytes).toString();
      final jsonData = _tryReadBackupJson(bytes);
      if (jsonData != null) {
        comparisonHash = sha256
            .convert(utf8.encode(jsonEncode(_normalizedBackupJson(jsonData))))
            .toString();
        metadata = _backupMetadata(jsonData, relativePath);
      }
    } else {
      contentHash = (await sha256.bind(entity.openRead()).first).toString();
    }

    signatures[relativePath] = {
      'size': stat.size,
      'modifiedAtMs': stat.modified.millisecondsSinceEpoch,
      'contentHash': contentHash,
      if (comparisonHash != null) 'comparisonHash': comparisonHash,
      if (metadata != null) 'metadata': metadata,
    };
  }
  return signatures;
}

bool _isBackupSourcePath(String relativePath) {
  final normalized = relativePath.replaceAll('\\', '/');
  final parts = normalized.split('/').where((part) => part.isNotEmpty).toList();
  if (parts.isEmpty) return false;
  const operationalCollections = {
    'failed-requests',
    'skipped-requests',
    'image-index',
  };
  if (operationalCollections.contains(parts.first)) return false;
  return !(parts.first == 'other' && parts.last.startsWith('__sync_maps__'));
}

_BackupState _withoutOperationalBackupFiles(_BackupState state) => _BackupState(
      files: {
        for (final entry in state.files.entries)
          if (_isBackupSourcePath(entry.key)) entry.key: entry.value,
      },
      backupChain: state.backupChain,
      pendingMovedFiles: state.pendingMovedFiles,
    );

_RemappedBackupState _remapEquivalentImagePaths(
  _BackupState state,
  _SourceSnapshot snapshot,
) {
  final currentImagesByHash = <String, List<String>>{};
  for (final entry in snapshot.signatures.entries) {
    final hash = entry.value.contentHash;
    if (hash == null || !_isImageBackupPath(entry.key)) continue;
    currentImagesByHash.putIfAbsent(hash, () => []).add(entry.key);
  }

  final remappedFiles = Map<String, _FileSignature>.from(state.files);
  final movedFiles = <String, String>{};
  for (final entry in state.files.entries) {
    if (snapshot.signatures.containsKey(entry.key) ||
        !_isImageBackupPath(entry.key)) {
      continue;
    }
    final hash = entry.value.contentHash;
    if (hash == null) continue;
    final basename = _basename(entry.key);
    final candidates = (currentImagesByHash[hash] ?? const <String>[])
        .where((path) => _basename(path) == basename)
        .toList()
      ..sort();
    if (candidates.isEmpty) continue;

    final targetPath = candidates.first;
    remappedFiles.remove(entry.key);
    remappedFiles.putIfAbsent(targetPath, () => entry.value);
    movedFiles[entry.key] = targetPath;
  }

  return _RemappedBackupState(
    state: _BackupState(
      files: remappedFiles,
      backupChain: state.backupChain,
      pendingMovedFiles: state.pendingMovedFiles,
    ),
    movedFiles: movedFiles,
  );
}

bool _isImageBackupPath(String path) {
  final lower = path.toLowerCase();
  return lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.png') ||
      lower.endsWith('.webp') ||
      lower.endsWith('.heic') ||
      lower.endsWith('.gif') ||
      lower.endsWith('.img');
}

Map<String, dynamic>? _tryReadBackupJson(List<int> bytes) {
  try {
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
  } catch (_) {}
  return null;
}

dynamic _normalizedBackupJson(dynamic value) {
  const ignoredKeys = {
    'local_id',
    'parent_local_id',
    'offline',
    'E1',
    'E2',
    'E3',
  };
  if (value is Map) {
    final keys = value.keys.map((key) => key.toString()).toList()..sort();
    return {
      for (final key in keys)
        if (!ignoredKeys.contains(key)) key: _normalizedBackupJson(value[key]),
    };
  }
  if (value is List) return value.map(_normalizedBackupJson).toList();
  return value;
}

Map<String, dynamic>? _backupMetadata(
  Map<String, dynamic> json,
  String relativePath,
) {
  String? readableValue(List<String> keys) {
    for (final key in keys) {
      final value = json[key]?.toString().trim();
      if (value != null && value.isNotEmpty && value != 'null') return value;
    }
    return null;
  }

  final hasInspectionFields = json['StONr'] != null;
  final hasE1 = json['E1'] != null;
  final hasE2 = json['E2'] != null;
  final hasE3 = json['E3'] != null;
  final type = hasInspectionFields
      ? 'Inspektion'
      : hasE3
          ? 'Mangel'
          : hasE2
              ? 'Prüfpunkt'
              : hasE1
                  ? 'Prüfkategorie'
                  : null;
  if (type == null) return null;

  final fallbackName = type == 'Inspektion'
      ? [json['Straße'], json['Ort']]
          .where((value) => value != null && value.toString().trim().isNotEmpty)
          .join(', ')
      : null;
  final name = readableValue(
        type == 'Inspektion'
            ? const ['PjName', 'KurzText', 'LangText']
            : const ['KurzText', 'LangText'],
      ) ??
      (fallbackName?.isNotEmpty == true ? fallbackName! : type);
  final pathParts = relativePath.split('/');
  final sourceParentId =
      pathParts.length > 1 ? pathParts[pathParts.length - 2] : null;
  final parentId = readableValue(const ['parent_local_id']) ?? sourceParentId;

  return {
    'Typ': type,
    'Name': name,
    if (json['PjNr'] != null) 'PjNr': json['PjNr'],
    if (json['E1'] != null) 'E1': json['E1'],
    if (json['E2'] != null) 'E2': json['E2'],
    if (json['E3'] != null) 'E3': json['E3'],
    'localId': readableValue(const ['local_id']) ?? pathParts.last,
    if (parentId != null) 'parentId': parentId,
  };
}

Future<Map<String, String>> _readLocalIdMappings(
  Directory sourceDirectory,
) async {
  final mappings = <String, String>{};
  final otherDirectory = Directory('${sourceDirectory.path}/other');
  if (!await otherDirectory.exists()) return mappings;

  await for (final entity
      in otherDirectory.list(recursive: false, followLinks: false)) {
    if (entity is! File ||
        !_basename(entity.path).startsWith('__sync_maps__')) {
      continue;
    }
    try {
      final decoded = jsonDecode(await entity.readAsString());
      if (decoded is! Map || decoded['localIdMap'] is! Map) continue;
      for (final entry in (decoded['localIdMap'] as Map).entries) {
        final oldId = entry.key.toString().trim();
        final newId = entry.value.toString().trim();
        if (oldId.isNotEmpty && newId.isNotEmpty && oldId != newId) {
          mappings[oldId] = newId;
        }
      }
    } catch (_) {}
  }
  return mappings;
}

_RemappedBackupState _remapBackupState(
  _BackupState state,
  Map<String, String> mappings,
  Set<String> currentPaths,
) {
  if (mappings.isEmpty || state.files.isEmpty) {
    return _RemappedBackupState(state: state, movedFiles: const {});
  }

  String resolveId(String value) {
    var current = value;
    final visited = <String>{};
    while (visited.add(current)) {
      final next = mappings[current];
      if (next == null || next == current) break;
      current = next;
    }
    return current;
  }

  String mappedPath(String path) => path.split('/').map(resolveId).join('/');

  final remappedFiles = <String, _FileSignature>{};
  final movedFiles = <String, String>{};

  for (final entry in state.files.entries.where(
    (entry) => mappedPath(entry.key) == entry.key,
  )) {
    remappedFiles[entry.key] = entry.value;
  }
  for (final entry in state.files.entries.where(
    (entry) => mappedPath(entry.key) != entry.key,
  )) {
    final targetPath = mappedPath(entry.key);
    if (!currentPaths.contains(targetPath)) {
      remappedFiles.putIfAbsent(entry.key, () => entry.value);
      continue;
    }
    remappedFiles.putIfAbsent(targetPath, () => entry.value);
    movedFiles[entry.key] = targetPath;
  }

  return _RemappedBackupState(
    state: _BackupState(
      files: remappedFiles,
      backupChain: state.backupChain,
      pendingMovedFiles: state.pendingMovedFiles,
    ),
    movedFiles: movedFiles,
  );
}

({String? indexJson, List<String> directories}) _buildReadableBackupStructure(
    _SourceSnapshot snapshot) {
  final records = <Map<String, dynamic>>[];
  final byLocalId = <String, Map<String, dynamic>>{};
  for (final entry in snapshot.signatures.entries) {
    final metadata = entry.value.metadata;
    if (metadata == null) continue;
    final record = Map<String, dynamic>.from(metadata)
      ..['Quelldatei'] = entry.key;
    records.add(record);
    final localId = metadata['localId']?.toString();
    if (localId != null && localId.isNotEmpty) byLocalId[localId] = record;
  }
  if (records.isEmpty) return (indexJson: null, directories: const []);

  String safeName(Object? value) {
    final cleaned = (value?.toString() ?? '')
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.isEmpty) return 'Ohne Namen';
    return cleaned.length <= 80 ? cleaned : cleaned.substring(0, 80).trim();
  }

  List<String> nameChain(Map<String, dynamic> record) {
    final chain = <String>[];
    Map<String, dynamic>? current = record;
    final visited = <String>{};
    while (current != null) {
      final localId = current['localId']?.toString();
      if (localId != null && !visited.add(localId)) break;
      chain.add(safeName(current['Name']));
      final parentId = current['parentId']?.toString();
      current = parentId == null ? null : byLocalId[parentId];
    }
    return chain.reversed.toList();
  }

  final directories = <String>{};
  for (final record in records) {
    final folder = ['Backup-Struktur', ...nameChain(record)].join('/');
    record['LesbarerOrdner'] = folder;
    directories.add(folder);
  }
  records.sort(
    (left, right) => left['LesbarerOrdner']
        .toString()
        .compareTo(right['LesbarerOrdner'].toString()),
  );

  return (
    indexJson: const JsonEncoder.withIndent('  ').convert({
      'Hinweis':
          'Namen dienen nur der Lesbarkeit. PjNr und E-Nummern stehen separat.',
      'Einträge': records,
    }),
    directories: directories.toList()..sort(),
  );
}

Future<_BackupState?> _readState(Directory backupDirectory) async {
  final stateFile =
      File('${backupDirectory.path}/$_incrementalBackupStateName');
  if (!await stateFile.exists()) return null;

  try {
    final decoded = jsonDecode(await stateFile.readAsString());
    if (decoded is! Map) return null;
    return _BackupState.fromJson(Map<String, dynamic>.from(decoded));
  } catch (_) {
    return null;
  }
}

Future<_BackupState> _recoverMissingContentHashes(
  _BackupState state,
  _SourceSnapshot snapshot,
  Directory backupDirectory,
) async {
  final pathsToRecover = state.files.entries
      .where((entry) {
        final current = snapshot.signatures[entry.key];
        return entry.value.contentHash == null &&
            current != null &&
            current.size == entry.value.size &&
            current.modifiedAtMs != entry.value.modifiedAtMs;
      })
      .map((entry) => entry.key)
      .toList();
  if (pathsToRecover.isEmpty || state.backupChain.isEmpty) return state;

  final recoveredHashes = await Isolate.run(
    () => _recoverHashesFromArchives(
      backupDirectory.path,
      state.backupChain,
      pathsToRecover,
    ),
  );
  if (recoveredHashes.isEmpty) return state;

  final recoveredFiles = Map<String, _FileSignature>.from(state.files);
  for (final entry in recoveredHashes.entries) {
    final previous = recoveredFiles[entry.key];
    if (previous == null) continue;
    recoveredFiles[entry.key] = _FileSignature(
      size: previous.size,
      modifiedAtMs: previous.modifiedAtMs,
      contentHash: entry.value,
      comparisonHash: previous.comparisonHash,
      metadata: previous.metadata,
    );
  }
  return _BackupState(
    files: recoveredFiles,
    backupChain: state.backupChain,
    pendingMovedFiles: state.pendingMovedFiles,
  );
}

Future<_BackupState> _recoverMissingComparisonHashes(
  _BackupState state,
  Directory backupDirectory,
) async {
  final pathsToRecover = state.files.entries
      .where((entry) =>
          entry.value.comparisonHash == null &&
          _couldContainBackupJson(entry.key))
      .map((entry) => entry.key)
      .toList();
  if (pathsToRecover.isEmpty || state.backupChain.isEmpty) return state;

  final recovered = await Isolate.run(
    () => _recoverJsonSignaturesFromArchives(
      backupDirectory.path,
      state.backupChain,
      pathsToRecover,
    ),
  );
  if (recovered.isEmpty) return state;

  final recoveredFiles = Map<String, _FileSignature>.from(state.files);
  for (final entry in recovered.entries) {
    final previous = recoveredFiles[entry.key];
    if (previous == null) continue;
    recoveredFiles[entry.key] = _FileSignature(
      size: previous.size,
      modifiedAtMs: previous.modifiedAtMs,
      contentHash: previous.contentHash,
      comparisonHash: entry.value['comparisonHash']?.toString(),
      metadata: entry.value['metadata'] is Map
          ? Map<String, dynamic>.from(entry.value['metadata'] as Map)
          : previous.metadata,
    );
  }
  return _BackupState(
    files: recoveredFiles,
    backupChain: state.backupChain,
    pendingMovedFiles: state.pendingMovedFiles,
  );
}

bool _couldContainBackupJson(String path) {
  final name = _basename(path);
  return !name.contains('.') || name.toLowerCase().endsWith('.json');
}

Map<String, Map<String, dynamic>> _recoverJsonSignaturesFromArchives(
  String backupDirectoryPath,
  List<String> backupChain,
  List<String> paths,
) {
  final unresolved = paths.toSet();
  final recovered = <String, Map<String, dynamic>>{};

  for (final backupName in backupChain.reversed) {
    if (unresolved.isEmpty) break;
    final backup = File(
      '$backupDirectoryPath${Platform.pathSeparator}$backupName',
    );
    if (!backup.existsSync()) continue;

    InputFileStream? input;
    try {
      input = InputFileStream(backup.path);
      final archive = ZipDecoder().decodeBuffer(input);
      for (final archivedFile in archive.files) {
        if (!archivedFile.isFile || archivedFile.size > 2 * 1024 * 1024) {
          continue;
        }
        final path = archivedFile.name.replaceFirst(RegExp(r'^/+'), '');
        if (!unresolved.contains(path)) continue;
        final jsonData = _tryReadBackupJson(
          archivedFile.content as List<int>,
        );
        if (jsonData == null) continue;
        final metadata = _backupMetadata(jsonData, path);
        recovered[path] = {
          'comparisonHash': sha256
              .convert(utf8.encode(jsonEncode(_normalizedBackupJson(jsonData))))
              .toString(),
          if (metadata != null) 'metadata': metadata,
        };
        unresolved.remove(path);
        archivedFile.clear();
      }
    } catch (_) {
      continue;
    } finally {
      input?.closeSync();
    }
  }
  return recovered;
}

Map<String, String> _recoverHashesFromArchives(
  String backupDirectoryPath,
  List<String> backupChain,
  List<String> paths,
) {
  final unresolved = paths.toSet();
  final recovered = <String, String>{};

  for (final backupName in backupChain.reversed) {
    if (unresolved.isEmpty) break;
    final backup = File(
      '$backupDirectoryPath${Platform.pathSeparator}$backupName',
    );
    if (!backup.existsSync()) continue;

    InputFileStream? input;
    try {
      input = InputFileStream(backup.path);
      final archive = ZipDecoder().decodeBuffer(input);
      for (final archivedFile in archive.files) {
        if (!archivedFile.isFile) continue;
        final path = archivedFile.name.replaceFirst(RegExp(r'^/+'), '');
        if (!unresolved.contains(path)) continue;
        recovered[path] =
            sha256.convert(archivedFile.content as List<int>).toString();
        unresolved.remove(path);
        archivedFile.clear();
      }
    } catch (_) {
      continue;
    } finally {
      input?.closeSync();
    }
  }
  return recovered;
}

Future<void> _writeState(
  Directory backupDirectory,
  _BackupState state,
) async {
  final stateFile =
      File('${backupDirectory.path}/$_incrementalBackupStateName');
  final temporaryStateFile = File('${stateFile.path}.partial');
  final previousStateFile = File('${stateFile.path}.previous');
  await temporaryStateFile.writeAsString(
    jsonEncode(state.toJson()),
    flush: true,
  );

  if (await previousStateFile.exists()) {
    await previousStateFile.delete();
  }
  if (await stateFile.exists()) {
    await stateFile.rename(previousStateFile.path);
  }
  try {
    await temporaryStateFile.rename(stateFile.path);
    if (await previousStateFile.exists()) {
      await previousStateFile.delete();
    }
  } catch (_) {
    if (await previousStateFile.exists() && !await stateFile.exists()) {
      await previousStateFile.rename(stateFile.path);
    }
    rethrow;
  }
}

Future<_BackupState> _stateFromLegacyBackup(
  _SourceSnapshot snapshot,
  List<File> existingBackups,
) async {
  if (existingBackups.isEmpty) {
    return const _BackupState(files: {}, backupChain: []);
  }

  final latestBackup = existingBackups.first;
  final backupTime = latestBackup.statSync().modified.millisecondsSinceEpoch;
  final archivedFiles = <String, ArchiveFile>{};
  _BackupState? embeddedState;
  InputFileStream? input;
  try {
    input = InputFileStream(latestBackup.path);
    final archive = ZipDecoder().decodeBuffer(input);
    for (final archivedFile in archive.files.where((file) => file.isFile)) {
      final normalizedPath = archivedFile.name.replaceFirst(RegExp(r'^/+'), '');
      archivedFiles[normalizedPath] = archivedFile;
    }
    final manifestFile = archivedFiles[incrementalBackupManifestName];
    if (manifestFile != null) {
      final decoded = jsonDecode(
        utf8.decode(manifestFile.content as List<int>),
      );
      if (decoded is Map) {
        final manifest = Map<String, dynamic>.from(decoded);
        final snapshot = manifest['snapshot'];
        final chain = manifest['backupChain'];
        if (snapshot is Map && chain is List) {
          embeddedState = _BackupState.fromJson({
            'files': snapshot,
            'backupChain': chain,
          });
        }
      }
    }
  } catch (_) {
    return const _BackupState(files: {}, backupChain: []);
  } finally {
    input?.closeSync();
  }

  if (embeddedState != null) {
    return _isBackupChainComplete(
      embeddedState.backupChain,
      existingBackups,
    )
        ? embeddedState
        : const _BackupState(files: {}, backupChain: []);
  }

  if (archivedFiles.containsKey(incrementalBackupManifestName)) {
    return const _BackupState(files: {}, backupChain: []);
  }

  final backedUpFiles = <String, _FileSignature>{};
  for (final entry in snapshot.signatures.entries) {
    final archivedFile = archivedFiles[entry.key];
    if (archivedFile == null) continue;
    final signature = entry.value;
    if (archivedFile.size == signature.size &&
        signature.modifiedAtMs <= backupTime) {
      backedUpFiles[entry.key] = signature;
    }
  }
  return _BackupState(
    files: backedUpFiles,
    backupChain: [_basename(latestBackup.path)],
  );
}

bool _isBackupChainComplete(List<String> chain, List<File> existingBackups) {
  final existingNames =
      existingBackups.map((backup) => _basename(backup.path)).toSet();
  return chain.every(existingNames.contains);
}

Future<File> _nextBackupFile(Directory backupDirectory) async {
  var timestamp = DateTime.now().millisecondsSinceEpoch;
  while (true) {
    final file = File('${backupDirectory.path}/backup-$timestamp.zip');
    final partialFile = File('${file.path}.partial');
    if (!await file.exists() && !await partialFile.exists()) return file;
    timestamp++;
  }
}

String _relativePath(Directory root, File file) {
  final rootPath = root.absolute.path;
  final prefix = rootPath.endsWith(Platform.pathSeparator)
      ? rootPath
      : '$rootPath${Platform.pathSeparator}';
  return file.absolute.path
      .substring(prefix.length)
      .replaceAll(Platform.pathSeparator, '/');
}

String _basename(String path) => path.split(RegExp(r'[/\\]')).last;

String _formatEta(Duration eta) {
  final seconds = eta.inSeconds;
  if (seconds <= 10) return 'weniger als 10 s';
  if (seconds < 60) {
    final roundedSeconds = ((seconds + 4) ~/ 5) * 5;
    return '$roundedSeconds s';
  }

  final roundedMinutes = (seconds + 59) ~/ 60;
  return '$roundedMinutes min';
}
