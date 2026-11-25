import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/core.dart';

Future<void> shareInspectorText(BuildContext context, String text) async {
  final renderBox = context.findRenderObject();
  final origin = renderBox is RenderBox && renderBox.hasSize
      ? renderBox.localToGlobal(Offset.zero) & renderBox.size
      : null;
  try {
    final result = await SharePlus.instance.share(
      ShareParams(text: text, sharePositionOrigin: origin),
    );
    if (result.status != ShareResultStatus.unavailable) return;
  } catch (_) {
    // A share target may be unavailable on desktop or in a browser.
  }
  if (!context.mounted) return;
  try {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) context.successSnackBar('Copied to clipboard');
  } catch (_) {
    if (context.mounted) context.errorSnackBar('Unable to share or copy');
  }
}
