import 'package:flutter/material.dart';
import 'dart:ui'; // Required for PlatformDispatcher
import '../utils/logger.dart';

class ErrorBoundary extends StatefulWidget {
  final Widget child;
  const ErrorBoundary({super.key, required this.child});

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  bool _hasError = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
  }

  static void reportError(Object error, StackTrace stackTrace) {
    AppLogger.error('Caught by ErrorBoundary', error: error, stackTrace: stackTrace);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Something went wrong',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                const Text(
                  'We\'ve encountered an unexpected error. Our team has been notified.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _hasError = false;
                    });
                  },
                  child: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ErrorWidget.builder == null 
      ? widget.child 
      : widget.child;
  }

  // This is the key method for catching errors in children
  @override
  void onError(FlutterErrorDetails details) {
    AppLogger.error('Flutter Framework Error', error: details.exception, stackTrace: details.stack);
    setState(() {
      _hasError = true;
      _error = details.exception;
    });
  }
}

// Global error hook to be used in main.dart
void setupGlobalErrorHandling() {
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    AppLogger.error('Global Flutter Error', error: details.exception, stackTrace: details.stack);
  };

  // For async errors
  PlatformDispatcher.instance.onError = (error, stack) {
    AppLogger.error('Global Async Error', error: error, stackTrace: stack);
    return true;
  };
}
