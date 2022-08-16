import 'dart:async';
import 'dart:io';

import 'package:MBG_Inspektionen/backend/local.dart';
import 'package:MBG_Inspektionen/backend/remote.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:MBG_Inspektionen/classes/dropdownClasses.dart';
import '../classes/imageData.dart';
import '../extension/future.dart';
import '../generated/l10n.dart';
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
    if (type == Helper.SimulatedRequestType.GET ||
        Options().tryOnlineUploadRequestsInCachedMode)
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
    /// onlineFailedCB(T onlineResult, RequestAndParser<R, T> requestAndParser) async {
    ///   modifyReq(requestAndParser.rd);
    /// };
    /// ```
    FutureOr<T> Function(T, RequestAndParser<R, T>)? onlineFailedCB,
    required Helper.SimulatedRequestType requestType,
    bool? itPrefersCache = false,
  }) {
    var controller = StreamController<T>();
    late var canBeClosed; // = Future.delayed(Duration(seconds: 10), () => true);
    final _itPrefersCache = itPrefersCache ?? false;
    late T offlineRes;
    T onlineRes;
    if (Options().canBeOffline) {
      canBeClosed = Future<T>(offline).then((value) {
        offlineRes = value;
        controller.add(offlineRes);
        return true;
      }, onError: (err) {
        debugPrint('offline failed: ' + err.toString());
        return false;
      });
    }

    Future<RequestAndParser<R, T>>(online).then(
      (rap) async {
        late Object _latestErr;
        Future<bool> doOnline({bool orDontIf = false}) async {
          try {
            if (orDontIf)
              throw BackendCommunicationException(
                  'we prefer the local variant');
            await tryNetwork(requestType: requestType);
            final bool wantsmerged = merge != null &&
                Options().canBeOffline &&
                (Options().mergeOnlineEvenInCached ||
                    Options().mergeOnline && !_itPrefersCache);
            final bool wantsonline =
                //TODO: okay but this might be the wrong type
                Options().preferRemoteData || Options().preferRemoteImgs;
            if (wantsonline || wantsmerged) {
              final res = await remote.postJSON(rap.rd);
              onlineRes = await rap.parser(res as R);
              if (wantsonline) controller.add(onlineRes);
              if (wantsmerged)
                controller.add(await merge(offlineRes, onlineRes));
            }
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
          else if (log) await local.logFailedReq(rap.rd);
          if (Options().debugLocalMirror)
            debugPrint(
                'failed request ${log ? "and logged it" : ""}: ${rap.rd.json} \n\t error was $_latestErr');
        }

        bool onlineSucc = await doOnline(
          orDontIf: _itPrefersCache && !Options().mergeOnlineEvenInCached,
        );
        bool offlineFailed = !(await canBeClosed);
        var x = 0;
        if (!onlineSucc && offlineFailed && Options().tryOnlineIfOfflineFailed)
          onlineSucc =
              await doOnline(); //TODO: why arent the images loaded here?
        controller.close();
        if (!onlineSucc) onlineFailedProcedure();
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
          S.current.nonetwork_forcedOfflineMode);
    final connection = await (Connectivity().checkConnectivity());
    if (connection == ConnectivityResult.none)
      throw NoConnectionToBackendException(S.current.noNetworkAvailable);
    if (connection == ConnectivityResult.mobile &&
        ((requestType != Helper.SimulatedRequestType.GET &&
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
    // final requestType =
    //     Helper.SimulatedRequestType.GET;
    // if user is already logged in
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
        S.current.wontFetchAnythingSinceNoOneIsLoggedIn);

    yield* _run(
      itPrefersCache: _dataPrefersCache(data, type: requestType),
      offline: () => local.getNextDatapoint(data),
      online: () => remote.getNextDatapoint(data),
      requestType: requestType,
      merge: (cached, upstream) async {
        try {
          cached
              .retainWhere((element) => (element as WithOffline).forceOffline);
          var cachedIds = cached.map((element) => element.id).toList();
          upstream.retainWhere((element) =>
              element.id != null && !cachedIds.contains(element.id));
          upstream.addAll(cached);
          return upstream;
        } catch (e) {
          debugPrint("error merging data: " + e.toString());
          return cached;
        }
      },
    );
  }

  /// sets a new [DataT]
  Future<DataT?> setNew<DataT extends Data>(
    DataT? data, {
    Data? caller,
  }) async {
    final requestType = Helper.SimulatedRequestType.PUT;

    return _run(
      itPrefersCache: _dataPrefersCache(caller, type: requestType),
      offline: () => local.setNew(data, caller: caller),
      online: () => remote.setNew(data),
      requestType: requestType,
    ).last;
  }

  /// updates a [DataT] and returns the response
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

  /// deletes an image specified by its hash and returns the response
  Future<ImageData?> getImageByHash(String hash) async {
    final requestType = Helper.SimulatedRequestType.GET;

    return _run(
      itPrefersCache: !Options().preferRemoteImgs,
      offline: () => local.getImageByHash(hash),
      online: () => remote.getImageByHash(hash),
      requestType: requestType,
    ).last;
  }

  /// deletes an image specified by its hash and returns the response
  Future<String?> deleteImageByHash<DataT extends Data>(
    DataT? data,
    String hash,
  ) async {
    final requestType = Helper.SimulatedRequestType.DELETE;
    return _run(
      itPrefersCache: _dataPrefersCache(data, type: requestType),
      offline: () => local.deleteImageByHash(hash),
      online: () => remote.deleteImageByHash(hash),
      requestType: requestType,
    ).last;
  }

  /// sets an image specified by its hash as the new main image
  Future<String?> setMainImageByHash<DataT extends Data>(
    DataT? data,
    String hash, {
    Data? caller,
    bool forceUpdate = false,
  }) async {
    final requestType = Helper.SimulatedRequestType.PUT;
    return _run(
      itPrefersCache: _dataPrefersCache(data, type: requestType),
      offline: () => local.setMainImageByHash(
        data,
        hash,
        caller: caller,
        forceUpdate: forceUpdate,
      ),
      online: () => remote.setMainImageByHash(
        data,
        hash,
      ),
      requestType: requestType,
    ).last;
  }

  /// upload a bunch of images
  Future<String?> uploadFiles<DataT extends Data>(
    DataT data,
    List<XFile> files, {
    Data? caller,
    bool forceUpdate = false,
  }) async {
    final requestType = Helper.SimulatedRequestType.PUT;
    return _run(
      itPrefersCache: _dataPrefersCache(data, type: requestType),
      offline: () => local.uploadFiles(
        data,
        files,
        caller: caller,
        forceUpdate: forceUpdate,
      ),
      online: () => remote.uploadFiles(
        data,
        files,
      ),
      onlineFailedCB: (onlineRes, rap) {},
      requestType: requestType,
    ).last;
  }
}

D injectImages<D extends WithImgHashes>(D data) {
  if (data.imagehashes == null ||
      data.imagehashes!.length == 0) //the second check *could* be omitted
    return data;
  String _firstHash = data.imagehashes![0];
  data.mainImage = (_firstHash == Options().no_image_placeholder_name)
      ? null
      : API().getImageByHash(_firstHash);
  data.imageFutures = data.imagehashes
      ?.map((hash) => API().getImageByHash(hash))
      .toList()
      .sublist((_firstHash == Options().no_image_placeholder_name) ? 1 : 0);
  data.previewImage = data.imageFutures != null
      ? data.imageFutures!.ordered_firstNonNull
      : Future.value(null);
  return data;
}
