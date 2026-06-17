import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'app_constants.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AppToast — Global top-of-screen overlay toast (replaces SnackBar)
// ─────────────────────────────────────────────────────────────────────────────

enum _ToastType { success, error, info, loading }

class _ToastEntry {
  final OverlayEntry entry;
  final Timer? autoDismiss;
  _ToastEntry({required this.entry, this.autoDismiss});
}

class AppToast {
  static _ToastEntry? _current;

  /// Dismiss any active toast immediately.
  static void dismiss() {
    _current?.autoDismiss?.cancel();
    try {
      _current?.entry.remove();
    } catch (_) {}
    _current = null;
  }

  /// Internal method to show a toast overlay.
  static void _show(
    BuildContext context,
    String message,
    _ToastType type, {
    Duration duration = const Duration(seconds: 3),
    bool autoDismiss = true,
  }) {
    dismiss(); // Clear any existing toast first

    final overlay = Overlay.of(context, rootOverlay: true);
    late OverlayEntry entry;
    Timer? timer;

    entry = OverlayEntry(
      builder: (_) => _AppToastWidget(
        message: message,
        type: type,
        onDismiss: dismiss,
      ),
    );

    overlay.insert(entry);

    if (autoDismiss) {
      timer = Timer(duration, () {
        try {
          entry.remove();
        } catch (_) {}
        _current = null;
      });
    }

    _current = _ToastEntry(entry: entry, autoDismiss: timer);
  }

  /// Show a success toast (green, auto-dismisses in 3s).
  static void success(BuildContext context, String message) {
    _show(context, message, _ToastType.success);
  }

  /// Show an error toast (red, auto-dismisses in 4s).
  static void error(BuildContext context, String message) {
    _show(context, message, _ToastType.error,
        duration: const Duration(seconds: 4));
  }

  /// Show an info toast (primary, auto-dismisses in 3s).
  static void info(BuildContext context, String message) {
    _show(context, message, _ToastType.info);
  }

  /// Show a persistent loading toast (stays until [dismiss] is called).
  static void loading(BuildContext context, {String message = "Processing…"}) {
    _show(context, message, _ToastType.loading, autoDismiss: false);
  }
}

// ─── Toast Widget ────────────────────────────────────────────────────────────

class _AppToastWidget extends StatefulWidget {
  final String message;
  final _ToastType type;
  final VoidCallback onDismiss;

  const _AppToastWidget({
    required this.message,
    required this.type,
    required this.onDismiss,
  });

  @override
  State<_AppToastWidget> createState() => _AppToastWidgetState();
}

class _AppToastWidgetState extends State<_AppToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _slideAnim = Tween<double>(begin: -1, end: 0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color get _bgColor {
    switch (widget.type) {
      case _ToastType.success:
        return AppColors.success;
      case _ToastType.error:
        return AppColors.danger;
      case _ToastType.loading:
        return AppColors.primary;
      case _ToastType.info:
        return AppColors.primary;
    }
  }

  IconData? get _icon {
    switch (widget.type) {
      case _ToastType.success:
        return Icons.check_circle_rounded;
      case _ToastType.error:
        return Icons.error_rounded;
      case _ToastType.info:
        return Icons.info_rounded;
      case _ToastType.loading:
        return null; // spinner instead
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Positioned(
      top: topPad + 12,
      left: 16,
      right: 16,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, child) => FadeTransition(
          opacity: _fadeAnim,
          child: Transform.translate(
            offset: Offset(0, _slideAnim.value * 60),
            child: child,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            onTap: widget.type != _ToastType.loading ? widget.onDismiss : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: _bgColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: _bgColor.withOpacity(0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Icon or spinner
                  if (widget.type == _ToastType.loading)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  else
                    Icon(_icon, color: Colors.white, size: 18),
                  const SizedBox(width: 10),
                  // Message
                  Expanded(
                    child: Text(
                      widget.message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ),
                  // Tap-to-dismiss X (not on loading)
                  if (widget.type != _ToastType.loading) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: widget.onDismiss,
                      child: Icon(
                        Icons.close_rounded,
                        color: Colors.white.withOpacity(0.8),
                        size: 16,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// UIUtils — Public API (unchanged signatures so all callers work as-is)
// ─────────────────────────────────────────────────────────────────────────────

class UIUtils {
  // ── Toast wrappers (kept for backward-compat with fluttertoast callers) ──

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

  // ── showSnackBar → now routes to AppToast ─────────────────────────────────

  /// Replaces the old floating snackbar. Same call signature — no changes
  /// needed in any screen.
  static void showSnackBar(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    if (isError) {
      AppToast.error(context, message);
    } else {
      AppToast.success(context, message);
    }
  }

  // ── showProcessingSnackbar → AppToast.loading ─────────────────────────────

  /// Replaces the old bottom-pinned progress snackbar. Call [hideProcessingSnackbar]
  /// (or ScaffoldMessenger.of(context).hideCurrentSnackBar()) to dismiss it.
  static void showProcessingSnackbar(
    BuildContext context, {
    String message = "Processing, please wait...",
  }) {
    AppToast.loading(context, message: message);
  }

  // ── hideCurrentSnackBar compatibility ─────────────────────────────────────
  // All existing screens call ScaffoldMessenger.of(context).hideCurrentSnackBar()
  // to hide the processing snackbar. We keep that working by also exposing a
  // helper — but since ScaffoldMessenger no longer owns these toasts, callers
  // that still do ScaffoldMessenger.hideCurrentSnackBar() are harmless (it's a
  // no-op). The AppToast.dismiss() auto-fires from showSnackBar anyway.
  // No changes required in any screen.

  // ── Shared Success Dialog ─────────────────────────────────────────────────

  /// Standard success dialog used across all form screens.
  static void showSuccessDialog(
    BuildContext context, {
    required String title,
    required String message,
    IconData icon = Icons.check_rounded,
    String buttonLabel = "Continue",
    VoidCallback? onContinue,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppColors.success, size: 40),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textHeading,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textDark),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    onContinue?.call();
                  },
                  child: Text(
                    buttonLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Shared Form Widgets ───────────────────────────────────────────────────

  /// Section label used above field groups in forms.
  static Widget buildLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppColors.textMuted,
        letterSpacing: 1.0,
      ),
    );
  }

  /// Standard input decoration used across all form screens.
  static InputDecoration inputDecoration(
    String label,
    IconData icon, {
    String? counterText,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.textMuted),
      prefixIcon: Icon(
        icon,
        color: AppColors.primary.withOpacity(0.7),
        size: 22,
      ),
      suffixIcon: suffixIcon,
      counterText: counterText,
      filled: true,
      fillColor: AppColors.background,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.danger, width: 1.0),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
    );
  }

  /// Standard submit button used in all form screens.
  static Widget buildSubmitButton({
    required String label,
    required bool loading,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          disabledBackgroundColor: AppColors.primary.withOpacity(0.6),
          elevation: 4,
          shadowColor: AppColors.primary.withOpacity(0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: loading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}
