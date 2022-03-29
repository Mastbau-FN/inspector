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
  static T? fromJson<T extends Data>(Map<String, dynamic> map) {
    //whacker workaround
    //XXX: alle subclassen müssen hier eingetragen werden
    switch (typeOf<T>()) {
      case InspectionLocation:
        return InspectionLocation.fromJson(map) as T?;
      case CheckCategory:
        return CheckCategory.fromJson(map) as T?;
      case CheckPoint:
        return CheckPoint.fromJson(map) as T?;
      case CheckPointDefect:
        return CheckPointDefect.fromJson(map) as T?;
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
  String? currentlyChosenChildId;
  void chooseChild(ChildData? child, {bool notify = false}) {
    currentlyChosenChildId = child?.id;
    if (notify) notifyListeners();
  }

  Future<ChildData?> get currentlyChosenChildData async {
    debugPrint('getting ${currentlyChosenChildId}');
    if (currentlyChosenChildId == null) return null;
    List<ChildData?> alln = await all;
    return alln.firstWhere(
      (child) {
        debugPrint('comparing ${child?.id} to ${currentlyChosenChildData}');
        return child?.id == currentlyChosenChildId;
      },
      orElse: () => null,
    );
  }
  // int? _currentlyChosenChildDataIndex;
  // // ChildData? _currentlyChosenChildData;
  // int? get currentlyChosenChildDataIndex => _currentlyChosenChildDataIndex;
  // void set currentlyChosenChildDataIndex(int? index) {
  //   if (index != currentlyChosenChildDataIndex) {
  //     _currentlyChosenChildDataIndex = index;
  //     notifyListeners();
  //   }
  // }

  // Future<ChildData?> get currentlyChosenChildData async =>
  //     (currentlyChosenChildDataIndex ?? -1) > 0
  //         ? (await all)[currentlyChosenChildDataIndex!]
  //         : null;

  void set currentlyChosenChildData(Future<ChildData?> data) {
    data.then(chooseChild);
  }

  // Future<void> _currentlyChosenChildDataHelper(ChildData? data) async {
  //   if (data != await currentlyChosenChildData) {
  //     if (data != null) {
  //       int index = (await all)
  //           .indexWhere(((element) => element.id == data.id)); //-1, meh
  //       currentlyChosenChildDataIndex = index;
  //       notifyListeners();
  //     }
  //     ;
  //   } else {
  //     currentlyChosenChildDataIndex = null;
  //     notifyListeners();
  //   }
  // }

  Future<T?> updateCurrentChild<T>(
      Future<T> Function(ChildData) updater) async {
    ChildData? childD = await currentlyChosenChildData;
    if (childD != null) {
      T ret = await updater(childD);
      notifyListeners();
      return ret;
    }
  }

  DropDownModel(this.currentData);

  /// returns a [List] of all the [Data] for this Model
  Future<List<ChildData>> get all => Backend().getNextDatapoint(currentData);

  /// a [List] which all the actions that could be made for a specific DropDown
  List<MyListTileData> get actions {
    //must be implemented by subclasses
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
        DDModel extends DropDownModel<ChildData, Data?>>(DDModel model) =>
    ChangeNotifierProvider<DDModel>.value(
        value: model,
        // child: ChangeNotifierProvider<ChildData>.value(
        //   value: data,
        child: Builder(builder: (context) {
          return Consumer<DDModel>(builder: (context, model, child) {
            // return Consumer<ChildData>(builder: (context, data, child) {
            return FutureBuilder<ChildData?>(
                future: model.currentlyChosenChildData,
                builder: (context, snapshot) {
                  return ImagesPage.streamed(
                    // TODO hier klappt scheinbar irgendwas von #36 noch nicht... eigtl müsste das ja neu gebaut werden wenn der consumer hier durch das notifylistners getriggert wird
                    // und es wird auch neu gebaut!
                    // deshalb ist wahrscheinlich einfach nur, dass das data (und damit data.image_streams) nicht erneuert wird...
                    imageStreams: (snapshot.data)?.image_streams,
                    //s ?.map((e) => e.asBroadcastStream())
                    // .toList(),
                    onNewImages: (files) => model
                        .updateCurrentChild(
                            (data) => Backend().uploadFiles(data, files))
                        .then((value) {
                      if (value != null) showToast(value);
                      return value;
                    }),
                    onStar: (hash) => model
                        .updateCurrentChild((data) =>
                            Backend().setMainImageByHash(data, hash.toString()))
                        .then((value) {
                      if (value != null && value != "") showToast(value);
                      return value;
                    }),
                    onDelete: (hash) => model
                        .updateCurrentChild((data) =>
                            Backend().deleteImageByHash(hash.toString()))
                        .then((value) {
                      if (value != null && value != "") showToast(value);
                      return value;
                    }),
                  );
                });
          });
        })
        // ;
        // }),
        // ),
        );

Type typeOf<T>() => T;
typedef BuilderT = Widget Function(BuildContext);
