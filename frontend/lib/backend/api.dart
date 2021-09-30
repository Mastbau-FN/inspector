// TODO offline storage etc

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:mastbau_inspector/assets/consts.dart';
import 'package:mastbau_inspector/classes/data/checkcategory.dart';
import 'package:mastbau_inspector/classes/data/checkpoint.dart';
import 'package:mastbau_inspector/classes/data/checkpointdefect.dart';
import 'package:mastbau_inspector/classes/data/inspection_location.dart';
import 'package:mastbau_inspector/pages/dropdown/dropdownModel.dart';
import '/classes/exceptions.dart';
import '/classes/user.dart';

const _getProjects_r = '/getProjects';
const _getCategories_r = '/getCategories';
const _getCheckPoints_r = '/getCheckPoints';
const _getCheckPointDefects_r = '/getCheckPointDefects';

const _getImageFromHash_r = '/image';

/// backend Singleton to provide all functionality related to the backend
class Backend {
  // MARK: internals

  static final Backend _instance = Backend._internal();
  factory Backend() => _instance;

  final _baseurl = dotenv.env['API_URL'];
  final _api_key = dotenv.env['API_KEY'] ?? "apitestkey";

  User? _user;

  /// returns the currently logged in [User], whether its already initialized or not.
  /// should be prefered over [_user], since it makes sure to have it initialized
  Future<User?> get _c_user async {
    if (_user != null) return _user;
    return await User.fromStore();
  }

  Backend._internal() {
    // init
  }

  // MARK: available Helpers

  /// checks whether a connection to the backend is possible
  /// throws [NoConnectionToBackendException] or [SocketException] if its not.
  Future connectionGuard() async {
    if (_baseurl == null)
      throw NoConnectionToBackendException("no url provided");

    //check network
    var connection = await (Connectivity().checkConnectivity());
    if (connection == ConnectivityResult.none)
      throw NoConnectionToBackendException("no network available");
    if (!canUseMobileNetworkIfPossible &&
        connection == ConnectivityResult.mobile)
      throw NoConnectionToBackendException("mobile network not allowed");

    try {
      // check if we can reach our api
      await post_JSON('/login');
    } catch (e) {
      throw NoConnectionToBackendException("couldn't reach $_baseurl");
    }
  }

  /// make an actual API request to a route, and always append the API_KEY as authorization-header
  Future<http.Response> post(String route,
      {Map<String, String>? headers, Object? body, Encoding? encoding}) async {
    headers = headers ?? {};
    headers.addAll({HttpHeaders.authorizationHeader: _api_key});
    var fullURL = Uri.parse(_baseurl! + route);
    return http.post(fullURL, headers: headers, body: body, encoding: encoding);
  }

  /// post_JSON to our backend as the user
  Future<http.Response?> post_JSON(String route,
      {Map<String, dynamic>? json}) async {
    var headers = {HttpHeaders.contentTypeHeader: 'application/json'};
    json = json ?? {};
    json['user'] = await _c_user;
    try {
      return post(route, headers: headers, body: jsonEncode(json));
    } catch (e) {
      return null;
    }
  }

  Future<Image?> _fetchImage(String hash) async {
    var bytes = (await post_JSON(_getImageFromHash_r, json: {'imghash': hash}))
        ?.bodyBytes;
    return bytes == null ? null : Image.memory(bytes);
  }

  Future<T?> Function(Map<String, dynamic>)
      _generateImageFetcher<T extends Data>(
    T? Function(Map<String, dynamic>) jsoner,
  ) {
    return (Map<String, dynamic> json) async {
      //debugPrint(json.toString() + '\n');
      T? data = jsoner(json);
      data?.images = await Future.wait(
        List<Future<Image?>>.from(
          // i could use CachedNetworkImage here, and that would be a nice in-between solution, but the idea is that post_json will handle offline availability in the future
          data.imagehashes?.map(
                (hash) => _fetchImage(hash),
              ) ??
              [],
        ),
      );
      return data;
    };
  }

  /// Helper function to get the next [Data] (e.g. all [CheckPoint]s for chosen [CheckCategory])
  Future<List<D>> _getAllForNextLevel<D extends Data>({
    required String route,
    required String jsonResponseID,
    Map<String, dynamic>? json,
    required D? Function(Map<String, dynamic>) fromJson,
  }) async =>
      await getListFromJson(
        jsonDecode(
          (await post_JSON(route, json: json))?.body ?? '',
        ),
        _generateImageFetcher(fromJson),
        objName: jsonResponseID,
      );

  // MARK: API

  /// checks whether the given user is currently logged in
  Future<bool> isUserLoggedIn(User user) async => user == await _c_user;

  /// checks whether anyone is currently logged in
  Future<bool> get isAnyoneLoggedIn async => await _c_user != null;

  /// gets the currently logged in [DisplayUser], which is the current [User] but with removed [User.pass] to avoid abuse
  Future<DisplayUser?> get user async => await _c_user;

  /// login a [User] by checking if he exists in the remote database
  Future<DisplayUser?> login(User user) async {
    // if user is already logged in
    if (await isUserLoggedIn(user)) return await this.user;
    await connectionGuard();
    _user = user;
    var res = await post_JSON('/login');
    if (res != null && res.statusCode == 200) {
      //success
      var resb = jsonDecode(res.body)['user'];
      _user?.fromMap(resb);
      await _user?.store();
      return this.user;
    }
    await logout(); //we could omit the await for a slight speed improvement (but if anything crashes for some reason it could lead to unexpected behaviour)
    throw ResponseException(res);
  }

  /// removes the credentials from local storage and therefors logs out
  Future logout() async {
    (await _c_user)?.unstore();
    _user = null;
    debugPrint('user logged out');
  }

  /// gets all the [InspectionLocation]s for the currently logged in [user]
  Future<List<InspectionLocation>> getAllInspectionLocationsForCurrentUser() =>
      _getAllForNextLevel(
        route: _getProjects_r,
        jsonResponseID: 'inspections',
        fromJson: InspectionLocation.fromJson,
      );

  /// gets all the [CheckCategory]s for the given [InspectionLocation]
  Future<List<CheckCategory>> getAllCheckCategoriesForLocation(
          InspectionLocation location) =>
      _getAllForNextLevel(
        route: _getCategories_r,
        jsonResponseID: 'categories',
        json: location.toSmallJson(),
        fromJson: CheckCategory.fromJson,
      );

  /// gets all the [CheckPoint]s corresponding to a given [CheckCategory]
  Future<List<CheckPoint>> getAllCheckPointsForCategory(
          CheckCategory category) =>
      _getAllForNextLevel(
        route: _getCheckPoints_r,
        jsonResponseID: 'checkpoints',
        json: category.toSmallJson(),
        fromJson: CheckPoint.fromJson,
      );

  /// gets all the [CheckPointDefect]s for the given [CheckPoint]
  Future<List<CheckPointDefect>> getAllDefectsForCheckpoint(
          CheckPoint checkpoint) =>
      _getAllForNextLevel(
        route: _getCheckPointDefects_r,
        jsonResponseID: 'checkpointdefects',
        json: checkpoint.toSmallJson(),
        fromJson: CheckPointDefect.fromJson,
      );
}

/// Helper function to parse a [List] of [Data] Objects from a Json-[Map]
Future<List<T>> getListFromJson<T extends Data>(Map<String, dynamic> json,
    FutureOr<T?> Function(Map<String, dynamic>) converter,
    {String? objName}) async {
  try {
    List<dynamic> str = (objName != null) ? json[objName] : json;
    return List<T>.from(
        (await Future.wait(str.map((insp) async => await converter(insp))))
            .whereType<T>());
  } catch (e) {
    debugPrint(e.toString());
  }
  return [];
}
