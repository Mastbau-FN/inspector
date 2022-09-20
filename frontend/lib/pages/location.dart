import 'package:MBG_Inspektionen/backend/api.dart';
import 'package:MBG_Inspektionen/classes/data/checkcategory.dart';
import 'package:MBG_Inspektionen/classes/imageData.dart';
import 'package:MBG_Inspektionen/fragments/weather/editableWeatherView.dart';
import 'package:MBG_Inspektionen/helpers/toast.dart';
import 'package:MBG_Inspektionen/widgets/nulleableToggle.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maps_launcher/maps_launcher.dart';

import 'package:flutter_map/flutter_map.dart';

import 'package:MBG_Inspektionen/classes/data/inspection_location.dart';
import 'package:MBG_Inspektionen/classes/listTileData.dart';
import 'package:MBG_Inspektionen/classes/user.dart';
import 'package:MBG_Inspektionen/pages/checkcategories.dart';
import 'package:MBG_Inspektionen/classes/dropdownClasses.dart';

import '../generated/l10n.dart';
import 'detailsPage.dart';

class LocationModel extends DropDownModel<InspectionLocation, Null> {
  final DisplayUser? user;

  static const _nextViewTitle = "Prüfkategorien";

  LocationModel({this.user}) : super(null);

  @override
  final List<MyListTileData> actions = [
    MyListTileData(
      title: _nextViewTitle,
      icon: Icons.category,
    ),
    MyListTileData(
      title: "Fotos",
      icon: Icons.photo_library,
    ),

    ///see #24
    MyListTileData(
      title: "Infos",
      icon: Icons.text_snippet,
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
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) {
        switch (tiledata.title) {
          case _nextViewTitle:
            return nextModel<CheckCategory, InspectionLocation, CategoryModel>(
                generateNextModel(data));
          case 'Fotos':
            return standard_statefulImageView(this, data);
          default:
            return LocationDetailPage(
              locationdata: data,
            );
        }
      }),
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
            EditableText(
              label: S.current.localtionOwner,
              text: locationdata.eigentuemer,
              onChanged: (val) {
                locationdata.eigentuemer = val;
                updateData(locationdata);
              },
            ),
            Divider(),
            _ASP(locationdata, updateData: updateData),
            Divider(),
            EditableText(
              label: S.current.locationWayUp,
              text: locationdata.steigwegtyp,
              onChanged: (val) {
                locationdata.steigwegtyp = val;
                updateData(locationdata);
              },
            ),
            Divider(),
            EditableText(
              label: S.current.locationAbschaltung,
              text: locationdata.abschaltungen,
              onChanged: (val) {
                locationdata.abschaltungen = val;
                updateData(locationdata);
              },
            ),
            Divider(),
            EditableText(
              label: S.current.locationSteigschutzKey,
              text: locationdata.steigschutzschluessel,
              onChanged: (val) {
                locationdata.steigschutzschluessel = val;
                updateData(locationdata);
              },
            ),
            Divider(),
            EditableText(
              keyboardType: TextInputType.numberWithOptions(decimal: false),
              label: S.current.locationHeight,
              text: locationdata.bauwerkhoehe.toString(),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                    RegExp(r'^-?[0-9]+(\.|,)?[0-9]*$'))
              ],
              onChanged: (val) {
                locationdata.bauwerkhoehe =
                    double.parse(val.replaceAll(r',', '.'));
                updateData(locationdata);
              },
            ),
            Divider(),
            EditableText(
              keyboardType: TextInputType.number,
              label: S.current.locationYearOfBuild,
              text: locationdata.baujahr.toString(),
              onChanged: (val) {
                locationdata.baujahr = int.tryParse(val);
                updateData(locationdata);
              },
            ),
            Divider(),
            _Schluessel(locationdata, updateData: updateData),
            Divider(),
            NamedNulleableBoolToggle(
              label: S.current.locationHasWCLabel,
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
              label: S.current.locationHasStorageSpaceLabel,
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
    _maybeShowToast(S.current.updateSuccessful + ": $val");
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
                builder: (context, snapshot) =>
                    snapshot.data?.image ?? Icon(Icons.construction)),
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
  final bool showsMapPerDefault;
  const _Map({
    Key? key,
    required this.locationdata,
    this.showsMapPerDefault = false,
  }) : super(key: key);

  final InspectionLocation locationdata;

  @override
  State<_Map> createState() => _MapState();
}

class _MapState extends State<_Map> {
  bool showsMap = false;
  @override
  void initState() {
    showsMap = widget.showsMapPerDefault;
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
                            FlutterMap(
                              options: MapOptions(
                                center: widget.locationdata.coords!,
                                zoom: 8.0,
                              ),
                              layers: [
                                TileLayerOptions(
                                    urlTemplate:
                                        "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                                    subdomains: ['a', 'b', 'c']),
                                MarkerLayerOptions(
                                  markers: [
                                    Marker(
                                      width: 80.0,
                                      height: 80.0,
                                      point: widget.locationdata.coords!,
                                      builder: (ctx) => Container(
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
                      onPressed: () {
                        MapsLauncher.launchCoordinates(
                            widget.locationdata.coords!.latitude,
                            widget.locationdata.coords!.longitude,
                            widget.locationdata.pjName);
                      },
                    ),
                  ),
                ),
              ],
            );
}

// ignore: must_be_immutable
class EditableText extends StatefulWidget {
  EditableText({
    Key? key,
    required this.label,
    required this.text,
    required this.onChanged,
    this.keyboardType = TextInputType.text,
    this.inputFormatters = const [],
  }) : super(key: key);

  final String label;
  String? text;
  final Function(String) onChanged;
  final TextInputType keyboardType;
  final List<TextInputFormatter> inputFormatters;

  @override
  State<EditableText> createState() => _EditableTextState();
}

class _EditableTextState extends State<EditableText> {
  bool isEditing = false;
  @override
  Widget build(BuildContext context) {
    var editor = PlainEditor(
      inputFormatters: widget.inputFormatters,
      sdetails: widget.text ?? "--",
      isEditing: isEditing,
      keyboardType: widget.keyboardType,
    );
    return Row(
      children: [
        Text(
          widget.label + ': ',
          style: TextStyle(fontWeight: FontWeight.w300),
        ),
        Flexible(
          child: editor,
        ),
        // Spacer(),
        TextButton(
          // style: ButtonStyle(
          //     fixedSize: MaterialStateProperty.all<Size>(Size(50, 10)),
          //     padding: MaterialStateProperty.all(EdgeInsets.all(-10))),
          // constraints: BoxConstraints(maxHeight: 20, maxWidth: 20),
          child: Icon(isEditing ? Icons.check : Icons.edit),
          onPressed: () => setState(() {
            if (isEditing) {
              widget.onChanged(editor.details);
              widget.text = editor.details;
            }
            isEditing ^= true;
          }),
        ),
      ],
    );
  }
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

class _ASP extends StatefulWidget {
  final InspectionLocation loc;
  final Function(InspectionLocation) updateData;
  const _ASP(this.loc, {required this.updateData, Key? key}) : super(key: key);

  @override
  State<_ASP> createState() => __ASPState();
}

class __ASPState extends State<_ASP> {
  @override
  void initState() {
    isOn = widget.loc.asp_required;
    super.initState();
  }

  bool? isOn;
  @override
  Widget build(BuildContext context) {
    var locationdata = widget.loc;
    return Column(
      children: [
        NamedNulleableBoolToggle(
          label: S.current.locationASPRequieredLabel,
          isSelected: locationdata.asp_required,
          onSelected: (val) {
            locationdata.asp_required = val;
            widget.updateData(locationdata);
            setState(() {
              isOn = val;
            });
          },
        ),
        if (isOn ?? false)
          EditableText(
            label: S.current.locationASPLabel,
            text: locationdata.ansprechpartner,
            onChanged: (val) {
              locationdata.ansprechpartner = val;
              widget.updateData(locationdata);
            },
          ),
      ],
    );
  }
}

class _Schluessel extends StatefulWidget {
  final InspectionLocation loc;
  final Function(InspectionLocation) updateData;
  const _Schluessel(this.loc, {required this.updateData, Key? key})
      : super(key: key);

  @override
  State<_Schluessel> createState() => __SchluesselState();
}

class __SchluesselState extends State<_Schluessel> {
  @override
  void initState() {
    isOn = widget.loc.needs_schluessel;
    super.initState();
  }

  bool? isOn;
  @override
  Widget build(BuildContext context) {
    var locationdata = widget.loc;
    return Column(
      children: [
        NamedNulleableBoolToggle(
          isSelected: locationdata.needs_schluessel,
          label: S.current.locationRequiresKeyLabel,
          onSelected: (val) {
            locationdata.needs_schluessel = val;
            widget.updateData(locationdata);
            setState(() {
              isOn = val;
            });
          },
        ),
        if (isOn ?? true)
          EditableText(
            label: S.current.locationKeyAddintionalInfoLabel,
            text: locationdata.schluessel_description,
            onChanged: (val) {
              locationdata.schluessel_description = val;
              widget.updateData(locationdata);
            },
          ),
      ],
    );
  }
}

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
          label: S.current.locationHasSteckdosenLabel,
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
          EditableText(
            label: S.current.locationAdditionalInfoSteckdosenLabel,
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
