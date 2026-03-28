import 'package:flutter/foundation.dart';

class AppLogger {
  static void log(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    final timestamp = DateTime.now().toIso8601String();
    final tagSection = tag != null ? '[$tag] ' : '';
    
    if (kDebugMode) {
      print('$timestamp $tagSection$message');
      if (error != null) print('Error: $error');
      if (stackTrace != null) print('StackTrace: $stackTrace');
    }
    
    
  }

  static void info(String message, {String? tag}) => log('INFO: $message', tag: tag);
  static void warning(String message, {String? tag}) => log('WARNING: $message', tag: tag);
  static void error(String message, {String? tag, Object? error, StackTrace? stackTrace}) => 
      log('ERROR: $message', tag: tag, error: error, stackTrace: stackTrace);
}
