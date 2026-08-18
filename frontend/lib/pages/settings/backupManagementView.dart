import 'dart:io';

import 'package:MBG_Inspektionen/backend/api.dart';
import 'package:MBG_Inspektionen/backend/backup_restore.dart';
import 'package:MBG_Inspektionen/backend/backup_server_snapshot.dart';
import 'package:MBG_Inspektionen/backend/offlineProvider.dart' show localPath;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:MBG_Inspektionen/backend/incremental_backup.dart';
import 'package:MBG_Inspektionen/helpers/toast.dart';

enum _BackupImportMode { normal, v270Rescue }

class BackupManagementView extends StatefulWidget {
  const BackupManagementView({Key? key}) : super(key: key);

  @override
  State<BackupManagementView> createState() => _BackupManagementViewState();
}

class _BackupManagementViewState extends State<BackupManagementView> {
  List<FileSystemEntity> backups = [];
  bool isLoading = true;
  bool isRestoring = false;
  String? restoreStatus;

  @override
  void initState() {
    super.initState();
    _loadBackups();
  }

  Future<void> _loadBackups() async {
    final externalDir = await getExternalStorageDirectory();
    if (externalDir == null) {
      if (mounted) {
        setState(() {
          backups = [];
          isLoading = false;
        });
      }
      return;
    }

    final backupDir = Directory('${externalDir.parent.path}/MBGBackups');
    final files = await listManagedLocalBackups(backupDir);
    if (mounted) {
      setState(() {
        backups = files;
        isLoading = false;
      });
    }
  }

  Future<void> _deleteBackup(File backup) async {
    if (BackupCoordinator.instance.isRunning) {
      showToast('Backup kann während der Erstellung nicht gelöscht werden');
      return;
    }

    try {
      final backupDirectory = backup.parent;
      await backup.delete();
      await invalidateIncrementalBackupState(backupDirectory);
      showToast('Backup gelöscht');
      _loadBackups();
    } catch (e) {
      showToast('Fehler beim Löschen des Backups');
    }
  }

  Future<void> _shareBackup(File backup) async {
    try {
      await Share.shareXFiles(
        [XFile(backup.path)],
        text: 'Backup von MBG Inspektionen',
        subject: 'Backup von MBG Inspektionen',
      );
    } catch (e) {
      showToast('Fehler beim Teilen des Backups');
    }
  }

  Future<void> _restoreBackup() async {
    if (isRestoring) return;
    if (BackupCoordinator.instance.isRunning) {
      showToast('Wiederherstellung ist während eines Backups nicht möglich');
      return;
    }

    try {
      // Android's document picker copies every selected file into the app
      // cache, even when withData is false. Remove copies left by an aborted
      // multi-gigabyte import before creating another one.
      await _clearTemporaryImportFiles();
      final selection = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['zip'],
        allowMultiple: true,
        withData: false,
      );
      if (selection == null || selection.files.isEmpty) return;

      final selectedFiles = <File>[];
      for (final selected in selection.files) {
        final path = selected.path;
        if (path == null || path.isEmpty) {
          throw const BackupRestoreException(
            'Eine ausgewählte ZIP konnte nicht vom Gerät gelesen werden.',
          );
        }
        selectedFiles.add(File(path));
      }

      if (mounted) {
        setState(() {
          isRestoring = true;
          restoreStatus = 'Backup-Kette wird geprüft …';
        });
      }
      final targetDirectory = Directory(await localPath);
      final targetRootId = await API().rootID;
      final preview = await inspectIncrementalBackupChain(
        selectedFiles,
        currentDataDirectory: targetDirectory,
        currentRootId: targetRootId,
      );
      if (!mounted) return;

      if (preview.inspections.isEmpty) {
        throw const BackupRestoreException(
          'In diesem Backup wurden keine importierbaren Inspektionen gefunden.',
        );
      }
      final importMode = await _selectImportMode(preview);
      if (importMode == null) return;
      final selectedInspectionIds = await _selectInspections(
        preview,
        mode: importMode,
      );
      if (selectedInspectionIds == null || selectedInspectionIds.isEmpty) {
        return;
      }

      if (importMode == _BackupImportMode.v270Rescue) {
        final selectedPreviews = preview.inspections
            .where((inspection) =>
                selectedInspectionIds.contains(inspection.selectionId))
            .toList(growable: false);
        if (mounted) {
          setState(() {
            restoreStatus = 'Aktueller Serverstand wird geladen …';
          });
        }
        final snapshots = await fetchBackupServerInspectionSnapshots(
          selectedPreviews,
          onProgress: (status) {
            if (mounted) setState(() => restoreStatus = status);
          },
        );
        if (mounted) {
          setState(() {
            restoreStatus = 'Fehlende Upload-Aufträge werden rekonstruiert …';
          });
        }
        final result = await recoverInspectionsFromIncrementalBackupChain(
          backupFiles: selectedFiles,
          selectedInspectionIds: selectedInspectionIds,
          serverSnapshots: snapshots,
          targetDirectory: targetDirectory,
          targetRootId: targetRootId,
        );
        if (!mounted) return;
        final uncertain = result.skippedUncertainRecordCount == 0
            ? ''
            : ' ${result.skippedUncertainRecordCount} nicht eindeutig '
                'zuordenbare, früher vorhandene Datensätze wurden aus '
                'Sicherheitsgründen nicht neu angelegt.';
        await _showRestoreSuccess(
          '${result.importedInspectionCount} Inspektion(en) wurden mit dem '
          'Server abgeglichen. ${result.reconstructedRequestCount} fehlende '
          'Upload-Aufträge wurden rekonstruiert; '
          '${result.alreadySynchronizedRecordCount} Datensätze und '
          '${result.alreadySynchronizedImageCount} Fotos waren bereits '
          'synchronisiert und wurden nicht erneut eingeplant.$uncertain',
        );
      } else {
        if (mounted) {
          setState(() {
            restoreStatus = 'Ausgewählte Inspektionen werden importiert …';
          });
        }
        final result = await importInspectionsFromIncrementalBackupChain(
          backupFiles: selectedFiles,
          selectedInspectionIds: selectedInspectionIds,
          targetDirectory: targetDirectory,
          targetRootId: targetRootId,
        );
        if (!mounted) return;
        await _showRestoreSuccess(
          '${result.importedInspectionCount} Inspektion(en) und '
          '${result.importedFailedRequestCount} ausstehende Upload-Aufträge '
          'wurden aus ${result.appliedBackupCount} Backup-ZIP(s) importiert.',
        );
      }
    } on BackupRestoreException catch (error) {
      if (mounted) await _showRestoreError(error.message);
    } catch (error) {
      if (mounted) {
        await _showRestoreError(
          'Die Wiederherstellung ist fehlgeschlagen: $error',
        );
      }
    } finally {
      await _clearTemporaryImportFiles();
      if (mounted) {
        setState(() {
          isRestoring = false;
          restoreStatus = null;
        });
      }
    }
  }

  Future<void> _clearTemporaryImportFiles() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    try {
      await FilePicker.clearTemporaryFiles();
    } catch (_) {
      // Cache cleanup must not hide the actual import result. Mobile systems
      // may also remove these temporary files independently.
    }
  }

  Future<_BackupImportMode?> _selectImportMode(
    BackupRestorePreview preview,
  ) async {
    var selected = preview.containsFailedRequests
        ? _BackupImportMode.normal
        : _BackupImportMode.v270Rescue;
    return showDialog<_BackupImportMode>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Importart auswählen'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  selected: selected == _BackupImportMode.normal,
                  leading: Icon(
                    selected == _BackupImportMode.normal
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                  ),
                  onTap: () => setDialogState(
                    () => selected = _BackupImportMode.normal,
                  ),
                  title: const Text('Normaler Import'),
                  subtitle: Text(
                    preview.containsFailedRequests
                        ? 'Übernimmt die in der ZIP enthaltenen Failed Requests.'
                        : 'Importiert nur die Daten. Diese ZIP enthält keine '
                            'Failed Requests.',
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  selected: selected == _BackupImportMode.v270Rescue,
                  leading: Icon(
                    selected == _BackupImportMode.v270Rescue
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                  ),
                  onTap: () => setDialogState(
                    () => selected = _BackupImportMode.v270Rescue,
                  ),
                  title: const Text('v270-Rettung mit Serverabgleich'),
                  subtitle: const Text(
                    'Rekonstruiert fehlende Erstellen-, Aktualisieren- und '
                    'Foto-Uploads aus den lokalen Daten. Bereits auf dem '
                    'Server vorhandene Inhalte werden übersprungen.',
                  ),
                ),
                if (selected == _BackupImportMode.v270Rescue) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Wichtig: Gelöschte Datensätze lassen sich ohne die alte '
                    'Queue nicht erkennen. Abweichende lokale Daten gelten als '
                    'gewünschter Backup-Stand und können neuere Serveränderungen '
                    'überschreiben. Der Abgleich benötigt eine stabile '
                    'Internetverbindung und lädt Serverfotos zum Vergleich.',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(selected),
              child: const Text('Weiter'),
            ),
          ],
        ),
      ),
    );
  }

  Future<Set<String>?> _selectInspections(
    BackupRestorePreview preview, {
    required _BackupImportMode mode,
  }) async {
    final rescueMode = mode == _BackupImportMode.v270Rescue;
    final selected = preview.inspections
        .where((inspection) => rescueMode || !inspection.alreadyOnDevice)
        .map((inspection) => inspection.selectionId)
        .toSet();

    return showDialog<Set<String>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final importableCount = preview.inspections
              .where((inspection) => rescueMode || !inspection.alreadyOnDevice)
              .length;
          return AlertDialog(
            title: const Text('Inspektionen auswählen'),
            content: SizedBox(
              width: double.maxFinite,
              height: MediaQuery.sizeOf(context).height * 0.65,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      'Backup-Stand: ${_formatDate(preview.createdAt.toLocal())}'),
                  const SizedBox(height: 8),
                  Text(
                    rescueMode
                        ? 'Für jede ausgewählte Inspektion wird der aktuelle '
                            'Serverstand geprüft. Bereits synchronisierte '
                            'Datensätze und Fotos werden nicht erneut '
                            'eingeplant.'
                        : 'Nur ausgewählte Inspektionen werden ergänzt. '
                            'Bereits auf diesem Gerät vorhandene Projekte sind '
                            'gesperrt; dadurch werden deren alte Upload-Aufträge '
                            'nicht erneut ausgeführt.',
                  ),
                  if (!rescueMode && !preview.containsFailedRequests) ...[
                    const SizedBox(height: 10),
                    const Text(
                      'Die ausgewählten ZIPs enthalten keine Failed Requests. '
                      'Die Inspektionsdaten können importiert werden, alte '
                      'Upload-Aufträge jedoch nicht.',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                  if (preview.ignoredBackupCount > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${preview.ignoredBackupCount} nicht zur neuesten '
                      'Backup-Kette gehörende ZIP-Datei(en) werden ignoriert.',
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      TextButton(
                        onPressed: importableCount == 0
                            ? null
                            : () => setDialogState(() {
                                  selected
                                    ..clear()
                                    ..addAll(
                                      preview.inspections
                                          .where((inspection) =>
                                              rescueMode ||
                                              !inspection.alreadyOnDevice)
                                          .map((inspection) =>
                                              inspection.selectionId),
                                    );
                                }),
                        child: const Text('Alle auswählen'),
                      ),
                      TextButton(
                        onPressed: selected.isEmpty
                            ? null
                            : () => setDialogState(selected.clear),
                        child: const Text('Alle abwählen'),
                      ),
                    ],
                  ),
                  Expanded(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: preview.inspections.length,
                      itemBuilder: (context, index) {
                        final inspection = preview.inspections[index];
                        final location = inspection.locationNumber.isEmpty
                            ? ''
                            : ' · Standort ${inspection.locationNumber}';
                        final requestLabel = inspection.failedRequestCount == 1
                            ? '1 Upload-Auftrag'
                            : '${inspection.failedRequestCount} Upload-Aufträge';
                        return CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          value: selected.contains(inspection.selectionId),
                          onChanged: inspection.alreadyOnDevice && !rescueMode
                              ? null
                              : (checked) => setDialogState(() {
                                    if (checked == true) {
                                      selected.add(inspection.selectionId);
                                    } else {
                                      selected.remove(inspection.selectionId);
                                    }
                                  }),
                          title: Text(inspection.name),
                          subtitle: Text(
                            inspection.alreadyOnDevice && !rescueMode
                                ? 'Projekt ${inspection.projectNumber}$location · '
                                    'bereits vorhanden – wird nicht importiert'
                                : 'Projekt ${inspection.projectNumber}$location · '
                                    '${rescueMode ? 'Serverabgleich' : requestLabel} · '
                                    '${_formatFileSize(inspection.totalBytes)}',
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Nach dem Import muss die App geschlossen und neu geöffnet '
                    'werden.',
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Abbrechen'),
              ),
              FilledButton(
                onPressed: selected.isEmpty
                    ? null
                    : () => Navigator.of(dialogContext).pop(Set.of(selected)),
                child: Text('Importieren (${selected.length})'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showRestoreSuccess(String message) => showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Wiederherstellung abgeschlossen'),
          content: Text('$message Die App wird jetzt geschlossen.'),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                SystemNavigator.pop(animated: true);
              },
              child: const Text('App schließen'),
            ),
          ],
        ),
      );

  Future<void> _showRestoreError(String message) => showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Backup nicht wiederhergestellt'),
          content: SingleChildScrollView(child: Text(message)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatDate(DateTime date) {
    return '${date.day}.${date.month}.${date.year} ${date.hour}:${date.minute}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backups verwalten'),
      ),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.fromLTRB(8, 8, 8, 4),
            child: ListTile(
              leading: const Icon(Icons.restore),
              title: const Text('Inspektionen aus Backup importieren'),
              subtitle: Text(
                restoreStatus ??
                    'Alle ZIP-Dateien einer inkrementellen Kette auswählen',
              ),
              trailing: isRestoring
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    )
                  : const Icon(Icons.file_open),
              onTap: isRestoring ? null : _restoreBackup,
            ),
          ),
          if (isRestoring) const LinearProgressIndicator(),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : backups.isEmpty
                    ? const Center(
                        child: Text('Keine lokalen Backups vorhanden'))
                    : ListView.builder(
                        itemCount: backups.length,
                        itemBuilder: (context, index) {
                          final backup = backups[index] as File;
                          final stats = backup.statSync();
                          final size = _formatFileSize(stats.size);
                          final date = _formatDate(stats.modified);

                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            child: ListTile(
                              title: Text('Backup vom $date'),
                              subtitle: Text('Inkrementell · Größe: $size'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.share),
                                    onPressed: isRestoring
                                        ? null
                                        : () => _shareBackup(backup),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete),
                                    onPressed: isRestoring
                                        ? null
                                        : () => _deleteBackup(backup),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
