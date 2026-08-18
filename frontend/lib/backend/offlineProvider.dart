import 'dart:core';
import 'dart:convert';
import 'dart:io';

import 'package:MBG_Inspektionen/options.dart';
import 'package:MBG_Inspektionen/classes/requestData.dart';
import 'package:flutter/foundation.dart';

import 'package:http/http.dart' as http;

import 'package:MBG_Inspektionen/classes/dropdownClasses.dart';
import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';
import 'package:io/io.dart';
import 'package:path_provider/path_provider.dart';

import 'package:localstore/localstore.dart';

import './helpers.dart' as Helper;

const useOldImgEncoding = false;

// MARK: image stuff

Future<String> get localPath async {
  if (kIsWeb) return "okay_we_need_to_fake_it_for_web/";
  return (await getApplicationDocumentsDirectory()).path;
}

String _canonicalizeScope(String scope) {
  final s = scope.trim();
  if (s.isEmpty) return s;
  final parts = s.split('-');
  final normalized = parts.map((p) => p == 'null' ? 'undefined' : p).toList();
  return normalized.join('-');
}

String _legacyScopeForCanonical(String canonicalScope) {
  return canonicalScope.contains('undefined')
      ? canonicalScope.replaceAll('undefined', 'null')
      : canonicalScope;
}

String _canonicalizeScopedName(String name) {
  final normalized = name.replaceAll('\\', '/');
  if (!normalized.contains('/')) return normalized;
  final parts = normalized.split('/');
  parts[0] = _canonicalizeScope(parts[0]);
  return parts.join('/');
}

Future<void> _mergeLegacyScopeIntoCanonical(String canonicalScope) async {
  if (kIsWeb) return;
  if (canonicalScope.isEmpty) return;
  final legacyScope = _legacyScopeForCanonical(canonicalScope);
  if (legacyScope == canonicalScope) return;

  final base = await localPath;
  final fromDir = Directory('$base/$legacyScope');
  if (!fromDir.existsSync()) return;

  final toDir = Directory('$base/$canonicalScope');
  await toDir.create(recursive: true);
  try {
    await copyPath(fromDir.path, toDir.path);
    if (fromDir.existsSync()) {
      await fromDir.delete(recursive: true);
    }
  } catch (_) {}
}

Future<File> localFile(String name, [String? doc]) async {
  name = _canonicalizeScopedName(name);
  // allow nested relative paths (e.g. per inspection) and create dirs if needed
  final basePath = await localPath;
  var p0 = File('$basePath/$name');
  // keep legacy behaviour only for flat names; otherwise preserve folders
  final hasFolder = name.contains('/');
  String? legacyName;
  if (hasFolder) {
    final parts = name.split('/');
    final scope = _canonicalizeScope(parts.first);
    await _mergeLegacyScopeIntoCanonical(scope);
    final legacyScope = _legacyScopeForCanonical(scope);
    if (legacyScope != scope) {
      legacyName = [legacyScope, ...parts.skip(1)].join('/');
    }
  }

  Future<File?> migrateLegacyFileIfPresent() async {
    if (legacyName == null || legacyName.isEmpty) return null;
    final legacyFile = File('$basePath/$legacyName');
    if (!legacyFile.existsSync()) return null;
    await p0.parent.create(recursive: true);
    if (!p0.existsSync()) {
      await legacyFile.copy(p0.path);
    }
    try {
      await legacyFile.delete();
    } catch (_) {}
    return p0;
  }

  if (doc != null) {
    final migrated = await migrateLegacyFileIfPresent();
    if (migrated != null) return migrated;
    await p0.parent.create(recursive: true);
    return p0;
  }

  if (await p0.exists()) return p0;
  final migrated = await migrateLegacyFileIfPresent();
  if (migrated != null) return migrated;
  if (hasFolder) {
    // if the file has no extension, prefer a .jpg to keep it recognizable
    final baseName = p0.uri.pathSegments.last;
    if (!baseName.contains('.')) {
      final withExt = File('$basePath/$name.jpg');
      return withExt;
    }
    await p0.parent.create(recursive: true);
    return p0;
  }

  final sanitized =
      name.replaceAll(RegExp(r'[^\w]+'), '_'); // legacy naming fallback
  final p1 = File('$basePath/$sanitized.img');
  if (await p1.exists() || useOldImgEncoding) {
    await p1.parent.create(recursive: true);
    return p1;
  }
  final p2 = File('$basePath/$sanitized.maybe.jpg');
  await p2.parent.create(recursive: true);
  return p2;
}

/// stores the [imgBytes] as an image given by the [name], returns the new [File]
Future<File?> storeImage(Uint8List imgBytes, String name) async {
  // Write the file
  try {
    var file = await localFile(name);
    await file.parent.create(recursive: true);
    // Avoid rewriting already valid cached files (prevents duplicate "Stored image at ..."
    // logs and reduces UI-triggered redundant writes).
    if (await file.exists()) {
      try {
        if (await file.length() >= 5 &&
            await _hasSupportedImageSignature(file)) {
          return file;
        }
      } catch (_) {}
    }
    file = await file.writeAsBytes(imgBytes); //u good?
    debugPrint('Stored image at ${file.path}');
    return file;
  } catch (e) {
    debugPrint("!!! failed to store image: " + e.toString());
    return null;
  }
}

Future<File?> storeDoc(Uint8List imgBytes, String name) async {
  // Write the file
  try {
    var file = await localFile(name, "jaman");
    await file.parent.create(recursive: true);
    // Avoid rewriting already valid cached files
    if (file.existsSync()) {
      try {
        if (file.lengthSync() >= 5) return file;
      } catch (_) {}
    }
    file = await file.writeAsBytes(imgBytes); //u good?
    return file;
  } catch (e) {
    debugPrint("!!! failed to store image: " + e.toString());
    return null;
  }
}

class NoImagePlaceholderException implements Exception {
  @override
  String toString() =>
      'tried to read the placeholder image, which of course is not there';
}

@visibleForTesting
bool hasSupportedImageSignature(List<int> bytes) {
  bool startsWith(List<int> signature, [int offset = 0]) {
    if (bytes.length < offset + signature.length) return false;
    for (var i = 0; i < signature.length; i++) {
      if (bytes[offset + i] != signature[i]) return false;
    }
    return true;
  }

  if (startsWith(const [0xff, 0xd8, 0xff])) return true; // JPEG
  if (startsWith(const [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])) {
    return true; // PNG
  }
  if (startsWith('GIF87a'.codeUnits) || startsWith('GIF89a'.codeUnits)) {
    return true;
  }
  if (startsWith('RIFF'.codeUnits) && startsWith('WEBP'.codeUnits, 8)) {
    return true;
  }
  if (startsWith('BM'.codeUnits)) return true; // BMP
  if (startsWith(const [0x49, 0x49, 0x2a, 0x00]) ||
      startsWith(const [0x4d, 0x4d, 0x00, 0x2a])) {
    return true; // TIFF
  }

  // HEIF/HEIC/AVIF are ISO base-media containers with an `ftyp` box.
  if (startsWith('ftyp'.codeUnits, 4)) {
    const brands = <String>{
      'heic',
      'heix',
      'hevc',
      'hevx',
      'mif1',
      'msf1',
      'avif',
      'avis',
    };
    for (var offset = 8; offset + 4 <= bytes.length; offset += 4) {
      if (brands
          .contains(String.fromCharCodes(bytes.sublist(offset, offset + 4)))) {
        return true;
      }
    }
  }
  return false;
}

Future<bool> _hasSupportedImageSignature(File file) async {
  RandomAccessFile? handle;
  try {
    handle = await file.open();
    return hasSupportedImageSignature(await handle.read(32));
  } catch (_) {
    return false;
  } finally {
    await handle?.close();
  }
}

///tries to open an [Image] given by its [name] and returns it if successful
Future<Image?> readImage(String name, {int? cacheSize}) async {
  final file = (await localFile(
    name,
  ));
  if (!await file.exists()) return null;
  if (await file.length() < 5) return null;
  if (!await _hasSupportedImageSignature(file)) return null;
  //TO-DO: was wenn keine datei da lesbar ist? -> return null
  // das ist wichtig damit der placeholder statt einem "image corrupt" dargestellt wird
  return Image.file(file, cacheHeight: cacheSize, cacheWidth: cacheSize);
}

/// Tries to resolve an existing on-disk image file for a given hash/name.
/// Supports scoped paths (`<scope>/<hash>`) and legacy naming.
Future<File?> resolveImageFileByHash(
  String hash, {
  String? scope,
}) async {
  final isPath = hash.contains('/');
  final names = <String>[];

  void add(String n) {
    if (n.isEmpty) return;
    names.add(n);
  }

  if (!isPath && scope != null && scope.isNotEmpty) {
    add('$scope/$hash');
  }
  add(hash);

  for (final name in names) {
    try {
      final f = await localFile(name);
      if (f.existsSync()) return f;
    } catch (_) {}
  }
  return null;
}

bool _looksLikeImageFilename(String filename) {
  final lower = filename.toLowerCase();
  return lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.png') ||
      lower.endsWith('.webp') ||
      lower.endsWith('.heic') ||
      lower.endsWith('.maybe.jpg') ||
      lower.endsWith('.img');
}

Future<List<String>> listScopedImageNames(String scope) async {
  final s = _canonicalizeScope(scope.trim());
  if (s.isEmpty || kIsWeb) return const [];

  await _mergeLegacyScopeIntoCanonical(s);

  final base = await localPath;
  final byName = <String, DateTime>{};

  void collectScope(String scopeName, {String? exposeAsScope}) {
    final dir = Directory('$base/$scopeName');
    if (!dir.existsSync()) return;
    final outScope = exposeAsScope ?? scopeName;

    for (final entity in dir.listSync(followLinks: false)) {
      if (entity is! File) continue;
      final segments = entity.uri.pathSegments;
      if (segments.isEmpty) continue;
      final filename = segments.last;
      if (filename.isEmpty || filename.startsWith('.')) continue;
      if (!_looksLikeImageFilename(filename)) continue;

      DateTime modified = DateTime.fromMillisecondsSinceEpoch(0);
      try {
        modified = entity.statSync().modified;
      } catch (_) {}
      byName['$outScope/$filename'] = modified;
    }
  }

  collectScope(s, exposeAsScope: s);
  final legacyScope = _legacyScopeForCanonical(s);
  if (legacyScope != s) {
    collectScope(legacyScope, exposeAsScope: s);
  }

  final out = byName.keys.toList()
    ..sort((a, b) {
      final am = byName[a] ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bm = byName[b] ?? DateTime.fromMillisecondsSinceEpoch(0);
      final cmp = am.compareTo(bm);
      return cmp != 0 ? cmp : a.compareTo(b);
    });
  return out;
}

Future<void> deleteScopedImages(String scope) async {
  final canonicalScope = _canonicalizeScope(scope.trim());
  if (canonicalScope.isEmpty) return;

  if (!kIsWeb) {
    final base = await localPath;
    await deleteScopedImageFilesAt(canonicalScope, base);
  }

  try {
    final indexedImages = await imageIndexCollection.get();
    if (indexedImages == null) return;
    for (final entry in indexedImages.entries) {
      final value = entry.value;
      if (value is! Map) continue;
      final indexedScope = _canonicalizeScope(value['scope']?.toString() ?? '');
      final storedName =
          _canonicalizeScopedName(value['storedName']?.toString() ?? '');
      if (indexedScope == canonicalScope ||
          storedName.startsWith('$canonicalScope/')) {
        await imageIndexCollection.doc(entry.key.split('/').last).delete();
      }
    }
  } catch (_) {}
}

@visibleForTesting
Future<void> deleteScopedImageFilesAt(String scope, String basePath) async {
  final canonicalScope = _canonicalizeScope(scope.trim());
  if (canonicalScope.isEmpty) return;
  final scopes = <String>{
    canonicalScope,
    _legacyScopeForCanonical(canonicalScope),
  };
  for (final scopeName in scopes) {
    final directory = Directory('$basePath/$scopeName');
    if (!directory.existsSync()) continue;
    for (final entity in directory.listSync(followLinks: false)) {
      if (entity is File && _looksLikeImageFilename(entity.path)) {
        try {
          await entity.delete();
        } catch (_) {}
      }
    }
    try {
      if (directory.existsSync() && directory.listSync().isEmpty) {
        await directory.delete();
      }
    } catch (_) {}
  }
}

Future<File?> readDoc(String name, {int? cacheSize}) async {
  final file = (await localFile(name, "jaman"));
  // ignore: unused_local_variable
  final err = (name == Options().no_image_placeholder_name)
      ? NoImagePlaceholderException()
      : Exception("file $file doesnt exist");
  if (!file.existsSync())
    // throw err;
    return null;
  if (file.lengthSync() < 5) throw Exception("file $file definitely to small");
  //TO-DO: was wenn keine datei da lesbar ist? -> return null
  // das ist wichtig damit der placeholder statt einem "image corrupt" dargestellt wird
  return await localFile(name);
}

///tries to remove an [Image] given by its [name] , throws if unsuccessful
Future<File> deleteImage(String name) async {
  final file = (await localFile(name));
  if (!file.existsSync()) throw Exception("file $file doesnt exist");

  return await file.delete() as File;
}

Future<void> deleteAll({
  bool keepSkippedRequests = false,
}) async {
  final root = await getApplicationDocumentsDirectory();
  final cache = await getApplicationCacheDirectory();
  if (keepSkippedRequests) {
    copyPath(root.path + "/" + SKIPPEDCOLLECTION,
        cache.path + "/" + SKIPPEDCOLLECTION);
    await deleteAll();
    copyPath(cache.path + "/" + SKIPPEDCOLLECTION,
        root.path + "/" + SKIPPEDCOLLECTION);
  } else {
    root.delete(recursive: true);
  }
}

String? _projectNumberFromScopedValue(Object? value) {
  final raw = value?.toString().trim().replaceAll('\\', '/');
  if (raw == null || raw.isEmpty) return null;
  final firstPathPart = raw.split('/').first;
  final match = RegExp(r'^(\d+)(?:-|$)').firstMatch(firstPathPart);
  if (match == null) return null;
  final projectNumber = int.tryParse(match.group(1)!);
  if (projectNumber == null || projectNumber <= 0) return null;
  return projectNumber.toString();
}

Set<String> _projectNumbersInJson(Object? value, [int depth = 0]) {
  if (value == null || depth > 12) return <String>{};
  final projectNumbers = <String>{};

  if (value is Map) {
    for (final entry in value.entries) {
      final key = entry.key.toString().toLowerCase();
      if (const {
        'pjnr',
        'local_id',
        'parent_local_id',
        'scope',
        'storedname',
      }.contains(key)) {
        final projectNumber = _projectNumberFromScopedValue(entry.value);
        if (projectNumber != null) projectNumbers.add(projectNumber);
      }
      projectNumbers.addAll(_projectNumbersInJson(entry.value, depth + 1));
    }
    return projectNumbers;
  }

  if (value is Iterable) {
    for (final child in value) {
      projectNumbers.addAll(_projectNumbersInJson(child, depth + 1));
    }
    return projectNumbers;
  }

  if (value is String) {
    final trimmed = value.trimLeft();
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      try {
        projectNumbers.addAll(
          _projectNumbersInJson(jsonDecode(value), depth + 1),
        );
      } catch (_) {}
    }
  }
  return projectNumbers;
}

Future<Set<String>> _projectNumbersInRecord(File file) async {
  final fromName = _projectNumberFromScopedValue(
    file.uri.pathSegments.isEmpty ? null : file.uri.pathSegments.last,
  );
  final projectNumbers = <String>{
    if (fromName != null) fromName,
  };
  try {
    final stat = await file.stat();
    if (stat.size <= 2 * 1024 * 1024) {
      projectNumbers.addAll(
        _projectNumbersInJson(jsonDecode(await file.readAsString())),
      );
    }
  } catch (_) {}
  return projectNumbers;
}

Future<void> _deleteInactiveRecords(
  Directory directory,
  Set<String> retainedPjNrs,
  Set<String> removedPjNrs,
) async {
  List<FileSystemEntity> entities;
  try {
    entities = await directory.list(followLinks: false).toList();
  } catch (_) {
    return;
  }

  for (final entity in entities) {
    if (entity is Directory) {
      await _deleteInactiveRecords(
        entity,
        retainedPjNrs,
        removedPjNrs,
      );
      try {
        if (await entity.exists() &&
            !await entity.list(followLinks: false).isEmpty) {
          continue;
        }
        await entity.delete();
      } catch (_) {}
      continue;
    }
    if (entity is! File) continue;

    final projectNumbers = await _projectNumbersInRecord(entity);
    if (projectNumbers.isEmpty || projectNumbers.any(retainedPjNrs.contains)) {
      continue;
    }
    try {
      await entity.delete();
      removedPjNrs.addAll(projectNumbers);
    } catch (_) {}
  }
}

/// Removes all cached records and files that can be assigned to a project
/// which is absent from the latest authoritative server response.
///
/// Callers must include locally created/edited offline inspections in
/// [retainedPjNrs]. Unknown files are deliberately preserved.
Future<Set<String>> pruneInactiveInspectionStorage(
  Set<String> retainedPjNrs,
) async {
  if (kIsWeb) return <String>{};
  return pruneInactiveInspectionStorageAt(
    applicationDocumentsDirectory: Directory(await localPath),
    retainedPjNrs: retainedPjNrs,
  );
}

@visibleForTesting
Future<Set<String>> pruneInactiveInspectionStorageAt({
  required Directory applicationDocumentsDirectory,
  required Set<String> retainedPjNrs,
}) async {
  final retained = retainedPjNrs
      .map(_projectNumberFromScopedValue)
      .whereType<String>()
      .toSet();
  final removed = <String>{};
  if (!await applicationDocumentsDirectory.exists()) return removed;

  List<FileSystemEntity> topLevelEntities;
  try {
    topLevelEntities =
        await applicationDocumentsDirectory.list(followLinks: false).toList();
  } catch (_) {
    return removed;
  }

  for (final entity in topLevelEntities) {
    if (entity is! Directory) continue;
    final segments =
        entity.uri.pathSegments.where((segment) => segment.isNotEmpty).toList();
    if (segments.isEmpty) continue;
    final name = segments.last;

    // Runtime assets are owned by the installed app, not by inspections.
    if (name == 'flutter_assets') continue;

    if (name == OTHERCOLLECTION) {
      List<FileSystemEntity> files;
      try {
        files = await entity.list(followLinks: false).toList();
      } catch (_) {
        continue;
      }
      for (final file in files.whereType<File>()) {
        final fileName = file.uri.pathSegments.last;
        final match = RegExp(r'^__sync_maps__(\d+)$').firstMatch(fileName);
        final projectNumber = match?.group(1);
        if (projectNumber == null || retained.contains(projectNumber)) {
          continue;
        }
        try {
          await file.delete();
          removed.add(projectNumber);
        } catch (_) {}
      }
      continue;
    }

    final scopedProjectNumber = _projectNumberFromScopedValue(name);
    if (scopedProjectNumber != null) {
      if (!retained.contains(scopedProjectNumber)) {
        try {
          await entity.delete(recursive: true);
          removed.add(scopedProjectNumber);
        } catch (_) {}
      }
      // A numeric scope belongs to exactly one project. If that project is
      // retained, avoid opening and JSON-decoding every cached photo.
      continue;
    }

    await _deleteInactiveRecords(entity, retained, removed);
    try {
      if (name.startsWith('__loc__') &&
          await entity.exists() &&
          await entity.list(followLinks: false).isEmpty) {
        await entity.delete();
      }
    } catch (_) {}
  }
  return removed;
}

//MARK: data-stuff

final db = Localstore.instance;

const IMAGE_INDEX_COLLECTION = 'image-index';
final imageIndexCollection = (db).collection(IMAGE_INDEX_COLLECTION);

Future<void> _ensureCollectionDirExists(String collection) async {
  if (kIsWeb) return;
  try {
    final basePath = await localPath;
    final dir = Directory('$basePath/$collection');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  } catch (_) {}
}

String _imageIndexDocId(
  String hash, {
  String? scope,
}) {
  final s = (scope ?? '').trim();
  final key = '$s|$hash';
  // Localstore doc ids are path-like; keep it filesystem-safe and reasonably short.
  return base64UrlEncode(utf8.encode(key)).replaceAll('=', '');
}

Future<void> indexImageHash({
  required String hash,
  required String storedName,
  String? scope,
}) async {
  try {
    await _ensureCollectionDirExists(IMAGE_INDEX_COLLECTION);

    final payload = {
      'hash': hash,
      'storedName': storedName,
      'scope': scope ?? '',
      'ts': DateTime.now().millisecondsSinceEpoch,
    };

    // scoped entry
    final id = _imageIndexDocId(hash, scope: scope);
    await imageIndexCollection.doc(id).set(payload);

    // global entry (scope-agnostic fallback)
    final globalId = _imageIndexDocId(hash, scope: '');
    await imageIndexCollection.doc(globalId).set({
      ...payload,
      'scope': '',
    });
  } catch (e) {
    debugPrint('indexImageHash failed: $e');
  }
}

Future<String?> lookupImageNameForHash(
  String hash, {
  String? scope,
}) async {
  try {
    await _ensureCollectionDirExists(IMAGE_INDEX_COLLECTION);
  } catch (_) {}

  Future<String?> tryScope(String? s) async {
    final scopedId = _imageIndexDocId(hash, scope: s);
    final scoped = await imageIndexCollection.doc(scopedId).get();
    final scopedName = scoped?['storedName']?.toString();
    if (scopedName != null && scopedName.isNotEmpty) return scopedName;
    return null;
  }

  final s = _canonicalizeScope((scope ?? '').trim());
  final direct = await tryScope(s);
  if (direct != null) return direct;

  // legacy lookup for old "null" folders
  final legacyScope = _legacyScopeForCanonical(s);
  if (legacyScope != s) {
    final legacy = await tryScope(legacyScope);
    if (legacy != null) return legacy;
  }

  // fallback: global entry (no scope)
  final globalId = _imageIndexDocId(hash, scope: '');
  final global = await imageIndexCollection.doc(globalId).get();
  final globalName = global?['storedName']?.toString();
  if (globalName != null && globalName.isNotEmpty) return globalName;

  return null;
}

String _normalizeStoredNameForMatch(String name) {
  return _canonicalizeScopedName(name).replaceAll('\\', '/').trim();
}

String _basenameOfStoredName(String name) {
  final normalized = _normalizeStoredNameForMatch(name);
  if (normalized.isEmpty) return normalized;
  final parts = normalized.split('/').where((e) => e.isNotEmpty).toList();
  return parts.isEmpty ? normalized : parts.last;
}

/// Finds a backend hash for a cached stored image name (best-effort).
Future<String?> lookupHashForImageName(
  String storedName, {
  String? scope,
}) async {
  try {
    await _ensureCollectionDirExists(IMAGE_INDEX_COLLECTION);
  } catch (_) {}

  final wanted = _normalizeStoredNameForMatch(storedName);
  if (wanted.isEmpty) return null;
  final wantedBase = _basenameOfStoredName(wanted);
  final wantedScope = _canonicalizeScope((scope ?? '').trim());
  final legacyScope = _legacyScopeForCanonical(wantedScope);

  final docs = await imageIndexCollection.get();
  if (docs == null || docs.isEmpty) return null;

  int scopeRank(String docScopeRaw) {
    final docScope = _canonicalizeScope(docScopeRaw.trim());
    if (wantedScope.isEmpty) {
      return docScope.isEmpty ? 0 : 1;
    }
    if (docScope == wantedScope) return 0;
    if (legacyScope != wantedScope && docScope == legacyScope) return 1;
    if (docScope.isEmpty) return 2;
    return 3;
  }

  String? bestHash;
  int? bestScore;

  for (final entry in docs.entries) {
    final raw = entry.value;
    if (raw is! Map) continue;
    final map = Map<String, dynamic>.from(raw);
    final hash = map['hash']?.toString().trim();
    final indexedName = map['storedName']?.toString().trim();
    if (hash == null ||
        hash.isEmpty ||
        indexedName == null ||
        indexedName.isEmpty) {
      continue;
    }

    final normalizedIndexed = _normalizeStoredNameForMatch(indexedName);
    final exactMatch = normalizedIndexed == wanted;
    final baseMatch = _basenameOfStoredName(normalizedIndexed) == wantedBase;
    if (!exactMatch && !baseMatch) continue;

    final rank = scopeRank(map['scope']?.toString() ?? '');
    if (rank >= 3) continue;

    final matchRank = exactMatch ? 0 : 1;
    final score = rank * 10 + matchRank;
    if (bestScore == null || score < bestScore) {
      bestScore = score;
      bestHash = hash;
    }
  }

  return bestHash;
}

Future<void> unindexImageHash({
  required String hash,
  String? scope,
}) async {
  final h = hash.trim();
  if (h.isEmpty) return;

  try {
    await _ensureCollectionDirExists(IMAGE_INDEX_COLLECTION);
  } catch (_) {}

  final s = _canonicalizeScope((scope ?? '').trim());
  final legacyScope = _legacyScopeForCanonical(s);
  final scopes = <String>{'', s};
  if (legacyScope != s) scopes.add(legacyScope);

  for (final scopeCandidate in scopes) {
    try {
      final id = _imageIndexDocId(h, scope: scopeCandidate);
      await imageIndexCollection.doc(id).delete();
    } catch (_) {}
  }
}

/// @depricated, its now only the parentID
/// ~~non-null wrapper for [Helper.getIdentifierFromData]~~
/// ~~a collection is always named via the scheme `${DataT}-${ParentId}`~~
String _getCollectionNameForData<DataT extends Data>(String parentId) {
  return parentId;
  // final dataName = Helper.getIdentifierFromData<DataT>(null);
  // if (dataName == null) throw Exception('could not get collection $dataName');
  // return dataName + '-' + parentId;
}

enum OverrideMode { abortIfExistent, update, createNew }

/// permanently stores a DataT in its corresponding collection
Future<String> storeData<DataT extends Data>(
  DataT data, {
  required String forId,
  bool addId = true,
  OverrideMode overrideMode = OverrideMode.update,
}) async {
  final collectionName = _getCollectionNameForData<DataT>(forId);

  var json = data.toJson();
  String? oldId = data.id;

  // A localstore collection directory can also contain inspection photos.
  // Loading the complete collection here used to read/decode every photo just
  // to check whether one JSON document exists.
  final basePath = await localPath;
  final isExistent = File('$basePath/$collectionName/$oldId').existsSync();
  if (overrideMode == OverrideMode.abortIfExistent && isExistent) {
    debugPrint('wont override $oldId');
    return '';
  }

  //create a new document with new id if wanted
  final id = (!isExistent || overrideMode == OverrideMode.update)
      ? oldId
      : db.collection(collectionName).doc().id;

  if (addId) json['local_id'] = id;
  db.collection(collectionName).doc(id).set(json);

  return id;
}

/// retrieves a DataT via its [id] and corresponding [parentId]
Future<DataT?> retrieveData<DataT extends Data>(String id,
    {required String parentId}) async {
  final collectionName = _getCollectionNameForData<DataT>(parentId);
  final data = await db.collection(collectionName).doc(id).get();
  return Data.fromJson<DataT>(data ?? {});
}

/// deletes a DataT via its [id] and corresponding [parentId]
Future deleteData<DataT extends Data>(String id,
    {required String parentId}) async {
  final collectionName = _getCollectionNameForData<DataT>(parentId);
  final ret = await db.collection(collectionName).doc(id).delete();
  return ret;
}

/// this is probably the most used in this project
/// it returns all [Data] ([ChildData]) -points that correspond to the [ParentData] with given [id]
Future<List<ChildData?>?> getAllChildrenFrom<ChildData extends Data>(
    String id) async {
  final collectionName = _getCollectionNameForData<ChildData>(id);
  final items = await readLocalstoreCollection(collectionName);
  return items?.values
          .map((data) => Data.fromJson<ChildData>(data ?? {}))
          .toList() ??
      [];
}

const int _maxLocalstoreDocumentBytes = 4 * 1024 * 1024;

Future<Map<String, dynamic>?> _readLocalstoreDocument(File file) async {
  RandomAccessFile? handle;
  try {
    final stat = await file.stat();
    if (stat.type != FileSystemEntityType.file ||
        stat.size <= 1 ||
        stat.size > _maxLocalstoreDocumentBytes) {
      return null;
    }

    // Photos share the same directories as localstore JSON documents. Check a
    // tiny prefix before reading the complete file so JPEG/PDF payloads never
    // become large temporary Uint8Lists during normal navigation or sync.
    handle = await file.open();
    final prefix = await handle.read(stat.size.clamp(1, 64));
    final firstContentByte = prefix.cast<int?>().firstWhere(
          (byte) =>
              byte != 0x20 && byte != 0x09 && byte != 0x0a && byte != 0x0d,
          orElse: () => null,
        );
    await handle.close();
    handle = null;
    if (firstContentByte != 0x7b) return null; // JSON object starts with `{`.

    final decoded = jsonDecode(await file.readAsString());
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
  } catch (_) {
    return null;
  } finally {
    await handle?.close();
  }
  return null;
}

@visibleForTesting
Future<Map<String, Map<String, dynamic>>> readLocalstoreDocumentDirectory(
  Directory directory,
) async {
  final documents = <String, Map<String, dynamic>>{};
  if (!await directory.exists()) return documents;
  await for (final entity in directory.list(followLinks: false)) {
    if (entity is! File) continue;
    final data = await _readLocalstoreDocument(entity);
    if (data != null) {
      documents[entity.path.split(Platform.pathSeparator).last] = data;
    }
  }
  return documents;
}

/// Reads only localstore JSON documents and skips photos/PDFs that happen to
/// live in the same collection directory.
Future<Map<String, dynamic>?> readLocalstoreCollection(
  String collectionName,
) async {
  final basePath = await localPath;
  final documents = await readLocalstoreDocumentDirectory(
    Directory('$basePath/$collectionName'),
  );
  if (documents.isEmpty) return null;
  return documents.map(
    (name, data) => MapEntry('/$collectionName/$name', data),
  );
}

@visibleForTesting
Future<int> countLocalstoreDocumentDirectory(Directory directory) async {
  if (!await directory.exists()) return 0;
  var count = 0;
  await for (final entity in directory.list(followLinks: false)) {
    if (entity is File && await _readLocalstoreDocument(entity) != null) {
      count++;
    }
  }
  return count;
}

Future<int> countLocalstoreCollection(String collectionName) async {
  final basePath = await localPath;
  return countLocalstoreDocumentDirectory(
    Directory('$basePath/$collectionName'),
  );
}

const OTHERCOLLECTION = 'other';
final otherCollection = (db).collection(OTHERCOLLECTION);
storeJson(String documentName, Map<String, dynamic> json) =>
    otherCollection.doc(documentName).set(json);

Future<Map<String, dynamic>?> getJson(String documentName) =>
    otherCollection.doc(documentName).get();

String _syncMapsDocId(String pjNr) => '__sync_maps__$pjNr';

Future<({Map<String, String> localIdMap, Map<String, String> imageHashMap})>
    getSyncMaps(String pjNr) async {
  try {
    final raw = await getJson(_syncMapsDocId(pjNr));
    if (raw == null) {
      return (localIdMap: <String, String>{}, imageHashMap: <String, String>{});
    }
    Map<String, String> asStringMap(Object? v) {
      if (v is Map) {
        return v.map((k, val) => MapEntry(k.toString(), val.toString()));
      }
      return {};
    }

    return (
      localIdMap: asStringMap(raw['localIdMap']),
      imageHashMap: asStringMap(raw['imageHashMap']),
    );
  } catch (_) {
    return (localIdMap: <String, String>{}, imageHashMap: <String, String>{});
  }
}

Future<void> storeSyncMaps(
  String pjNr, {
  required Map<String, String> localIdMap,
  required Map<String, String> imageHashMap,
}) async {
  try {
    await storeJson(_syncMapsDocId(pjNr), {
      'localIdMap': localIdMap,
      'imageHashMap': imageHashMap,
      'ts': DateTime.now().millisecondsSinceEpoch,
    });
  } catch (_) {}
}

String _docIdFromKey(String key) => key.split('/').last;

({int pjNr, int? e1, int? e2, int? e3})? _parseNumericLocalId(String? localId) {
  final s = (localId ?? '').trim();
  if (s.isEmpty) return null;
  final parts = s.split('-');
  int? toInt(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty || t == 'null' || t == 'undefined') return null;
    return int.tryParse(t);
  }

  final pjNr = toInt(parts.isNotEmpty ? parts[0] : null);
  if (pjNr == null || pjNr <= 0) return null;
  return (
    pjNr: pjNr,
    e1: toInt(parts.length > 1 ? parts[1] : null),
    e2: toInt(parts.length > 2 ? parts[2] : null),
    e3: toInt(parts.length > 3 ? parts[3] : null),
  );
}

bool _missingEventValue(Object? v) {
  if (v == null) return true;
  if (v is num) return !(v > 0);
  final s = v.toString().trim();
  if (s.isEmpty || s == 'null' || s == 'undefined') return true;
  final n = int.tryParse(s);
  return n == null || n <= 0;
}

void _fillFromParsedLocalId(
  Map<String, dynamic> map,
  ({int pjNr, int? e1, int? e2, int? e3}) parsed,
) {
  if (_missingEventValue(map['PjNr'])) map['PjNr'] = parsed.pjNr;
  if (parsed.e1 != null && _missingEventValue(map['E1'])) map['E1'] = parsed.e1;
  if (parsed.e2 != null && _missingEventValue(map['E2'])) map['E2'] = parsed.e2;
  if (parsed.e3 != null && _missingEventValue(map['E3'])) map['E3'] = parsed.e3;
}

Future<void> applyLocalIdMapping({
  required String oldLocalId,
  required String newLocalId,
  String? parentLocalId,
}) async {
  if (oldLocalId == newLocalId) return;
  final parent = (parentLocalId ?? '').trim();

  try {
    // 1) Move the document itself inside its parent collection.
    if (parent.isNotEmpty) {
      final oldDoc = await db.collection(parent).doc(oldLocalId).get();
      if (oldDoc != null) {
        final map = Map<String, dynamic>.from(oldDoc);
        map['local_id'] = newLocalId;
        map['parent_local_id'] = parent;
        final parsed = _parseNumericLocalId(newLocalId);
        if (parsed != null) {
          _fillFromParsedLocalId(map, parsed);
        }
        await db.collection(parent).doc(newLocalId).set(map);
        await db.collection(parent).doc(oldLocalId).delete();
      }
    }
  } catch (_) {}

  try {
    // 2) Move the children collection (collection name == parent local_id).
    final children = await readLocalstoreCollection(oldLocalId);
    if (children != null) {
      final parsedParent = _parseNumericLocalId(newLocalId);
      for (final entry in children.entries) {
        final docId = _docIdFromKey(entry.key);
        final raw = entry.value;
        if (raw is! Map) continue;
        final map = Map<String, dynamic>.from(raw);
        map['local_id'] = docId;
        final plid = map['parent_local_id']?.toString();
        if (plid == null || plid.isEmpty || plid == oldLocalId) {
          map['parent_local_id'] = newLocalId;
        }
        if (parsedParent != null) {
          _fillFromParsedLocalId(map, parsedParent);
        }
        await db.collection(newLocalId).doc(docId).set(map);
        await db.collection(oldLocalId).doc(docId).delete();
      }
    }
  } catch (_) {}
}

const FAILEDCOLLECTION = 'failed-requests';
const SKIPPEDCOLLECTION = 'skipped-requests';
final failedReqLogCollection = (db).collection(FAILEDCOLLECTION);
final skippedReqLogCollection = (db).collection(
    SKIPPEDCOLLECTION); //bei fragen zu logik hierzu hannes fragen, war sein commit

Map<String, dynamic> _withoutStoredCredentials(Map<String, dynamic> data) {
  final sanitized = Map<String, dynamic>.from(data);
  final requestJson = sanitized['json'];
  if (requestJson is Map) {
    sanitized['json'] = Map<String, dynamic>.from(requestJson)..remove('user');
  }
  sanitized.remove('user');
  return sanitized;
}

Future<String> logFailedReq(RequestData rd) async {
  final doc = failedReqLogCollection
      .doc(DateTime.now().millisecondsSinceEpoch.toRadixString(36));

  //TO-DO: idk if this uses the baserquest to json, which it shouldnt.. yes, it did
  await doc.set(_withoutStoredCredentials(await rd.serialized));
  return doc.id;
}

///returns a List of weird structures of the id of the failed request and a tuple where exactly one is null, either a [http.Response] or an [http.MultipartRequest]
Future<List<(String, RequestData?)>?> getAllFailedRequests() async {
  final docs = (await failedReqLogCollection
      .get()); //TO-DO: das muss in-order sein, sonst könnte es probleme geben..

  if (docs == null) return null;
  final docsWithTimeStr =
      docs.map((key, value) => MapEntry(key.split('/').last, value));
  final docsWithTimeAsFutureTuples = docsWithTimeStr.entries.map((e) async {
    try {
      final sanitized = _withoutStoredCredentials(e.value);
      final requestJson = e.value['json'];
      if (requestJson is Map && requestJson.containsKey('user')) {
        await failedReqLogCollection.doc(e.key).set(sanitized);
      }
      final parsedReq = RequestData.deserialize(sanitized);
      return (e.key, parsedReq);
    } catch (err) {
      debugPrint('failed parse of request hm, $err');
    }
    return (e.key, null);
  });
  var reqs = (await Future.wait(docsWithTimeAsFutureTuples));
  reqs.sort((a, b) =>
      int.parse(a.$1, radix: 36).compareTo(int.parse(b.$1, radix: 36)));
  return reqs;
}

Future<void> failedRequestWasSuccessful(String id,
    {bool wasntTho = false}) async {
  if (wasntTho) {
    final data = await failedReqLogCollection.doc(id).get();
    if (data == null) {
      debugPrint('request $id wasnt in the failed-Log');
      return;
    }
    await skippedReqLogCollection.doc(id).set(_withoutStoredCredentials(data));
    debugPrint('request $id was skipped and moved to skipped-Log');
  }
  await failedReqLogCollection.doc(id).delete();
  debugPrint(
      'request $id was apperently successful, so we deleted it from the failed-Log');
}

/// Moves a request that can never succeed through retries out of the active
/// queue while retaining enough metadata for diagnostics and manual recovery.
Future<void> quarantineFailedRequest(
  String id, {
  required String reason,
  Map<String, dynamic> details = const {},
}) async {
  final data = await failedReqLogCollection.doc(id).get();
  if (data == null) {
    debugPrint('request $id was already absent while quarantining');
    return;
  }

  final quarantined = _withoutStoredCredentials(data)
    ..['_quarantine'] = {
      'reason': reason,
      'timestamp': DateTime.now().toIso8601String(),
      ...details,
    };
  await skippedReqLogCollection.doc(id).set(quarantined);
  await failedReqLogCollection.doc(id).delete();
  debugPrint('request $id was quarantined: $reason');
}

extension SerializableBaseRequest on http.BaseRequest {
  Map<String, dynamic> get toJson => {
        'type': 'Request',
        'url': this.url.toString(),
        'headers': this.headers,
        'method': this.method,
      };
}

extension SerializableRequest on http.Request {
  ////very unpolished version that only works for my kind of post req
  Map<String, dynamic> get toJson => {
        'type': 'Request',
        'url': this.url.toString(),
        'headers': this.headers,
        'body': this.body,
        'encoding': this.encoding,
        'method': this.method,
      };

  // static http.Request fromJson(Map<String, dynamic> json) =>
  //     requestFromJson(json) as http.Request;
}

extension SerializableMultiPartReq on http.MultipartRequest {
  ////very unpolished version that only works for my kind of post req
  Map<String, dynamic> get toJson => {
        'type': 'MultipartRequest',
        'url': this.url.toString(),
        'headers': this.headers,
        'body': this.fields,
        'file-names': this.files.map((e) => e.filename).toList(),
        'method': this.method,
      };

  // static http.MultipartRequest fromJson(Map<String, dynamic> json) =>
  //     requestFromJson(json) as http.MultipartRequest;
}

Future<String> permaStoreCachedXFile(XFile file, [String? _name]) async {
  final basePath = await localPath;
  // prefer keeping relative folder if the file already lives in our app dir
  String? relativeName;
  if (file.path.startsWith(basePath)) {
    relativeName = file.path.substring(basePath.length + 1);
  }
  final name = _name ?? relativeName ?? file.name;
  final target = await localFile(name);
  await target.parent.create(recursive: true);
  final srcAbs = File(file.path).absolute.path;
  final dstAbs = target.absolute.path;
  if (srcAbs == dstAbs && target.existsSync() && target.lengthSync() >= 5) {
    return name;
  }
  await file.saveTo(target.path);
  debugPrint('Persisted cached file to ${target.path}');
  return name;
}

/// Deletes an image-picker/camera source after its permanent copy is known to
/// exist. Files outside the app cache are intentionally never touched.
Future<void> deleteCachedSource(XFile file) async {
  try {
    final cachePath = (await getTemporaryDirectory()).absolute.path;
    final source = File(file.path).absolute;
    if (source.path.startsWith('$cachePath${Platform.pathSeparator}') &&
        await source.exists()) {
      await source.delete();
    }
  } catch (_) {}
}

Future<XFile> retrieveStoredXFile(String name) async {
  return XFile((await localFile(name)).path);
}
