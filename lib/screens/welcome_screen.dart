import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/validators.dart';
import '../state/passport_store.dart';
import '../theme.dart';
import '../widgets/auth_form.dart';
import '../widgets/passport_cover.dart';

/// Bìa hộ chiếu: đăng nhập / đăng ký bằng email, hoặc vào bằng tài khoản khách.
/// Khi nền tảng chưa có Firebase thì chỉ tạo hồ sơ lưu cục bộ trên thiết bị.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _name = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  /// Tài khoản khách: chỉ cần tên; có thể lưu vào tài khoản email sau.
  Future<void> _enterAsGuest() async {
    final store = PassportScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _GuestNameDialog(),
    );
    if (name == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await store.enterAsGuest(name);
    } on AuthFailure catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
                    if (store.hasAccounts)
                      Column(
                        children: [
                          const AuthForm(onDark: true),
                          TextButton(
                            onPressed: _busy ? null : _enterAsGuest,
                            style: TextButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                            ),
                            child: Text(
                              'Vào nhanh bằng tài khoản khách',
                              style: bodyStyle(
                                14,
                                weight: FontWeight.w500,
                                color: AppColors.paper.withValues(alpha: 0.85),
                              ),
                            ),
                          ),
                        ],
                      )
                    else
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
                            label: 'Tạo hộ chiếu trên thiết bị',
                            icon: Icons.auto_stories_outlined,
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
                              'Vào nhanh với khách demo',
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

class _GuestNameDialog extends StatefulWidget {
  const _GuestNameDialog();

  @override
  State<_GuestNameDialog> createState() => _GuestNameDialogState();
}

class _GuestNameDialogState extends State<_GuestNameDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _ok() {
    if (_formKey.currentState!.validate()) {
      Navigator.pop(context, _name.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Vào bằng tài khoản khách', style: displayStyle(22)),
    content: Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hộ chiếu khách chỉ gắn với trình duyệt/máy này. Bạn có thể lưu vào tài khoản email sau ở tab Hộ chiếu.',
            style: bodyStyle(13.5, color: AppColors.inkSoft),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _name,
            autofocus: true,
            maxLength: nameMaxLength,
            decoration: const InputDecoration(
              labelText: 'Tên hiển thị trên hộ chiếu',
            ),
            validator: validateName,
            onFieldSubmitted: (_) => _ok(),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton(onPressed: _ok, child: const Text('Vào app')),
    ],
  );
}
