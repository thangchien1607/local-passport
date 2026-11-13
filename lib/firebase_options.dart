// Cấu hình Firebase cho bản web (project local-passport-danang).
// Lấy bằng: firebase apps:sdkconfig WEB 1:343799587256:web:f075a230d4049d4cebaf4d
// Đây là cấu hình công khai của web app, không phải khóa bí mật: quyền truy cập
// dữ liệu do firestore.rules quyết định.
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// null khi nền tảng chưa cấu hình Firebase (Android/iOS): app dùng lưu trữ cục bộ.
FirebaseOptions? get currentFirebaseOptions => kIsWeb ? _web : null;

const _web = FirebaseOptions(
  apiKey: 'AIzaSyDAA1dNHbs7HaZbhnVRZXfkcsSPeztWRpo',
  appId: '1:343799587256:web:f075a230d4049d4cebaf4d',
  messagingSenderId: '343799587256',
  projectId: 'local-passport-danang',
  authDomain: 'local-passport-danang.firebaseapp.com',
  storageBucket: 'local-passport-danang.firebasestorage.app',
  measurementId: 'G-266DGDS0L3',
);
