import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'config/mapbox_config.dart';
import 'services/supabase_service.dart';

/// Mapbox **public** access token.
///
/// Loaded at startup from the bundled `.env` file (see repo root). When empty
/// or missing, the map falls back to a stylised backdrop so the app still
/// runs offline.
///
/// A `--dart-define=MAPBOX_ACCESS_TOKEN=…` value, if provided, takes
/// precedence over the `.env` entry.
String kMapboxAccessToken = '';

const String _mapboxTokenFromDefine = String.fromEnvironment(
  'MAPBOX_ACCESS_TOKEN',
  defaultValue: '',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    if (kDebugMode) {
      debugPrint('Cheers: no .env file loaded ($e). Falling back to defaults.');
    }
  }

  kMapboxAccessToken = _mapboxTokenFromDefine.isNotEmpty
      ? _mapboxTokenFromDefine
      : (dotenv.maybeGet('MAPBOX_ACCESS_TOKEN') ?? '');
  initMapboxToken(kMapboxAccessToken);

  await SupabaseService.init();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
    ),
  );

  runApp(const ProviderScope(child: CheersApp()));
}
