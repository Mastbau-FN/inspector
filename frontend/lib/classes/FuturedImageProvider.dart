import 'package:flutter/material.dart';

class FuturedImageProvider implements ImageProvider {
  const FuturedImageProvider(this.futureImage);
  final Future<ImageProvider> futureImage;

  @override
  ImageStream createStream(ImageConfiguration configuration) {
    // TODO: implement createStream
    throw UnimplementedError();
  }

  @override
  Future<bool> evict(
          {ImageCache? cache,
          ImageConfiguration configuration = ImageConfiguration.empty}) async =>
      (await futureImage).evict();

  @override
  ImageStreamCompleter load(Object key, DecoderCallback decode) {
    // TODO: implement load
    throw UnimplementedError();
  }

  @override
  Future<ImageCacheStatus?> obtainCacheStatus(
          {required ImageConfiguration configuration,
          ImageErrorListener? handleError}) async =>
      (await futureImage).obtainCacheStatus(
          configuration: configuration, handleError: handleError);

  @override
  Future<Object> obtainKey(ImageConfiguration configuration) async =>
      (await futureImage).obtainCacheStatus(configuration: configuration);

  @override
  ImageStream resolve(ImageConfiguration configuration) {
    // TODO: implement resolve
    throw UnimplementedError();
  }

  @override
  void resolveStreamForKey(ImageConfiguration configuration, ImageStream stream,
          Object key, ImageErrorListener handleError) async =>
      (await futureImage)
          .resolveStreamForKey(configuration, stream, key, handleError);
}
