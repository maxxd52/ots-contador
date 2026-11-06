import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Opciones de inicialización de Firebase para todas las plataformas soportadas
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions no están soportadas para esta plataforma.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyC9KosF1Y1FRAcJBfNVbP3WBoRh767WYMk',
    appId: '1:689987404314:web:c06c6fa31af9bfdf5d47a3',
    messagingSenderId: '689987404314',
    projectId: 'ots-contador',
    authDomain: 'ots-contador.firebaseapp.com',
    storageBucket: 'ots-contador.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDv392sQbMsLL7dp1Gmp3u8jXW8YunKzTU',
    appId: '1:689987404314:android:ccdbbf44dc257df45d47a3',
    messagingSenderId: '689987404314',
    projectId: 'ots-contador',
    storageBucket: 'ots-contador.firebasestorage.app',
  );
}
