import 'dart:convert';

const imageFieldValueSeparator = ', ';

List<String> parseImageFieldValue(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return const <String>[];

  if (value.startsWith('[')) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is List) {
        return decoded
            .whereType<String>()
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList();
      }
    } catch (_) {
      // Fall through to the readable storage format below.
    }
  }

  return value
      .split(RegExp(r'[\n,]+'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();
}

String encodeImageFieldValue(Iterable<String> paths) {
  return paths
      .map((path) => path.trim())
      .where((path) => path.isNotEmpty)
      .join(imageFieldValueSeparator);
}

bool looksLikeImageAssetPath(String path) {
  final lower = path.trim().toLowerCase();
  if (!lower.startsWith('assets/')) return false;
  return lower.endsWith('.png') ||
      lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.gif') ||
      lower.endsWith('.webp');
}
