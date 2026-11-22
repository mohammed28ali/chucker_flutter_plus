import 'package:flutter/material.dart';

extension SnackBarExtension on BuildContext {
  void closeSnackBar() => ScaffoldMessenger.of(this).hideCurrentSnackBar();

  void errorSnackBar(String error, {int duration = 2}) {
    _showToast(error, isError: true, duration: duration);
  }

  void successSnackBar(String msg, {int duration = 2}) {
    _showToast(msg, isError: false, duration: duration);
  }

  void _showToast(String message, {required bool isError, int duration = 2}) {
    final messenger = ScaffoldMessenger.maybeOf(this);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: Duration(seconds: duration),
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError
              ? Colors.red.shade700
              : Colors.green.shade700,
        ),
      );
  }
}
