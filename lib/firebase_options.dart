// Cấu hình Firebase (project local-passport-danang) cho web và Android.
// Lấy bằng: firebase apps:sdkconfig WEB|ANDROID <appId>
// Đây là cấu hình công khai của app, không phải khóa bí mật: quyền truy cập
// dữ liệu do firestore.rules quyết định.
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// null khi nền tảng chưa cấu hình Firebase (iOS, desktop): app chỉ lưu cục bộ.
FirebaseOptions? get currentFirebaseOptions {
  if (kIsWeb) return _web;
  if (defaultTargetPlatform == TargetPlatform.android) return _android;
  return null;
}

const _web = FirebaseOptions(
  apiKey: 'AIzaSyDAA1dNHbs7HaZbhnVRZXfkcsSPeztWRpo',
  appId: '1:343799587256:web:f075a230d4049d4cebaf4d',
  messagingSenderId: '343799587256',
  projectId: 'local-passport-danang',
  authDomain: 'local-passport-danang.firebaseapp.com',
  storageBucket: 'local-passport-danang.firebasestorage.app',
  measurementId: 'G-266DGDS0L3',
);

const _android = FirebaseOptions(
  apiKey: 'AIzaSyAyxTq-hGOcQ_W0tZq-tu7eiql9nDiDZ0g',
  appId: '1:343799587256:android:a4ecfafd6eaf11edebaf4d',
  messagingSenderId: '343799587256',
  projectId: 'local-passport-danang',
  storageBucket: 'local-passport-danang.firebasestorage.app',
);
