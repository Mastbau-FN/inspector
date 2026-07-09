import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:MBG_Inspektionen/backend/incremental_backup.dart';
import 'package:MBG_Inspektionen/helpers/toast.dart';

class BackupManagementView extends StatefulWidget {
  const BackupManagementView({Key? key}) : super(key: key);

  @override
  State<BackupManagementView> createState() => _BackupManagementViewState();
}

class _BackupManagementViewState extends State<BackupManagementView> {
  List<FileSystemEntity> backups = [];
  bool isLoading = true;

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
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : backups.isEmpty
              ? const Center(child: Text('Keine Backups vorhanden'))
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
                              onPressed: () => _shareBackup(backup),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => _deleteBackup(backup),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
