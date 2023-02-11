import 'package:flutter/widgets.dart';

extension RefitImage on Image {
  // void set fit(BoxFit fit) => this = fit; //fit is final :/
  Image refit(BoxFit fit) => Image(
        image: image,
        width: width,
        height: height,
        color: color,
        colorBlendMode: colorBlendMode,
        fit: fit,
        alignment: alignment,
        repeat: repeat,
        centerSlice: centerSlice,
        matchTextDirection: matchTextDirection,
        gaplessPlayback: gaplessPlayback,
        isAntiAlias: isAntiAlias,
        filterQuality: filterQuality,
        frameBuilder: frameBuilder,
        loadingBuilder: loadingBuilder,
        errorBuilder: errorBuilder,
      );
}
