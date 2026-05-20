import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

Future<bool> shareOrCopy({required String text, String? subject}) async {
  if (kIsWeb || _isDesktop) {
    try {
      await SharePlus.instance.share(ShareParams(text: text, subject: subject));
      return true;
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text));
      return false;
    }
  }
  try {
    await SharePlus.instance.share(ShareParams(text: text, subject: subject));
    return true;
  } catch (_) {
    await Clipboard.setData(ClipboardData(text: text));
    return false;
  }
}

bool get _isDesktop {
  return defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.windows;
}
