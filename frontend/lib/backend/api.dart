// TODO offline storage etc

import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:mastbau_inspector/assets/consts.dart';
import 'package:mastbau_inspector/classes/data/checkcategory.dart';
import 'package:mastbau_inspector/classes/data/inspection_location.dart';
import 'package:mastbau_inspector/pages/dropdown/dropdownModel.dart';
import '/classes/exceptions.dart';
import '/classes/user.dart';

const _getProjects_r = '/getProjects';
const _getCategories_r = '/getCategories';

/// backend Singleton to provide all functionality related to the backend
class Backend {
  // MARK: internals

  static final Backend _instance = Backend._internal();
  factory Backend() => _instance;

  bool _isFaked = false;

  /// creates a fake backend which can be used for mocking data
  factory Backend.fake() {
    _instance._isFaked = true;
    return _instance;
  }

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
  Future<http.Response> post_JSON(String route,
      {Map<String, dynamic>? json}) async {
    var headers = {HttpHeaders.contentTypeHeader: 'application/json'};
    json = json ?? {};
    json['user'] = await _c_user;
    return post(route, headers: headers, body: jsonEncode(json));
  }

  // MARK: API

  /// checks whether the given user is currently logged in
  Future<bool> isUserLoggedIn(User user) async => user == await _c_user;

  /// checks whether anyone is currently logged in
  Future<bool> get isAnyoneLoggedIn async => await _c_user != null;

  /// gets the currently logged in [DisplayUser], which is the current [User] but with removed [User.pass] to avoid abuse
  Future<DisplayUser> get user async => (await _c_user) as DisplayUser;

  /// login a [User] by checking if he exists in the remote database
  Future<DisplayUser?> login(User user) async {
    // if user is already logged in
    if (await isUserLoggedIn(user)) return await this.user;
    if (_isFaked) {
      return user;
    }
    await connectionGuard();
    _user = user;
    var res = await post_JSON('/login');
    if (res.statusCode == 200) {
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
    _user?.unstore();
    _user = null;
    debugPrint('user logged out');
  }

  /// gets all the [InspectionLocation]s for the currently logged in [user]
  Future<List<InspectionLocation>>
      getAllInspectionLocationsForCurrentUser() async {
    if (_isFaked) {
      return [
        InspectionLocation(pjName: 'mock-location 1', pjNr: 4, stONr: 7),
        InspectionLocation(pjName: 'mock-location 2', pjNr: 7, stONr: 4)
      ];
    }
    return getListFromJson(jsonDecode((await post_JSON(_getProjects_r)).body),
        InspectionLocation.fromMap,
        objName: 'inspections');
  }

  /// gets all the [CheckCategory]s for the currently logged in [user]
  Future<List<CheckCategory>> getAllChackCategoriesForLocation(
      InspectionLocation location) async {
    if (_isFaked) {
      return [
        CheckCategory(),
        CheckCategory(),
      ];
    }
    return getListFromJson(
        jsonDecode((await post_JSON(_getCategories_r, location.toJson())).body),
        CheckCategory.fromMap,
        objName: 'categories');
  }
}

/// Helper function to parse a [List] of [Data] Objects from a Json-[Map]
List<T> getListFromJson<T extends Data>(
    Map<String, dynamic> json, T? Function(Map<String, dynamic>) converter,
    {String? objName}) {
  try {
    List<dynamic> str = (objName != null) ? json[objName] : json;
    return List<T>.from(str.map((insp) => converter(insp)));
  } catch (e) {
    debugPrint(e.toString());
  }
  return [];
}
