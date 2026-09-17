import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:freon/services/meal_photo.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'turns a real meal JPEG into a bounded PNG for model and storage',
    () async {
      final photo = await MealPhoto.prepare(
        await File('assets/images/lunch.jpg').readAsBytes(),
      );
      expect(photo.bytes.take(4), [137, 80, 78, 71]);
      expect(photo.width, lessThanOrEqualTo(1280));
      expect(photo.height, lessThanOrEqualTo(1280));
    },
  );
  test('downscales while preserving aspect ratio', () async {
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawColor(const ui.Color(0xff00695c), ui.BlendMode.src);
    final picture = recorder.endRecording();
    final image = await picture.toImage(2400, 1200);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    final photo = await MealPhoto.prepare(png!.buffer.asUint8List());
    image.dispose();
    picture.dispose();
    expect((photo.width, photo.height), (1280, 640));
  });
  test('rejects oversized, invalid and corrupted photos', () async {
    for (final bytes in [
      Uint8List(0),
      Uint8List(MealPhoto.maxInputBytes + 1),
      Uint8List.fromList([1, 2, 3]),
      Uint8List.fromList([255, 216, 255, 0]),
    ]) {
      await expectLater(MealPhoto.prepare(bytes), throwsFormatException);
    }
  });
  test('camera capture rejects non-device paths', () async {
    final camera = MealPhotoService();
    await expectLater(
      camera.capture('/tmp/not-a-camera'),
      throwsFormatException,
    );
    camera.dispose();
  });
}
