// lib/firebase_options.dart

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
// ⭐️ تم إصلاح الخطأ: استيراد مكتبة foundation.dart بالكامل
import 'package:flutter/foundation.dart'; 

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      // ⭐️ خيارات الويب: يتم استخدامها عند التشغيل على المتصفح ⭐️
      return const FirebaseOptions(
        apiKey: 'AIzaSyAA2JbmtD52JMCz483glEV8eX1ZDeK0fZE',
        appId: '1:32660558108:web:102632793b65058953ead9',
        messagingSenderId: '32660558108',
        projectId: 'aksabeg-b6571',
        authDomain: 'aksabeg-b6571.firebaseapp.com',
        storageBucket: 'aksabeg-b6571.appspot.com',
      );
    }
    
    // ⭐️ لجميع المنصات الأخرى (بما فيها الأندرويد) ⭐️
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        // يتم قراءة معظم هذه الخيارات تلقائيًا من ملف google-services.json
        return const FirebaseOptions(
          apiKey: '', // يمكن تركه فارغًا لأن google-services.json يغطيه
          appId: '', // يمكن تركه فارغًا لأن google-services.json يغطيه
          messagingSenderId: '32660558108',
          projectId: 'aksabeg-b6571',
          storageBucket: 'aksabeg-b6571.appspot.com',
        );
      
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        // يجب إضافة خيارات لهذه المنصات هنا إن لزم الأمر
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }
}
