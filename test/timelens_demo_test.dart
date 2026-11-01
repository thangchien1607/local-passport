import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:local_passport/data/routes.dart';
import 'package:local_passport/screens/timelens_screen.dart';

void main() {
  test('TimeLens xem trước chỉ dùng di tích có sẵn, đủ dữ liệu', () {
    expect(timeLensFeaturedIds, hasLength(4));
    for (final id in timeLensFeaturedIds) {
      final location = locationById[id];
      expect(location, isNotNull, reason: id);
      expect(location!.routeId, isNot('test'), reason: id);
      expect(location.stories, isNotEmpty, reason: id);
      expect(location.timeLens.pastYear, isNotEmpty, reason: id);
    }
  });

  test('4 di tích tiêu biểu dùng ảnh thật, có ghi nguồn và đủ file', () {
    for (final id in timeLensFeaturedIds) {
      final lens = locationById[id]!.timeLens;
      expect(lens.credit, isNotNull, reason: id);
      for (final path in [lens.pastImageUrl, lens.presentImageUrl]) {
        expect(path, startsWith('assets/photos/'), reason: id);
        expect(File(path!).existsSync(), isTrue, reason: path);
      }
    }
  });
}
