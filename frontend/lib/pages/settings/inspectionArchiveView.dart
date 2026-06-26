import 'dart:async';

import 'package:MBG_Inspektionen/backend/api.dart';
import 'package:MBG_Inspektionen/backend/failedRequestManager.dart'
    show deleteInspectionFromDevice;
import 'package:MBG_Inspektionen/backend/inspection_visibility.dart';
import 'package:MBG_Inspektionen/backend/sync_events.dart';
import 'package:MBG_Inspektionen/classes/data/inspection_location.dart';
import 'package:MBG_Inspektionen/classes/dropdownClasses.dart';
import 'package:MBG_Inspektionen/helpers/toast.dart';
import 'package:flutter/material.dart';

class InspectionArchiveView extends StatefulWidget {
  const InspectionArchiveView({super.key});

  @override
  State<InspectionArchiveView> createState() => _InspectionArchiveViewState();
}

class _InspectionArchiveViewState extends State<InspectionArchiveView> {
  final _visibility = InspectionVisibility();

  bool _loading = true;
  bool _working = false;
  List<InspectionLocation> _localInspections = [];
  Map<String, HiddenInspectionEntry> _hiddenInspections = {};

  @override
  void initState() {
    super.initState();
    unawaited(_loadData());
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
    });

    try {
      final local = await API()
          .local
          .getNextDatapoint<InspectionLocation, WithOffline?>(null);
      final hidden = await _visibility.getHiddenInspections();

      local.sort((a, b) => a.pjNr.compareTo(b.pjNr));

      if (!mounted) return;
      setState(() {
        _localInspections = local;
        _hiddenInspections = hidden;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
      showToast('Konnte Inspektionen nicht laden: $e');
    }
  }

  Future<void> _hideInspection(InspectionLocation inspection) async {
    if (_working) return;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Inspektion auf Handy löschen'),
        content: Text(
          'Die Inspektion ${inspection.pjNr} wird lokal gelöscht, ausgeblendet und bis zur Wiederherstellung nicht mehr vom Server aktualisiert.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Löschen'),
          ),
        ],
      ),
    );
    if (accepted != true) return;

    setState(() {
      _working = true;
    });
    try {
      await _visibility.hideInspection(inspection);
      await deleteInspectionFromDevice(inspection);
      await _visibility
          .removeFailedRequestsForInspection(inspection.pjNr.toString());
      SyncEvents.instance.notifyLocalDataChanged();
      showToast(
          'Inspektion ${inspection.pjNr} lokal gelöscht und ausgeblendet');
      await _loadData();
    } catch (e) {
      showToast('Löschen fehlgeschlagen: $e');
    } finally {
      if (mounted) {
        setState(() {
          _working = false;
        });
      }
    }
  }

  Future<void> _restoreInspection(HiddenInspectionEntry entry) async {
    if (_working) return;
    setState(() {
      _working = true;
    });
    try {
      await _visibility.restoreInspection(entry.pjNr);
      SyncEvents.instance.notifyLocalDataChanged();
      showToast(
          'Inspektion ${entry.pjNr} wiederhergestellt und wieder sichtbar');
      await _loadData();
    } catch (e) {
      showToast('Wiederherstellung fehlgeschlagen: $e');
    } finally {
      if (mounted) {
        setState(() {
          _working = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hiddenEntries = _hiddenInspections.values.toList()
      ..sort((a, b) => b.hiddenAtMs.compareTo(a.hiddenAtMs));
    final activeInspections = _localInspections
        .where((inspection) =>
            !_hiddenInspections.containsKey(inspection.pjNr.toString()))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Inspektionen auf Handy'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Text(
                  'Hier gelöschte Inspektionen werden lokal nicht mehr angezeigt und erhalten keine Server-Updates, bis sie wiederhergestellt werden.',
                ),
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Aktive Inspektionen',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (_loading)
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (activeInspections.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text('Keine lokalen Inspektionen vorhanden'),
              )
            else
              ...activeInspections.map((inspection) => Card(
                    child: ListTile(
                      title: Text('PJNr ${inspection.pjNr}'),
                      subtitle: Text(inspection.pjName ?? inspection.title),
                      trailing: IconButton(
                        onPressed:
                            _working ? null : () => _hideInspection(inspection),
                        icon: Icon(Icons.delete_forever),
                      ),
                    ),
                  )),
            SizedBox(height: 16),
            Text(
              'Gelöschte Inspektionen',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (_loading)
              SizedBox.shrink()
            else if (hiddenEntries.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text('Keine gelöschten Inspektionen'),
              )
            else
              ...hiddenEntries.map((entry) => Card(
                    child: ListTile(
                      title: Text('PJNr ${entry.pjNr}'),
                      subtitle: Text(entry.title ?? 'Inspektion ${entry.pjNr}'),
                      trailing: TextButton.icon(
                        onPressed:
                            _working ? null : () => _restoreInspection(entry),
                        icon: Icon(Icons.restore),
                        label: Text('Wiederherstellen'),
                      ),
                    ),
                  )),
            SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
