import 'package:image_picker/image_picker.dart';

class RequestData {
  RequestData(
    this.route, {
    this.json,
    this.multipart_files = const [],
    this.timeout,
    this.returnsBinary = false,
    this.logIfFailed = true,
  });

  String route;
  Map<String, dynamic>? json;
  List<XFile> multipart_files;
  Duration? timeout;
  bool returnsBinary;
  bool logIfFailed;
}
