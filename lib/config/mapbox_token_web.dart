import 'dart:js_interop';

@JS('MAPBOX_ACCESS_TOKEN')
external String? get _windowToken;

/// Reads the Mapbox public token injected by [web/token.js] on Flutter web.
String readWebMapboxToken() {
  final token = _windowToken;
  if (token == null || token.isEmpty) return '';
  if (token.contains('YOUR_TOKEN') || token.contains('replace_me')) return '';
  return token;
}
