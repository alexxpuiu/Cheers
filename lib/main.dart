import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'app.dart';

/// Mapbox public access token. Set at run time via:
///   flutter run --dart-define=MAPBOX_ACCESS_TOKEN=pk.xxxxxxxx
const String kMapboxAccessToken = String.fromEnvironment(
  'MAPBOX_ACCESS_TOKEN',
  defaultValue: '',
);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
    ),
  );

  if (kMapboxAccessToken.isNotEmpty) {
    MapboxOptions.setAccessToken(kMapboxAccessToken);
  }

  runApp(const ProviderScope(child: CheersApp()));
}
