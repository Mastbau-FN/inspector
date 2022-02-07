import 'package:MBG_Inspektionen/backend/api.dart';
import 'package:MBG_Inspektionen/classes/data/checkpoint.dart';
import 'package:MBG_Inspektionen/classes/imageData.dart';
import 'package:MBG_Inspektionen/helpers/toast.dart';
import 'package:MBG_Inspektionen/pages/imagesPage.dart';
import 'package:flutter/material.dart';
import 'package:MBG_Inspektionen/classes/data/checkpointdefect.dart';
import 'package:MBG_Inspektionen/classes/data/inspection_location.dart';
import 'package:MBG_Inspektionen/classes/listTileData.dart';
import 'package:MBG_Inspektionen/pages/dropdownPage.dart';
import 'package:MBG_Inspektionen/pages/location.dart';
import 'package:provider/provider.dart';

import 'data/checkcategory.dart';

abstract class WithImgHashes {
  List<String>? imagehashes = []; //should not be used
  Stream<ImageData?> mainImage = Stream.value(null);
  Stream<ImageData?> previewImage = Stream.value(null);
  List<Stream<ImageData?>>? image_streams = [];
  //Null Function() onNextImageLoaded = () {};
}

/// interface that all our models need to use to handle data like e.g. [InspectionLocation]
abstract class Data implements WithImgHashes {
  String get title;
  String? get subtitle => null;

  String? id;

  /// an optional extra Widget, to display extra data (currently only used by [CheckPointDefect] to show the urgency)
  Widget? get extra => null;

  Map<String, dynamic> toJson();
  Map<String, dynamic> toSmallJson();

  //XXX: sadly https://github.com/dart-lang/language/issues/356
  static T? fromJson<T extends Data?>(Map<String, dynamic> map) {
    //whacker workaround
    //XXX: alle subclassen müssen hier eingetragen werden
    switch (typeOf<T>()) {
      case InspectionLocation:
        return InspectionLocation.fromJson(map) as T;
      case CheckCategory:
        return CheckCategory.fromJson(map) as T;
      case CheckPoint:
        return CheckPoint.fromJson(map) as T;
      case CheckPointDefect:
        return CheckPointDefect.fromJson(map) as T;
      default:
        return null;
    }
  }
}

mixin WithLangText on Data {
  String? langText;
}

mixin WithAuthor on Data {
  String? get author;
}

/// this class must be implemented by all models for the main pages like e.g. [LocationModel]
class DropDownModel<ChildData extends WithLangText, ParentData extends Data?>
    extends ChangeNotifier {
  /// could be used for the scaffold appbar title
  String get title => currentData?.title ?? "root";

  ParentData currentData;

  DropDownModel(this.currentData);

  /// returns a [List] of all the [Data] for this Model
  Future<List<ChildData>> get all => Backend().getNextDatapoint(currentData);

  /// a [List] which all the actions that could be made for a specific DropDown
  List<MyListTileData> get actions {
    // TODO: implement actions
    throw UnimplementedError();
  }

  void update(ChildData data, txt) async {
    data.langText = txt;
    showToast(await Backend().update(data) ??
        "we sent the request but we didnt get any response");
    notifyListeners();
  }

  /// when pressed on a tile in the [DropDownPage] this will be invoked
  void open(
    BuildContext context,
    ChildData data,
    MyListTileData tiledata,
  ) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (newcontext) => Text("${tiledata.title} not yet implemeted"),
    ));
  }

  /*
  ///used by the backend to inject when a new image was succesfully loaded 
  Null data_onNextImageLoaded() {
    notifyListeners();
  }
  */

  ////adding a new [DataT], if this is not null the DropDown will create a new floatingactionbutton
  /// for adding new [DataT] to this level (or other additional functionality)
  Widget? floatingActionButton = null;
}

Widget nextModel<ChildData extends WithLangText, ParentData extends Data?,
        DDModel extends DropDownModel<ChildData, ParentData>>(DDModel child) =>
    ChangeNotifierProvider<DDModel>.value(
      value: child,
      child: DropDownPage<ChildData, ParentData, DDModel>(),
    );

Widget standard_statefulImageView<ChildData extends WithLangText,
            DDModel extends DropDownModel<ChildData, Data?>>(
        ChildData data, DDModel model) =>
    ChangeNotifierProvider<DDModel>.value(
      value: model,
      child: Builder(builder: (context) {
        return Consumer<DDModel>(builder: (context, model, child) {
          return ImagesPage.streamed(
            imageStreams: data.image_streams,
            //s ?.map((e) => e.asBroadcastStream())
            // .toList(),
            onNewImages: (files) =>
                Backend().uploadFiles(data, files).then((value) {
              model.notifyListeners();
              if (value != null) showToast(value);
              return value;
            }),
            onStar: (hash) => Backend()
                .setMainImageByHash(data, hash.toString())
                .then((value) {
              if (value != null && value != "") showToast(value);
              model.notifyListeners();
              return value;
            }),
          );
        });
      }),
    );

Type typeOf<T>() => T;
typedef BuilderT = Widget Function(BuildContext);
