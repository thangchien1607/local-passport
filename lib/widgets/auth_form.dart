import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/validators.dart';
import '../state/passport_store.dart';
import '../theme.dart';

enum AuthMode { signIn, register }

/// Form đăng nhập / đăng ký bằng email. Kiểm tra đầu vào ngay dưới từng ô và
/// hiện lỗi từ máy chủ (sai mật khẩu, email đã dùng, mất mạng…) phía trên nút.
class AuthForm extends StatefulWidget {
  const AuthForm({
    super.key,
    this.initialMode = AuthMode.signIn,
    this.onDark = false,
    this.allowSwitch = true,
    this.initialName,
    this.onSuccess,
  });

  final AuthMode initialMode;

  /// Đặt trên nền burgundy của màn chào.
  final bool onDark;
  final bool allowSwitch;
  final String? initialName;
  final VoidCallback? onSuccess;

  @override
  State<AuthForm> createState() => _AuthFormState();
}

class _AuthFormState extends State<AuthForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initialName);
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  late AuthMode _mode = widget.initialMode;
  bool _busy = false;
  bool _hidePassword = true;
  bool _submitted = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Color get _fg => widget.onDark ? AppColors.paper : AppColors.ink;
  Color get _accent => widget.onDark ? AppColors.goldLight : AppColors.primary;
  Color get _errorColor =>
      widget.onDark ? const Color(0xFFFFD2BF) : const Color(0xFFB91C1C);

  InputDecoration _decoration(String hint, IconData icon, {Widget? suffix}) {
    OutlineInputBorder border(Color c) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: c),
    );
    return InputDecoration(
      counterText: '',
      hintText: hint,
      hintStyle: bodyStyle(15, color: _fg.withValues(alpha: 0.55)),
      prefixIcon: Icon(icon, color: _fg.withValues(alpha: 0.7), size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: widget.onDark
          ? Colors.white.withValues(alpha: 0.1)
          : AppColors.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      errorStyle: bodyStyle(12.5, color: _errorColor),
      errorMaxLines: 2,
      enabledBorder: border(
        widget.onDark
            ? AppColors.goldLight.withValues(alpha: 0.4)
            : AppColors.line,
      ),
      focusedBorder: border(_accent),
      errorBorder: border(_errorColor),
      focusedErrorBorder: border(_errorColor),
    );
  }

  Future<void> _submit() async {
    setState(() {
      _submitted = true;
      _error = null;
    });
    if (!_formKey.currentState!.validate()) return;
    final store = PassportScope.read(context);
    setState(() => _busy = true);
    try {
      if (_mode == AuthMode.signIn) {
        await store.signIn(email: _email.text, password: _password.text);
      } else {
        await store.register(
          name: _name.text,
          email: _email.text,
          password: _password.text,
        );
      }
      widget.onSuccess?.call();
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgotPassword() async {
    final emailError = validateEmail(_email.text);
    if (emailError != null) {
      setState(() => _error = 'Nhập email để nhận link đặt lại mật khẩu.');
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await PassportScope.read(context).sendPasswordReset(_email.text);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Đã gửi link đặt lại mật khẩu tới ${_email.text.trim()}.',
          ),
        ),
      );
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signInProvider(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      widget.onSuccess?.call();
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _switch(AuthMode mode) => setState(() {
    _mode = mode;
    _error = null;
    _submitted = false;
    _formKey.currentState?.reset();
  });

  @override
  Widget build(BuildContext context) {
    final register = _mode == AuthMode.register;
    final textStyle = bodyStyle(16, color: _fg);
    return Form(
      key: _formKey,
      autovalidateMode: _submitted
          ? AutovalidateMode.onUserInteraction
          : AutovalidateMode.disabled,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.allowSwitch) ...[
              Row(
                children: [
                  for (final (mode, label) in [
                    (AuthMode.signIn, 'Đăng nhập'),
                    (AuthMode.register, 'Đăng ký'),
                  ])
                    Expanded(
                      child: Semantics(
                        selected: _mode == mode,
                        button: true,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: _busy ? null : () => _switch(mode),
                          child: Container(
                            height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: _mode == mode
                                      ? _accent
                                      : _fg.withValues(alpha: 0.2),
                                  width: _mode == mode ? 3 : 1,
                                ),
                              ),
                            ),
                            child: Text(
                              label,
                              style: bodyStyle(
                                15,
                                weight: FontWeight.w700,
                                color: _mode == mode
                                    ? _accent
                                    : _fg.withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            if (register) ...[
              TextFormField(
                controller: _name,
                maxLength: nameMaxLength,
                style: textStyle,
                cursorColor: _accent,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                decoration: _decoration(
                  'Tên hiển thị trên hộ chiếu',
                  Icons.badge_outlined,
                ),
                validator: validateName,
              ),
              const SizedBox(height: 10),
            ],
            TextFormField(
              controller: _email,
              style: textStyle,
              cursorColor: _accent,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              autofillHints: const [AutofillHints.email],
              decoration: _decoration('Email', Icons.alternate_email_rounded),
              validator: validateEmail,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _password,
              style: textStyle,
              cursorColor: _accent,
              obscureText: _hidePassword,
              maxLength: passwordMaxLength,
              textInputAction: register
                  ? TextInputAction.next
                  : TextInputAction.done,
              autofillHints: [
                register ? AutofillHints.newPassword : AutofillHints.password,
              ],
              onFieldSubmitted: register ? null : (_) => _submit(),
              decoration: _decoration(
                register ? 'Mật khẩu (≥ 6 ký tự, có chữ và số)' : 'Mật khẩu',
                Icons.lock_outline_rounded,
                suffix: IconButton(
                  tooltip: _hidePassword ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                  icon: Icon(
                    _hidePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: _fg.withValues(alpha: 0.7),
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _hidePassword = !_hidePassword),
                ),
              ),
              validator: register
                  ? validatePassword
                  : (v) => (v ?? '').isEmpty ? 'Nhập mật khẩu' : null,
            ),
            if (register) ...[
              const SizedBox(height: 10),
              TextFormField(
                controller: _confirm,
                style: textStyle,
                cursorColor: _accent,
                obscureText: _hidePassword,
                maxLength: passwordMaxLength,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                decoration: _decoration(
                  'Nhập lại mật khẩu',
                  Icons.lock_reset_rounded,
                ),
                validator: (v) => validatePasswordConfirm(_password.text, v),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _errorColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: _errorColor, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: bodyStyle(13.5, color: _errorColor),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            PrimaryButton(
              label: register ? 'Tạo tài khoản' : 'Đăng nhập',
              icon: register
                  ? Icons.person_add_alt_1_rounded
                  : Icons.login_rounded,
              loading: _busy,
              background: widget.onDark ? Colors.white : null,
              foreground: widget.onDark ? AppColors.ink : null,
              onPressed: _submit,
            ),
            if (!register)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _busy ? null : _forgotPassword,
                  child: Text(
                    'Quên mật khẩu?',
                    style: bodyStyle(
                      13.5,
                      weight: FontWeight.w600,
                      color: _fg.withValues(alpha: 0.85),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: Divider(color: _fg.withValues(alpha: 0.25))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    'hoặc tiếp tục với',
                    style: bodyStyle(12, color: _fg.withValues(alpha: 0.7)),
                  ),
                ),
                Expanded(child: Divider(color: _fg.withValues(alpha: 0.25))),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _signInProvider(
                            PassportScope.read(context).signInWithGoogle,
                          ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 46),
                      foregroundColor: _fg,
                      side: BorderSide(color: _fg.withValues(alpha: 0.35)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.g_mobiledata_rounded, size: 22),
                    label: const Text('Google'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _signInProvider(
                            PassportScope.read(context).signInWithApple,
                          ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 46),
                      foregroundColor: _fg,
                      side: BorderSide(color: _fg.withValues(alpha: 0.35)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.apple_rounded, size: 20),
                    label: const Text('Apple'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
