import 'package:flutter/material.dart';

import 'screens/timelens_screen.dart';
import 'theme.dart';

/// Bản demo công khai chỉ gồm Lăng kính thời gian (TimeLens).
/// Không import các màn hình/state khác nên khi build với
/// `-t lib/main_timelens.dart`, phần còn lại của app không vào bundle.
/// Trong app đầy đủ, cùng màn này được mở từ tab Khám phá.
/// Build & deploy: xem timelens_demo_plan.md.
void main() => runApp(const TimeLensDemoApp());

class TimeLensDemoApp extends StatelessWidget {
  const TimeLensDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TimeLens — Local Passport',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      // Giống app chính: trên web/tablet giữ khung mobile 440px ở giữa màn hình.
      builder: (context, child) => ColoredBox(
        color: AppColors.outside,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: ClipRect(child: child),
          ),
        ),
      ),
      home: const TimeLensScreen(standalone: true),
    );
  }
}
