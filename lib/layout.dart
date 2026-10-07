/// Chia cột cho các sự kiện chồng giờ nhau trong chế độ xem tuần/ngày.
class Placed<T> {
  Placed(this.item, this.col, this.cols, this.start, this.end);
  final T item;
  final int col;
  final int cols;
  final int start;
  final int end;
}

List<Placed<T>> layoutColumns<T>(List<(int, int, T)> items) {
  final sorted = [...items]..sort((a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2));
  final out = <Placed<T>>[];
  var cluster = <(int, int, T)>[];
  var clusterEnd = -1;

  void flush() {
    final cols = <int>[];
    final placed = <(T, int, int, int)>[];
    for (final (s, e, o) in cluster) {
      var idx = cols.indexWhere((ce) => ce <= s);
      if (idx >= 0) {
        cols[idx] = e;
      } else {
        cols.add(e);
        idx = cols.length - 1;
      }
      placed.add((o, idx, s, e));
    }
    for (final (o, i, s, e) in placed) {
      out.add(Placed(o, i, cols.length, s, e));
    }
  }

  for (final it in sorted) {
    if (cluster.isNotEmpty && it.$1 >= clusterEnd) {
      flush();
      cluster = [];
      clusterEnd = -1;
    }
    cluster.add(it);
    if (it.$2 > clusterEnd) clusterEnd = it.$2;
  }
  if (cluster.isNotEmpty) flush();
  return out;
}
