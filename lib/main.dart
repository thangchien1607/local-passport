import 'dart:ui' show PointerDeviceKind;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';

import 'screens/community_screen.dart';
import 'screens/leaderboard_screen.dart';
import 'screens/location_screen.dart';
import 'screens/map_screen.dart';
import 'screens/passport_screen.dart';
import 'screens/welcome_screen.dart';
import 'services/geo.dart';
import 'services/auth_service.dart';
import 'services/maps_config.dart';
import 'services/passport_remote.dart';
import 'data/routes.dart';
import 'state/passport_store.dart';
import 'theme.dart';

/// Link check-in khi app được mở bằng cách quét QR ở di tích (bản web):
/// `https://…/?checkin=<id>&k=<secret>`. Xử lý một lần sau khi đăng nhập.
String? _pendingCheckinLink;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final link = Uri.base.toString();
  if (parseQr(link) != null) _pendingCheckinLink = link;
  final (remote, auth) = await _initFirebase();
  final store = await PassportStore.load(remote: remote, auth: auth);
  await initGoogleMaps();
  runApp(LocalPassportApp(store: store));
}

/// Bật Firebase (Firestore + tài khoản) nếu nền tảng đã cấu hình; lỗi thì
/// chỉ lưu cục bộ với hồ sơ không cần đăng nhập.
Future<(PassportRemote?, AuthGateway?)> _initFirebase() async {
  final options = currentFirebaseOptions;
  if (options == null) return (null, null);
  try {
    await Firebase.initializeApp(options: options);
    final auth = await FirebaseAuthGateway.create();
    return (FirestorePassportRemote(), auth);
  } catch (e) {
    debugPrint('Không khởi tạo được Firebase: $e');
    return (null, null);
  }
}

class LocalPassportApp extends StatelessWidget {
  const LocalPassportApp({super.key, required this.store});

  final PassportStore store;

  @override
  Widget build(BuildContext context) {
    return PassportScope(
      store: store,
      child: MaterialApp(
        title: 'Local Passport — Đà Nẵng',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        scrollBehavior: const _DragScrollBehavior(),
        // Trên web/tablet: giữ khung mobile 440px ở giữa màn hình.
        builder: (context, child) => ColoredBox(
          color: AppColors.outside,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: ClipRect(child: child),
            ),
          ),
        ),
        home: const _Root(),
      ),
    );
  }
}

/// Flutter Web mặc định chỉ cho kéo cuộn bằng cảm ứng; bật thêm chuột/touchpad
/// để thanh bộ lọc, thẻ câu chuyện… kéo ngang được trên máy tính.
class _DragScrollBehavior extends MaterialScrollBehavior {
  const _DragScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final loggedIn = PassportScope.of(context).user != null;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: loggedIn
          ? const HomeShell(key: ValueKey('home'))
          : const WelcomeScreen(key: ValueKey('welcome')),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;
  late final PassportStore _store = PassportScope.read(context);

  @override
  void initState() {
    super.initState();
    _store.saveProblem.addListener(_showSaveProblem);
    final link = _pendingCheckinLink;
    final qr = link == null ? null : parseQr(link);
    _pendingCheckinLink = null;
    if (qr != null && locationById.containsKey(qr.locationId)) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _openLocation(qr.locationId, checkinCode: link),
      );
    }
  }

  @override
  void dispose() {
    _store.saveProblem.removeListener(_showSaveProblem);
    super.dispose();
  }

  /// Lưu thất bại (mất mạng, bộ nhớ đầy): báo và cho thử lại.
  void _showSaveProblem() {
    final message = _store.saveProblem.value;
    if (message == null || !mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 8),
          action: SnackBarAction(label: 'Thử lại', onPressed: _store.retrySave),
        ),
      );
  }

  void _openLocation(String id, {String? checkinCode}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            LocationScreen(locationId: id, autoCheckinCode: checkinCode),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _tab,
          children: [
            MapScreen(onOpenLocation: _openLocation),
            PassportScreen(onOpenLocation: _openLocation),
            const CommunityScreen(),
            const LeaderboardScreen(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: AppColors.card,
          indicatorColor: AppColors.primary.withValues(alpha: 0.1),
          labelTextStyle: WidgetStateProperty.resolveWith(
            (s) => bodyStyle(
              12,
              weight: FontWeight.w600,
              color: s.contains(WidgetState.selected)
                  ? AppColors.primary
                  : AppColors.inkSoft,
            ),
          ),
          iconTheme: WidgetStateProperty.resolveWith(
            (s) => IconThemeData(
              color: s.contains(WidgetState.selected)
                  ? AppColors.primary
                  : AppColors.inkSoft,
            ),
          ),
        ),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.line)),
          ),
          child: NavigationBar(
            selectedIndex: _tab,
            height: 68,
            onDestinationSelected: (i) => setState(() => _tab = i),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.map_outlined),
                selectedIcon: Icon(Icons.map),
                label: 'Khám phá',
              ),
              NavigationDestination(
                icon: Icon(Icons.menu_book_outlined),
                selectedIcon: Icon(Icons.menu_book),
                label: 'Hộ chiếu',
              ),
              NavigationDestination(
                icon: Icon(Icons.forum_outlined),
                selectedIcon: Icon(Icons.forum),
                label: 'Bảng tin',
              ),
              NavigationDestination(
                icon: Icon(Icons.emoji_events_outlined),
                selectedIcon: Icon(Icons.emoji_events),
                label: 'Xếp hạng',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
