import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mastbau_inspector/backend/api.dart';
import 'package:mastbau_inspector/classes/inspection_location.dart';
import 'package:provider/provider.dart';

enum LocationNext { categories, images, informations }

extension LocationNextString on LocationNext {
  static const _names = {
    LocationNext.categories: "Prüfkategorien",
    LocationNext.images: "Fotos",
    LocationNext.informations: "Infos"
  };
  static Map<LocationNext, Widget Function(BuildContext)> _views = {
    LocationNext.categories: (c) => Text('todo'), //TODO
    LocationNext.images: (c) => Text('todo'), //TODO
    LocationNext.informations: (c) => Text('todo'), //TODO
  };

  String? get name => _names[this];
  Widget? view(context) => _views[this]?.call(context);

  void open(BuildContext context, InspectionLocation inspectionLocation) {
    Provider.of<LocationModel>(context, listen: false)
        .open(this, inspectionLocation, context);
  }
}

class LocationModel with ChangeNotifier {
  final Backend _b = Backend();

  Future<List<InspectionLocation>> get allLocations async =>
      _b.getAllInspectionLocationsForCurrentUser();

  void open(LocationNext locationNext, InspectionLocation inspectionLocation,
      BuildContext context) {
    var v = locationNext.view(context);
    if (v != null) {
      Navigator.of(context).push(MaterialPageRoute(builder: (context) => v));
    }
  }
}
