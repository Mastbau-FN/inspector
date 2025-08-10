import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

/// An ImageProvider that loads its underlying provider asynchronously.
class FuturedImageProvider extends ImageProvider<FuturedImageProvider> {
  final Future<ImageProvider> futureImageProvider;

  FuturedImageProvider(this.futureImageProvider);

  @override
  Future<FuturedImageProvider> obtainKey(ImageConfiguration configuration) {
    // The key is just this instance
    return SynchronousFuture(this);
  }

  @override
  ImageStreamCompleter loadImage(FuturedImageProvider key, ImageDecoderCallback decode) {
    return OneFrameImageStreamCompleter(_loadAsync(key, decode));
  }

  Future<ImageInfo> _loadAsync(FuturedImageProvider key, ImageDecoderCallback decode) async {
    final provider = await futureImageProvider;
    final resolvedKey = await provider.obtainKey(const ImageConfiguration());
    final completer = provider.loadImage(resolvedKey, decode);
    final completerResult = Completer<ImageInfo>();
    void listener(ImageInfo image, bool synchronousCall) {
      if (!completerResult.isCompleted) {
        completerResult.complete(image);
      }
    }
    final stream = ImageStream();
    final listenerObj = ImageStreamListener(listener);
    stream.setCompleter(completer);
    stream.addListener(listenerObj);
    final imageInfo = await completerResult.future;
    stream.removeListener(listenerObj);
    return imageInfo;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FuturedImageProvider &&
          runtimeType == other.runtimeType &&
          futureImageProvider == other.futureImageProvider;

  @override
  int get hashCode => futureImageProvider.hashCode;
}
