// ignore_for_file: non_constant_identifier_names

import 'package:MBG_Inspektionen/backend/api.dart';
import 'package:MBG_Inspektionen/backend/download_progress.dart';
import 'package:MBG_Inspektionen/backend/failedRequestManager.dart';
import 'package:MBG_Inspektionen/classes/documentData.dart';
import 'package:MBG_Inspektionen/pages/checkcategories.dart';
import 'package:flutter/material.dart';
import 'package:MBG_Inspektionen/classes/dropdownClasses.dart';
import 'package:json_annotation/json_annotation.dart';
import "package:latlong2/latlong.dart";

import 'weather.dart';

part 'inspection_location.g.dart';

String inspectionDownloadKey(InspectionLocation inspection) =>
    'inspection:${inspection.pjNr}:${inspection.stONr}';

/// stores all the data needed for a specific location in a type-safe way

@JsonSerializable()
class InspectionLocation extends Data
    with WithImgHashes, WithLangText, WithOffline {
  @JsonKey(name: 'PjNr')
  final int pjNr;
  @JsonKey(name: 'PjName')
  final String? pjName;
  @JsonKey(name: 'PjInfo')
  final String? pjInfo;
  @JsonKey(name: 'Bauleitung')
  final String? bauleitung;
  @JsonKey(name: 'StONr')
  final int stONr;
  @JsonKey(name: 'Straße')
  final String? strasse;
  @JsonKey(name: 'PLZ')
  final String? plz;
  @JsonKey(name: 'Ort')
  final String? ort;
  @JsonKey(name: "User")
  String? user;
  @JsonKey(name: "Login_ID_Pruefer")
  String? login_id_pruefer;
  @JsonKey(name: "Eigentuemer")
  String? eigentuemer;
  @JsonKey(name: "Bauwerkhoehe")
  double? bauwerkhoehe;
  @JsonKey(name: "Baujahr")
  int? baujahr;
  @JsonKey(name: "Ansprechpartner")
  String? ansprechpartner;
  @JsonKey(name: "Steigwegtyp")
  String? steigwegtyp;
  @JsonKey(name: "Schluessel")
  bool? needs_schluessel;
  @JsonKey(name: "Abschaltungen")
  String? abschaltungen;
  @JsonKey(name: "Steckdosen")
  bool? has_steckdosen;
  @JsonKey(name: "WC")
  bool? has_wc;
  @JsonKey(name: "Lagerraeume")
  bool? has_lagerraeume;
  @JsonKey(name: "Steigschutzschluessel")
  String? steigschutzschluessel;

  @JsonKey(name: "ASP_required")
  bool? asp_required;
  @JsonKey(name: "Steckdosen_description")
  String? steckdosen_description;
  @JsonKey(name: "Schlüssel_description")
  String? schluessel_description;

  //Wetter
  @JsonKey(name: "Temperatur")
  int? temp;
  @JsonKey(name: "Wetter")
  Weather? weather;
  @JsonKey(name: "Wind")
  WindPower? wind_speed;
  @JsonKey(name: "Windrichtung")
  WindDirection? wind_direction;

  @JsonKey(name: 'DokusPaths')
  List<DocumentData>? dokuspaths;

  @JsonKey(includeFromJson: false, includeToJson: false)
  WeatherData get weatherData => WeatherData(
      temperature: temp,
      weather: weather,
      wind_speed: wind_speed,
      wind_direction: wind_direction);

  // @JsonKey(ignore: true) //only needed on getter
  set weatherData(WeatherData value) {
    temp = value.temperature;
    weather = value.weather;
    wind_speed = value.wind_speed;
    wind_direction = value.wind_direction;
  }

//XXX: ist das redundand mit den latLng?
  @JsonKey(name: "X")
  String? x;
  @JsonKey(name: "Y")
  String? y;

  LatLng? get coords => y != null && x != null
      ? LatLng(double.parse(y!.replaceAll(',', '.')),
          double.parse(x!.replaceAll(',', '.')))
      : fallback_coords;

  @JsonKey(
    name: 'latLng',
    fromJson: _toplevelhelperLatLng_fromJson,
    toJson: _toplevelhelperLatLng_toJson,
  )
  final LatLng? fallback_coords;

  InspectionLocation({
    this.bauleitung,
    ////this.defaultpicture,
    ///
    this.user,
    this.ort,
    this.pjInfo,
    this.pjName,
    required this.pjNr,
    this.plz,
    required this.stONr,
    this.strasse,
    this.fallback_coords,
    this.dokuspaths,
  });

  @override
  String toString() {
    return pjName ?? 'Inspektion $pjNr';
  }

  String toSubString() {
    return '${bauleitung ?? ''}';
  }

  @override
  String get title => toString();

  @override
  List<Widget> extras({BuildContext? context}) => [
        _RecursiveDownloadButton(
          key: ValueKey('recursive_download_${pjNr}_$stONr'),
          caller: CategoryModel(this),
        ),
      ];

  static InspectionLocation? fromJson(Map<String, dynamic> json) {
    final normalized = _normalizeInspectionLocationJson(json);
    if (normalized['PjNr'] == null || normalized['StONr'] == null) {
      debugPrint(
          'Skipping InspectionLocation because of missing identifiers: $json');
      return null;
    }

    try {
      return _$InspectionLocationFromJson(normalized);
    } catch (e) {
      debugPrint(
          'Decoding InspectionLocation failed: $e\njson: $json\nnormalized: $normalized');
    }
    return null;
  }

  Map<String, dynamic> toJson() => _$InspectionLocationToJson(this);

  @override
  Map<String, dynamic> toSmallJson() {
    return {
      'PjNr': pjNr,
      'StONr': stONr,
      if (login_id_pruefer != null && login_id_pruefer!.trim().isNotEmpty)
        'Login_ID_Pruefer': login_id_pruefer,
      'local_id': id,
    };
  }
}

Map<String, dynamic> _toplevelhelperLatLng_toJson(LatLng? latlng) {
  if (latlng == null) return {};
  return {'lat': latlng.latitude, 'lng': latlng.longitude};
}

LatLng? _toplevelhelperLatLng_fromJson(Map<String, dynamic>? map) {
  try {
    return LatLng(map!['lat'], map['lng']);
  } catch (e) {
    return null;
  }
}

Map<String, dynamic> _normalizeInspectionLocationJson(
    Map<String, dynamic> json) {
  final normalized = Map<String, dynamic>.from(json);

  int? toInt(dynamic value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  double? toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.replaceAll(',', '.'));
    return null;
  }

  bool? toBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final lower = value.toLowerCase();
      if (lower == 'true' || lower == '1') return true;
      if (lower == 'false' || lower == '0') return false;
    }
    return null;
  }

  void normalizeInt(String key) {
    if (!normalized.containsKey(key)) return;
    final parsed = toInt(normalized[key]);
    if (parsed != null) {
      normalized[key] = parsed;
    } else {
      normalized.remove(key);
    }
  }

  void normalizeDouble(String key) {
    if (!normalized.containsKey(key)) return;
    final parsed = toDouble(normalized[key]);
    if (parsed != null) {
      normalized[key] = parsed;
    } else {
      normalized.remove(key);
    }
  }

  void normalizeBool(String key) {
    if (!normalized.containsKey(key)) return;
    final parsed = toBool(normalized[key]);
    if (parsed != null) {
      normalized[key] = parsed;
    } else {
      normalized.remove(key);
    }
  }

  void normalizeString(String key) {
    if (!normalized.containsKey(key)) return;
    normalized[key] = normalized[key]?.toString();
  }

  normalizeInt('PjNr');
  normalizeInt('StONr');
  normalizeInt('Baujahr');
  normalizeInt('Temperatur');
  normalizeDouble('Bauwerkhoehe');

  for (final key in [
    'Steckdosen',
    'WC',
    'Lagerraeume',
    'Schluessel',
    'ASP_required',
    'offline',
  ]) {
    normalizeBool(key);
  }

  final latLng = normalized['latLng'];
  if (latLng is Map) {
    final lat = toDouble(latLng['lat']);
    final lng = toDouble(latLng['lng']);
    if (lat != null && lng != null) {
      normalized['latLng'] = {'lat': lat, 'lng': lng};
    } else {
      normalized.remove('latLng');
    }
  } else {
    normalized.remove('latLng');
  }

  for (final key in ['Login_ID_Pruefer', 'X', 'Y']) {
    normalizeString(key);
  }

  final documents = normalized['DokusPaths'] ??
      normalized['dokusPaths'] ??
      normalized['dokuspaths'] ??
      normalized['Dokus'] ??
      normalized['Dokumente'];
  if (documents != null) normalized['DokusPaths'] = documents;

  return normalized;
}

class _RecursiveDownloadButton extends StatefulWidget {
  // ignore: unused_element
  _RecursiveDownloadButton({required this.caller, Key? key}) : super(key: key);
  final CategoryModel
      caller; //XXX: if other ebenen should be downloadeable too (finer granularity), this must be a generic

  @override
  State<_RecursiveDownloadButton> createState() =>
      _RecursiveDownloadButtonState();
}

class _RecursiveDownloadButtonState extends State<_RecursiveDownloadButton> {
  bool wasPressed = false;
  bool? success;
  DownloadProgressSession? _session;

  String get _downloadKey {
    final inspection = widget.caller.currentData;
    return inspectionDownloadKey(inspection);
  }

  @override
  void initState() {
    super.initState();
    _syncDownloadState();
  }

  @override
  void didUpdateWidget(covariant _RecursiveDownloadButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncDownloadState();
  }

  void _syncDownloadState() {
    final activeSession = DownloadProgress.instance.activeFor(_downloadKey);
    if (activeSession != null) {
      wasPressed = true;
      success = null;
      _session = activeSession;
      return;
    }
    if (widget.caller.currentData.forceOffline && success != false) {
      wasPressed = true;
      success = true;
      _session = null;
    }
  }

  void press() async {
    final activeSession = DownloadProgress.instance.active;
    final activeForThisInspection =
        DownloadProgress.instance.activeFor(_downloadKey);
    if (activeSession != null && activeForThisInspection == null) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Es läuft bereits ein Inspektionsdownload.'),
        ),
      );
      return;
    }
    if (activeForThisInspection != null) {
      setState(() {
        success = null;
        wasPressed = true;
        _session = activeForThisInspection;
      });
      return;
    }

    setState(() {
      success = null;
      wasPressed = true;
    });
    final session = DownloadProgress.instance.start(
      label: InspectionDownloadSteps.refreshLabel,
      stepCount: InspectionDownloadSteps.count,
      key: _downloadKey,
    );
    session.setStep(
      InspectionDownloadSteps.refresh,
      label: InspectionDownloadSteps.refreshLabel,
    );
    _session = session;
    if (mounted) {
      // Trigger rebuild so the percentage replaces the download icon immediately.
      setState(() {});
    }

    try {
      final manager = FailedRequestmanager();
      final refreshed = await manager.refreshInspectionForDownload(
        widget.caller.currentData,
      );
      widget.caller.currentData = refreshed;
      final rootid = await API().rootID;
      final succeeded = await manager.downloadInspectionForOffline(
        widget.caller.currentData,
        rootId: rootid,
      );

      DownloadProgress.instance.finish(session);
      if (!mounted) return;
      setState(() {
        _session = null;
        success = succeeded;
      });
    } catch (e, stackTrace) {
      debugPrint('Inspektionsdownload fehlgeschlagen: $e\n$stackTrace');
      DownloadProgress.instance.finish(session);
      if (!mounted) return;
      setState(() {
        _session = null;
        success = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    _syncDownloadState();
    if (!wasPressed) {
      return IconButton(
          onPressed: press,
          icon: Icon(
            Icons.download,
          ));
    }
    if (success == null) {
      final session = _session;
      if (session == null) {
        return IconButton(
          onPressed: null,
          icon: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        );
      }
      return IconButton(
        onPressed: null,
        tooltip: 'Download läuft',
        icon: ValueListenableBuilder<DownloadProgressState>(
          valueListenable: session.notifier,
          builder: (context, state, _) {
            return SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                value: state.totalTasks == 0 ? null : state.fraction,
              ),
            );
          },
        ),
      );
    }
    if (success!) {
      return Icon(
        Icons.check,
        color: Colors.green,
      );
    }
    return IconButton(
        onPressed: press,
        icon: Icon(
          Icons.refresh,
          color: Colors.red,
        ));
  }
}

class InspectionDownloadProgressPanel extends StatelessWidget {
  const InspectionDownloadProgressPanel({
    super.key,
    required this.location,
  });

  final InspectionLocation location;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: DownloadProgress.instance.revision,
      builder: (context, _, __) {
        final session = DownloadProgress.instance
            .activeFor(inspectionDownloadKey(location));
        return AnimatedSize(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.topCenter,
          child: session == null
              ? const SizedBox.shrink()
              : ValueListenableBuilder<DownloadProgressState>(
                  valueListenable: session.notifier,
                  builder: (context, state, _) {
                    final colors = Theme.of(context).colorScheme;
                    final label = state.currentLabel.isEmpty
                        ? 'Download wird vorbereitet'
                        : state.currentLabel;
                    final stepText = state.stepIndex <= 0
                        ? 'Vorbereitung'
                        : 'Schritt ${state.stepIndex}/${state.stepCount}';
                    final progressValue =
                        state.totalTasks == 0 && state.fraction <= 0
                            ? null
                            : state.fraction;
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: SizedBox(
                        width: double.infinity,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color:
                                colors.primaryContainer.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: colors.primary.withValues(alpha: 0.24),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.cloud_download_outlined,
                                      size: 20,
                                      color: colors.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Inspektion offline speichern',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: colors.onPrimaryContainer,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '${state.percent}%',
                                      style: TextStyle(
                                        color: colors.onPrimaryContainer,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(99),
                                  child: LinearProgressIndicator(
                                    value: progressValue,
                                    minHeight: 7,
                                    backgroundColor:
                                        colors.surface.withValues(alpha: 0.65),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '$stepText · $label',
                                  maxLines: 2,
                                  softWrap: true,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: colors.onPrimaryContainer,
                                    height: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
