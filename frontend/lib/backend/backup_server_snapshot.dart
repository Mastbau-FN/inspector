import 'package:MBG_Inspektionen/backend/api.dart';
import 'package:MBG_Inspektionen/backend/backup_restore.dart';
import 'package:MBG_Inspektionen/classes/data/checkcategory.dart';
import 'package:MBG_Inspektionen/classes/data/checkpoint.dart';
import 'package:MBG_Inspektionen/classes/data/checkpointdefect.dart';
import 'package:MBG_Inspektionen/classes/data/inspection_location.dart';
import 'package:MBG_Inspektionen/classes/dropdownClasses.dart';
import 'package:MBG_Inspektionen/options.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

typedef BackupServerSnapshotProgress = void Function(String status);

/// Loads an uncached, authoritative tree for every selected inspection.
/// Server photos are hashed by content as well.  This costs an extra download
/// in rescue mode, but is what lets an old local filename be recognized after
/// the backend has replaced it with an opaque image hash.
Future<List<BackupServerInspectionSnapshot>>
    fetchBackupServerInspectionSnapshots(
  List<BackupInspectionPreview> inspections, {
  BackupServerSnapshotProgress? onProgress,
}) async {
  if (inspections.isEmpty) return const [];
  onProgress?.call('Aktuelle Inspektionen werden vom Server geladen …');
  final locations =
      await _fetchRemoteChildren<InspectionLocation, WithOffline?>(null);
  final snapshots = <BackupServerInspectionSnapshot>[];

  for (var inspectionIndex = 0;
      inspectionIndex < inspections.length;
      inspectionIndex++) {
    final wanted = inspections[inspectionIndex];
    final matchingLocations = locations.where((location) {
      final sameProject =
          location.pjNr.toString() == wanted.projectNumber.trim();
      final sameLocation = wanted.locationNumber.trim().isEmpty ||
          location.stONr.toString() == wanted.locationNumber.trim();
      return sameProject && sameLocation;
    }).toList(growable: false);
    if (matchingLocations.length != 1) {
      throw BackupRestoreException(
        matchingLocations.isEmpty
            ? 'Projekt ${wanted.projectNumber} ist im aktuellen Serverstand nicht vorhanden.'
            : 'Projekt ${wanted.projectNumber} konnte auf dem Server nicht eindeutig zugeordnet werden.',
      );
    }

    final location = matchingLocations.single;
    onProgress?.call(
      'Serverabgleich ${inspectionIndex + 1}/${inspections.length}: '
      'Projekt ${wanted.projectNumber} …',
    );
    final categories =
        await _fetchRemoteChildren<CheckCategory, InspectionLocation>(location);
    final checkpoints = <CheckPoint>[];
    final defects = <CheckPointDefect>[];
    for (final category in categories) {
      final children =
          await _fetchRemoteChildren<CheckPoint, CheckCategory>(category);
      checkpoints.addAll(children);
      for (final checkpoint in children) {
        defects.addAll(
          await _fetchRemoteChildren<CheckPointDefect, CheckPoint>(checkpoint),
        );
      }
    }

    final locationJson = location.toJson();
    final categoryJson = categories.map((category) {
      return category.toJson()..['parent_local_id'] = location.id;
    }).toList(growable: false);
    final checkpointJson = checkpoints.map((checkpoint) {
      final parent = categories.where((category) {
        return category.pjNr == checkpoint.pjNr &&
            category.index == checkpoint.category_index;
      }).toList(growable: false);
      if (parent.length != 1) {
        throw BackupRestoreException(
          'Der Server lieferte für Projekt ${wanted.projectNumber} eine '
          'uneindeutige Kategorie-Struktur.',
        );
      }
      return checkpoint.toJson()..['parent_local_id'] = parent.single.id;
    }).toList(growable: false);
    final defectJson = defects.map((defect) {
      final parent = checkpoints.where((checkpoint) {
        return checkpoint.pjNr == defect.pjNr &&
            checkpoint.category_index == defect.category_index &&
            checkpoint.index == defect.check_index;
      }).toList(growable: false);
      if (parent.length != 1) {
        throw BackupRestoreException(
          'Der Server lieferte für Projekt ${wanted.projectNumber} eine '
          'uneindeutige Prüfpunkt-Struktur.',
        );
      }
      return defect.toJson()..['parent_local_id'] = parent.single.id;
    }).toList(growable: false);

    final imageHashes = <String>{};
    for (final data in <Data>[
      location,
      ...categories,
      ...checkpoints,
      ...defects,
    ]) {
      final main = data.mainhash?.trim();
      if (main != null &&
          main.isNotEmpty &&
          main != Options().no_image_placeholder_name &&
          !main.contains('/')) {
        imageHashes.add(main);
      }
      for (final image in data.imagehashes ?? const <String>[]) {
        final hash = image.trim();
        if (hash.isNotEmpty &&
            hash != Options().no_image_placeholder_name &&
            !hash.contains('/')) {
          imageHashes.add(hash);
        }
      }
    }
    final imageContentHashes = <String, String>{};
    var imageIndex = 0;
    for (final hash in imageHashes) {
      imageIndex++;
      onProgress?.call(
        'Projekt ${wanted.projectNumber}: Serverfotos werden verglichen '
        '($imageIndex/${imageHashes.length}) …',
      );
      final bytes = await _fetchRemoteImage(hash);
      imageContentHashes[hash] = sha256.convert(bytes).toString();
    }

    snapshots.add(
      BackupServerInspectionSnapshot(
        selectionId: wanted.selectionId,
        location: locationJson,
        categories: categoryJson,
        checkpoints: checkpointJson,
        defects: defectJson,
        imageContentHashes: imageContentHashes,
      ),
    );
  }
  return snapshots;
}

Future<List<ChildData>> _fetchRemoteChildren<ChildData extends Data,
    ParentData extends WithOffline?>(ParentData parent) async {
  final request = API().remote.getNextDatapoint<ChildData, ParentData>(parent);
  final response = await API().remote.postJSON(request.rd);
  final buffered = await _asResponse(response);
  if (buffered == null || buffered.statusCode ~/ 100 != 2) {
    throw BackupRestoreException(
      'Der aktuelle Serverstand konnte nicht vollständig geladen werden '
      '(HTTP ${buffered?.statusCode ?? response?.statusCode ?? 'ohne Antwort'}).',
    );
  }
  try {
    return await request.parser(buffered);
  } catch (error) {
    throw BackupRestoreException(
      'Der aktuelle Serverstand konnte nicht ausgewertet werden: $error',
    );
  }
}

Future<List<int>> _fetchRemoteImage(String hash) async {
  final request = API().remote.getImageByHash(hash);
  final response = await API().remote.postJSON(request.rd);
  if (response == null || response.statusCode ~/ 100 != 2) {
    throw BackupRestoreException(
      'Ein Serverfoto konnte für den sicheren Dublettenabgleich nicht '
      'geladen werden (HTTP ${response?.statusCode ?? 'ohne Antwort'}).',
    );
  }
  if (response is http.Response) return response.bodyBytes;
  if (response is http.StreamedResponse) return response.stream.toBytes();
  throw const BackupRestoreException(
    'Ein Serverfoto hatte ein unbekanntes Antwortformat.',
  );
}

Future<http.Response?> _asResponse(http.BaseResponse? response) async {
  if (response is http.Response) return response;
  if (response is http.StreamedResponse) {
    return http.Response.fromStream(response);
  }
  return null;
}
