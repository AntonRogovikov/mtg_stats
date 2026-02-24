import 'package:flutter/material.dart';

/// Общие helper'ы для показа пользовательских уведомлений (SnackBar).
class UiFeedback {
  static void showRawSnack(BuildContext context, SnackBar snackBar) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.showSnackBar(snackBar);
  }

  static void showMessage(
    BuildContext context, {
    required String message,
    required Color backgroundColor,
    Duration duration = const Duration(seconds: 4),
  }) {
    showRawSnack(
      context,
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: duration,
      ),
    );
  }

  static void showError(BuildContext context, String message) {
    showMessage(
      context,
      message: message,
      backgroundColor: Colors.red,
    );
  }

  static void showWarning(BuildContext context, String message) {
    showMessage(
      context,
      message: message,
      backgroundColor: Colors.orange,
    );
  }

  static void showSuccess(BuildContext context, String message) {
    showMessage(
      context,
      message: message,
      backgroundColor: Colors.green,
    );
  }
}
