import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:local_passport/data/routes.dart';

void main() {
  test('10 di tích thật đều có ảnh "nay" thật, có ghi nguồn và đủ file', () {
    final real = locations.where((l) => l.routeId != 'test');
    expect(real, hasLength(10));
    for (final location in real) {
      final lens = location.timeLens;
      expect(lens.presentImageUrl, isNotNull, reason: location.id);
      expect(lens.credit, isNotNull, reason: location.id);
      for (final path in [lens.pastImageUrl, lens.presentImageUrl]) {
        if (path == null) continue;
        expect(path, startsWith('assets/photos/'), reason: location.id);
        expect(File(path).existsSync(), isTrue, reason: path);
      }
    }
  });
}
