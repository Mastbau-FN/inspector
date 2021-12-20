import 'package:flutter/material.dart';
import 'package:flutter/src/foundation/diagnostics.dart';
import 'package:flutter/src/foundation/assertions.dart';

class FuturedImageProvider implements ImageProvider {
  FuturedImageProvider(this.futureImage);
  FuturedImageProvider.fromFunc(
      Future<ImageProvider> Function() futureImageFunc)
      : this.futureImage = futureImageFunc();
  final Future<ImageProvider> futureImage;
  ImageStream? _imageStream;

  @override
  ImageStream createStream(ImageConfiguration configuration) {
    _imageStream ??= ImageStream();
    _setCompleter(configuration);
    return _imageStream!;
  }

  void _setCompleter(ImageConfiguration configuration) async =>
      _imageStream!.setCompleter((await futureImage)
          .resolve(configuration)
          .completer!); //TODO: das ausrufezeichen hinter dem completer ist gefährlich

  @override
  Future<bool> evict(
          {ImageCache? cache,
          ImageConfiguration configuration = ImageConfiguration.empty}) async =>
      (await futureImage).evict();

  @override
  ImageStreamCompleter load(Object key, DecoderCallback decode) {
    return _imageStream!
        .completer!; //TODO: das ausrufezeichen hinter dem completer ist gefährlich
  }

  @override
  Future<ImageCacheStatus?> obtainCacheStatus(
          {required ImageConfiguration configuration,
          ImageErrorListener? handleError}) async =>
      (await futureImage).obtainCacheStatus(
          configuration: configuration, handleError: handleError);

  @override
  Future<Object> obtainKey(ImageConfiguration configuration) async =>
      (await futureImage).obtainKey(configuration);

  @override
  ImageStream resolve(ImageConfiguration configuration) {
    _imageStream ??= ImageStream();
    return _imageStream!;
  }

  @override
  void resolveStreamForKey(ImageConfiguration configuration, ImageStream stream,
          Object key, ImageErrorListener handleError) async =>
      (await futureImage)
          .resolveStreamForKey(configuration, stream, key, handleError);
}

// class _FutureImageStreamCompleter implements ImageStreamCompleter {
//   NetworkImage img;
// }
