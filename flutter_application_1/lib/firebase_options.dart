// Firebase initialization options
// Generated configuration for 3elty-app
// You can regenerate this by running: flutterfire configure

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return web;
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDu4...',  // Will be auto-filled by flutterfire configure
    appId: '1:000000000000:android:...',
    messagingSenderId: '000000000000',
    projectId: '3elty-app',
    databaseURL: 'https://3elty-app.firebaseio.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDu4...',
    appId: '1:000000000000:ios:...',
    messagingSenderId: '000000000000',
    projectId: '3elty-app',
    databaseURL: 'https://3elty-app.firebaseio.com',
    iosBundleId: 'com.example.flutterApplication1',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDu4...',
    appId: '1:000000000000:web:...',
    messagingSenderId: '000000000000',
    projectId: '3elty-app',
    authDomain: '3elty-app.firebaseapp.com',
    databaseURL: 'https://3elty-app.firebaseio.com',
    storageBucket: '3elty-app.appspot.com',
  );

  /// For automatic Firebase configuration, run:
  /// flutterfire configure --project=3elty-app
  /// This will auto-generate the correct credentials.
}
