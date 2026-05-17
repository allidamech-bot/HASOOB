import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// Manages the initialization of the database factory for different platforms.
/// This service is designed to be called after the initial Flutter frame has rendered,
/// especially for web and desktop platforms, to prevent blocking the UI startup.
class DatabaseInitializer {
  static const bool disableWebDatabaseBootstrap =
      bool.fromEnvironment('disableWebDatabaseBootstrap');

  // Internal flags and future to manage the initialization state safely.
  static bool _isInitializing = false;
  static bool _isInitialized = false;
  static Future<void>? _initializationFuture;

  /// Initializes the database factory for the current platform.
  ///
  /// This method is idempotent:
  /// - If initialization has already succeeded, it returns immediately.
  /// - If initialization is currently in progress, it returns the existing Future.
  /// - If initialization failed previously, it allows a retry.
  ///
  /// Returns a Future that completes when the database factory is initialized,
  /// or completes with an error if initialization fails.
  ///
  /// It does not block the first Flutter frame.
  static Future<void> initializeDatabase() async {
    // If already successfully initialized, return immediately.
    if (_isInitialized) {
      debugPrint(
          '[DatabaseInitializer] Already initialized successfully. Skipping.');
      return Future.value();
    }

    // If initialization is already in progress, return the existing future.
    if (_isInitializing && _initializationFuture != null) {
      debugPrint(
          '[DatabaseInitializer] Initialization already in progress. Awaiting existing future.');
      return _initializationFuture!;
    }

    _isInitializing = true;
    debugPrint('[DatabaseInitializer] Database initialization started.');

    _initializationFuture = () async {
      // Assign the future of this async block
      try {
        if (kIsWeb) {
          if (!disableWebDatabaseBootstrap) {
            debugPrint(
                '[DatabaseInitializer] Initializing Web Database Factory (Web path)...');
            final factory = await Future.sync(() {
              return createDatabaseFactoryFfiWeb(
                options: SqfliteFfiWebOptions(
                  sqlite3WasmUri: Uri.base.resolve('sqlite3.wasm'),
                  // ignore: invalid_use_of_visible_for_testing_member
                  forceAsBasicWorker: defaultTargetPlatform ==
                          TargetPlatform.iOS ||
                      defaultTargetPlatform ==
                          TargetPlatform
                              .macOS, // Required for Safari/iOS WASM support
                ),
              );
            }).timeout(const Duration(seconds: 20), onTimeout: () {
              // Increased timeout for Safari's WASM compilation
              throw TimeoutException(
                  'Web database initialization timed out after 20 seconds.');
            });
            databaseFactory =
                factory; // Assign to the global sqflite databaseFactory
            debugPrint(
                '[DatabaseInitializer] Web Database Factory successfully initialized.');
          } else {
            debugPrint(
                '[DatabaseInitializer] Web Database Bootstrap is disabled via flag.');
          }
        } else if (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.macOS) {
          debugPrint(
              '[DatabaseInitializer] Initializing Desktop Database Factory (Native path)...');
          sqfliteFfiInit();
          databaseFactory =
              databaseFactoryFfi; // Assign to the global sqflite databaseFactory
          debugPrint(
              '[DatabaseInitializer] Desktop Database Factory successfully initialized.');
        } else {
          debugPrint(
              '[DatabaseInitializer] Using default Mobile Database Factory (Native path) - no explicit action needed.');
          // For mobile, sqflite typically handles this automatically.
          // No explicit assignment to databaseFactory is required here.
        }
        _isInitialized = true; // Mark as successfully initialized
        debugPrint(
            '[DatabaseInitializer] Database initialization completed successfully.');
      } catch (e, st) {
        debugPrint(
            '[DatabaseInitializer] Database Factory initialization FAILED: $e');
        debugPrint(st.toString());
        _isInitialized = false;
        _initializationFuture = null;
        rethrow; // Propagate the error.
      } finally {
        _isInitializing = false; // Always reset initializing flag
      }
    }(); // Immediately execute the async closure and assign its Future to _initializationFuture

    return _initializationFuture!;
  }

  /// Exposes the current initialization status.
  static bool get isInitialized => _isInitialized;

  /// Resets the initializer for testing purposes.
  @visibleForTesting
  static void reset() {
    _isInitializing = false;
    _isInitialized = false;
    _initializationFuture = null;
    // Note: Cannot safely reset global `databaseFactory` here as it might be used elsewhere.
  }
}
