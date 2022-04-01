import 'package:MBG_Inspektionen/backend/api.dart';
import 'package:MBG_Inspektionen/classes/data/checkcategory.dart';
import 'package:MBG_Inspektionen/classes/imageData.dart';
import 'package:MBG_Inspektionen/helpers/toast.dart';
import 'package:MBG_Inspektionen/widgets/nulleableToggle.dart';
import 'package:flutter/material.dart';
import 'package:maps_launcher/maps_launcher.dart';

import 'package:flutter_map/flutter_map.dart';

import 'package:MBG_Inspektionen/classes/data/inspection_location.dart';
import 'package:MBG_Inspektionen/classes/listTileData.dart';
import 'package:MBG_Inspektionen/classes/user.dart';
import 'package:MBG_Inspektionen/pages/checkcategories.dart';
import 'package:MBG_Inspektionen/classes/dropdownClasses.dart';

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
  void open(
    BuildContext context,
    InspectionLocation data,
    MyListTileData tiledata,
  ) {
    currentlyChosenChildData = Future.sync(() => data);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) {
        switch (tiledata.title) {
          case _nextViewTitle:
            return nextModel<CheckCategory, InspectionLocation, CategoryModel>(
                CategoryModel(data));
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

//TODO: ansichrt den neuen daten anpassen
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
              label: "Eigentümer",
              text: locationdata.eigentuemer,
              onChanged: (val) {
                locationdata.eigentuemer = val;
                updateData(locationdata);
              },
            ),
            ...[
              NamedNulleableBoolToggle(
                label: "Ansprechpartner nötig",
                isSelected: locationdata.asp_required,
                onSelected: (val) {
                  locationdata.asp_required = val;
                  updateData(locationdata);
                },
              ),
              EditableText(
                label: "Ansprechpartner",
                text: locationdata.ansprechpartner,
                onChanged: (val) {
                  locationdata.ansprechpartner = val;
                  updateData(locationdata);
                },
              ),
            ],
            EditableText(
              label: "Steigweg-Typ",
              text: locationdata.steigwegtyp,
              onChanged: (val) {
                locationdata.steigwegtyp = val;
                updateData(locationdata);
              },
            ),
            EditableText(
              label: "Abschaltungen",
              text: locationdata.abschaltungen,
              onChanged: (val) {
                locationdata.abschaltungen = val;
                updateData(locationdata);
              },
            ),
            EditableText(
              label: "SSSchlüssel",
              text: locationdata.steigschutzschluessel,
              onChanged: (val) {
                locationdata.steigschutzschluessel = val;
                updateData(locationdata);
              },
            ),
            EditableText(
              keyboardType: TextInputType.number,
              label: "Höhe",
              text: locationdata.bauwerkhoehe.toString(),
              onChanged: (val) {
                locationdata.bauwerkhoehe = int.tryParse(val);
                updateData(locationdata);
              },
            ),
            EditableText(
              keyboardType: TextInputType.number,
              label: "Baujahr",
              text: locationdata.baujahr.toString(),
              onChanged: (val) {
                locationdata.baujahr = int.tryParse(val);
                updateData(locationdata);
              },
            ),
            ...[
              NamedNulleableBoolToggle(
                isSelected: locationdata.needs_schluessel,
                label: "Benötigt Schlüssel",
                onSelected: (val) {
                  locationdata.needs_schluessel = val;
                  updateData(locationdata);
                },
              ),
              EditableText(
                label: "Anmerkung Schlüssel",
                text: locationdata.schlussel_description,
                onChanged: (val) {
                  locationdata.schlussel_description;
                  updateData(locationdata);
                },
              ),
            ],
            NamedNulleableBoolToggle(
              label: "WC Vorort",
              isSelected: locationdata.has_wc,
              onSelected: (val) {
                locationdata.has_wc = val;
                updateData(locationdata);
              },
            ),
            ...[
              NamedNulleableBoolToggle(
                label: "Steckdosen verfügbar",
                isSelected: locationdata.has_steckdosen,
                onSelected: (val) {
                  locationdata.has_steckdosen = val;
                  updateData(locationdata);
                },
              ),
              EditableText(
                label: "Anmerkung Steckdosen",
                text: locationdata.steckdosen_description,
                onChanged: (val) {
                  locationdata.steckdosen_description = val;
                  updateData(locationdata);
                },
              ),
            ],
            NamedNulleableBoolToggle(
              label: "Lagerraum verfügbar",
              isSelected: locationdata.has_lagerraeume,
              onSelected: (val) {
                locationdata.has_lagerraeume = val;
                updateData(locationdata);
              },
            ),
          ],
        ),
      );

  Future<String?> updateData(InspectionLocation loc) async {
    var val = await Backend().update(loc);
    showToast("update successful: $val");
    return val;
  }

  Widget _previewImg() => Container(
        height: 100,
        width: 100,
        child: ClipOval(
          child: Container(
            height: 100,
            width: 100,
            child: StreamBuilder<ImageData?>(
                stream: locationdata.mainImage,
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
          _map(),
        ],
      );

  Widget _map() => //Container();
      locationdata.coords == null
          ? Container(
              height: 20,
            )
          : Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  height:
                      400, //XXX expanded to take available space would be much better than giving a fixed height
                  child: FlutterMap(
                    options: MapOptions(
                      center: locationdata.coords!,
                      zoom: 13.0,
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
                            point: locationdata.coords!,
                            builder: (ctx) => Container(
                              child: Icon(Icons.location_on),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: FloatingActionButton(
                    child: Icon(Icons.navigation_rounded),
                    onPressed: () {
                      MapsLauncher.launchCoordinates(
                          locationdata.coords!.latitude,
                          locationdata.coords!.longitude);
                    },
                  ),
                ),
              ],
            );
}

class EditableText extends StatefulWidget {
  EditableText({
    Key? key,
    required this.label,
    required this.text,
    required this.onChanged,
    this.keyboardType = TextInputType.text,
  }) : super(key: key);

  final String label;
  String? text;
  final Function(String) onChanged;
  final TextInputType keyboardType;

  @override
  State<EditableText> createState() => _EditableTextState();
}

class _EditableTextState extends State<EditableText> {
  bool isEditing = false;
  @override
  Widget build(BuildContext context) {
    var editor = PlainEditor(
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
