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
