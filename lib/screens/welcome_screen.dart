import 'package:flutter/material.dart';

import '../state/passport_store.dart';
import '../theme.dart';
import '../widgets/passport_cover.dart';

/// Bìa hộ chiếu + đăng nhập. Nút Google hiện là mô phỏng;
/// khi nối Firebase Auth thay bằng signInWithGoogle().
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = PassportScope.read(context);
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: PassportCover(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, c) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: c.maxHeight - 64),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOut,
                      builder: (context, v, child) => Opacity(
                        opacity: v,
                        child: Transform.translate(
                          offset: Offset(0, 16 * (1 - v)),
                          child: child,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'HỘ CHIẾU TRẢI NGHIỆM',
                            style: bodyStyle(
                              12,
                              weight: FontWeight.w600,
                              color: AppColors.goldLight,
                              letterSpacing: 4,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Local\nPassport',
                            textAlign: TextAlign.center,
                            style: displayStyle(
                              48,
                              color: AppColors.goldLight,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 36),
                          Container(
                            width: 160,
                            height: 160,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.goldLight.withValues(
                                  alpha: 0.7,
                                ),
                                width: 2,
                              ),
                            ),
                            padding: const EdgeInsets.all(12),
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.goldLight.withValues(
                                    alpha: 0.4,
                                  ),
                                ),
                              ),
                              child: const Icon(
                                Icons.explore_outlined,
                                size: 64,
                                color: AppColors.goldLight,
                              ),
                            ),
                          ),
                          const SizedBox(height: 36),
                          Text(
                            'Đà Nẵng',
                            style: displayStyle(
                              26,
                              weight: FontWeight.w500,
                              color: AppColors.paper,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: 290,
                            child: Text(
                              'Biến thành phố thành bảo tàng mở. Đến tận nơi, quét mã, nhìn xuyên thời gian và sưu tầm dấu mộc.',
                              textAlign: TextAlign.center,
                              style: bodyStyle(
                                14,
                                color: AppColors.paper.withValues(alpha: 0.78),
                                height: 1.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'LEARN BEYOND LIMITS',
                            style: bodyStyle(
                              11,
                              weight: FontWeight.w600,
                              color: AppColors.goldLight.withValues(
                                alpha: 0.85,
                              ),
                              letterSpacing: 3.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    Column(
                      children: [
                        TextField(
                          controller: _name,
                          maxLength: 30,
                          style: bodyStyle(16, color: AppColors.paper),
                          cursorColor: AppColors.goldLight,
                          decoration: InputDecoration(
                            counterText: '',
                            hintText: 'Tên hiển thị trên hộ chiếu',
                            hintStyle: bodyStyle(
                              16,
                              color: AppColors.paper.withValues(alpha: 0.55),
                            ),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.1),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide(
                                color: AppColors.goldLight.withValues(
                                  alpha: 0.4,
                                ),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: const BorderSide(
                                color: AppColors.goldLight,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        PrimaryButton(
                          label: 'Đăng nhập bằng Google',
                          icon: Icons.login_rounded,
                          background: Colors.white,
                          foreground: AppColors.ink,
                          onPressed: () => store.login(_name.text.trim()),
                        ),
                        const SizedBox(height: 4),
                        TextButton(
                          onPressed: () => store.login(
                            _name.text.trim().isEmpty
                                ? 'Ban giám khảo'
                                : _name.text.trim(),
                          ),
                          style: TextButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                          ),
                          child: Text(
                            'Dùng thử không cần đăng nhập',
                            style: bodyStyle(
                              14,
                              weight: FontWeight.w500,
                              color: AppColors.paper.withValues(alpha: 0.85),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
