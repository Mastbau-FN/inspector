import 'package:stream_transform/stream_transform.dart';

extension IterateFuture on Future {
  static Future<T?> ordered_firstNonNull<T extends Object>(
          Iterable<Future<T?>> iterable) =>
      Future.microtask(() async {
        for (var fut in iterable) {
          var val = await fut;
          if (val != null) return val;
        }
      });
}

//das macht wenig sinn..
extension IterateStream on Stream {
  static Stream<T?> firstNonNull<T extends Object>(
      Iterable<Stream<T?>> iterable) async* {
    await for (final event
        in iterable.first.combineLatestAll([...iterable.skip(1)])) {
      yield event.firstWhere((element) => element != null);
    }
  }
}
