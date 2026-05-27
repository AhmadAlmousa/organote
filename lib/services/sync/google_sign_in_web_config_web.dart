import 'package:web/web.dart' as web;

String? googleSignInWebClientIdFromMeta() {
  const selector = 'meta[name=google-signin-client_id]';
  final content = web.document.querySelector(selector)?.getAttribute('content');
  final normalized = content?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  if (_isPlaceholderClientId(normalized)) {
    return null;
  }
  return normalized;
}

bool _isPlaceholderClientId(String value) {
  final lower = value.toLowerCase();
  return lower.contains('replace-me') ||
      lower.contains('<') ||
      lower.contains('your_');
}
