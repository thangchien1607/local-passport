import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:local_passport/services/passport_remote.dart';

void main() {
  test('chunkIds chia đúng thành từng lô tối đa 30 ID', () {
    expect(chunkIds<String>([]), isEmpty);
    expect(chunkIds(List.generate(30, (i) => 'id-$i')), hasLength(1));

    final chunks = chunkIds(List.generate(75, (i) => 'id-$i'));
    expect(chunks.map((c) => c.length).toList(), [30, 30, 15]);
  });

  test(
    'fetchInChunks chạy song song các lô <= 30 ID bằng Future.wait thay cho N+1',
    () async {
      final ids = List.generate(75, (i) => 'r-$i');
      final batchSizes = <int>[];
      var inFlight = 0;
      var maxInFlight = 0;
      final gate = Completer<void>();

      final future = fetchInChunks<String>(
        ids: ids,
        queryChunk: (chunk) async {
          batchSizes.add(chunk.length);
          inFlight++;
          if (inFlight > maxInFlight) maxInFlight = inFlight;
          if (batchSizes.length == 3 && !gate.isCompleted) {
            gate.complete();
          }
          await gate.future;
          inFlight--;
          return chunk.map((id) => 'doc:$id').toList();
        },
      );

      final results = await future;
      expect(batchSizes, [30, 30, 15]);
      // Tất cả 3 truy vấn lô phải chạy đồng thời (song song qua Future.wait).
      expect(maxInFlight, 3);
      expect(results, hasLength(75));
      expect(results.first, 'doc:r-0');
      expect(results.last, 'doc:r-74');
    },
  );
}
