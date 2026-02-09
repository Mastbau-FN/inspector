import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:MBG_Inspektionen/backend/local.dart';
import 'package:MBG_Inspektionen/classes/imageData.dart';
import 'package:MBG_Inspektionen/classes/requestData.dart' show RequestData;
import 'package:MBG_Inspektionen/backend/offlineProvider.dart' as OP;
import 'package:MBG_Inspektionen/env.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:MBG_Inspektionen/classes/dropdownClasses.dart';
import 'package:MBG_Inspektionen/l10n/locales.dart';
import '../helpers/toast.dart';
import '/classes/exceptions.dart';
import '/classes/user.dart';

import './helpers.dart' as Helper;
import 'api.dart';

class _AsyncSemaphore {
  int _available;
  final Queue<Completer<void>> _waiters = Queue<Completer<void>>();

  _AsyncSemaphore(int maxPermits) : _available = maxPermits;

  Future<T> withPermit<T>(Future<T> Function() fn) async {
    await _acquire();
    try {
      return await fn();
    } finally {
      _release();
    }
  }

  Future<void> _acquire() {
    if (_available > 0) {
      _available -= 1;
      return Future.value();
    }
    final c = Completer<void>();
    _waiters.add(c);
    return c.future;
  }

  void _release() {
    if (_waiters.isNotEmpty) {
      _waiters.removeFirst().complete();
      return;
    }
    _available += 1;
  }
}

String routesFromData<DataT extends Data>(DataT? data) =>
    '/${Helper.getIdentifierFromData(data)}/get';

const _getImageFromHash_r = '/image/get';
const _uploadImage_r = "/image/set";

const _getDocFromHash_r = '/doc/get';

const _addNew_r = "/set";
const _update_r = "/update";
const _delete_r = "/delete"; // issue #36

const _touchPruefer_r = "/pruefer/touch";

const _deleteImageByHash_r = "/deleteImgH"; // issue #39
const _setMainImageByHash_r = "/setMainImgH"; // issue #20

class TouchPrueferResult {
  final bool updated;
  final int? oldLoginIdPruefer;
  final int? loginIdPruefer;

  TouchPrueferResult({
    required this.updated,
    required this.oldLoginIdPruefer,
    required this.loginIdPruefer,
  });

  static int? _parseInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  static TouchPrueferResult fromJson(Map<String, dynamic> json) {
    return TouchPrueferResult(
      updated: json['updated'] == true,
      oldLoginIdPruefer: _parseInt(json['old_login_id_pruefer']),
      loginIdPruefer: _parseInt(json['login_id_pruefer']),
    );
  }
}

class RequestAndParser<Response extends http.BaseResponse, T> {
  final RequestData rd;
  final FutureOr<T> Function(Response) parser;

  RequestAndParser({required this.rd, required this.parser});
}

extension _Parser on http.BaseResponse {
  http.Response? forceRes() {
    try {
      return this as http.Response;
    } catch (e) {
      return null;
    }
  }
}

/// backend Singleton to provide all functionality related to the backend
class Remote {
  // MARK: internals

  static final Remote _instance = Remote._internal();

  factory Remote() => _instance;

  Remote._internal() {
    // init
  }

  final http.Client _client = http.Client();
  final _AsyncSemaphore _binaryDownloadSemaphore = _AsyncSemaphore(4);

  User? _user;
  injectUser(User? user) {
    if (user == null) {
      _user = null;
      debugPrint('Remote.injectUser: user=null');
      return;
    }

    // Preserve Def_Login_ID if we already know it and the incoming user doesn't have it yet.
    if (_user != null &&
        _user?.name == user.name &&
        user.defLoginId == null &&
        _user?.defLoginId != null) {
      user.defLoginId = _user?.defLoginId;
    }

    _user = user;
    debugPrint(
        'Remote.injectUser: KZL=${_user?.name}, Def_Login_ID=${_user?.defLoginId}, hash=${_user.hashCode}');
  }

  final _baseurl = Env.mbgUrl;
  // ignore: non_constant_identifier_names
  final _api_key = Env.mbgKey;

  // MARK: available Helpers

  /// checks whether a connection to the backend is possible
  /// throws [NoConnectionToBackendException] or [SocketException] if its not.
  Future connectionGuard({Duration? timeout}) async {
    try {
      // check if we can reach our api
      await postJSON(RequestData(
        '/login',
        // json: {'user': User('test  ', 'test').toJson()},
        timeout: timeout,
      )); ////logIfFailed: false));
    } catch (e) {
      throw NoConnectionToBackendException(
          S.current!.couldntReach + " $_baseurl");
    }
  }

  /// make an actual API request to a route, and always append the API_KEY as authorization-header
  Future<http.Response?> post(
    String route, {
    Map<String, String>? headers,
    String? body,
    Encoding? encoding,
    Duration? timeout,
  }) =>
      send(
        makepost(route, headers: headers, body: body, encoding: encoding),
        timeout: timeout,
      );

  Future<http.Response?> send(
    http.Request request, {
    Duration? timeout,
    bool returnsBinary = false,
  }) async {
    Future<http.Response?> doSendOnce(http.Request req) async {
      final streamed = await _client.send(req).timeout(timeout!, onTimeout: () {
        debugPrint('HTTP Request Timeout nach ${timeout?.inSeconds} Sekunden');
        throw TimeoutException('HTTP Request Timeout', timeout);
      });

      if (!returnsBinary) {
        return http.Response.fromStream(streamed);
      }

      // For binary responses (images/docs): read manually to reduce stream errors
      // and avoid unhandled exceptions from partially closed connections.
      final builder = BytesBuilder(copy: false);
      await for (final chunk in streamed.stream) {
        builder.add(chunk);
      }
      return http.Response.bytes(
        builder.takeBytes(),
        streamed.statusCode,
        headers: streamed.headers,
        request: streamed.request,
        isRedirect: streamed.isRedirect,
        persistentConnection: streamed.persistentConnection,
        reasonPhrase: streamed.reasonPhrase,
      );
    }

    http.Request clone(http.Request req) {
      final r = http.Request(req.method, req.url);
      r.headers.addAll(req.headers);
      r.bodyBytes = req.bodyBytes;
      r.encoding = req.encoding;
      r.followRedirects = req.followRedirects;
      r.maxRedirects = req.maxRedirects;
      r.persistentConnection = req.persistentConnection;
      return r;
    }

    bool isRetryableStreamError(Object e) {
      if (e is http.ClientException) {
        final msg = e.message.toLowerCase();
        return msg.contains('connection closed') ||
            msg.contains('connection reset') ||
            msg.contains('broken pipe');
      }
      if (e is IOException) return true;
      return false;
    }

    // Verwende einen längeren Standard-Timeout, wenn keiner angegeben ist
    timeout ??= Duration(minutes: 2);

    final runner = returnsBinary
        ? _binaryDownloadSemaphore.withPermit<http.Response?>(() async {
            return _sendWithRetries(
              () => doSendOnce(clone(request)),
              isRetryable: isRetryableStreamError,
            );
          })
        : _sendWithRetries(
            () => doSendOnce(clone(request)),
            isRetryable: isRetryableStreamError,
          );

    try {
      return await runner;
    } on SocketException catch (e) {
      debugPrint('Socket-Fehler beim Senden des Requests: ${e.message}');
      if (e.message.contains('Software caused connection abort') ||
          e.message.contains('Write failed')) {
        debugPrint(
            'App wahrscheinlich im Hintergrund, Socket wurde vom System geschlossen');
      }
      rethrow;
    } catch (e) {
      debugPrint('Fehler beim Senden des Requests: $e');
      rethrow;
    }
  }

  Future<T> _sendWithRetries<T>(
    Future<T> Function() attempt, {
    required bool Function(Object e) isRetryable,
    int maxRetries = 2,
  }) async {
    int tries = 0;
    while (true) {
      try {
        return await attempt();
      } catch (e) {
        tries += 1;
        if (tries > maxRetries || !isRetryable(e)) rethrow;
        final backoffMs = 300 * tries;
        debugPrint('Retrying request after error ($tries/$maxRetries): $e');
        await Future<void>.delayed(Duration(milliseconds: backoffMs));
      }
    }
  }

  /// make an actual API request to a route, and always append the API_KEY as authorization-header
  http.Request makepost(
    String route, {
    Map<String, String>? headers,
    String? body,
    Encoding? encoding,
  }) {
    headers = headers ?? {};
    headers.addAll({HttpHeaders.authorizationHeader: _api_key});
    var fullURL = Uri.parse(_baseurl + route);
    final req = http.Request('post', fullURL)..headers.addAll(headers);
    if (encoding != null) req.encoding = encoding;
    if (body != null) req.body = body;
    return req;
  }

  /// post_JSON to our backend as the user
  Future<http.BaseResponse?> postJSON(RequestData rd) async {
    var headers = {HttpHeaders.contentTypeHeader: 'application/json'};
    rd.json ??= {};
    rd.json!['user'] = _user?.toJson();
    debugPrint(
        'Sending request ${rd.route} as KZL=${_user?.name}, Def_Login_ID=${_user?.defLoginId}, hash=${_user.hashCode}');
    try {
      if (rd.multipartFiles.isNotEmpty) {
        http.MultipartRequest? mreq;
        try {
          var fullURL = Uri.parse(_baseurl + rd.route);
          mreq = http.MultipartRequest('POST', fullURL)
            ..files.addAll(
              List<http.MultipartFile>.from((await Future.wait(
                rd.multipartFiles.map(
                  (fxfile) async {
                    final xfile = await fxfile;
                    final name = xfile.name;
                    var creation = 0;
                    creation = FileStat.statSync(xfile.path)
                        .changed
                        .toUtc()
                        .millisecondsSinceEpoch;
                    final path = xfile.path;
                    return http.MultipartFile.fromPath(
                        creation.toString(), path,
                        filename: name);
                  },
                ),
              ))
                  .whereType<http.MultipartFile>()),
            )
            ..headers.addAll({HttpHeaders.authorizationHeader: _api_key})
            ..fields.addAll(/*flatten()*/ rd.json!.map<String, String>(
                (key, value) => MapEntry(
                    key,
                    value
                        .toString()))); // this causes #279, but that is fixed in backend, since the formrequests fields is Map<String, String> and not Map<String, dynamic>
          debugPrint("gonna send multipart-req with booty ${mreq.fields}");
          var res = (rd.timeout == null)
              ? await _client.send(mreq)
              : await _client.send(mreq).timeout(rd.timeout!);
          return res;
        } on SocketException catch (e) {
          debugPrint('Socket-Fehler bei Multipart-Request: ${e.message}');
          if (e.message.contains('Write failed') ||
              e.message.contains('connection abort') ||
              e.message.contains('Connection refused') ||
              e.message.contains('Software caused connection abort')) {
            debugPrint(
                'Hintergrund-Socket-Fehler erkannt, App möglicherweise im Hintergrund');
          }
          rethrow;
        } on Exception catch (e) {
          debugPrint('multipartRequest, failed: $e');
          rethrow;
        }
      } else {
        final req =
            makepost(rd.route, headers: headers, body: jsonEncode(rd.json));
        try {
          // Erhöhe die Robustheit des Requests speziell für Hintergrundausführung
          final response = await send(
            req,
            timeout:
                rd.timeout ?? Duration(minutes: 2), // Längerer Standard-Timeout
            returnsBinary: rd.returnsBinary,
          );

          return response;
        } on SocketException catch (e) {
          debugPrint('Socket-Fehler bei HTTP-Request: ${e.message}');
          if (e.message.contains('Write failed') ||
              e.message.contains('connection abort') ||
              e.message.contains('Connection refused') ||
              e.message.contains('Software caused connection abort')) {
            debugPrint(
                'Hintergrund-Socket-Fehler erkannt, App möglicherweise im Hintergrund');
          }
          rethrow;
        } catch (e) {
          debugPrint('request failed: $e');
          rethrow;
        }
      }
    } catch (e) {
      debugPrint("request failed, cause : $e");
      return null;
    }
  }

  /// Erweiterte Version von postJSON mit robuster Behandlung von Socket-Fehlern
  /// Besonders wichtig für Hintergrundprozesse, bei denen die App in den Hintergrund wechselt
  Future<http.BaseResponse?> postJSONWithSocketRetry(
    RequestData rd, {
    int maxRetries = 3,
    Duration initialDelay = const Duration(seconds: 2),
    bool exponentialBackoff = true,
  }) async {
    int attempts = 0;
    SocketException? lastSocketException;
    Duration currentDelay = initialDelay;

    while (attempts < maxRetries) {
      try {
        // Verwende die ursprüngliche postJSON-Methode
        final response = await postJSON(rd);
        if (response != null) {
          return response;
        } else {
          // Wenn null zurückkommt, war ein Fehler aufgetreten
          attempts++;
          debugPrint('Null-Antwort bei Versuch $attempts/$maxRetries');
        }
      } on SocketException catch (e) {
        lastSocketException = e;
        attempts++;

        debugPrint(
            'Socket-Fehler bei Versuch $attempts/$maxRetries: ${e.message}');

        // Spezielle Behandlung für typische Hintergrund-Socket-Fehler
        if (e.message.contains('Write failed') ||
            e.message.contains('connection abort') ||
            e.message.contains('Connection refused') ||
            e.message.contains('Software caused connection abort')) {
          debugPrint(
              'Erkannter Socket-Fehler im Hintergrund, warte vor Wiederversuch...');

          // Versuche die Verbindung zurückzusetzen
          try {
            final client = HttpClient();
            client.connectionTimeout = Duration(seconds: 30);
            client.idleTimeout = Duration(minutes: 2);
            client.close(force: true);
            debugPrint('HTTP-Client zurückgesetzt');
          } catch (resetError) {
            debugPrint(
                'Fehler beim Zurücksetzen des HTTP-Clients: $resetError');
          }
        }
      } catch (e) {
        attempts++;
        debugPrint(
            'Allgemeiner Fehler bei HTTP-Request (Versuch $attempts/$maxRetries): $e');
      }

      // Warte vor dem nächsten Versuch
      await Future.delayed(currentDelay);

      // Erhöhe die Wartezeit bei exponentiellem Backoff
      if (exponentialBackoff) {
        currentDelay *= 2;
      }
    }

    if (lastSocketException != null) {
      // Werfe den letzten Socket-Fehler, wenn wir hier angekommen sind
      throw lastSocketException;
    }

    debugPrint('Alle Wiederholungsversuche ausgeschöpft ohne Erfolg');
    return null; // Konsistent mit dem Rückgabewert von postJSON bei Fehlern
  }

  //final _imageStreamController = BehaviorSubject<String>();
  RequestAndParser<http.BaseResponse, ImageData?> getImageByHash(String hash,
      {bool compressed = false, Data? owner}) {
    final isPathHash = hash.contains('/');
    final rd = switch (kIsWeb) {
      true => RequestData('/login'),
      false => RequestData(
          _getImageFromHash_r,
          json: {
            'hash': hash,
            'compressed': compressed,
          },
          returnsBinary: true,
        )
    };

    parser(http.BaseResponse _res) async {
      if (kIsWeb)
        return ImageData(
            Image(
                image: NetworkImage("$_baseurl/get/compressed/$hash",
                    headers: {HttpHeaders.authorizationHeader: _api_key})),
            id: hash);
      final res = _res.forceRes();
      if (res == null || res.statusCode ~/ 100 != 2)
        return null;
      else {
        try {
          final scope = owner != null ? API().local.scopeFor(owner) : '';
          final name = compressed ? OP.convertToCompressedHashName(hash) : hash;
          final scopedName =
              (!isPathHash && scope.isNotEmpty) ? '$scope/$name' : name;
          await API().local.storeImage(res.bodyBytes, scopedName);
          return ImageData(
            (await API().local.readImage(scopedName,
                cacheSize: compressed ? CACHESIZE : null))!,
            id: hash,
          );
        } catch (e) {
          debugPrint("failed to load webimg: " + e.toString());
        }
      }
    }

    return RequestAndParser(rd: rd, parser: parser);
  }

  Future<DataT?> Function(Map<String, dynamic>)
      _generateImageFetcher<DataT extends Data>(
          DataT? Function(Map<String, dynamic>) jsoner,
          {bool preloadFullImages = false}) {
    // only fetch first image automagically and the others only when said so (or at least not make the UI wait for it (#34, #35))
    return (Map<String, dynamic> json) async {
      DataT? data = jsoner(json);
      if (data == null) return null;
      return injectImages(data, preloadFull: preloadFullImages);
    };
  }

  RequestAndParser<http.BaseResponse, File?> getDocument(String docPath) {
    final rd = switch (kIsWeb) {
      true => RequestData('/login'),
      false => RequestData(
          _getDocFromHash_r,
          json: {
            'docPath': docPath,
          },
          returnsBinary: true,
        )
    };
    debugPrint("fssgfsfsdf" + rd.toString());

    parser(http.BaseResponse _res) async {
      final res = _res.forceRes();
      if (res == null || res.statusCode ~/ 100 != 2)
        return null;
      else {
        try {
          await API().local.storeDoc(res.bodyBytes, docPath.split('/').last);
          return API().local.readDoc(docPath.split('/').last);
        } catch (e) {
          debugPrint("failed to load webimg: " + e.toString());
        }
      }
    }

    return RequestAndParser(rd: rd, parser: parser);
  }

  // Future<String> get rootID async => _user!.name;

  /// Helper function to get the next [Data] (e.g. all [CheckPoint]s for chosen [CheckCategory])
  RequestAndParser<http.Response, List<ChildData>>
      _getAllForNextLevel<ChildData extends Data, ParentData extends Data>({
    required String route,
    required String jsonResponseID,
    Map<String, dynamic>? json,
    preloadFullImages = false,
    required ChildData? Function(Map<String, dynamic>) fromJson,
  }) {
    final rd = RequestData(
      route,
      json: json,
      timeout: Duration(seconds: 10),
      ////logIfFailed: false,
    );

    Future<List<ChildData>> parser(http.Response? res) {
      Future<ChildData?> Function(Map<String, dynamic>) imageFetcher =
          _generateImageFetcher(fromJson, preloadFullImages: preloadFullImages);
      Future<List<ChildData>> __parse(__json) => getListFromJson(
            __json,
            imageFetcher,
            objName: jsonResponseID,
          );
      final body = res!.forceRes()!.body;
      final _json = jsonDecode(body);
      return __parse(_json);
    }

    return RequestAndParser(rd: rd, parser: parser);
  }

  /// sends a [DataT] with the corresponding identifier to the given route
  RequestAndParser<http.Response, http.Response?>
      _sendDataToRoute<DataT extends Data>({
    required DataT? data,
    required String route,
    Map<String, dynamic> other = const {},
  }) {
    assert(data != null, 'we cant send no data, data needs to be supplied');
    var jsonData = data!.toJson();
    // Never upload local-only flags.
    jsonData.remove('offline');
    jsonData.remove('parent_local_id');
    final rd = RequestData(route, json: {
      'type': Helper.getIdentifierFromData(data),
      'data': jsonData,
      ...other
    });

    parser(http.Response? res) {
      res = res?.forceRes();

      if (res != null && res.statusCode ~/ 100 != 2) {
        _maybeShowToast(
            "${S.current!.anUnknownErrorOccured}, ${res.statusCode}: ${res.reasonPhrase}");
      }
      return res;
    }

    return RequestAndParser(rd: rd, parser: parser);
  }

  void _maybeShowToast(String? message) {
    if (message != null && message != "") {
      showToast(message);
    }
  }

  // MARK: API

  /// login a [User] by checking if he exists in the remote database
  Future<User?> login(User user) async {
    // if user is already logged in
    await connectionGuard();
    _user = user;
    var res = (await postJSON(RequestData(
      '/login',
    ))) ////logIfFailed: false)))
        ?.forceRes();
    if (res != null && (res.statusCode ~/ 100 == 2)) {
      //success
      final resb = jsonDecode(res.body)['user'];
      try {
        final dbgMap = (resb is Map) ? resb : null;
        debugPrint('login response user keys: ${dbgMap?.keys.toList()}');
        debugPrint('login response Def_Login_ID: ${dbgMap?['Def_Login_ID']}');
      } catch (_) {}

      // Best-effort: set Def_Login_ID explicitly (some maps/keys differ across backends).
      try {
        final map = resb as Map?;
        final v = map?['Def_Login_ID'] ??
            map?['def_login_id'] ??
            map?['Login_ID_Pruefer'] ??
            map?['login_id_pruefer'];
        if (v is int) _user?.defLoginId = v;
        if (v is num) _user?.defLoginId = v.toInt();
        if (v is String) _user?.defLoginId = int.tryParse(v);
      } catch (_) {}

      _user?.fromMap((resb is Map) ? resb.cast<String, dynamic>() : null);
      debugPrint(
          'login parsed user: KZL=${_user?.name}, Def_Login_ID=${_user?.defLoginId}');
      return _user;
    }
    throw ResponseException(res);
  }

  /// gets all the [ChildData]points for the given [ParentData]
  /// if no [ParentData] is given it defaults to root
  RequestAndParser<http.Response, List<ChildData>>
      getNextDatapoint<ChildData extends Data, ParentData extends WithOffline?>(
    ParentData data, {
    preloadFullImages = false,
  }) {
    final childTypeStr = Helper.getIdentifierFromData<ChildData>(null);
    if (childTypeStr == null) throw Exception('type not supported');
    return _getAllForNextLevel(
      route: routesFromData<ChildData>(null),
      jsonResponseID: childTypeStr + 's',
      json: data?.toSmallJson(),
      fromJson: (json) {
        // "offline" (forceOffline) is a local-only flag; never trust/propagate it from server payloads.
        final scrubbed = Map<String, dynamic>.from(json);
        scrubbed.remove('offline');
        scrubbed.remove('parent_local_id');
        return Data.fromJson<ChildData>(scrubbed);
      },
      preloadFullImages: preloadFullImages,
    );
  }

  /// sets a new [DataT]
  RequestAndParser<http.Response, DataT?> setNew<DataT extends Data>(
    DataT? data,
  ) {
    final rap = _sendDataToRoute(
      data: data,
      route: _addNew_r,
      // networkIsCrucial: requestType != Helper.SimulatedRequestType.GET,
    );

    return RequestAndParser(
        rd: rap.rd,
        parser: (x) async {
          return (await rap.parser(x))?.body != null ? data : null;
        });
  }

  /// updates a [DataT] and returns the response
  RequestAndParser<http.Response, String?> update<DataT extends Data>(
    DataT? data,
  ) {
    final rap = _sendDataToRoute(
      data: data,
      route: _update_r,
    );

    return RequestAndParser(
        rd: rap.rd,
        parser: (x) async {
          return (await rap.parser(x))?.body;
        });
  }

  /// deletes a [DataT] and returns the response
  RequestAndParser<http.Response, String?> delete<DataT extends Data>(
    DataT? data,
  ) {
    final rap = _sendDataToRoute(
      data: data,
      route: _delete_r,
    );

    return RequestAndParser(
        rd: rap.rd,
        parser: (x) async {
          return (await rap.parser(x))?.body;
        });
  }

  /// updates the pruefer-id for a project to the currently logged-in user, but only if it differs.
  RequestAndParser<http.Response, TouchPrueferResult> touchPruefer(int pjNr) {
    final rd = RequestData(
      _touchPruefer_r,
      json: {'PjNr': pjNr},
    );

    parser(http.Response res) {
      try {
        final decoded = jsonDecode(res.body);
        return TouchPrueferResult.fromJson(decoded);
      } catch (_) {
        return TouchPrueferResult(
          updated: false,
          oldLoginIdPruefer: null,
          loginIdPruefer: null,
        );
      }
    }

    return RequestAndParser(rd: rd, parser: parser);
  }

  /// deletes an image specified by its hash and returns the response
  RequestAndParser<http.BaseResponse, String?> deleteImageByHash(String hash) {
    final rd = RequestData(
      _deleteImageByHash_r,
      json: {'hash': hash},
    );

    parser(http.BaseResponse? res) => res?.forceRes()?.body;

    return RequestAndParser(rd: rd, parser: parser);
  }

  // sets an image specified by its hash as the new main image
  RequestAndParser<http.Response, String?>
      setMainImageByHash<DataT extends Data>(
    DataT? data,
    String mainhash,
  ) {
    final rap = _sendDataToRoute(
      data: data,
      route: _setMainImageByHash_r,
      other: {
        'hash': mainhash,
      },
    );
    return RequestAndParser(
        rd: rap.rd,
        parser: (x) async {
          return (await rap.parser(x))?.body;
        });
  }

  /// upload a bunch of images
  RequestAndParser<http.BaseResponse, String?>
      uploadNewImagesOrFiles<DataT extends Data>(
    DataT data,
    List<XFile> files,
  ) {
    debugPrint('uploading images ${files.map((e) => e.name)}');
    var jsonData = data.toJson();
    final rd = RequestData.fromFiles(
      _uploadImage_r,
      json: {
        'type': Helper.getIdentifierFromData(data),
        'data': json.encode(jsonData),
      },
      multipartFiles: files,
    );

    parser(http.BaseResponse res) async {
      if (res.statusCode ~/ 100 != 2) {
        debugPrint('image uploading not ok: ${res.statusCode.toString()}');
        throw BackendCommunicationException(
            'we need a 2xx, but got ${res.statusCode}');
      }
      return (res.runtimeType == http.Response)
          ? (res as http.Response?)?.body //meh
          : await (res as http.StreamedResponse?)?.stream.bytesToString();
    }

    return RequestAndParser(rd: rd, parser: parser);
  }
}

/// Helper function to parse a [List] of [Data] Objects from a Json-[Map]
Future<List<T>> getListFromJson<T extends Data>(Map<String, dynamic> json,
    FutureOr<T?> Function(Map<String, dynamic>) converter,
    {String? objName}) async {
  try {
    List<dynamic> str = (objName != null) ? json[objName] : json;
    return List<T>.from(
        (await Future.wait(str.map((elem) async => await converter(elem))))
            .whereType<T>());
  } catch (e) {
    debugPrint(
        'could not parse response: ' + e.toString() + '<--' + jsonEncode(json));
    throw BackendCommunicationException(
        S.current!.couldNotParseResponse + jsonEncode(json));
  }
  //return [];
}
