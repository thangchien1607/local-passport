// Bản web phải nạp Maps JavaScript API; Android đọc key từ AndroidManifest.
export 'maps_loader_stub.dart'
    if (dart.library.js_interop) 'maps_loader_web.dart';
