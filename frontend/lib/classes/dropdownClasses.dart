import 'package:MBG_Inspektionen/backend/api.dart';
import 'package:MBG_Inspektionen/backend/local.dart';
import 'package:MBG_Inspektionen/classes/data/checkpoint.dart';
import 'package:MBG_Inspektionen/classes/imageData.dart';
import 'package:MBG_Inspektionen/helpers/toast.dart';
import 'package:MBG_Inspektionen/options.dart';
import 'package:MBG_Inspektionen/pages/imagesPage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:MBG_Inspektionen/classes/data/checkpointdefect.dart';
import 'package:MBG_Inspektionen/classes/data/inspection_location.dart';
import 'package:MBG_Inspektionen/classes/listTileData.dart';
import 'package:MBG_Inspektionen/pages/dropdownPage.dart';
import 'package:MBG_Inspektionen/pages/location.dart';
import 'package:image/image.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../backend/offlineProvider.dart';
import '../generated/l10n.dart';
import 'data/checkcategory.dart';

abstract class WithImgHashes {
  @JsonKey(name: 'mainhash')
  String? mainhash;
  @JsonKey(name: 'images')
  List<String>? imagehashes; //should not be used
  @JsonKey(includeToJson: false, includeFromJson: false)
  Future<ImageData?> mainImage = Future.value(null);
  @JsonKey(includeToJson: false, includeFromJson: false)
  List<Future<ImageData?>>? imageFutures;
  @JsonKey(includeToJson: false, includeFromJson: false)
  Future<ImageData?> previewImage = Future.value(null);
}

/// interface that all our models need to use to handle data like e.g. [InspectionLocation]
@JsonSerializable(includeIfNull: false)
abstract class Data implements WithImgHashes {
  String get title;
  String? get subtitle => null;

  static idFromJson(String? id) =>
      id ?? LOCALLY_ADDED_PREFIX + UniqueKey().hashCode.toRadixString(36);
  static idToJson(String id) => id;
  @JsonKey(fromJson: Data.idFromJson, toJson: Data.idToJson, name: 'local_id')
  late String id;

  /// an optional extra Widget, to display extra data (currently only used by [CheckPointDefect] to show the urgency)
  List<Widget> extras({BuildContext? context}) => const [];

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

mixin WithOffline on Data {
  @JsonKey(name: 'offline')
  // ignore: non_constant_identifier_names
  bool? forceOffline_nullable = false;

  @JsonKey(name: 'parent_local_id')
  String? parentId;

  @JsonKey(includeToJson: false, includeFromJson: false)
  bool get forceOffline => forceOffline_nullable ?? false;

  // @JsonKey(ignore: true)
  set forceOffline(bool? next) {
    forceOffline_nullable = next ?? false;
  }
}

/// this class must be implemented by all models for the main pages like e.g. [LocationModel]
class DropDownModel<ChildData extends WithLangText,
        ParentData extends WithOffline?> extends ChangeNotifier
    implements KnowsNext<ChildData> {
  /// could be used for the scaffold appbar title
  String get title => currentData?.title ?? "root";

  ParentData currentData;
  String? currentlyChosenChildId;
  void chooseChild(ChildData? child, {bool notify = false}) {
    currentlyChosenChildId = child?.id;
    debugPrint('chose child ${child?.title} (id: ${child?.id})');
    if (notify) notifyListeners();
  }

  Stream<ChildData?> _getCurrentlyChosenChildData(
      // ignore: unused_element
      {int? remainingTries}) async* {
    // int reloadTries = (remainingTries ?? Options().reloadTries) - 1;
    debugPrint('getting $currentlyChosenChildId');
    await for (var a in all) {
      if (currentlyChosenChildId == null) yield null;

      try {
        yield a.firstWhere((child) {
          // debugPrint('comparing ${child?.id} to ${currentlyChosenChildId}');
          return child.id == currentlyChosenChildId;
        });
      } catch (e) {
        // yield await _getCurrentlyChosenChildData(
        //     remainingTries:
        //         reloadTries); //refetch //XXX: this will result in a stack overflow if no data can be retreived
      }
    }
  }

  Future<ChildData?> get currentlyChosenChildData => _getCurrentlyChosenChildData()
      .last; //XXX: locally mirrored (.first) should suffice, but as this doenst work perfectly rn we rather use .last to override with online data
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

  set currentlyChosenChildData(Future<ChildData?> data) {
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
      // await Future.delayed(Duration(milliseconds: 3000));
      // notifyListeners();
      return ret;
    }
    return null;
  }

  DropDownModel(this.currentData);

  bool get isOffline => currentData?.forceOffline ?? false;

  /// returns a [List] of all the [Data] for this Model
  Stream<List<ChildData>> get all => API().getNextDatapoint<ChildData,
          ParentData>(
      currentData); //TO/DO: not use last, but buffer latest element somehow if even possible?

  /// a [List] which all the actions that could be made for a specific DropDown
  List<MyListTileData> get actions {
    //must be implemented by subclasses
    throw UnimplementedError();
  }

  void update(ChildData data, {String? langText}) async {
    if (langText != null) data.langText = langText;
    _maybeShowToast(await API().update(data, caller: currentData) ??
        S.current.didntGetAnyResponseAfterSend);
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
  Widget? floatingActionButton;

  @override
  DropDownModel<WithLangText, WithOffline> generateNextModel(ChildData data) {
    // XXX: this class itself should be abstract..
    throw UnimplementedError();
  }
}

abstract class KnowsNext<ChildData extends Data> {
  KnowsNext generateNextModel(ChildData data);
}

Widget nextModel<
        ChildData extends WithLangText,
        ParentData extends WithOffline?,
        DDModel extends DropDownModel<ChildData, ParentData>>(DDModel child) =>
    ChangeNotifierProvider<DDModel>(
      create: (context) => child,
      child: DropDownPage<ChildData, ParentData, DDModel>(),
    );

void _maybeShowToast(String? message) {
  if (kDebugMode) if (message != null && message != "") {
    showToast(message);
  }
}

// ignore: non_constant_identifier_names
Widget standard_statefulImageView<ChildData extends WithLangText,
            DDModel extends DropDownModel<ChildData, WithOffline?>>(
        DDModel model, ChildData? data) =>
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
                  var hasMain = snapshot.data?.mainImage != null &&
                      (snapshot.data!.mainhash ??
                              Options().no_image_placeholder_name) !=
                          Options().no_image_placeholder_name;
                  return Stack(
                    children: [
                      ImagesPage.futured(
                        hasMainImage: hasMain,
                        futureImages: [
                          if (hasMain) snapshot.data!.mainImage,
                          ...?((snapshot.data ?? data)?.imageFutures)
                        ],
                        onNewImages: (files) async {
                          showToast(
                              S.of(context).newImageSendingThisMayTakeASec);
                          var value = await model.updateCurrentChild(
                            (data) async {
                              var ret = await API().uploadNewImagesOrFiles(
                                  data, files,
                                  caller: model.currentData, forceUpdate: true);
                              // await Future.delayed(Duration(seconds: 5));
                              return ret;
                            },
                          );

                          _maybeShowToast(value);
                          return value;
                        },
                        onStar: (hash) {
                          showToast(
                              S.of(context).settingMainImageThisMayTakeASec);
                          model
                              .updateCurrentChild((data) => API()
                                  .setMainImageByHash(data, hash.toString(),
                                      caller: model.currentData,
                                      forceUpdate: true))
                              .then((value) {
                            _maybeShowToast(value);
                            return value;
                          });
                        },
                        onDelete: (hash) {
                          showToast(S.of(context).deletingImageThisMayTakeASec);
                          model
                              .updateCurrentChild((data) => API()
                                  .deleteImageByHash(data, hash.toString(),
                                      caller: model.currentData,
                                      forceUpdate: true))
                              .then((value) {
                            _maybeShowToast(value);
                            return value;
                          });
                        },
                        onShare: (hash) async {
                          var files = await Future.wait(
                              [await localFile(hash.toString())]
                                  .map(
                                    (e) async => XFile.fromData(
                                      Uint8List.fromList(
                                        encodePng(
                                          decodeImage(await e.readAsBytes())!,
                                        ),
                                      ),
                                      name:
                                          'mbg_${hash.hashCode.toRadixString(36)}.png',
                                      mimeType: 'image/png',
                                    ),
                                  )
                                  .toList());
                          await Share.shareXFiles(files, text: 'Internes Bild');
                        },
                      ),
                      if (snapshot.connectionState == ConnectionState.waiting)
                        Card(
                          child:
                              Text(S.of(context).pleaseWaitDataIsBeeingSynced),
                        ),
                    ],
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
