import 'dart:ui';

import 'package:flutter/material.dart';

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
    _setStream(configuration);
    return _imageStream!;
  }

  void _setStream(ImageConfiguration configuration) async {
    _imageStream = (await futureImage).resolve(configuration);
  }

  @override
  Future<bool> evict(
          {ImageCache? cache,
          ImageConfiguration configuration = ImageConfiguration.empty}) async =>
      (await futureImage).evict();

  @override
  ImageStreamCompleter load(Object key, decode) {
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

  @override
  ImageStreamCompleter loadBuffer(Object key, DecoderBufferCallback decode) {
    // TODO: implement loadBuffer
    return _imageStream!.completer!;
  }

  // ignore: override_on_non_overriding_member
  @override
  ImageStreamCompleter loadImage(Object key, ImageDecoderCallback decode) {
    // TODO: implement loadImage
    return _imageStream!.completer!;
  }
}

// class _FutureImageStreamCompleter implements ImageStreamCompleter {
//   NetworkImage img;
// }
