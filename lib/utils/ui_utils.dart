import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'app_constants.dart';

class UIUtils {
  // 1. Success Toast
  static void showSuccessToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: AppColors.success,
      textColor: Colors.white,
      fontSize: 14.0,
    );
  }

  // 2. Error Toast (For API Errors)
  static void showErrorToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: AppColors.danger,
      textColor: Colors.white,
      fontSize: 14.0,
    );
  }

  // 3. Loading Snackbar (To notify user to wait)
  static void showProcessingSnackbar(
    BuildContext context, {
    String message = "Processing, please wait...",
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 15),
            Text(message),
          ],
        ),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
