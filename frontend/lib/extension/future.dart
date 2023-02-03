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
    //TO-DO: warum bad state no element?
    for (final fut in this) {
      try {
        final T val = await fut;
        if (val != null) return val;
      } catch (e) {}
    }
    return null;
  }
}
