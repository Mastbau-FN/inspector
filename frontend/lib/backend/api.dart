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
  Future<User?> get _c_user async {
    if (_user != null) return _user;
    final user = await User.fromStore();
    _user = user;
    remote.injectUser(user);
    return _user;
  }

  Stream<T> _run<R extends http.BaseResponse, T>({
    required FutureOr<T> Function() offline,
    required FutureOr<RequestAndParser<R, T>> Function() online,
    FutureOr<T> Function(T, T)? merge,
    required Helper.SimulatedRequestType requestType,
    bool itPrefersCache = false,
  }) async* {
    //TODO
    late T offlineRes;
    T onlineRes;
    if (Options().canBeOffline) {
      offlineRes = await offline();
      yield offlineRes;
    }

    final rap = await online();
    try {
      if (itPrefersCache && !Options().mergeOnlineEvenInCached)
        throw BackendCommunicationException('we prefer the local variant');
      await tryNetwork(requestType: requestType);
      final res = await remote.post_JSON(rap.rd);
      onlineRes = await rap.parser(res as R);
      if (Options().preferRemote) yield onlineRes;
      if (merge != null &&
          Options().canBeOffline &&
          (Options().mergeOnlineEvenInCached ||
              Options().mergeOnline && !itPrefersCache))
        yield await merge(offlineRes, onlineRes);
    } catch (e) {
      if (rap.rd.logIfFailed ??
          (requestType != Helper.SimulatedRequestType.GET))
        await local.logFailedReq(rap.rd);
      if (Options().debugLocalMirror)
        debugPrint(
            'failed request and logged it: ${rap.rd.json} \n\t error was $e');
    }
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
      offline: () => local.delete(data, caller: caller),
      online: () => remote.delete(data),
      requestType: requestType,
    ).last;
  }

  /// deletes an image specified by its hash and returns the response
  Future<ImageData?> getImageByHash(String hash) async {
    final requestType = Helper.SimulatedRequestType.GET;

    return _run(
      offline: () => local.getImageByHash(hash),
      online: () => remote.getImageByHash(hash),
      requestType: requestType,
    ).last;
  }

  /// deletes an image specified by its hash and returns the response
  Future<String?> deleteImageByHash(String hash) async {
    final requestType = Helper.SimulatedRequestType.DELETE;
    return _run(
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
      offline: () => local.setMainImageByHash(data, hash,
          caller: caller, forceUpdate: forceUpdate),
      online: () => remote.setMainImageByHash(data, hash),
      requestType: requestType,
    ).last;
  }

  /// upload a bunch of images
  Future<String?> uploadFiles<DataT extends Data>(
    DataT data,
    List<XFile> files,
  ) async {
    final requestType = Helper.SimulatedRequestType.PUT;
    return _run(
      offline: () => local.uploadFiles(data, files),
      online: () => remote.uploadFiles(data, files),
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
  data.image_futures = data.imagehashes
      ?.map((hash) => API().getImageByHash(hash))
      .toList()
      .sublist((_firstHash == Options().no_image_placeholder_name) ? 1 : 0);
  data.previewImage =
      IterateFuture.ordered_firstNonNull(data.image_futures ?? []);
  return data;
}
