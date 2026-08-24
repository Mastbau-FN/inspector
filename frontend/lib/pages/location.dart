import 'dart:async';

import 'package:MBG_Inspektionen/backend/api.dart';
import 'package:MBG_Inspektionen/classes/data/checkcategory.dart';
import 'package:MBG_Inspektionen/classes/imageData.dart';
import 'package:MBG_Inspektionen/fragments/weather/editableWeatherView.dart';
import 'package:MBG_Inspektionen/helpers/toast.dart';
import 'package:MBG_Inspektionen/pages/dokusPage.dart';
import 'package:MBG_Inspektionen/pages/inspection_defect_checker.dart';
import 'package:MBG_Inspektionen/widgets/nulleableToggle.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:map_launcher/map_launcher.dart';

import 'package:flutter_map/flutter_map.dart' as FM;

import 'package:MBG_Inspektionen/classes/data/inspection_location.dart';
import 'package:MBG_Inspektionen/classes/listTileData.dart';
import 'package:MBG_Inspektionen/classes/user.dart';
import 'package:MBG_Inspektionen/pages/checkcategories.dart';
import 'package:MBG_Inspektionen/classes/dropdownClasses.dart';

import 'package:MBG_Inspektionen/l10n/locales.dart';

const osmTileUrlTemplate = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const osmUserAgentPackageName = 'com.mbgsolutions.inspector';

class LocationModel extends DropDownModel<InspectionLocation, Null> {
  final DisplayUser? user;
  final InspectionDefectChecker _defectChecker;
  final Set<String> _openingInspections = {};

  static const _nextViewTitle = "Prüfkategorien";

  LocationModel({
    this.user,
    InspectionDefectChecker? defectChecker,
  })  : _defectChecker = defectChecker ?? InspectionDefectChecker(),
        super(null);

  @override
  final List<MyListTileData> actions = [
    MyListTileData(
      title: _nextViewTitle,
      icon: Icons.category,
    ),
    MyListTileData(
      title: "Fotos",
    ),

    ///see #24
    MyListTileData(
      title: "Infos",
    ),
    MyListTileData(
      title: "Docs",
    ),
    MyListTileData(
      title: _nextViewTitle,
    ),
  ];

  @override
  String get title => 'Inspektionen: $user';

  @override
  CategoryModel generateNextModel(InspectionLocation data) =>
      CategoryModel(data);

  @override
  void open(
    BuildContext context,
    InspectionLocation data,
    MyListTileData tiledata,
  ) {
    currentlyChosenChildData = Future.value(data);
    if (tiledata.title == _nextViewTitle) {
      unawaited(_openInspection(context, data));
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) {
        switch (tiledata.title) {
          case 'Fotos':
            return standard_statefulImageView(this, data);
          case 'Docs':
            return DokusList(
              dokus: data.dokuspaths,
              scope: API().local.scopeFor(data),
            );
          default:
            return LocationDetailPage(
              locationdata: data,
            );
        }
      }),
    );
  }

  Future<void> _openInspection(
    BuildContext context,
    InspectionLocation inspection,
  ) async {
    if (!_openingInspections.add(inspection.id)) return;
    try {
      final hasDefects = await _checkDefectsWithProgressDialog(
        context,
        inspection,
      );
      if (!context.mounted) return;
      if (hasDefects) {
        final continueEditing = await showDialog<bool>(
              context: context,
              barrierDismissible: false,
              builder: (dialogContext) => AlertDialog(
                title: const Text('Gefundene Mängel'),
                content: const Text(
                  'Diese Inspektion enthält bereits Mängel. '
                  'Möchtest du sie wirklich bearbeiten?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: const Text('Abbrechen'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    child: const Text('Trotzdem fortfahren'),
                  ),
                ],
              ),
            ) ??
            false;
        if (!continueEditing || !context.mounted) return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              nextModel<CheckCategory, InspectionLocation, CategoryModel>(
            generateNextModel(inspection),
          ),
        ),
      );
    } finally {
      _openingInspections.remove(inspection.id);
    }
  }

  Future<bool> _checkDefectsWithProgressDialog(
    BuildContext context,
    InspectionLocation inspection,
  ) async {
    _showDefectLookupDialog(context);
    try {
      return await _defectChecker.hasDefectEntries(inspection);
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          'Mängelprüfung für Inspektion ${inspection.id} fehlgeschlagen: '
          '$error',
        );
      }
      return false;
    } finally {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
  }

  void _showDefectLookupDialog(BuildContext context) {
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => PopScope(
          canPop: false,
          child: AlertDialog(
            title: const Text('Mängelprüfung'),
            content: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Es wird geprüft, ob Mängel in dieser Inspektion '
                    'existieren.',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LocationDetailPage extends StatelessWidget {
  final InspectionLocation locationdata;
  const LocationDetailPage({required this.locationdata, Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
        title: Text(locationdata.title),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(height: 20),
            _previewImg(),
            Container(height: 20),
            _mgauftr(),
            Container(height: 20),
            _weatherBlock,
            Container(height: 20),
            _additionalInfo,
            Container(height: 20),
            _standort(),
          ],
        ),
      ));

  Widget get _additionalInfo => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            LocationEditableField(
              label: S.current!.localtionOwner,
              text: locationdata.eigentuemer,
              onChanged: (val) {
                locationdata.eigentuemer = val;
                updateData(locationdata);
              },
            ),
            //Divider(),
            //ASP(locationdata, updateData: updateData),
            //Issue-236
            Divider(),
            Row(
              children: [
                Text(
                  'Prüfer_ID: ',
                  style: TextStyle(fontWeight: FontWeight.w300),
                ),
                Flexible(
                  child: Text(locationdata.login_id_pruefer ?? '--'),
                ),
              ],
            ),
            //Divider(),
            //ASP(locationdata, updateData: updateData),
            //Issue-236
            Divider(),
            LocationEditableField(
              label: S.current!.locationWayUp,
              text: locationdata.steigwegtyp,
              onChanged: (val) {
                locationdata.steigwegtyp = val;
                updateData(locationdata);
              },
            ),
            Divider(),
            // EditableText(
            //   label: S.current!.locationAbschaltung,
            //   text: locationdata.abschaltungen,
            //   onChanged: (val) {
            //     locationdata.abschaltungen = val;
            //     updateData(locationdata);
            //   },
            // ),
            // Divider(),
            // EditableText(
            //   label: S.current!.locationSteigschutzKey,
            //   text: locationdata.steigschutzschluessel,
            //   onChanged: (val) {
            //     locationdata.steigschutzschluessel = val;
            //     updateData(locationdata);
            //   },
            // ),
            // Divider(),
            // Issue 235 Felder wieder entfernt, da sie nicht mehr benötigt werden
            LocationEditableField(
              keyboardType: TextInputType.numberWithOptions(decimal: false),
              label: S.current!.locationHeight,
              text: locationdata.bauwerkhoehe?.toString(),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                    RegExp(r'^-?[0-9]+(\.|,)?[0-9]*$'))
              ],
              validator: _optionalDoubleValidator,
              onChanged: (val) {
                locationdata.bauwerkhoehe = val.trim().isEmpty
                    ? null
                    : double.tryParse(val.replaceAll(',', '.'));
                updateData(locationdata);
              },
            ),
            Divider(),
            LocationEditableField(
              keyboardType: TextInputType.number,
              label: S.current!.locationYearOfBuild,
              text: locationdata.baujahr?.toString(),
              validator: _optionalIntegerValidator,
              onChanged: (val) {
                locationdata.baujahr =
                    val.trim().isEmpty ? null : int.tryParse(val);
                updateData(locationdata);
              },
            ),
            Divider(),
            // Schluessel(locationdata, updateData: updateData),
            //Divider(),
            //Issue 235 Felder wieder entfernt, da sie nicht mehr benötigt werden
            NamedNulleableBoolToggle(
              label: S.current!.locationHasWCLabel,
              isSelected: locationdata.has_wc,
              onSelected: (val) {
                locationdata.has_wc = val;
                updateData(locationdata);
              },
            ),
            Divider(),
            _SteckDosen(locationdata, updateData: updateData),
            Divider(),
            NamedNulleableBoolToggle(
              label: S.current!.locationHasStorageSpaceLabel,
              isSelected: locationdata.has_lagerraeume,
              onSelected: (val) {
                locationdata.has_lagerraeume = val;
                updateData(locationdata);
              },
            ),
            Divider(),
          ],
        ),
      );

  Future<String?> updateData(InspectionLocation loc) async {
    var val = await API().update(loc, forceUpdate: true);
    _maybeShowToast(S.current!.updateSuccessful + ": $val");
    return val;
  }

  Widget _previewImg() => Container(
        height: 100,
        width: 100,
        child: ClipOval(
          child: Container(
            height: 100,
            width: 100,
            child: FutureBuilder<ImageData?>(
                future: locationdata.mainImage,
                builder: (context, snapshot) {
                  final provider = snapshot.data?.image.image;
                  if (provider == null) return Icon(Icons.construction);
                  return Image(
                    image: ResizeImage.resizeIfNeeded(
                      (100 * MediaQuery.devicePixelRatioOf(context))
                          .round()
                          .clamp(100, 512),
                      null,
                      provider,
                    ),
                    fit: BoxFit.cover,
                  );
                }),
          ),
        ),
      );

  Widget _mgauftr() => Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text("${locationdata.pjNr}, ${locationdata.bauleitung}"),
          Text("${locationdata.pjName}"),
          Text("${locationdata.pjInfo}"),
        ],
      );

  Widget _standort() => Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text("${locationdata.stONr}:"),
          Text("${locationdata.strasse}"),
          Text("${locationdata.plz}, ${locationdata.ort}"),
          Container(height: 10),
          _Map(locationdata: locationdata),
        ],
      );

  Widget get _weatherBlock => Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Divider(),
          WeatherSet(
              weatherData: locationdata.weatherData,
              onChanged: (newweather) {
                locationdata.weatherData = newweather;
                updateData(locationdata);
              }),
          Divider(),
        ],
      );
}

class _Map extends StatefulWidget {
  const _Map({
    Key? key,
    required this.locationdata,
  }) : super(key: key);

  final InspectionLocation locationdata;

  @override
  State<_Map> createState() => _MapState();
}

class _MapState extends State<_Map> {
  bool showsMap = false;
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) => //Container();
      widget.locationdata.coords == null
          ? Container(
              height: 20,
            )
          : Stack(
              alignment: Alignment.bottomRight,
              children: [
                showsMap
                    ? Container(
                        height:
                            400, //XXX expanded to take available space would be much better than giving a fixed height
                        child: Stack(
                          children: [
                            FM.FlutterMap(
                              options: FM.MapOptions(
                                initialCenter: widget.locationdata.coords!,
                                initialZoom: 8.0,
                              ),
                              children: [
                                FM.TileLayer(
                                  urlTemplate: osmTileUrlTemplate,
                                  userAgentPackageName: osmUserAgentPackageName,
                                ),
                                FM.MarkerLayer(
                                  markers: [
                                    FM.Marker(
                                      width: 80.0,
                                      height: 80.0,
                                      point: widget.locationdata.coords!,
                                      child: Container(
                                        child: Icon(Icons.location_on),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Align(
                              alignment: Alignment.topRight,
                              child: IconButton(
                                onPressed: () {
                                  setState(() {
                                    showsMap = false;
                                  });
                                },
                                icon: Icon(Icons.close),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Align(
                        alignment: Alignment.center,
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                    'lat: ${widget.locationdata.coords?.latitude}, lng:${widget.locationdata.coords?.longitude}'),
                                TextButton(
                                    onPressed: (() => setState(() {
                                          showsMap = true;
                                        })),
                                    child: Icon(Icons.map))
                              ],
                            ),
                            SizedBox(height: 20),
                          ],
                        ),
                      ),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: FloatingActionButton(
                      child: Icon(Icons.navigation_rounded),
                      onPressed: () async {
                        return await (await MapLauncher.installedMaps)
                            .first
                            .showMarker(
                              coords: Coords(
                                  widget.locationdata.coords!.latitude,
                                  widget.locationdata.coords!.longitude),
                              title: widget.locationdata.title,
                              description: widget.locationdata.subtitle ??
                                  widget.locationdata.langText,
                            );
                      },
                    ),
                  ),
                ),
              ],
            );
}

class LocationEditableField extends StatefulWidget {
  const LocationEditableField({
    Key? key,
    required this.label,
    required this.text,
    required this.onChanged,
    this.keyboardType = TextInputType.text,
    this.inputFormatters = const [],
    this.validator,
  }) : super(key: key);

  final String label;
  final String? text;
  final ValueChanged<String> onChanged;
  final TextInputType keyboardType;
  final List<TextInputFormatter> inputFormatters;
  final String? Function(String value)? validator;

  @override
  State<LocationEditableField> createState() => _LocationEditableFieldState();
}

class _LocationEditableFieldState extends State<LocationEditableField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  late String _savedValue;
  bool _isEditing = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _savedValue = widget.text ?? '';
    _controller = TextEditingController(text: _savedValue);
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant LocationEditableField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isEditing && oldWidget.text != widget.text) {
      _savedValue = widget.text ?? '';
      _controller.text = _savedValue;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startEditing() {
    setState(() {
      _isEditing = true;
      _errorText = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  void _save() {
    final value = _controller.text;
    final error = widget.validator?.call(value);
    if (error != null) {
      setState(() {
        _errorText = error;
      });
      return;
    }

    widget.onChanged(value);
    setState(() {
      _savedValue = value;
      _isEditing = false;
      _errorText = null;
    });
  }

  void _cancel() {
    _controller.text = _savedValue;
    setState(() {
      _isEditing = false;
      _errorText = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${widget.label}:',
          style: TextStyle(fontWeight: FontWeight.w300),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: _isEditing
                  ? TextFormField(
                      key: ValueKey('location_field_${widget.label}'),
                      controller: _controller,
                      focusNode: _focusNode,
                      autofocus: true,
                      keyboardType: widget.keyboardType,
                      inputFormatters: widget.inputFormatters,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(errorText: _errorText),
                      onFieldSubmitted: (_) => _save(),
                    )
                  : Text(
                      _controller.text.isEmpty ? '--' : _controller.text,
                    ),
            ),
            if (_isEditing)
              IconButton(
                tooltip: 'Abbrechen',
                icon: const Icon(Icons.close),
                onPressed: _cancel,
              ),
            IconButton(
              tooltip: _isEditing ? 'Speichern' : 'Bearbeiten',
              icon: Icon(_isEditing ? Icons.check : Icons.edit),
              onPressed: _isEditing ? _save : _startEditing,
            ),
          ],
        ),
      ],
    );
  }
}

String? _optionalDoubleValidator(String value) {
  final normalized = value.trim().replaceAll(',', '.');
  if (normalized.isEmpty || double.tryParse(normalized) != null) return null;
  return 'Bitte eine gültige Zahl eingeben';
}

String? _optionalIntegerValidator(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty || int.tryParse(normalized) != null) return null;
  return 'Bitte eine ganze Zahl eingeben';
}

class NamedNulleableBoolToggle extends StatelessWidget {
  final String label;
  final Function(bool?)? onSelected;
  final bool? isSelected;
  const NamedNulleableBoolToggle({
    Key? key,
    required this.label,
    this.onSelected,
    this.isSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(fontWeight: FontWeight.w300),
        ),
        Spacer(),
        NulleableToggle(
          isSelected: isSelected,
          onSelected: onSelected,
        ),
      ],
    );
  }
}

// class _ASP extends StatefulWidget {
//   final InspectionLocation loc;
//   final Function(InspectionLocation) updateData;
//   const _ASP(this.loc, {required this.updateData, Key? key}) : super(key: key);

//   @override
//   State<_ASP> createState() => __ASPState();
// }

// class __ASPState extends State<_ASP> {
//   @override
//   void initState() {
//     isOn = widget.loc.asp_required;
//     super.initState();
//   }

//   bool? isOn;
//   @override
//   Widget build(BuildContext context) {
//     var locationdata = widget.loc;
//     return Column(
//       children: [
//         NamedNulleableBoolToggle(
//           label: S.current!.locationASPRequieredLabel,
//           isSelected: locationdata.asp_required,
//           onSelected: (val) {
//             locationdata.asp_required = val;
//             widget.updateData(locationdata);
//             setState(() {
//               isOn = val;
//             });
//           },
//         ),
//         if (isOn ?? false)
//           LocationEditableField(
//             label: S.current!.locationASPLabel,
//             text: locationdata.ansprechpartner,
//             onChanged: (val) {
//               locationdata.ansprechpartner = val;
//               widget.updateData(locationdata);
//             },
//           ),
//       ],
//     );
//   }
// }
//
// class _Schluessel extends StatefulWidget {
//   final InspectionLocation loc;
//   final Function(InspectionLocation) updateData;
//   const _Schluessel(this.loc, {required this.updateData, Key? key})
//       : super(key: key);

//   @override
//   State<_Schluessel> createState() => __SchluesselState();
// }

// class __SchluesselState extends State<_Schluessel> {
//   @override
//   void initState() {
//     isOn = widget.loc.needs_schluessel;
//     super.initState();
//   }

//   bool? isOn;
//   @override
//   Widget build(BuildContext context) {
//     var locationdata = widget.loc;
//     return Column(
//       children: [
//         NamedNulleableBoolToggle(
//           isSelected: locationdata.needs_schluessel,
//           label: S.current!.locationRequiresKeyLabel,
//           onSelected: (val) {
//             locationdata.needs_schluessel = val;
//             widget.updateData(locationdata);
//             setState(() {
//               isOn = val;
//             });
//           },
//         ),
//         if (isOn ?? true)
//           LocationEditableField(
//             label: S.current!.locationKeyAddintionalInfoLabel,
//             text: locationdata.schluessel_description,
//             onChanged: (val) {
//               locationdata.schluessel_description = val;
//               widget.updateData(locationdata);
//             },
//           ),
//       ],
//     );
//   }
// }
// issue: 235 schluessel nicht mehr benötigt

class _SteckDosen extends StatefulWidget {
  final InspectionLocation loc;
  final Function(InspectionLocation) updateData;
  const _SteckDosen(this.loc, {required this.updateData, Key? key})
      : super(key: key);

  @override
  State<_SteckDosen> createState() => __SteckDosenState();
}

class __SteckDosenState extends State<_SteckDosen> {
  @override
  void initState() {
    isOn = widget.loc.has_steckdosen;
    super.initState();
  }

  bool? isOn;
  @override
  Widget build(BuildContext context) {
    var locationdata = widget.loc;
    return Column(
      children: [
        NamedNulleableBoolToggle(
          label: S.current!.locationHasSteckdosenLabel,
          isSelected: locationdata.has_steckdosen,
          onSelected: (val) {
            locationdata.has_steckdosen = val;
            widget.updateData(locationdata);
            setState(() {
              isOn = val;
            });
          },
        ),
        if (isOn ?? false)
          LocationEditableField(
            label: S.current!.locationAdditionalInfoSteckdosenLabel,
            text: locationdata.steckdosen_description,
            onChanged: (val) {
              locationdata.steckdosen_description = val;
              widget.updateData(locationdata);
            },
          ),
      ],
    );
  }
}

void _maybeShowToast(String? message) {
  if (kDebugMode) if (message != null && message != "") {
    showToast(message);
  }
}
