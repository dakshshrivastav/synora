import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Re-encoded, metadata-free PNG used for both the model and the saved log.
class MealPhoto {
  MealPhoto._(this.bytes, this.width, this.height);
  final Uint8List bytes;
  final int width, height;
  static const maxInputBytes = 10 * 1024 * 1024;

  static Future<MealPhoto> prepare(Uint8List bytes) async {
    if (bytes.isEmpty || bytes.length > maxInputBytes) {
      throw const FormatException('Choose a photo smaller than 10 MB.');
    }
    final jpeg =
        bytes.length >= 3 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff;
    final png =
        bytes.length >= 8 &&
        bytes[0] == 137 &&
        bytes[1] == 80 &&
        bytes[2] == 78 &&
        bytes[3] == 71;
    if (!jpeg && !png) {
      throw const FormatException('Choose a valid JPEG or PNG photo.');
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    ui.Image? image;
    try {
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      if (descriptor.width * descriptor.height > 40000000) {
        throw const FormatException(
          'Photo is too large. Export it below 40 megapixels.',
        );
      }
      final scale = math.min(
        1.0,
        1280 / math.max(descriptor.width, descriptor.height),
      );
      codec = await descriptor.instantiateCodec(
        targetWidth: math.max(1, (descriptor.width * scale).round()),
        targetHeight: math.max(1, (descriptor.height * scale).round()),
      );
      image = (await codec.getNextFrame()).image;
      final encoded = await image.toByteData(format: ui.ImageByteFormat.png);
      if (encoded == null || encoded.lengthInBytes > maxInputBytes) {
        throw const FormatException(
          'Could not prepare this photo. Try a smaller image.',
        );
      }
      return MealPhoto._(
        encoded.buffer.asUint8List(
          encoded.offsetInBytes,
          encoded.lengthInBytes,
        ),
        image.width,
        image.height,
      );
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException(
        'This image could not be decoded. Choose a different JPEG or PNG.',
      );
    } finally {
      image?.dispose();
      codec?.dispose();
      descriptor?.dispose();
      buffer.dispose();
    }
  }
}

class MealPhotoService {
  Process? _capture;
  bool _disposed = false;
  bool _capturing = false;
  Future<MealPhoto?> pick() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png'],
    );
    if (file?.path == null) return null;
    final source = File(file!.path!);
    if (await source.length() > MealPhoto.maxInputBytes) {
      throw const FormatException('Choose a photo smaller than 10 MB.');
    }
    return MealPhoto.prepare(await source.readAsBytes());
  }

  Future<List<String>> cameras() async {
    if (!Platform.isLinux) return [];
    return (await Directory('/dev')
          .list()
          .where((f) => RegExp(r'^/dev/video\d+$').hasMatch(f.path))
          .map((f) => f.path)
          .toList())
      ..sort();
  }

  /// One user-triggered V4L2 capture; no shell and no background camera access.
  Future<MealPhoto> capture(String device) async {
    if (_disposed || _capturing) {
      throw const FormatException(
        'Camera capture is unavailable or already running.',
      );
    }
    if (!Platform.isLinux || !RegExp(r'^/dev/video\d+$').hasMatch(device)) {
      throw const FormatException('Choose an available Linux camera.');
    }
    Process? process;
    _capturing = true;
    try {
      process = await Process.start('ffmpeg', [
        '-nostdin',
        '-hide_banner',
        '-loglevel',
        'error',
        '-f',
        'video4linux2',
        '-i',
        device,
        '-frames:v',
        '1',
        '-f',
        'image2pipe',
        '-vcodec',
        'mjpeg',
        'pipe:1',
      ]);
      _capture = process;
      if (_disposed) process.kill(ProcessSignal.sigkill);
      final bytes = BytesBuilder(copy: false);
      var oversized = false;
      final output = process.stdout.listen((chunk) {
        if (bytes.length + chunk.length > MealPhoto.maxInputBytes) {
          oversized = true;
          process!.kill(ProcessSignal.sigkill);
        } else if (!oversized) {
          bytes.add(chunk);
        }
      });
      final errors = process.stderr.drain<void>();
      final collected = output.asFuture<void>();
      try {
        final exit = await process.exitCode.timeout(
          const Duration(seconds: 12),
        );
        await collected;
        await errors;
        if (exit != 0 || oversized || _disposed) {
          throw const FormatException(
            'Could not capture a photo. Check camera permissions or choose a photo instead.',
          );
        }
        return await MealPhoto.prepare(bytes.takeBytes());
      } finally {
        await output.cancel();
      }
    } on ProcessException {
      throw const FormatException(
        'Webcam capture needs FFmpeg. Install it or use Choose photo.',
      );
    } on TimeoutException {
      throw const FormatException(
        'Camera timed out. It may be in use by another app.',
      );
    } finally {
      process?.kill(ProcessSignal.sigkill);
      _capture = null;
      _capturing = false;
    }
  }

  void dispose() {
    _disposed = true;
    _capture?.kill(ProcessSignal.sigkill);
  }
}

final mealPhotoServiceProvider = Provider.autoDispose<MealPhotoService>((ref) {
  final service = MealPhotoService();
  ref.onDispose(service.dispose);
  return service;
});
