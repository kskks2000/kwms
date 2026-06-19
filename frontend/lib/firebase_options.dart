import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  const DefaultFirebaseOptions._();

  static const webApiKey = String.fromEnvironment('FIREBASE_WEB_API_KEY');
  static const webAppId = String.fromEnvironment('FIREBASE_WEB_APP_ID');
  static const webMessagingSenderId = String.fromEnvironment(
    'FIREBASE_WEB_MESSAGING_SENDER_ID',
  );
  static const webProjectId = String.fromEnvironment('FIREBASE_WEB_PROJECT_ID');
  static const webAuthDomain = String.fromEnvironment(
    'FIREBASE_WEB_AUTH_DOMAIN',
  );
  static const webStorageBucket = String.fromEnvironment(
    'FIREBASE_WEB_STORAGE_BUCKET',
  );
  static const webMeasurementId = String.fromEnvironment(
    'FIREBASE_WEB_MEASUREMENT_ID',
  );

  static const androidApiKey = String.fromEnvironment(
    'FIREBASE_ANDROID_API_KEY',
  );
  static const androidAppId = String.fromEnvironment('FIREBASE_ANDROID_APP_ID');
  static const androidMessagingSenderId = String.fromEnvironment(
    'FIREBASE_ANDROID_MESSAGING_SENDER_ID',
  );
  static const androidProjectId = String.fromEnvironment(
    'FIREBASE_ANDROID_PROJECT_ID',
  );
  static const androidStorageBucket = String.fromEnvironment(
    'FIREBASE_ANDROID_STORAGE_BUCKET',
  );

  static const iosApiKey = String.fromEnvironment('FIREBASE_IOS_API_KEY');
  static const iosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');
  static const iosMessagingSenderId = String.fromEnvironment(
    'FIREBASE_IOS_MESSAGING_SENDER_ID',
  );
  static const iosProjectId = String.fromEnvironment('FIREBASE_IOS_PROJECT_ID');
  static const iosStorageBucket = String.fromEnvironment(
    'FIREBASE_IOS_STORAGE_BUCKET',
  );
  static const iosBundleId = String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID');

  static FirebaseOptions? get currentPlatform {
    if (kIsWeb) {
      return _webOptions;
    }

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => _androidOptions,
      TargetPlatform.iOS || TargetPlatform.macOS => _iosOptions,
      _ => null,
    };
  }

  static bool get isConfigured => currentPlatform != null;

  static FirebaseOptions? get _webOptions {
    if (_hasMissingValue([
      webApiKey,
      webAppId,
      webMessagingSenderId,
      webProjectId,
      webAuthDomain,
    ])) {
      return null;
    }

    return const FirebaseOptions(
      apiKey: webApiKey,
      appId: webAppId,
      messagingSenderId: webMessagingSenderId,
      projectId: webProjectId,
      authDomain: webAuthDomain,
      storageBucket: webStorageBucket,
      measurementId: webMeasurementId,
    );
  }

  static FirebaseOptions? get _androidOptions {
    if (_hasMissingValue([
      androidApiKey,
      androidAppId,
      androidMessagingSenderId,
      androidProjectId,
    ])) {
      return null;
    }

    return const FirebaseOptions(
      apiKey: androidApiKey,
      appId: androidAppId,
      messagingSenderId: androidMessagingSenderId,
      projectId: androidProjectId,
      storageBucket: androidStorageBucket,
    );
  }

  static FirebaseOptions? get _iosOptions {
    if (_hasMissingValue([
      iosApiKey,
      iosAppId,
      iosMessagingSenderId,
      iosProjectId,
      iosBundleId,
    ])) {
      return null;
    }

    return const FirebaseOptions(
      apiKey: iosApiKey,
      appId: iosAppId,
      messagingSenderId: iosMessagingSenderId,
      projectId: iosProjectId,
      storageBucket: iosStorageBucket,
      iosBundleId: iosBundleId,
    );
  }

  static bool _hasMissingValue(List<String> values) {
    return values.any((value) => value.trim().isEmpty);
  }
}
