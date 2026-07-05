import 'mapbox_token_stub.dart'
    if (dart.library.js_interop) 'mapbox_token_web.dart' as web_token;

import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Mapbox **public** token (`pk.…`).
///
/// Resolved in order:
/// 1. `--dart-define=MAPBOX_ACCESS_TOKEN=pk.…` (compile-time, all platforms)
/// 2. `window.MAPBOX_ACCESS_TOKEN` from [web/token.js] (web only, runtime)
const _envToken = String.fromEnvironment(
  'MAPBOX_ACCESS_TOKEN',
  defaultValue: '',
);

String? _runtimeToken;

/// Called from [main] after loading `.env` on mobile/desktop.
void initMapboxToken(String token) => _runtimeToken = token;

String get mapboxAccessToken {
  if (_envToken.isNotEmpty) return _envToken;
  if (_runtimeToken != null && _runtimeToken!.isNotEmpty) return _runtimeToken!;
  final fromDotenv = dotenv.maybeGet('MAPBOX_ACCESS_TOKEN');
  if (fromDotenv != null && fromDotenv.isNotEmpty) return fromDotenv;
  return web_token.readWebMapboxToken();
}

bool get hasMapboxToken => mapboxAccessToken.isNotEmpty;

String mapboxTileUrl(String styleId) =>
    'https://api.mapbox.com/styles/v1/mapbox/$styleId/tiles/{z}/{x}/{y}'
    '?access_token=$mapboxAccessToken';

/// Retina raster tiles for [flutter_map] — Mapbox CARTO URL with @2x.
String mapboxRasterTileUrl({String styleId = 'mapbox/light-v11'}) =>
    'https://api.mapbox.com/styles/v1/$styleId/tiles/256/{z}/{x}/{y}@2x'
    '?access_token=$mapboxAccessToken';
