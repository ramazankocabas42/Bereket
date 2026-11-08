// Firebase proje ayarları (egitim-takip-5a833).
// google-services.json dosyasından oluşturuldu.
// Bu bilgiler gizli değildir; erişim güvenliği firestore.rules ile sağlanır.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (defaultTargetPlatform == TargetPlatform.android) return android;
    throw UnsupportedError('Bu uygulama yalnızca Android için yapılandırıldı.');
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCc1S_Log_bfejrqZSF6btMyz1MeaPMUxs',
    appId: '1:346066162484:android:0da3d7f5313e9e336bcb61',
    messagingSenderId: '346066162484',
    projectId: 'egitim-takip-5a833',
    storageBucket: 'egitim-takip-5a833.firebasestorage.app',
  );
}
