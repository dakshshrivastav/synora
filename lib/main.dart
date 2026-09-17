import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    for (final name in ['Outfit', 'HankenGrotesk']) {
      yield LicenseEntryWithLineBreaks([
        name,
      ], await rootBundle.loadString('assets/fonts/$name-OFL.txt'));
    }
  });
  runApp(const ProviderScope(child: FreonApp()));
}
