import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mastbau_inspector/backend/api.dart';
import 'package:mastbau_inspector/classes/checkcategory.dart';
import 'package:mastbau_inspector/classes/inspection_location.dart';
import 'package:mastbau_inspector/classes/listTileData.dart';
import 'package:provider/provider.dart';

enum CategoryNext { categories, images, informations }

extension CategoryNextE on CategoryNext {
  static Map<CategoryNext, MyListTileData> _data = {
    CategoryNext.categories: MyListTileData(
      title: "Prüfpunkte",
      nextBuilder: (c) => Text('todo'),
    ),
    CategoryNext.images: MyListTileData(
      title: "Fotos",
      nextBuilder: (c) => Text('todo'),
    ),
    CategoryNext.informations: MyListTileData(
      title: "Kommentar",
      nextBuilder: (c) => Text('todo'),
    ),
  };

  String? get name => _data[this]?.title;
  Widget? view(context) => _data[this]?.nextBuilder.call(context);

  void open(BuildContext context, CheckCategory cat) {
    Provider.of<CategoryModel>(context, listen: false).open(this, cat, context);
  }
}

class CategoryModel with ChangeNotifier {
  final Backend _b = Backend();

  Future<List<CheckCategory>> get all async => []; //TODO

  void open(
      CategoryNext locationNext, CheckCategory cat, BuildContext context) {
    var v = locationNext.view(context);
    if (v != null) {
      Navigator.of(context).push(MaterialPageRoute(builder: (context) => v));
    }
  }
}
