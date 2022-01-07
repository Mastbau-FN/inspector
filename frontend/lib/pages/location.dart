import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:maps_launcher/maps_launcher.dart';

import 'package:flutter_map/flutter_map.dart';
import "package:latlong2/latlong.dart" as latLng;

import 'package:MBG_Inspektionen/backend/api.dart';
import 'package:MBG_Inspektionen/classes/data/inspection_location.dart';
import 'package:MBG_Inspektionen/classes/listTileData.dart';
import 'package:MBG_Inspektionen/classes/user.dart';
import 'package:MBG_Inspektionen/pages/checkcategories.dart';
import 'package:MBG_Inspektionen/classes/dropdownClasses.dart';

import 'imagesPage.dart';
import 'detailsPage.dart';

class LocationModel extends DropDownModel<InspectionLocation> {
  final Backend _b = Backend();
  final DisplayUser? user;

  static const _nextViewTitle = "Prüfkategorien";

  LocationModel({this.user});

  Future<List<InspectionLocation>> get all =>
      _b.getAllInspectionLocationsForCurrentUser();

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
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) {
        switch (tiledata.title) {
          case _nextViewTitle:
            return nextModel(CategoryModel(data));
          case 'Fotos':
            return ImagesPage.futured(
              future_images: data.image_futures,
              onNewImages: (files) => Backend().uploadFiles(data, files),
            );
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
      body: Center(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _previewImg(),
            Container(height: 20),
            _mgauftr(),
            Container(height: 20),
            _standort(),
          ],
        ),
      ));

  ClipOval _previewImg() => ClipOval(
        child: Container(
          height: 100,
          width: 100,
          child: FutureBuilder<Image?>(
              future: locationdata.mainImage,
              builder: (context, snapshot) =>
                  snapshot.data ?? Icon(Icons.construction)),
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
