import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../constants/app_colors.dart';

class ToastUtils {
  static void showSuccess(String message) {
    _show(message, AppColors.success);
  }

  static void showError(String message) {
    _show(message, AppColors.error);
  }

  static void showInfo(String message) {
    _show(message, Colors.white.withValues(alpha: 0.9), textColor: Colors.black);
  }

  static void _show(String message, Color background, {Color textColor = Colors.white}) {
    Fluttertoast.cancel();
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: background,
      textColor: textColor,
      fontSize: 14,
    );
  }
}
