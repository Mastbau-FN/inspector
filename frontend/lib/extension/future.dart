import 'package:stream_transform/stream_transform.dart';

extension IterateFuture on Future {
  // ignore: non_constant_identifier_names
  @deprecated
  static Future<T?> ordered_firstNonNull<T extends Object>(
          Iterable<Future<T?>> iterable) =>
      iterable.ordered_firstNonNull;
}

extension FutureIterate<T> on Iterable<Future<T>> {
  // ignore: non_constant_identifier_names
  Future<T?> get ordered_firstNonNull async {
    //TODO: warum bad state no element?
    for (final fut in this) {
      try {
        final T val = await fut;
        if (val != null) return val;
      } catch (e) {}
    }
    return null;
  }
}

// extension FutureList<T extends Object> on List<Future<T>> {
//   // ignore: non_constant_identifier_names
//   Future<T?> get ordered_firstNonNull => (this as Iterable<Future<T?>>).ordered_firstNonNull;
// }

//das macht wenig sinn..
// extension IterateStream on Stream {
//   static Stream<T?> firstNonNull<T extends Object>(
//       Iterable<Stream<T?>> iterable) async* {
//     await for (final event
//         in iterable.first.combineLatestAll([...iterable.skip(1)])) {
//       try {
//         yield event.firstWhere((element) => element != null);
//       } catch (e) {
//         //XXX: das ist eigentlich unsauber, lieber sollte der caller das errorhandling machen aber naja
//         yield null;
//       }
//     }
//   }
// }
