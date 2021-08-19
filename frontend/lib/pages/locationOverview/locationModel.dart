import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mastbau_inspector/backend/api.dart';
import 'package:mastbau_inspector/classes/inspection_location.dart';
import 'package:mastbau_inspector/classes/listTileData.dart';
import 'package:mastbau_inspector/pages/checkcategories/checkcategoriesModel.dart';
import 'package:mastbau_inspector/pages/checkcategories/checkcategoriesView.dart';
import 'package:provider/provider.dart';

enum LocationNext { categories, images, informations }

extension LocationNextE on LocationNext {
  static Map<LocationNext, MyListTileData> _data = {
    LocationNext.categories: MyListTileData(
      title: "Prüfkategorien",
      nextBuilder: (c) => CategoriesView(
        location: InspectionLocation(
          pjNr: 7,
          pjName: 'test',
          stONr: 7,
        ),
      ),
    ),
    LocationNext.images: MyListTileData(
      title: "Fotos",
      nextBuilder: (c) => Text('todo'),
    ),
    LocationNext.informations: MyListTileData(
      title: "Infos",
      nextBuilder: (c) => Text('todo'),
    ),
  };

  String? get name => _data[this]?.title;
  Widget? view(context) => _data[this]?.nextBuilder(context);

  void open(BuildContext context, InspectionLocation inspectionLocation) {
    Provider.of<LocationModel>(context, listen: false)
        .open(this, inspectionLocation, context);
  }
}

class LocationModel with ChangeNotifier {
  final Backend _b = Backend();

  Future<List<InspectionLocation>> get all async =>
      _b.getAllInspectionLocationsForCurrentUser();

  void open(LocationNext locationNext, InspectionLocation inspectionLocation,
      BuildContext context) {
    var v = locationNext.view(context);
    if (v != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (newcontext) => ChangeNotifierProvider<CategoryModel>.value(
            value: Provider.of<CategoryModel>(context),
            child: v,
          ),
        ),
      );
    }
  }
}
