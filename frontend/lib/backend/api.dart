import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:MBG_Inspektionen/backend/local.dart';
import 'package:MBG_Inspektionen/backend/offlineProvider.dart';
import 'package:MBG_Inspektionen/backend/remote.dart';
import 'package:MBG_Inspektionen/backend/image_naming.dart';
import 'package:MBG_Inspektionen/backend/inspection_visibility.dart';
import 'package:MBG_Inspektionen/classes/requestData.dart' show RequestData;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as imglib;
import 'package:MBG_Inspektionen/classes/dropdownClasses.dart';
import 'package:MBG_Inspektionen/classes/data/inspection_location.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../classes/imageData.dart';
import 'package:MBG_Inspektionen/l10n/locales.dart';
import '/classes/exceptions.dart';
import '/classes/user.dart';
import 'package:MBG_Inspektionen/options.dart';

import './helpers.dart' as Helper;
import 'download_progress.dart';

/// backend Singleton to provide all functionality related to the backend
class API {
  static const String _loginUsersStoreKey = 'login_users_cache_v1';
  final remote = Remote();
  final local = LocalMirror();
  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();
  // MARK: internals

  static final API _instance = API._internal();
  factory API() => _instance;

  API._internal() {
    // init
  }

  User? _user;
  final Set<int> _touchedPrueferForProjects = <int>{};
  final Map<int, String?> _prueferByPjNr = <int, String?>{};
  final Map<String, Future<ImageData?>> _inflightImageFetches =
      <String, Future<ImageData?>>{};
  final Map<String, Future<File?>> _inflightDocumentFetches =
      <String, Future<File?>>{};
  bool _refreshingLoginUsers = false;

  String? _readStringKey(Map<String, dynamic> map, List<String> candidates) {
    for (final key in candidates) {
      final v = map[key];
      if (v != null) {
        final s = v.toString().trim();
        if (s.isNotEmpty) return s;
      }
    }
    for (final entry in map.entries) {
      final key = entry.key.toLowerCase();
      if (candidates.any((c) => c.toLowerCase() == key)) {
        final v = entry.value;
        if (v != null) {
          final s = v.toString().trim();
          if (s.isNotEmpty) return s;
        }
      }
    }
    return null;
  }

  /// returns the currently logged in [User], whether its already initialized or not.
  /// should be prefered over [_user], since it makes sure to have it initialized
  // ignore: non_constant_identifier_names
  Future<User?> get _c_user async {
    if (_user != null) return _user;
    final user = await User.fromStore();
    _user = user;
    remote.injectUser(user);
    if (user != null) {
      unawaited(refreshLoginUsersCache());
    }
    return _user;
  }

  List<DisplayUser> _parseLoginUsers(dynamic entries) {
    if (entries is! List) return [];
    final usersByKzl = <String, DisplayUser>{};
    for (final entry in entries) {
      if (entry is! Map) continue;
      final map = Map<String, dynamic>.from(entry);
      final kzl = (_readStringKey(map, ['KZL', 'kzl']) ?? '').trim();
      if (kzl.isEmpty || kzl == '??') continue;
      final user = DisplayUser(kzl);
      user.full_name = _readStringKey(map, ['Vorname', 'vorname']);
      user.full_surname = _readStringKey(map, ['Name', 'name']);
      usersByKzl[kzl] = user;
    }
    final users = usersByKzl.values.toList();
    users.sort((a, b) {
      final aName = '${a.full_surname ?? ''} ${a.full_name ?? ''} ${a.name}'
          .toLowerCase();
      final bName = '${b.full_surname ?? ''} ${b.full_name ?? ''} ${b.name}'
          .toLowerCase();
      return aName.compareTo(bName);
    });
    return users;
  }

  Future<void> _storeLoginUsers(List<DisplayUser> users) async {
    final usersByKzl = <String, DisplayUser>{};
    for (final user in users) {
      final kzl = user.name.trim();
      if (kzl.isEmpty || kzl == '??') continue;
      usersByKzl[kzl] = user;
    }
    final normalized = usersByKzl.values.toList();
    normalized.sort((a, b) {
      final aName = '${a.full_surname ?? ''} ${a.full_name ?? ''} ${a.name}'
          .toLowerCase();
      final bName = '${b.full_surname ?? ''} ${b.full_name ?? ''} ${b.name}'
          .toLowerCase();
      return aName.compareTo(bName);
    });

    final encoded = normalized
        .map((user) => {
              'KZL': user.name,
              'Vorname': user.full_name,
              'Name': user.full_surname,
            })
        .toList(growable: false);
    final payload = jsonEncode(encoded);
    await (await _prefs).setString(_loginUsersStoreKey, payload);
    debugPrint(
      'Login users cache stored: count=${normalized.length}, bytes=${payload.length}',
    );
  }

  Future<List<DisplayUser>> _readStoredLoginUsers() async {
    final raw = (await _prefs).getString(_loginUsersStoreKey);
    if (raw == null || raw.isEmpty) {
      debugPrint('Login users cache read: empty');
      return [];
    }
    try {
      final decoded = jsonDecode(raw);
      final parsed = _parseLoginUsers(decoded);
      debugPrint(
        'Login users cache read: parsed=${parsed.length}, bytes=${raw.length}',
      );
      return parsed;
    } catch (e) {
      debugPrint('Could not parse cached login users: $e');
      return [];
    }
  }

  /// Refreshes the login-users cache from backend.
  /// This should only run while a user is already authenticated.
  Future<void> refreshLoginUsersCache() async {
    if (_refreshingLoginUsers) return;
    if (await _c_user == null) return;
    _refreshingLoginUsers = true;
    try {
      debugPrint('Refreshing login users cache from backend...');
      final users = await remote.getLoginUsers();
      debugPrint('Login users fetched from backend: ${users.length}');
      await _storeLoginUsers(users);
      debugPrint('Cached login users updated: ${users.length}');
    } catch (e) {
      debugPrint('Could not refresh login users cache: $e');
    } finally {
      _refreshingLoginUsers = false;
    }
  }

  Future<void> _seedLoginUsersCacheWithCurrentUser(DisplayUser user) async {
    final currentKzl = user.name.trim();
    if (currentKzl.isEmpty || currentKzl == '??') return;
    final cached = await _readStoredLoginUsers();
    final idx = cached.indexWhere(
      (u) => u.name.toLowerCase() == currentKzl.toLowerCase(),
    );
    if (idx >= 0) {
      final existing = cached[idx];
      if ((existing.full_name == null || existing.full_name!.isEmpty) &&
          (user.full_name != null && user.full_name!.isNotEmpty)) {
        existing.full_name = user.full_name;
      }
      if ((existing.full_surname == null || existing.full_surname!.isEmpty) &&
          (user.full_surname != null && user.full_surname!.isNotEmpty)) {
        existing.full_surname = user.full_surname;
      }
    } else {
      cached.add(
        DisplayUser(
          currentKzl,
          full_name: user.full_name,
          full_surname: user.full_surname,
        ),
      );
    }
    await _storeLoginUsers(cached);
    debugPrint('Seeded login users cache with current user: $currentKzl');
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

  @visibleForTesting
  static List<InspectionLocation> staleLocalRootInspections({
    required List<InspectionLocation> local,
    required List<InspectionLocation> remote,
  }) {
    final remoteIds = remote.map((inspection) => inspection.id).toSet();
    return local.where((inspection) {
      if (inspection.forceOffline) return false;
      return !remoteIds.contains(inspection.id);
    }).toList();
  }

  @visibleForTesting
  static bool shouldForceOnlineAfterOfflineMiss({
    required bool onlineSucceeded,
    required bool offlineSucceeded,
    required bool prefersCache,
    required bool forceOffline,
  }) {
    if (onlineSucceeded || offlineSucceeded) return false;
    if (prefersCache || forceOffline) return false;
    return true;
  }

  Future<void> _pruneStaleRootInspectionCache(
    List<InspectionLocation> remoteInspections,
  ) async {
    try {
      final localInspections =
          await local.getNextDatapoint<InspectionLocation, WithOffline?>(null);
      final stale = API.staleLocalRootInspections(
        local: localInspections,
        remote: remoteInspections,
      );
      if (stale.isEmpty) return;

      final rootId = await rootID;
      for (final inspection in stale) {
        try {
          await deleteData<InspectionLocation>(inspection.id, parentId: rootId);
          await InspectionVisibility()
              .removeFailedRequestsForInspection(inspection.pjNr.toString());
          debugPrint(
            'Pruned stale local inspection ${inspection.id} (${inspection.pjNr})',
          );
        } catch (e) {
          debugPrint(
            'Failed pruning stale local inspection ${inspection.id}: $e',
          );
        }
      }
    } catch (e) {
      debugPrint('Failed pruning stale root inspection cache: $e');
    }
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
    final _itPrefersCache = itPrefersCache ?? false;
    late T offlineRes;
    late T onlineRes;
    bool offlineHadValue = false;
    Future<bool> doOffline({bool orDontIf = false}) async {
      if (orDontIf) return false;
      return Future<T>(offline).then((value) {
        offlineRes = value;
        offlineHadValue = true;
        controller.add(offlineRes);
        return true;
      }, onError: (err) {
        if (err is NoImagePlaceholderException) return true;
        return false;
      });
    }

    Future<RequestAndParser<R, T>>(online).then(
      (rap) async {
        try {
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
              final bool wantsonline = forceOnline ??
                  (requestType != Helper.SimulatedRequestType.GET);
              if (wantsonline || wantsmerged) {
                await Future.delayed(Duration(milliseconds: 100));
                final session = DownloadProgress.instance.active;
                String? key;
                final currentStep = session?.notifier.value.stepIndex ?? 0;
                int step = currentStep;
                String? stepLabel;
                try {
                  final r = rap.rd.route;
                  if (r.contains('category')) {
                    step = InspectionDownloadSteps.categories;
                    stepLabel = InspectionDownloadSteps.categoriesLabel;
                  } else if (r.contains('checkpoint')) {
                    step = InspectionDownloadSteps.checkpoints;
                    stepLabel = InspectionDownloadSteps.checkpointsLabel;
                  } else if (r.contains('defect')) {
                    step = InspectionDownloadSteps.defects;
                    stepLabel = InspectionDownloadSteps.defectsLabel;
                  } else if (r.contains('/image/get')) {
                    step = InspectionDownloadSteps.photos;
                  } else if (r.contains('/doc/get')) {
                    step = InspectionDownloadSteps.documents;
                  }
                } catch (_) {}
                try {
                  key = inspectionDownloadRequestKey(
                    rap.rd.route,
                    rap.rd.json,
                  );
                } catch (_) {}

                if (stepLabel != null) {
                  session?.setStep(step, label: stepLabel);
                }
                final token = session?.beginTask(
                  stepLabel ?? '',
                  key: key,
                  step: step,
                );
                try {
                  final res = await remote.postJSON(rap.rd);
                  onlineRes = await rap.parser(res as R);
                  if (wantsonline) {
                    controller.add(onlineRes);
                  }
                  if (wantsmerged) {
                    controller.add(await merge(offlineRes, onlineRes));
                  }
                  if (token != null) session?.endTask(token, success: true);
                } catch (e) {
                  if (token != null) session?.endTask(token, success: false);
                  rethrow;
                }
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
            if (onlineFailedCB != null && offlineHadValue) {
              await onlineFailedCB(offlineRes, rap);
            } else if (log) {
              await local.logFailedReq(rap.rd);
            }
          }

          onlineSuccessProcedure() async {
            if (onlineSuccessCB != null) await onlineSuccessCB(onlineRes);
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
          if (API.shouldForceOnlineAfterOfflineMiss(
            onlineSucceeded: onlineSucc ?? false,
            offlineSucceeded: offlineSucc ?? false,
            prefersCache: _itPrefersCache,
            forceOffline: Options().forceOffline,
          )) {
            onlineSucc = await doOnline(forceOnline: true);
          }
          if (onlineSucc != null)
            onlineSucc ? onlineSuccessProcedure() : onlineFailedProcedure();
        } finally {
          if (!controller.isClosed) controller.close();
        }
      },
      onError: (e) {
        if (!controller.isClosed) controller.close();
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

  int? _extractPjNr({Data? data, Data? caller}) {
    try {
      final pjNr = data?.toSmallJson()['PjNr'];
      if (pjNr is int) return pjNr;
      if (pjNr is num) return pjNr.toInt();
      if (pjNr is String) return int.tryParse(pjNr);
    } catch (_) {}
    try {
      final pjNr = caller?.toSmallJson()['PjNr'];
      if (pjNr is int) return pjNr;
      if (pjNr is num) return pjNr.toInt();
      if (pjNr is String) return int.tryParse(pjNr);
    } catch (_) {}
    return null;
  }

  Future<List<XFile>> _normalizeUploadFilesForStorage<DataT extends Data>(
    DataT data,
    List<XFile> files, {
    Data? caller,
  }) async {
    final scope = local.scopeFor(data, caller: caller);
    final usedNames = <String>{};
    final prepared = <XFile>[];

    for (final file in files) {
      DateTime baseTime = parseTimestampImageFilename(file.name) ??
          parseTimestampImageFilename(
              canonicalTimestampFilenameForXFile(file)) ??
          DateTime.now();
      String candidate = formatTimestampImageFilename(baseTime);

      while (true) {
        if (usedNames.contains(candidate)) {
          baseTime = baseTime.add(const Duration(seconds: 1));
          candidate = formatTimestampImageFilename(baseTime);
          continue;
        }

        final scopedName = scope.isNotEmpty ? '$scope/$candidate' : candidate;
        final target = await localFile(scopedName);
        final samePath = File(file.path).absolute.path == target.absolute.path;
        if (target.existsSync() && !samePath) {
          baseTime = baseTime.add(const Duration(seconds: 1));
          candidate = formatTimestampImageFilename(baseTime);
          continue;
        }
        break;
      }

      usedNames.add(candidate);
      final scopedName = scope.isNotEmpty ? '$scope/$candidate' : candidate;
      final storedName = await permaStoreCachedXFile(file, scopedName);
      prepared.add(await retrieveStoredXFile(storedName));
    }

    return prepared;
  }

  int? _parseInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  bool _isLocalImageReference(String value) {
    final v = value.trim();
    if (v.isEmpty) return false;
    if (v.contains('/')) return true;
    if (v.startsWith(LOCALLY_ADDED_PREFIX)) return true;
    if (isTimestampImageFilename(v)) return true;
    return false;
  }

  Set<String> _collectImageRefs(Data? data) {
    final refs = <String>{};
    if (data == null) return refs;
    if (data.mainhash != null && data.mainhash!.trim().isNotEmpty) {
      refs.add(data.mainhash!.trim());
    }
    for (final hash in data.imagehashes ?? const <String>[]) {
      final trimmed = hash.trim();
      if (trimmed.isNotEmpty) refs.add(trimmed);
    }
    return refs;
  }

  Uint8List _encodeRotatedImageBytes(imglib.Image image, String nameHint) {
    final lower = nameHint.toLowerCase();
    if (lower.endsWith('.png')) {
      return Uint8List.fromList(imglib.encodePng(image));
    }
    if (lower.endsWith('.webp')) {
      return Uint8List.fromList(imglib.encodeJpg(image, quality: 92));
    }
    return Uint8List.fromList(imglib.encodeJpg(image, quality: 92));
  }

  Future<String> _nextScopedImageName(String scope) async {
    var ts = DateTime.now();
    while (true) {
      final filename = formatTimestampImageFilename(ts);
      final scoped = scope.isNotEmpty ? '$scope/$filename' : filename;
      final file = await localFile(scoped);
      if (!file.existsSync()) return scoped;
      ts = ts.add(const Duration(seconds: 1));
    }
  }

  int? _extractOldPrueferId({Data? data, Data? caller, int? pjNr}) {
    // First: try cached locations list
    if (pjNr != null) {
      final cached = _prueferByPjNr[pjNr];
      final parsed = _parseInt(cached);
      if (parsed != null) return parsed;
    }

    // Next: try if the current mutation involves a location object
    try {
      final v = (data?.toJson())?['Login_ID_Pruefer'];
      final parsed = _parseInt(v);
      if (parsed != null) return parsed;
    } catch (_) {}
    try {
      final v = (caller?.toJson())?['Login_ID_Pruefer'];
      final parsed = _parseInt(v);
      if (parsed != null) return parsed;
    } catch (_) {}

    return null;
  }

  void _cachePrueferIdsFromLocations(List<Data> childDatas) {
    for (final child in childDatas) {
      try {
        // Only InspectionLocation has Login_ID_Pruefer; use toJson for a light dependency.
        final json = child.toJson();
        final pjNr = _parseInt(json['PjNr']);
        if (pjNr == null) continue;
        final pruefer = json['Login_ID_Pruefer']?.toString();
        _prueferByPjNr[pjNr] = pruefer;
      } catch (_) {}
    }
  }

  Future<void> _touchPrueferIfNeeded({
    required Helper.SimulatedRequestType requestType,
    Data? data,
    Data? caller,
  }) async {
    final pjNr = _extractPjNr(data: data, caller: caller);
    if (pjNr == null) return;
    if (_touchedPrueferForProjects.contains(pjNr)) return;

    // Only touch when old != current.
    final currentUser = await _c_user;
    final currentPrueferId = currentUser?.defLoginId;
    if (currentPrueferId == null) return;
    final oldPrueferId =
        _extractOldPrueferId(data: data, caller: caller, pjNr: pjNr);
    if (oldPrueferId != null && oldPrueferId == currentPrueferId) {
      _touchedPrueferForProjects.add(pjNr);
      return;
    }

    bool prefersOffline =
        (_dataPrefersCache(caller, type: requestType) ?? false) ||
            Options().forceOffline;
    try {
      prefersOffline = prefersOffline || (caller as WithOffline).forceOffline;
    } catch (_) {}
    try {
      prefersOffline = prefersOffline || (data as WithOffline).forceOffline;
    } catch (_) {}
    if (prefersOffline) return;

    // Mark as touched before awaiting to prevent duplicate concurrent calls.
    _touchedPrueferForProjects.add(pjNr);
    try {
      await tryNetwork(requestType: requestType);
      final rap = remote.touchPruefer(pjNr);
      final baseRes = await remote.postJSON(rap.rd);
      if (baseRes is http.Response) {
        final result = await rap.parser(baseRes);
        if (result.updated) {
          debugPrint(
            'Prüfer changed for PjNr=$pjNr: ${result.oldLoginIdPruefer} -> ${result.loginIdPruefer} (current=${currentPrueferId})',
          );
        }
      }
      _prueferByPjNr[pjNr] = currentPrueferId.toString();
    } catch (_) {
      // Best-effort; don't block other mutations.
    }
  }

  // MARK: API

  /// checks whether the given user is currently logged in
  Future<bool> isUserLoggedIn(User user) async => user == await _c_user;

  /// checks whether anyone is currently logged in
  Future<bool> get isAnyoneLoggedIn async => await _c_user != null;

  /// gets the currently logged in [DisplayUser], which is the current [User] but with removed [User.pass] to avoid abuse
  Future<DisplayUser?> get user async => await _c_user;

  /// gets cached workers for the login dropdown.
  /// This is intentionally local-only, so it also works while logged out.
  Future<List<DisplayUser>> getLoginUsers() async =>
      await _readStoredLoginUsers();

  /// login a [User] by checking if he exists in the remote database
  Future<DisplayUser?> login(User user) async {
    if (await isUserLoggedIn(user)) return this.user;
    try {
      final loggedInUser = await remote.login(user);
      debugPrint(
          'API.login: logged in as KZL=${loggedInUser?.name}, Def_Login_ID=${loggedInUser?.defLoginId}');
      _user = loggedInUser;
      remote.injectUser(loggedInUser);
      await loggedInUser!.store();
      await _seedLoginUsersCacheWithCurrentUser(loggedInUser);
      await refreshLoginUsersCache();
      final cachedUsers = await _readStoredLoginUsers();
      debugPrint('Login users cache after login: ${cachedUsers.length}');
      return this.user;
    } catch (e) {
      logout();
      rethrow;
    }
  }

  /// removes the credentials from local storage and therefors logs out
  Future<void> logout() async {
    try {
      final currentUser = await _c_user;
      if (currentUser != null) {
        await currentUser.unstore();
        debugPrint('User-Daten gelöscht');
      }
      _user = null;
      _touchedPrueferForProjects.clear();
      _prueferByPjNr.clear();
      debugPrint('User ausgeloggt');
    } catch (e) {
      debugPrint('Fehler beim Ausloggen: $e');
      // Trotz Fehler zurücksetzen, um UI-Update zu ermöglichen
      _user = null;
      _touchedPrueferForProjects.clear();
      _prueferByPjNr.clear();
    }
  }

  /// gets all the [ChildData]points for the given [ParentData]
  /// if no [ParentData] is given it defaults to root
  Stream<List<ChildData>>
      getNextDatapoint<ChildData extends Data, ParentData extends WithOffline?>(
    ParentData data, {
    bool preloadFullImages = false,
  }) async* {
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

    Future<List<ChildData>> filterHiddenIfRootInspections(
        List<ChildData> children) async {
      if (typeOf<ChildData>() != typeOf<InspectionLocation>() || data != null) {
        return children;
      }
      final hiddenPjNrs = await InspectionVisibility().getHiddenPjNrs();
      if (hiddenPjNrs.isEmpty) return children;
      return children.where((child) {
        if (child is InspectionLocation) {
          return !hiddenPjNrs.contains(child.pjNr.toString());
        }
        return true;
      }).toList();
    }

    yield* _run(
      itPrefersCache: _dataPrefersCache(data, type: requestType),
      offline: () async => filterHiddenIfRootInspections(
          await local.getNextDatapoint<ChildData, ParentData>(data)),
      online: () async {
        final rap = remote.getNextDatapoint<ChildData, ParentData>(
          data,
          preloadFullImages: preloadFullImages,
        );
        return RequestAndParser<http.Response, List<ChildData>>(
          rd: rap.rd,
          parser: (response) async =>
              filterHiddenIfRootInspections(await rap.parser(response)),
        );
      },
      onlineSuccessCB: (childDatas) async {
        _cachePrueferIdsFromLocations(childDatas);
        if (typeOf<ChildData>() == typeOf<InspectionLocation>() &&
            data == null) {
          await _pruneStaleRootInspectionCache(
            childDatas.whereType<InspectionLocation>().toList(),
          );
        }
        for (final childData in childDatas) {
          // "offline" is a local-only flag; online data should clear it to avoid stale UI indicators.
          try {
            (childData as WithOffline).forceOffline = false;
          } catch (_) {}
          await local.storeData(
            childData,
            forId: data?.id ?? await API().rootID,
          );
        }
      },
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
    await _touchPrueferIfNeeded(
      requestType: requestType,
      data: data,
      caller: caller,
    );
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
    await _touchPrueferIfNeeded(
      requestType: requestType,
      data: data,
      caller: caller,
    );
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
    await _touchPrueferIfNeeded(
      requestType: requestType,
      data: data,
      caller: caller,
    );
    return _run(
      itPrefersCache: _dataPrefersCache(caller, type: requestType),
      offline: () => local.delete(data, caller: caller),
      online: () => remote.delete(data),
      requestType: requestType,
    ).last;
  }

  /// gets image specified by its hash
  Future<ImageData?> getImageByHash(String hash, {Data? owner}) async {
    // Scoped/local hashes (with folders or local prefix) must not trigger remote fetches
    final isLocalScoped = hash.contains('/') ||
        hash.startsWith(LOCALLY_ADDED_PREFIX) ||
        isTimestampImageFilename(hash);

    // Always prefer local cache first; if present, never hit network.
    try {
      return await local.getImageByHash(hash, owner: owner);
    } catch (_) {
      // not cached locally (or unreadable) -> continue
    }

    // For local-scoped names we never download remotely.
    if (isLocalScoped) return null;

    final activeDownload = DownloadProgress.instance.active;
    if (activeDownload != null &&
        activeDownload.notifier.value.stepIndex <
            InspectionDownloadSteps.photos) {
      return null;
    }

    // Deduplicate in-flight downloads for the same hash to prevent repeated
    // downloads on rebuild/opening views.
    final key = hash;
    final existing = _inflightImageFetches[key];
    if (existing != null) return await existing;

    Future<ImageData?> fetchRemote() async {
      final progressSession = DownloadProgress.instance.active;
      final progressToken = progressSession?.beginTask(
        '',
        key: '/image/get|$hash',
        step: InspectionDownloadSteps.photos,
      );

      void completeProgress(bool success) {
        if (progressToken != null) {
          progressSession?.endTask(progressToken, success: success);
        }
      }

      try {
        await tryNetwork(requestType: Helper.SimulatedRequestType.GET);
        final rap = remote.getImageByHash(hash, owner: owner);
        final res = await remote.postJSON(rap.rd);
        if (res == null) {
          completeProgress(false);
          return null;
        }
        final parsed = await rap.parser(res);
        completeProgress(parsed != null);
        if (parsed != null) return parsed;
      } catch (_) {}
      // last-chance local read (in case another concurrent fetch stored it)
      try {
        final cached = await local.getImageByHash(hash, owner: owner);
        completeProgress(cached != null);
        return cached;
      } catch (_) {
        completeProgress(false);
        return null;
      }
    }

    Future<ImageData?> fetch() async {
      final session = DownloadProgress.instance.active;
      if (session == null) return fetchRemote();
      return session.enqueueDownload(fetchRemote);
    }

    final future = fetch();
    _inflightImageFetches[key] = future;
    try {
      return await future;
    } finally {
      _inflightImageFetches.remove(key);
    }
  }

  Future<File?> getDocument(String path, {Data? owner, String? scope}) async {
    final requestType = Helper.SimulatedRequestType.GET;
    final effectiveScope = (scope != null && scope.isNotEmpty)
        ? scope
        : (owner != null ? local.scopeFor(owner) : null);

    try {
      return await local.getDocument(path, scope: effectiveScope);
    } catch (_) {}

    final key = '${effectiveScope ?? ''}|$path';
    final existing = _inflightDocumentFetches[key];
    if (existing != null) return existing;

    Future<File?> fetchRemote() async {
      final progressSession = DownloadProgress.instance.active;
      final progressToken = progressSession?.beginTask(
        '',
        key: '/doc/get|$path',
        step: InspectionDownloadSteps.documents,
      );
      try {
        await tryNetwork(requestType: requestType);
        final request = remote.getDocument(path, scope: effectiveScope);
        final response = await remote.postJSON(request.rd);
        if (response == null) {
          if (progressToken != null) {
            progressSession?.endTask(progressToken, success: false);
          }
          return null;
        }
        final document = await request.parser(response);
        if (progressToken != null) {
          progressSession?.endTask(progressToken, success: document != null);
        }
        return document;
      } catch (_) {
        if (progressToken != null) {
          progressSession?.endTask(progressToken, success: false);
        }
        try {
          return await local.getDocument(path, scope: effectiveScope);
        } catch (_) {
          return null;
        }
      }
    }

    Future<File?> fetch() async {
      final session = DownloadProgress.instance.active;
      if (session == null) return fetchRemote();
      return session.enqueueDownload(fetchRemote);
    }

    final future = fetch();
    _inflightDocumentFetches[key] = future;
    try {
      return await future;
    } finally {
      _inflightDocumentFetches.remove(key);
    }
  }

  /// deletes an image specified by its hash and returns the response
  Future<String?> deleteImageByHash<DataT extends Data>(
    DataT? data,
    String hash, {
    Data? caller,
    bool forceUpdate = false,
  }) async {
    final requestType = Helper.SimulatedRequestType.PUT;
    await _touchPrueferIfNeeded(
      requestType: requestType,
      data: data,
      caller: caller,
    );
    final requestedHash = hash.trim();
    final scope = local.scopeFor(data, caller: caller);
    var remoteHash = requestedHash;
    try {
      final mapped = await lookupHashForImageName(
        requestedHash,
        scope: scope,
      );
      if (mapped != null && mapped.trim().isNotEmpty) {
        remoteHash = mapped.trim();
      }
    } catch (_) {}

    if (data?.mainhash != null &&
        (data!.mainhash == requestedHash || data.mainhash == remoteHash)) {
      data.mainhash = null;
      debugPrint('deleted mainhash');
      await update(data, caller: caller, forceUpdate: forceUpdate);
    }

    final prefersCache = forceUpdate
        ? false
        : (_dataPrefersCache(data, type: requestType) ??
            _dataPrefersCache(caller, type: requestType) ??
            false);
    debugPrint(
      'deleteImageByHash: requested=$requestedHash remote=$remoteHash forceUpdate=$forceUpdate prefersCache=$prefersCache',
    );

    return _run(
      itPrefersCache: prefersCache,
      // offline: () => local.setMainImageByHash(
      //   data,
      //   hash,
      //   caller: caller,
      //   forceUpdate: forceUpdate,
      // ),
      offline: () => local.deleteImageByHash(
        data,
        requestedHash,
        canonicalHash: remoteHash,
        caller: caller,
        forceUpdate: forceUpdate,
      ),
      online: () => remote.deleteImageByHash(
        remoteHash,
        data: data,
      ),
      requestType: requestType,
    ).last;
  }

  Future<String?> rotateImageByHash<DataT extends Data>(
    DataT? data,
    String hash, {
    int quarterTurns = 1,
    Data? caller,
    bool forceUpdate = false,
  }) async {
    try {
      if (data == null) return 'no data to rotate';

      var turns = quarterTurns % 4;
      if (turns < 0) turns += 4;
      if (turns == 0) return 'rotation unchanged';

      final requested = hash.trim();
      if (requested.isEmpty) return 'no image selected';
      final scope = local.scopeFor(data, caller: caller).trim();

      File? sourceFile = await resolveImageFileByHash(requested, scope: scope);
      if (sourceFile == null && !_isLocalImageReference(requested)) {
        final mapped = await lookupImageNameForHash(requested, scope: scope);
        if (mapped != null && mapped.trim().isNotEmpty) {
          sourceFile =
              await resolveImageFileByHash(mapped.trim(), scope: scope);
        }
      }
      if (sourceFile == null) {
        return 'image not found locally';
      }

      final originalBytes = await sourceFile.readAsBytes();
      final decoded = imglib.decodeImage(originalBytes);
      if (decoded == null) return 'could not decode image';
      final rotated = imglib.copyRotate(decoded, angle: 90 * turns);
      final rotatedBytes =
          _encodeRotatedImageBytes(rotated, sourceFile.path.toLowerCase());

      // Local-only image refs (timestamp/scoped/local prefixes) are uploaded by
      // pending multipart requests. Overwrite the file in place so sync uploads
      // the rotated bytes.
      if (_isLocalImageReference(requested)) {
        await sourceFile.writeAsBytes(rotatedBytes, flush: true);
        await FileImage(sourceFile).evict();
        return 'image rotated locally';
      }

      // Backend hash: create a rotated replacement image, upload it, then remove
      // the old hash so backend and local state stay in sync.
      final oldRefs = _collectImageRefs(data);
      final wasMainImage = data.mainhash == requested;
      final newScopedName = await _nextScopedImageName(scope);
      final rotatedFile = await storeImage(rotatedBytes, newScopedName);
      if (rotatedFile == null) return 'could not persist rotated image';
      await FileImage(rotatedFile).evict();

      final uploadResult = await uploadNewImagesOrFiles<DataT>(
        data,
        [XFile(rotatedFile.path)],
        caller: caller,
        forceUpdate: forceUpdate,
      );

      final newRefs = _collectImageRefs(data);
      final addedRefs = newRefs.difference(oldRefs);
      final replacementRef = addedRefs.isEmpty ? null : addedRefs.first;

      if (wasMainImage && replacementRef != null) {
        await setMainImageByHash(
          data,
          replacementRef,
          caller: caller,
          forceUpdate: forceUpdate,
        );
      }

      await deleteImageByHash(
        data,
        requested,
        caller: caller,
        forceUpdate: forceUpdate,
      );
      return uploadResult ?? 'rotated image queued for sync';
    } catch (e) {
      return 'rotate failed: $e';
    }
  }

  // sets an image specified by its hash as the new main image
  Future<String?> setMainImageByHash<DataT extends Data>(
    DataT? data,
    String mainhash, {
    Data? caller,
    bool forceUpdate = false,
  }) async {
    final requestType = Helper.SimulatedRequestType.PUT;
    await _touchPrueferIfNeeded(
      requestType: requestType,
      data: data,
      caller: caller,
    );
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

  /// upload / add a bunch of images
  Future<String?> uploadNewImagesOrFiles<DataT extends Data>(
    DataT data,
    List<XFile> files, {
    Data? caller,
    bool forceUpdate = false,
  }) async {
    final preparedFiles =
        await _normalizeUploadFilesForStorage(data, files, caller: caller);

    // Wenn forceOffline aktiv ist: nur lokal speichern und Request zum Retry vormerken
    bool prefersOffline =
        _dataPrefersCache(caller, type: Helper.SimulatedRequestType.PUT) ??
            false;
    // fallback: nutze Daten-Flag oder globale Option
    try {
      prefersOffline = prefersOffline || (caller as WithOffline).forceOffline;
    } catch (_) {}
    try {
      prefersOffline = prefersOffline || (data as WithOffline).forceOffline;
    } catch (_) {}
    prefersOffline = prefersOffline || Options().forceOffline;

    // Always persist images locally first (even when online), so cache and
    // on-device storage are immediately available with canonical filenames.
    await local.uploadNewImagesOrFiles(
      data,
      preparedFiles,
      caller: caller,
      forceUpdate: forceUpdate,
    );

    if (prefersOffline) {
      final rap = remote.uploadNewImagesOrFiles<DataT>(data, preparedFiles);
      await local.logFailedReq(rap.rd);
      return 'added files offline (queued)';
    }

    await _touchPrueferIfNeeded(
      requestType: Helper.SimulatedRequestType.PUT,
      data: data,
      caller: caller,
    );

    final requestType = Helper.SimulatedRequestType.PUT;
    return _run(
      itPrefersCache: _dataPrefersCache(data, type: requestType),
      offline: () async => 'added files offline',
      online: () => remote.uploadNewImagesOrFiles(
        data,
        preparedFiles,
      ),
      onlineSuccessCB: (body) async {
        // If the backend returns hashes for uploaded images, replace any local placeholders.
        try {
          final decoded = jsonDecode(body ?? '');
          final uploaded = (decoded is Map) ? decoded['uploaded_images'] : null;
          if (uploaded is List) {
            final map = <String, String>{};
            for (final e in uploaded) {
              if (e is Map) {
                final client = e['client_filename']?.toString();
                final hash = e['hash']?.toString();
                if (client != null &&
                    client.isNotEmpty &&
                    hash != null &&
                    hash.isNotEmpty) {
                  map[client] = hash;
                  final scope = local.scopeFor(data, caller: caller);
                  final base =
                      client.contains('/') ? client.split('/').last : client;
                  final baseNoLocalPrefix =
                      base.startsWith(LOCALLY_ADDED_PREFIX)
                          ? base.substring(LOCALLY_ADDED_PREFIX.length)
                          : base;
                  final localPrefixedBase =
                      '$LOCALLY_ADDED_PREFIX$baseNoLocalPrefix';
                  map[base] = hash;
                  map[baseNoLocalPrefix] = hash;
                  map[localPrefixedBase] = hash;

                  String scoped(String b) => scope.isNotEmpty ? '$scope/$b' : b;

                  final candidateStoredNames = <String>[
                    scoped(baseNoLocalPrefix),
                    scoped(base),
                    scoped(localPrefixedBase),
                  ];
                  String storedName = candidateStoredNames.first;
                  for (final candidate in candidateStoredNames) {
                    final f = await localFile(candidate);
                    if (f.existsSync()) {
                      storedName = candidate;
                      break;
                    }
                  }

                  await indexImageHash(
                    hash: hash,
                    storedName: storedName,
                    scope: scope,
                  );
                  final fallbackStoredName =
                      scope.isNotEmpty ? '$scope/$hash' : hash;
                  if (fallbackStoredName != storedName) {
                    try {
                      final fallbackFile = await localFile(fallbackStoredName);
                      if (fallbackFile.existsSync()) {
                        await fallbackFile.delete();
                      }
                    } catch (_) {}
                  }
                }
              }
            }
            if (map.isNotEmpty) {
              String? rewrite(String? v) {
                if (v == null) return null;
                // match scoped values like "<scope>/<client_filename>"
                final base = v.contains('/') ? v.split('/').last : v;
                final repl = map[base] ?? map[v];
                return repl ?? v;
              }

              data.mainhash = rewrite(data.mainhash);
              if (data.imagehashes != null) {
                data.imagehashes =
                    data.imagehashes!.map((h) => rewrite(h) ?? h).toList();
              }

              // Persist updated hashes locally so subsequent requests use backend hashes.
              try {
                await local.storeData(
                  data,
                  forId: caller?.id ?? await rootID,
                );
              } catch (_) {}
            }
          }
        } catch (_) {}
      },
      // onlineSuccessCB: (response) async {},
      onlineFailedCB: (onlineRes, rap) {
        debugPrint('failed to upload images, ' +
            rap.rd.json.toString() +
            ': ' +
            onlineRes.toString());
        var rd = rap.rd;
        //biscchen ugly
        // rd.multipartFiles = rd.multipartFiles.map((_e) async {
        //   var e = await _e;
        //   // e.name = newName;
        //   var newName = LOCALLY_ADDED_PREFIX + e.name;
        //   var newPath =
        //       e.path.substring(0, e.path.length - e.name.length) + newName;
        //   e.saveTo(newPath);
        //   e = XFile(newPath);
        //   return e;
        // }).toList();
        local.logFailedReq(rd);
      },
      requestType: requestType,
    ).last;
  }

  /// Versucht, einen HTTP-Request unter Berücksichtigung möglicher Socket-Fehler durchzuführen
  /// Diese Methode erweitert die bestehende postJSON-Methode und fügt Wiederverbindungs-Logik hinzu
  Future<http.Response?> postJSONWithSocketRetry(
    RequestData requestData, {
    int maxRetries = 3,
    Duration retryDelay = const Duration(seconds: 2),
  }) async {
    int attempts = 0;
    SocketException? lastSocketException;

    while (attempts < maxRetries) {
      try {
        // Verwende die postJSON-Methode von remote
        final response = await remote.postJSON(requestData);
        return response as http.Response?;
      } on SocketException catch (e) {
        lastSocketException = e;
        attempts++;

        debugPrint(
            'Socket-Fehler bei Versuch $attempts/$maxRetries: ${e.message}');

        // Wenn es sich um einen "Write failed" oder "Connection abort" Fehler handelt
        if (e.message.contains('Write failed') ||
            e.message.contains('connection abort') ||
            e.message.contains('Connection refused')) {
          debugPrint(
              'Erkannter Socket-Fehler im Hintergrund, warte vor Wiederversuch...');

          // Warte etwas länger bei Socket-Fehlern, die typischerweise im Hintergrund auftreten
          await Future.delayed(retryDelay * attempts);

          // Versuche die Verbindung zurückzusetzen
          try {
            HttpClient().close(force: true);
            debugPrint('HTTP-Client zurückgesetzt');
          } catch (resetError) {
            debugPrint(
                'Fehler beim Zurücksetzen des HTTP-Clients: $resetError');
          }

          continue;
        }

        // Andere Socket-Fehler
        await Future.delayed(retryDelay);
      } catch (e) {
        // Andere Fehler einfach durchreichen
        debugPrint('Nicht-Socket-Fehler bei HTTP-Request: $e');
        rethrow;
      }
    }

    if (lastSocketException != null) {
      debugPrint(
          'Maximale Wiederversuche überschritten, werfe letzten Socket-Fehler');
      throw lastSocketException;
    }

    throw Exception('Unbekannter Fehler bei der HTTP-Kommunikation');
  }
}

D injectImages<D extends Data>(D data, {bool preloadFull = false}) {
  Future<ImageData?> getImgDataFromHash(String? hash) {
    if (hash == null) return Future.value(null);

    return API().getImageByHash(hash, owner: data).catchError((e, st) {
      debugPrint('getImageByHash failed ($hash): $e');
      return null;
    });
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
