import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_passport/data/routes.dart';
import 'package:local_passport/screens/qr_scanner_screen.dart';
import 'package:local_passport/state/passport_store.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _DelayedCamera extends MobileScannerPlatform {
  final capture = StreamController<BarcodeCapture?>.broadcast();
  final disposed = Completer<void>();
  bool disposeStarted = false;

  @override
  Stream<BarcodeCapture?> get barcodesStream => capture.stream;

  @override
  Stream<TorchState> get torchStateStream => const Stream.empty();

  @override
  Stream<double> get zoomScaleStateStream => const Stream.empty();

  @override
  Future<MobileScannerViewAttributes> start(StartOptions options) async =>
      const MobileScannerViewAttributes(
        size: Size(640, 480),
        currentTorchMode: TorchState.off,
        cameraDirection: CameraFacing.back,
      );

  @override
  Widget buildCameraView() => const SizedBox();

  @override
  Future<void> updateScanWindow(Rect? window) async {}

  @override
  Future<void> dispose() {
    disposeStarted = true;
    return disposed.future;
  }
}

void main() {
  for (final demo in [false, true]) {
    testWidgets(
      demo
          ? 'Đóng khi camera đang dừng cho Demo'
          : 'Đóng khi camera đang dừng sau quét',
      (tester) async {
        GoogleFonts.config.allowRuntimeFetching = false;
        final camera = _DelayedCamera();
        final original = MobileScannerPlatform.instance;
        MobileScannerPlatform.instance = camera;
        addTearDown(() async {
          MobileScannerPlatform.instance = original;
          await camera.capture.close();
        });
        SharedPreferences.setMockInitialValues({});
        final store = (await tester.runAsync(PassportStore.load))!;
        addTearDown(store.dispose);
        tester.view.physicalSize = const Size(800, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final location = locationById['dien-hai']!;

        await tester.pumpWidget(
          MaterialApp(
            home: PassportScope(
              store: store,
              child: QrScannerScreen(location: location),
            ),
          ),
        );
        await tester.tap(find.text('Bật camera quét QR'));
        await tester.pump();
        await tester.pump();

        if (demo) {
          await tester.tap(find.text('Giả lập quét QR (Demo)'));
        } else {
          camera.capture.add(
            BarcodeCapture(
              barcodes: [
                Barcode(
                  rawValue:
                      'LOCALPASSPORT|${location.id}|${location.qrCodeSecret}',
                ),
              ],
            ),
          );
        }
        await tester.pump();
        expect(camera.disposeStarted, isTrue);

        // Bỏ màn hình khi native camera chưa dừng xong.
        await tester.pumpWidget(const SizedBox());
        camera.disposed.complete();
        await tester.pump();

        expect(tester.takeException(), isNull);
      },
    );
  }
}
