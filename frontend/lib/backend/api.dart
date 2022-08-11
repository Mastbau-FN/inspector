import 'dart:async';
import 'dart:io';

import 'package:MBG_Inspektionen/backend/local.dart';
import 'package:MBG_Inspektionen/backend/remote.dart';
import 'package:MBG_Inspektionen/classes/requestData.dart' show RequestData;
import 'package:MBG_Inspektionen/pages/checkcategories.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:MBG_Inspektionen/classes/dropdownClasses.dart';
import 'package:provider/provider.dart';
import '../generated/l10n.dart';
import '../helpers/toast.dart';
import '../pages/location.dart';
import '/classes/exceptions.dart';
import '/classes/user.dart';
import 'package:MBG_Inspektionen/options.dart';

import './helpers.dart' as Helper;

/// backend Singleton to provide all functionality related to the backend
class API {
  final remote = Remote();
  final local = LocalMirror();
  // MARK: internals

  static final API _instance = API._internal();
  factory API() => _instance;

  API._internal() {
    // init
  }

  User? _user;

  /// returns the currently logged in [User], whether its already initialized or not.
  /// should be prefered over [_user], since it makes sure to have it initialized
  Future<User?> get _c_user async {
    if (_user != null) return _user;
    final user = await User.fromStore();
    _user = user;
    return _user;
  }

  // MARK: available Helpers

  /// checks whether a connection to the network is allowed
  /// throws [NoConnectionToBackendException] or [SocketException] if its not.
  Future tryNetwork({
    Duration? timeout,
    Helper.SimulatedRequestType? requestType,
  }) async {
    //check network
    var connection = await (Connectivity().checkConnectivity());
    if (connection == ConnectivityResult.none)
      throw NoConnectionToBackendException(S.current.noNetworkAvailable);
    if (connection == ConnectivityResult.mobile &&
        (!Options().canUseMobileNetworkIfPossible ||
            (requestType != Helper.SimulatedRequestType.GET &&
                !Options().useMobileNetworkForUpload) ||
            !Options().useMobileNetworkForDownload))
      throw NoConnectionToBackendException(S.current.mobileNetworkNotAllowed);
  }

  Future<String> get rootID async => (await user)!.name;

  // MARK: API

  /// checks whether the given user is currently logged in
  Future<bool> isUserLoggedIn(User user) async => user == await _c_user;

  /// checks whether anyone is currently logged in
  Future<bool> get isAnyoneLoggedIn async => await _c_user != null;

  /// gets the currently logged in [DisplayUser], which is the current [User] but with removed [User.pass] to avoid abuse
  Future<DisplayUser?> get user async => await _c_user;

  /// login a [User] by checking if he exists in the remote database
  Future<DisplayUser?> login(User user) async {
    final Helper.SimulatedRequestType requestType =
        Helper.SimulatedRequestType.GET;
    // if user is already logged in
    if (await isUserLoggedIn(user)) return this.user;
    try {
      final _user = await remote.login(user);
      await _user?.store();
      return this.user;
    } catch (e) {
      logout();
      rethrow;
    }
  }

  /// removes the credentials from local storage and therefors logs out
  Future logout() async {
    (await _c_user)?.unstore();
    _user = null;
    debugPrint('user logged out');
  }

  /// gets all the [ChildData]points for the given [ParentData]
  /// if no [ParentData] is given it defaults to root
  Stream<List<ChildData>>
      getNextDatapoint<ChildData extends Data, ParentData extends WithOffline?>(
    ParentData data,
  ) async* {
    final Helper.SimulatedRequestType requestType =
        Helper.SimulatedRequestType.GET;
  }

  /// sets a new [DataT]
  Future<DataT?> setNew<DataT extends Data>(
    DataT? data, {
    Data? caller,
  }) async {
    final Helper.SimulatedRequestType requestType =
        Helper.SimulatedRequestType.PUT;
  }

  /// updates a [DataT] and returns the response
  Future<String?> update<DataT extends Data>(
    DataT? data, {
    Data? caller,
    bool forceUpdate = false,
  }) async {
    final Helper.SimulatedRequestType requestType =
        Helper.SimulatedRequestType.PUT;
  }

  /// deletes a [DataT] and returns the response
  Future<String?> delete<DataT extends Data>(
    DataT? data, {
    Data? caller,
  }) async {
    final Helper.SimulatedRequestType requestType =
        Helper.SimulatedRequestType.DELETE;
  }

  /// deletes an image specified by its hash and returns the response
  Future<String?> deleteImageByHash(String hash) async {
    //TODO: #211
    final Helper.SimulatedRequestType requestType =
        Helper.SimulatedRequestType.DELETE;
  }

  /// sets an image specified by its hash as the new main image
  Future<String?> setMainImageByHash<DataT extends Data>(
    DataT? data,
    String hash, {
    Data? caller,
    bool forceUpdate = false,
  }) async {
    final Helper.SimulatedRequestType requestType =
        Helper.SimulatedRequestType.PUT;
  }

  /// upload a bunch of images
  Future<String?> uploadFiles<DataT extends Data>(
    DataT data,
    List<XFile> files,
  ) async {
    final Helper.SimulatedRequestType requestType =
        Helper.SimulatedRequestType.PUT;
    ////ODO: we currently store everything n the root dir, but we want to add into specific subdir that needs to be extracted from rew.body.E1 etc
  }

  Future<bool> retryFailedrequests() async {
    try {
      await tryNetwork(requestType: Helper.SimulatedRequestType.PUT);
    } catch (e) {
      showToast(S.current.noViableInternetConnection);
      return false;
    }
    final failedReqs = await local.getAllFailedRequests() ?? [];
    bool success = true;
    for (final reqd in failedReqs) {
      final docID = reqd.item1;
      final rd = reqd.item2;
      if (rd != null)
        try {
          rd.logIfFailed = false;
          final res = await remote.post_JSON(rd);
          //nur 200er als ok einstufen
          if (res!.statusCode == 200) {
            local.failedRequestWasSuccessful(docID);
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

  //TODO: das klappt zwar, aber das abspeichern selbst oder anzeigen nicht, wird aber OP liegen
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
      await tryNetwork(requestType: Helper.SimulatedRequestType.GET);
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
          bool child_succeeded = await loadAndCacheAll(
              caller.generateNextModel(child), depth,
              name: name, parentID: caller.currentData.id);
          return child_succeeded;
        },
      ));

      //if all children succeeded recursive calling succeeded
      bool success = didSucceed.every((el) => el);
      if (success) {
        caller.currentData.forceOffline = true;
        if (parentID == null) return false;

        try {
          var id = await local.storeData(caller.currentData, forId: parentID);
          if (Options().debugLocalMirror)
            debugPrint(
                '_32 loading. ${depth + 1} stored : ${id}  ${caller.currentData.title}');
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
        parentID: await rootID,
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
  }) async {}
}
