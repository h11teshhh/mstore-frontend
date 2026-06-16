import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AppDiagnostics {
  static void install() {
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      logFlutterError(details);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      recordError(error, stack, context: 'platform');
      return true;
    };

    ErrorWidget.builder = (details) {
      logFlutterError(details);
      return Material(
        color: const Color(0xFFFFF1F2),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.error_outline, color: Color(0xFF991B1B)),
                    SizedBox(width: 8),
                    Text(
                      'Screen render failed',
                      style: TextStyle(
                        color: Color(0xFF991B1B),
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  kReleaseMode
                      ? 'Please try again or contact support.'
                      : details.exceptionAsString(),
                  style: const TextStyle(color: Color(0xFF7F1D1D)),
                ),
              ],
            ),
          ),
        ),
      );
    };
  }

  static void log(String message) {
    if (!kReleaseMode) {
      debugPrint('[MSTORE] $message');
    }
  }

  static void recordError(
    Object error,
    StackTrace stack, {
    String context = 'runtime',
  }) {
    if (!kReleaseMode) {
      debugPrint('[MSTORE][$context] ERROR: $error');
      debugPrint(stack.toString());
    }
  }

  static void logFlutterError(FlutterErrorDetails details) {
    if (!kReleaseMode) {
      debugPrint('[MSTORE][flutter] ${details.exceptionAsString()}');
      final stack = details.stack;
      if (stack != null) debugPrint(stack.toString());
    }
  }
}

class DiagnosticsRouteObserver extends NavigatorObserver {
  void _log(String action, Route<dynamic>? route, Route<dynamic>? previous) {
    final routeName = route?.settings.name ?? route?.runtimeType.toString();
    final previousName =
        previous?.settings.name ?? previous?.runtimeType.toString();
    AppDiagnostics.log(
      'navigation $action route=$routeName previous=$previousName',
    );
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _log('push', route, previousRoute);
    super.didPush(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _log('replace', newRoute, oldRoute);
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _log('pop', route, previousRoute);
    super.didPop(route, previousRoute);
  }
}
