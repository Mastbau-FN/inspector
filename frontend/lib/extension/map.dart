extension CopyWith<K, V> on Map<K, V> {
  Map<K, V> copyWith(Map<K, V> other) {
    addAll(other);
    return this;
  }
}
