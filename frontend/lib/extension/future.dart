import 'package:stream_transform/stream_transform.dart';

extension IterateFuture on Future {
  // ignore: non_constant_identifier_names
  static Future<T?> ordered_firstNonNull<T extends Object>(
          Iterable<Future<T?>> iterable) =>
      Future.microtask(() async {
        //TODO: warum bad state no element?
        for (var fut in iterable) {
          var val = await fut;
          if (val != null) return val;
        }
        return null;
      });
}

//das macht wenig sinn..
extension IterateStream on Stream {
  static Stream<T?> firstNonNull<T extends Object>(
      Iterable<Stream<T?>> iterable) async* {
    await for (final event
        in iterable.first.combineLatestAll([...iterable.skip(1)])) {
      try {
        yield event.firstWhere((element) => element != null);
      } catch (e) {
        //XXX: das ist eigentlich unsauber, lieber sollte der caller das errorhandling machen aber naja
        yield null;
      }
    }
  }
}
