// ignore_for_file: non_constant_identifier_names

import 'package:MBG_Inspektionen/backend/api.dart';
import 'package:MBG_Inspektionen/backend/download_progress.dart';
import 'package:MBG_Inspektionen/backend/failedRequestManager.dart';
import 'package:MBG_Inspektionen/backend/sync_events.dart';
import 'package:MBG_Inspektionen/classes/documentData.dart';
import 'package:MBG_Inspektionen/fragments/loadingscreen/loadingView.dart';
import 'package:MBG_Inspektionen/pages/checkcategories.dart';
import 'package:flutter/material.dart';
import 'package:MBG_Inspektionen/classes/dropdownClasses.dart';
import 'package:json_annotation/json_annotation.dart';
import "package:latlong2/latlong.dart";

import 'weather.dart';

part 'inspection_location.g.dart';

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
        if (!forceOffline)
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
  void press() async {
    setState(() {
      success = null;
      wasPressed = true;
    });
    final session = DownloadProgress.instance.start(label: widget.caller.title);
    _session?.dispose();
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
      final succeeded = await manager.loadAndCacheAll(
        widget.caller,
        3,
        name: widget.caller.title,
        parentID: rootid,
      );

      DownloadProgress.instance.finish(session);
      session.dispose();
      if (succeeded) {
        SyncEvents.instance.notifyLocalDataChanged();
      }
      if (!mounted) return;
      setState(() {
        _session = null;
        success = succeeded;
      });
    } catch (e, stackTrace) {
      debugPrint('Inspektionsdownload fehlgeschlagen: $e\n$stackTrace');
      DownloadProgress.instance.finish(session);
      session.dispose();
      if (!mounted) return;
      setState(() {
        _session = null;
        success = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
          onPressed: (() {}),
          icon: Opacity(
            child: LoadingView(),
            opacity: 0.5,
          ),
        );
      }
      return ValueListenableBuilder<DownloadProgressState>(
        valueListenable: session.notifier,
        builder: (context, state, _) {
          return IconButton(
            onPressed: null,
            icon: SizedBox(
              width: 92,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      value: state.fraction,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Step ${state.stepIndex}/${state.stepCount}',
                        style: const TextStyle(fontSize: 9),
                      ),
                      Text(
                        '${state.percent}%',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            tooltip: state.currentLabel.isEmpty
                ? 'Step ${state.stepIndex}/${state.stepCount}'
                : state.currentLabel,
          );
        },
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
