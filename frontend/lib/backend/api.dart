import 'dart:async';
import 'dart:io';

import 'package:MBG_Inspektionen/backend/local.dart';
import 'package:MBG_Inspektionen/backend/offlineProvider.dart';
import 'package:MBG_Inspektionen/backend/remote.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:MBG_Inspektionen/classes/dropdownClasses.dart';
import '../classes/imageData.dart';
import 'package:MBG_Inspektionen/l10n/locales.dart';
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
  // ignore: non_constant_identifier_names
  Future<User?> get _c_user async {
    if (_user != null) return _user;
    final user = await User.fromStore();
    _user = user;
    remote.injectUser(user);
    return _user;
  }

  bool? _dataPrefersCache(Data? data,
      {required Helper.SimulatedRequestType type}) {
    bool? itPrefersCache;
    //die simulated GET request senden keine daten (die für sync relevant sind), bei den anderen muss woanders entschieden werden ob an den server gesendet wird oder nicht
    // #292 dirtyfix
    // if (type == Helper.SimulatedRequestType.GET)
    try {
      itPrefersCache = (data as WithOffline).forceOffline;
    } catch (e) {}
    return itPrefersCache;
  }

  Stream<T> _run<R extends http.BaseResponse, T>({
    required FutureOr<T> Function() offline,
    required FutureOr<RequestAndParser<R, T>> Function() online,

    /// if given and [Options] is set accordingly this is called to merge offline with online data
    FutureOr<T> Function(T, T)? merge,

    /// a callback that is called if the online request fails, it gets passed the offline result as well as the request and the parser for online result
    ///
    /// e.g.:
    /// ```dart
    /// onlineFailedCB(T offlineResult, RequestAndParser<R, T> requestAndParser) async {
    ///   modifyReq(requestAndParser.rd);
    /// };
    /// ```
    FutureOr Function(T, RequestAndParser<R, T>)? onlineFailedCB,

    /// a callback that is called if the online request succeeds, it gets passed the online result
    /// keep in mind that this is called INSTEAD OF the normal logging
    ///
    /// e.g.:
    /// ```dart
    /// onlineFailedCB(T onlineResult) async {
    ///   cache(onlineResult);
    /// };
    /// ```
    FutureOr Function(T)? onlineSuccessCB,
    required Helper.SimulatedRequestType requestType,
    bool? itPrefersCache = false,
  }) {
    var controller = StreamController<T>();
    // late var canBeClosed; // = Future.delayed(Duration(seconds: 10), () => true);
    final _itPrefersCache = itPrefersCache ?? false;
    late T offlineRes;
    late T onlineRes;
    Future<bool> doOffline({bool orDontIf = false}) async {
      if (orDontIf) return false;
      return Future<T>(offline).then((value) {
        offlineRes = value;
        controller.add(offlineRes);
        return true;
      }, onError: (err) {
        if (err is NoImagePlaceholderException) return true;
        debugPrint('offline failed: ' + err.toString());
        return false;
      });
    }

    Future<RequestAndParser<R, T>>(online).then(
      (rap) async {
        // ignore: unused_local_variable
        late Object _latestErr;
        Future<bool?> doOnline(
            {bool orDontIf = false, bool? forceOnline}) async {
          try {
            if (orDontIf) {
              throw BackendCommunicationException(
                  'we prefer the local variant');
            }

            await tryNetwork(requestType: requestType);
            final bool wantsmerged =
                merge != null && Options().canBeOffline && !_itPrefersCache;
            final bool wantsonline =
                forceOnline ?? (requestType != Helper.SimulatedRequestType.GET);
            if (wantsonline || wantsmerged) {
              // TODO: this is a very dirty fix for #225, would be better to make sure the online variant always comes after the offline one or something, by introducing a custom stream controller, but nah
              await Future.delayed(Duration(milliseconds: 100));
              final res = await remote.postJSON(rap.rd);
              onlineRes = await rap.parser(res as R);
              if (wantsonline) controller.add(onlineRes);
              if (wantsmerged)
                controller.add(await merge(offlineRes, onlineRes));
            } else
              return null;
          } catch (e) {
            _latestErr = e;
            return false;
          }
          return true;
        }

        onlineFailedProcedure() async {
          bool log = rap.rd.logIfFailed ??
              (requestType != Helper.SimulatedRequestType.GET);
          if (onlineFailedCB != null)
            await onlineFailedCB(offlineRes, rap);
          else if (log) {
            await local.logFailedReq(rap.rd);
          }
        }

        onlineSuccessProcedure() async {
          if (onlineSuccessCB != null) await onlineSuccessCB(onlineRes);
          //XXX: vllt das onsuccess lieber dem rd übergeben?
        }

        List<bool?> _success = await Future.wait([
          doOnline(
            orDontIf: _itPrefersCache,
            forceOnline: Options().canBeOffline ? null : true,
          ),
          doOffline(
            orDontIf: !Options().canBeOffline,
          )
        ], eagerError: false);

        bool? onlineSucc = _success[0];
        bool? offlineSucc = _success[1];
        if (!(onlineSucc ?? false) && !offlineSucc!) {
          onlineSucc = await doOnline(forceOnline: true);
        }
        controller.close();
        if (onlineSucc != null)
          onlineSucc ? onlineSuccessProcedure() : onlineFailedProcedure();
      },
    );
    return controller.stream;
  }

  // MARK: available Helpers

  /// checks whether a connection to the network is allowed
  /// throws [NoConnectionToBackendException] or [SocketException] if its not.
  Future tryNetwork({
    Duration? timeout,
    required Helper.SimulatedRequestType requestType,
  }) async {
    //check network
    if (Options().forceOffline)
      throw NoConnectionToBackendException(
          S.current!.nonetwork_forcedOfflineMode);
    final connection = await (Connectivity().checkConnectivity());
    if (connection == ConnectivityResult.none)
      throw NoConnectionToBackendException(S.current!.noNetworkAvailable);
    if (connection == ConnectivityResult.mobile &&
        ((requestType != Helper.SimulatedRequestType.GET &&
                !Options().useMobileNetworkForUpload) ||
            !Options().useMobileNetworkForDownload))
      throw NoConnectionToBackendException(S.current!.mobileNetworkNotAllowed);
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
    if (await isUserLoggedIn(user)) return this.user;
    try {
      final _user = await remote.login(user);
      await _user!.store();
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
    final requestType = Helper.SimulatedRequestType.GET;
    assert((await API().user) != null,
        S.current!.wontFetchAnythingSinceNoOneIsLoggedIn);

    Future<List<ChildData>> merge(
        List<ChildData> cached, List<ChildData> upstream) async {
      try {
        cached.retainWhere((element) => (element as WithOffline).forceOffline);
        var cachedIds = cached.map((element) => element.id).toList();
        upstream.retainWhere((element) => !cachedIds.contains(element.id));
        upstream.addAll(cached);
        return upstream;
      } catch (e) {
        debugPrint("error merging data: " + e.toString());
        return cached;
      }
    }

    yield* _run(
      itPrefersCache: _dataPrefersCache(data, type: requestType),
      offline: () => local.getNextDatapoint(data),
      online: () => remote.getNextDatapoint(data),
      onlineSuccessCB: (childDatas) => childDatas.forEach((childData) async {
        await local.storeData(
          childData,
          forId: data?.id ?? await API().rootID,
          //TODO: uncomment this as soon as offline can mirror everything well #211
          // overrideMode: OverrideMode.abortIfExistent,
        );
      }),
      requestType: requestType,
      merge: merge,
    );
  }

  /// sets a new [DataT]
  Future<DataT?> setNew<DataT extends Data>(
    DataT? data, {
    Data? caller,
  }) async {
    final requestType = Helper.SimulatedRequestType.PUT;
    try {
      (data as WithOffline).parentId = caller?.id ?? await rootID;
    } catch (e) {}
    if (data == null) return null;
    // data.id = null;
    return _run(
      itPrefersCache: (caller as WithOffline?)
          ?.forceOffline, // _dataPrefersCache(caller, type: requestType),
      offline: () => local.setNew(data, caller: caller),
      online: () => remote.setNew(data),
      onlineSuccessCB: (response) async {
        //toDo: etwas besser wäre das mit zu serialisieren und wenn der request bei retryFailedRequests später erfolgreich ist das auszuführen
        //aber unser hotfix wird sein beim erflogreichen retryFailedRequests alle lokalen daten zu entfernen (auch im die app-dateien-größe auf dauer kompakt zu halten)
        await deleteData(
          data.id,
          parentId: caller?.id ?? await API().rootID,
        );
      },
      onlineFailedCB: (DataT? data, rap) async {
        rap = remote.setNew<DataT>(data);
        await local.logFailedReq(rap.rd);
      },
      requestType: requestType,
    ).last;
  }

  /// updates a [DataT] and returns the respons
  Future<String?> update<DataT extends Data>(
    DataT? data, {
    Data? caller,
    bool forceUpdate = false,
  }) async {
    final requestType = Helper.SimulatedRequestType.PUT;
    return _run(
      itPrefersCache: _dataPrefersCache(caller, type: requestType),
      offline: () => local.update(data, caller: caller),
      online: () => remote.update(data),
      requestType: requestType,
    ).last;
  }

  /// deletes a [DataT] and returns the response
  Future<String?> delete<DataT extends Data>(
    DataT? data, {
    Data? caller,
  }) async {
    final requestType = Helper.SimulatedRequestType.DELETE;
    return _run(
      itPrefersCache: _dataPrefersCache(caller, type: requestType),
      offline: () => local.delete(data, caller: caller),
      online: () => remote.delete(data),
      requestType: requestType,
    ).last;
  }

  /// gets image specified by its hash
  Future<ImageData?> getImageByHash(String hash,
      {bool compressed = false}) async {
    final requestType = Helper.SimulatedRequestType.GET;
    return _run(
      itPrefersCache:
          false, //! wir nehmen immer lieber lokale bilder, bandbreite und so
      offline: () => local.getImageByHash(hash, compressed: compressed),
      online: () => remote.getImageByHash(hash, compressed: compressed),
      requestType: requestType,
    ).last;
  }

  /// deletes an image specified by its hash and returns the response
  Future<String?> deleteImageByHash<DataT extends Data>(
    DataT? data,
    String hash, {
    Data? caller,
    bool forceUpdate = false,
  }) async {
    final requestType = Helper.SimulatedRequestType.PUT;
    if (hash == data?.mainhash) {
      data?.mainhash = null;
      debugPrint('deleted mainhash');
      await update(data, caller: caller, forceUpdate: forceUpdate);
    }
    return _run(
      itPrefersCache: _dataPrefersCache(data, type: requestType),
      // offline: () => local.setMainImageByHash(
      //   data,
      //   hash,
      //   caller: caller,
      //   forceUpdate: forceUpdate,
      // ),
      offline: () => local.deleteImageByHash(data, hash,
          caller: caller, forceUpdate: forceUpdate),
      online: () => remote.deleteImageByHash(hash),
      requestType: requestType,
    ).last;
  }

  // sets an image specified by its hash as the new main image
  Future<String?> setMainImageByHash<DataT extends Data>(
    DataT? data,
    String mainhash, {
    Data? caller,
    bool forceUpdate = false,
  }) async {
    final requestType = Helper.SimulatedRequestType.PUT;
    return _run(
      itPrefersCache: _dataPrefersCache(data, type: requestType),
      offline: () => local.setMainImageByHash(
        data,
        mainhash,
        caller: caller,
        forceUpdate: forceUpdate,
      ),
      online: () => remote.setMainImageByHash(
        data,
        mainhash,
      ),
      requestType: requestType,
    ).last;
  }

  /// upload a bunch of images
  Future<String?> uploadNewImagesOrFiles<DataT extends Data>(
    DataT data,
    List<XFile> files, {
    Data? caller,
    bool forceUpdate = false,
  }) async {
    final requestType = Helper.SimulatedRequestType.PUT;
    return _run(
      itPrefersCache: _dataPrefersCache(data, type: requestType),
      offline: () => local.uploadNewImagesOrFiles(
        data,
        files,
        caller: caller,
        forceUpdate: forceUpdate,
      ),
      online: () => remote.uploadFiles(
        data,
        files,
      ),
      // onlineSuccessCB: (response) async {},
      onlineFailedCB: (onlineRes, rap) {
        debugPrint('failed to upload images, ' +
            rap.rd.json.toString() +
            ': ' +
            onlineRes.toString());
        var rd = rap.rd;
        //biscchen ugly
        rd.multipartFiles = rd.multipartFiles.map((e) {
          // e.name = newName;
          var newName = LOCALLY_ADDED_PREFIX + e.name;
          var newPath =
              e.path.substring(0, e.path.length - e.name.length) + newName;
          e.saveTo(newPath);
          e = XFile(newPath);
          return e;
        }).toList();
        local.logFailedReq(rd);
      },
      requestType: requestType,
    ).last;
  }
}

D injectImages<D extends WithImgHashes>(D data, {bool preloadFull = true}) {
  Future<ImageData?> getImgDataFromHash(String? hash) {
    if (preloadFull) API().getImageByHash(hash!, compressed: false);
    return API().getImageByHash(hash!, compressed: true).then((value) => value
      ?..fullImageGetter = () => API()
          .getImageByHash(hash, compressed: false)
          .then((value) => value?.fullImage()));
  }

  if (data.mainhash != null &&
      data.mainhash != Options().no_image_placeholder_name) {
    var mainImage = getImgDataFromHash(data.mainhash);
    data.imageFutures =
        data.imagehashes?.map((hash) => getImgDataFromHash(hash)).toList();
    data.mainImage = mainImage;
    data.previewImage = mainImage;
  } else {
    //no main image set
    if (data.imagehashes == null ||
        data.imagehashes!.length == 0) //the second check *could* be omitted
      return data;
    data.previewImage = Future.value(null);
    if (data.imagehashes != null && data.imagehashes!.length > 0) {
      data.imageFutures =
          data.imagehashes?.map((hash) => getImgDataFromHash(hash)).toList();
      data.previewImage = data.imageFutures!.first;
    }
  }

  return data;
}
