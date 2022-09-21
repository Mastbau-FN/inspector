import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../classes/dropdownClasses.dart';
import '../generated/l10n.dart';
import '../helpers/toast.dart';
import '../options.dart';
import '../pages/checkcategories.dart';
import '../pages/location.dart';
import 'api.dart';
import 'helpers.dart' as Helper;
import 'offlineProvider.dart' /*as OP*/ show storeJson, getJson;

class FailedRequestmanager {
  Future<bool> retryFailedrequests() async {
    try {
      await API().tryNetwork(requestType: Helper.SimulatedRequestType.PUT);
    } catch (e) {
      showToast(S.current.noViableInternetConnection);
      return false;
    }
    final failedReqs = await API().local.getAllFailedRequests() ?? [];
    bool success = true;
    for (final reqd in failedReqs) {
      final docID = reqd.item1;
      final rd = reqd.item2;
      if (rd != null)
        try {
          rd.logIfFailed = false;
          final res = await API().remote.postJSON(rd);
          //nur 200er als ok einstufen
          if (res!.statusCode ~/ 100 == 2) {
            API().local.failedRequestWasSuccessful(docID);
          } else {
            success = false;
            //TODO: what todo here?
            break;
          }
        } catch (e) {
          debugPrint('failed to retry request: $e');
          success = false;
        }
    }
    return success;
  }

  /// recursivle cache all elements that underly the caller
  Future<bool> loadAndCacheAll<
      ChildData extends WithLangText,
      ParentData extends WithOffline,
      DDModel extends DropDownModel<ChildData, ParentData>>(
    DDModel caller,
    int depth, {
    String? name,
    String? parentID,
  }) async {
    // base-case: CheckPointDefects have no children
    // if (typeOf<ChildData>() == CheckPointDefect) return true;//XXX: shit, this generic bums wont work
    if (depth == 0) return true;
    depth--;
    try {
      //fail early if no connection
      await API().tryNetwork(requestType: Helper.SimulatedRequestType.GET);
      //get all children, this will also cache them internally
      var children = await caller.all.last;
      var didSucceed = await Future.wait(children.map(
        (child) async {
          if (Options().debugLocalMirror) {
            name = '$name-> ${child.title}';
            debugPrint('__1234 got $depth: $name');
          }

          if (depth == 0)
            return true; //base-case as to not call generateNextModel
          bool childSucceeded = await loadAndCacheAll(
              caller.generateNextModel(child), depth,
              name: name, parentID: caller.currentData.id);
          return childSucceeded;
        },
      ));

      //if all children succeeded recursive calling succeeded
      bool success = didSucceed.every((el) => el);
      if (success) {
        caller.currentData.forceOffline = true;
        if (parentID == null) return false;

        try {
          var id =
              await API().local.storeData(caller.currentData, forId: parentID);
          if (Options().debugLocalMirror)
            debugPrint(
                '_32 loading. ${depth + 1} stored : $id  ${caller.currentData.title}');
        } catch (e) {
          return false;
        }
      }

      return success;
    } catch (error) {
      debugPrint('failed! ${depth + 1}');
      showToast(error.toString() + "\n" + S.current.tryAgainLater_noNetwork);
      return false; //failed
    }
  }

  ///this is used to remove all no-cloud icons from every datapoint aka set every [forceOffline] of [WithOffline] [Data]s
  setOnlineTotal(BuildContext context) async {
    final model = Provider.of<LocationModel>(context, listen: false);
    final locations = await model.all.last;
    for (final loc in locations) {
      final caller = CategoryModel(loc);
      await setOnlineAll(
        caller,
        3,
        name: caller.title,
        parentID: await API().rootID,
      );
    }
  }

  Future setOnlineAll<
      ChildData extends WithLangText,
      ParentData extends WithOffline,
      DDModel extends DropDownModel<ChildData, ParentData>>(
    DDModel caller,
    int depth, {
    String? name,
    String? parentID,
  }) async {
    // base-case: CheckPointDefects have no children
    // if (typeOf<ChildData>() == CheckPointDefect) return true;//XXX: shit, this generic bums wont work
    if (depth == 0) return true;
    depth--;
    var children = await caller.all.last;
    caller.currentData.forceOffline = false;
    if (parentID != null)
      API().local.storeData(caller.currentData, forId: parentID);
    final nextid = caller.currentData.id;
    for (final child in children) {
      String _name = '$name -> ${child.title}';
      debugPrint('__12342 got $depth: $_name');
      if (depth == 0) return; //base-case as to not call generateNextModel
      setOnlineAll(caller.generateNextModel(child), depth,
          name: _name, parentID: nextid);
    }
  }
}

class NewImages {
  Map<String, String?> localImageToRemoteImage_ = {};
  Future<Map<String, String?>> get() async {
    await load();
    return localImageToRemoteImage_;
  }

  set(Map<String, String?> map) async {
    localImageToRemoteImage_ = map;
    await store();
  }

  add(String local, String remote) async {
    return await addAll({local: remote});
  }

  addAll(Map<String, String?> map) async {
    await load();
    localImageToRemoteImage_.addAll(map);
    await store();
  }

  static const _IMGDOC_ = 'localImageToRemoteImageMap';
  store() => storeJson(_IMGDOC_, localImageToRemoteImage_);
  load() async => localImageToRemoteImage_ = await getJson(_IMGDOC_) ?? {};
}
