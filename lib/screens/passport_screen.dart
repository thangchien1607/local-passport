import 'package:flutter/material.dart';

import '../data/routes.dart';
import '../services/auth_service.dart';
import '../services/validators.dart';
import '../state/passport_store.dart';
import '../widgets/auth_form.dart';
import '../theme.dart';
import '../widgets/storage_info.dart';
import '../widgets/common.dart';
import '../widgets/passport_cover.dart';
import '../widgets/stamp_seal.dart';

class PassportScreen extends StatelessWidget {
  const PassportScreen({super.key, required this.onOpenLocation});

  final ValueChanged<String> onOpenLocation;

  Future<void> _confirmReset(BuildContext context) async {
    final store = PassportScope.read(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Làm lại từ đầu?', style: displayStyle(22)),
        content: Text(
          'Xóa toàn bộ tiến độ, dấu mộc và cảm nhận để demo lại.',
          style: bodyStyle(14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (ok == true) store.reset();
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final store = PassportScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    final guest = store.isGuest;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Đăng xuất?', style: displayStyle(22)),
        content: Text(
          guest
              ? 'Bạn đang dùng tài khoản khách. Đăng xuất sẽ mất hộ chiếu này. Hãy “Lưu vào tài khoản” trước nếu muốn giữ.'
              : 'Hộ chiếu vẫn được lưu trên máy chủ. Đăng nhập lại bằng ${store.accountEmail ?? 'email của bạn'} để tiếp tục.',
          style: bodyStyle(14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(guest ? 'Vẫn đăng xuất' : 'Đăng xuất'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await store.logout();
    } on AuthFailure catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _sendVerificationEmail(BuildContext context) async {
    final store = PassportScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await store.sendEmailVerification();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Đã gửi email xác minh. Kiểm tra hộp thư của bạn.'),
        ),
      );
    } on AuthFailure catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _checkEmailVerified(BuildContext context) async {
    final store = PassportScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final verified = await store.refreshEmailVerification();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            verified
                ? 'Email của bạn đã được xác minh.'
                : 'Email chưa được xác minh. Hãy bấm link trong hộp thư.',
          ),
        ),
      );
    } on AuthFailure catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _openRename(BuildContext context) async {
    final store = PassportScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _RenameDialog(initialName: store.user?.name ?? ''),
    );
    if (name == null) return;
    final error = store.rename(name);
    messenger.showSnackBar(
      SnackBar(content: Text(error ?? 'Đã đổi tên thành “${name.trim()}”.')),
    );
  }

  Future<void> _openChangePassword(BuildContext context) async {
    final store = PassportScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => _ChangePasswordDialog(store: store),
    );
    if (changed == true) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Đổi mật khẩu thành công.')),
      );
    }
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final store = PassportScope.read(context);
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DeleteAccountDialog(store: store),
    );
  }

  void _openSaveAccount(BuildContext context) {
    final store = PassportScope.read(context);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (routeContext) => Scaffold(
          appBar: AppBar(
            title: Text('Lưu vào tài khoản', style: displayStyle(22)),
          ),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Tạo tài khoản email để giữ hộ chiếu, dấu mộc và cảm nhận hiện tại, rồi đăng nhập trên máy khác.',
                style: bodyStyle(14, color: AppColors.inkSoft, height: 1.5),
              ),
              const SizedBox(height: 20),
              AuthForm(
                initialMode: AuthMode.register,
                allowSwitch: false,
                initialName: store.user?.name,
                onSuccess: () {
                  Navigator.of(routeContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Đã lưu hộ chiếu vào tài khoản.'),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = PassportScope.of(context);
    final user = store.user!;
    final rank = rankForXp(store.xp);
    final next = rank.next;
    final toNext = next == null
        ? 100
        : ((store.xp - rank.current.minXp) /
                  (next.minXp - rank.current.minXp) *
                  100)
              .round();
    final words = user.name.split(' ').where((w) => w.isNotEmpty).toList();
    final initials = words
        .skip(words.length > 2 ? words.length - 2 : 0)
        .map((w) => w[0])
        .join()
        .toUpperCase();
    final d = user.joinedAt;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
      children: [
        Semantics(
          header: true,
          child: Text('Hộ chiếu số', style: displayStyle(28)),
        ),
        const SizedBox(height: 16),

        // Trang thông tin chủ hộ chiếu
        PassportCover(
          radius: 24,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'LOCAL PASSPORT',
                      style: bodyStyle(
                        11,
                        weight: FontWeight.w600,
                        color: AppColors.goldLight,
                        letterSpacing: 2.5,
                      ),
                    ),
                    Text(
                      'ĐÀ NẴNG · VN',
                      style: bodyStyle(
                        11,
                        weight: FontWeight.w600,
                        color: AppColors.goldLight,
                        letterSpacing: 2.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.goldLight.withValues(alpha: 0.6),
                          width: 2,
                        ),
                      ),
                      child: Text(
                        initials,
                        style: displayStyle(26, color: AppColors.goldLight),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Field('HỌ TÊN', user.name, big: true),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _Field('SỐ HỘ CHIẾU', user.passportNo),
                              ),
                              Expanded(
                                child: _Field(
                                  'CẤP NGÀY',
                                  '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.workspace_premium_rounded,
                        size: 20,
                        color: AppColors.goldLight,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          rank.current.title,
                          style: bodyStyle(
                            13,
                            weight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Text(
                        '${store.xp} XP',
                        style: bodyStyle(
                          13,
                          weight: FontWeight.w700,
                          color: AppColors.goldLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Tiến độ lên hạng
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tiến độ lên hạng',
                style: bodyStyle(14, weight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              AppProgressBar(
                value: toNext,
                color: AppColors.gold,
                label: 'Tiến độ lên hạng',
              ),
              const SizedBox(height: 8),
              Text(
                next == null
                    ? 'Bạn đã đạt danh hiệu cao nhất!'
                    : 'Còn ${next.minXp - store.xp} XP để lên ${next.title}',
                style: bodyStyle(12, color: AppColors.inkSoft),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Stat('${store.totalStamps}/${store.totalLocations}', 'Dấu mộc'),
              const SizedBox(width: 8),
              _Stat(
                '${publishedRoutes.where((r) => store.routeProgress(r.id).percent == 100).length}',
                'Tuyến xong',
              ),
              const SizedBox(width: 8),
              _Stat('${store.reflections.length}', 'Cảm nhận'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const StorageInfoCard(),

        // Các trang đóng dấu theo tuyến
        for (final route in publishedRoutes) ...[
          const SizedBox(height: 24),
          Row(
            children: [
              Icon(route.icon, size: 20, color: route.color),
              const SizedBox(width: 8),
              Expanded(child: Text(route.title, style: displayStyle(18))),
              Text(
                '${store.routeProgress(route.id).stamped}/${store.routeProgress(route.id).total}',
                style: bodyStyle(
                  13,
                  weight: FontWeight.w700,
                  color: AppColors.progressInk,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.paper2,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.line),
            ),
            child: GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 8,
              childAspectRatio: 74 / 108,
              children: [
                for (final (i, loc) in locationsOfRoute(route.id).indexed)
                  _StampSlot(
                    location: loc,
                    route: route,
                    date: store.stamps[loc.id],
                    rotation: i.isOdd ? 7 : -9,
                    onTap: () => onOpenLocation(loc.id),
                  ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 32),
        if (store.hasAccounts) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      store.isGuest
                          ? Icons.person_outline_rounded
                          : store.emailVerified
                          ? Icons.verified_user_outlined
                          : Icons.mark_email_unread_outlined,
                      color: store.isGuest
                          ? AppColors.gold
                          : store.emailVerified
                          ? AppColors.progressInk
                          : AppColors.gold,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            store.isGuest
                                ? 'Tài khoản khách'
                                : store.emailVerified
                                ? 'Tài khoản · Đã xác minh email'
                                : 'Tài khoản · Chưa xác minh email',
                            style: bodyStyle(12, color: AppColors.inkSoft),
                          ),
                          Text(
                            store.isGuest
                                ? 'Chưa gắn email: đăng xuất sẽ mất hộ chiếu'
                                : store.accountEmail ?? '',
                            style: bodyStyle(14, weight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    if (store.isGuest)
                      TextButton(
                        onPressed: () => _openSaveAccount(context),
                        child: const Text('Lưu vào tài khoản'),
                      ),
                  ],
                ),
                ...[
                  const SizedBox(height: 10),
                  const Divider(height: 1, color: AppColors.line),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    children: [
                      TextButton.icon(
                        onPressed: () => _openRename(context),
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text('Đổi tên'),
                      ),
                      if (store.hasPasswordProvider &&
                          !store.emailVerified) ...[
                        TextButton.icon(
                          onPressed: () => _sendVerificationEmail(context),
                          icon: const Icon(Icons.send_outlined, size: 16),
                          label: const Text('Gửi email xác minh'),
                        ),
                        TextButton.icon(
                          onPressed: () => _checkEmailVerified(context),
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: const Text('Kiểm tra xác minh'),
                        ),
                      ],
                      if (store.hasPasswordProvider)
                        TextButton.icon(
                          onPressed: () => _openChangePassword(context),
                          icon: const Icon(Icons.lock_reset_rounded, size: 16),
                          label: const Text('Đổi mật khẩu'),
                        ),
                      if (!store.isGuest)
                        TextButton.icon(
                          onPressed: () => _confirmDeleteAccount(context),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFFB91C1C),
                          ),
                          icon: const Icon(
                            Icons.delete_forever_outlined,
                            size: 16,
                          ),
                          label: const Text('Xóa tài khoản'),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        Container(
          decoration: cardDecoration(),
          child: SwitchListTile(
            value: store.skipLocationCheck,
            onChanged: store.setSkipLocationCheck,
            title: Text(
              'Bỏ qua kiểm tra vị trí',
              style: bodyStyle(14, weight: FontWeight.w600),
            ),
            subtitle: Text(
              'Vẫn phải quét mã QR thật của di tích, nhưng không cần đứng '
              'gần di tích. Dùng khi thử hoặc báo cáo ở lớp. Chỉ áp dụng trên '
              'máy này.',
              style: bodyStyle(12, color: AppColors.inkSoft),
            ),
            secondary: const Icon(
              Icons.location_off_outlined,
              color: AppColors.gold,
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (store.remote != null) ...[
          Container(
            decoration: cardDecoration(),
            child: SwitchListTile(
              value: store.demoQrEnabled,
              onChanged: store.setDemoQr,
              title: Text(
                'Chế độ trình diễn',
                style: bodyStyle(14, weight: FontWeight.w600),
              ),
              subtitle: Text(
                'Hiện nút "Giả lập quét QR" khi không có mã QR thật. '
                'Chỉ áp dụng trên máy này.',
                style: bodyStyle(12, color: AppColors.inkSoft),
              ),
              secondary: const Icon(Icons.auto_awesome, color: AppColors.gold),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Expanded(
              child: SecondaryButton(
                label: 'Làm lại từ đầu',
                icon: Icons.restart_alt_rounded,
                onPressed: () => _confirmReset(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SecondaryButton(
                label: 'Đăng xuất',
                icon: Icons.logout_rounded,
                color: routeById['history']!.color,
                onPressed: () => _confirmLogout(context),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field(this.label, this.value, {this.big = false});

  final String label;
  final String value;
  final bool big;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: bodyStyle(
          10,
          color: AppColors.paper.withValues(alpha: 0.6),
          letterSpacing: 1,
        ),
      ),
      Text(
        value,
        overflow: TextOverflow.ellipsis,
        style: big
            ? displayStyle(18, weight: FontWeight.w500, color: AppColors.paper)
            : bodyStyle(14, color: AppColors.paper),
      ),
    ],
  );
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label);

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: cardDecoration(),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: displayStyle(
              24,
              weight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: bodyStyle(12, color: AppColors.inkSoft),
          ),
        ],
      ),
    ),
  );
}

class _StampSlot extends StatelessWidget {
  const _StampSlot({
    required this.location,
    required this.route,
    required this.date,
    required this.rotation,
    required this.onTap,
  });

  final Location location;
  final RouteInfo route;
  final DateTime? date;
  final double rotation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final stamped = date != null;
    return Semantics(
      button: true,
      label: '${location.name}${stamped ? ' — đã đóng mộc' : ' — chưa có dấu'}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: stamped
                    ? StampSeal(
                        location: location,
                        route: route,
                        date: date,
                        size: 70,
                        rotation: rotation,
                      )
                    : Container(
                        width: 70,
                        height: 70,
                        decoration: const ShapeDecoration(
                          shape: CircleBorder(
                            side: BorderSide(color: AppColors.line, width: 2),
                          ),
                        ),
                        child: const Icon(
                          Icons.lock_rounded,
                          color: AppColors.line,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              location.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: bodyStyle(
                11,
                color: stamped ? AppColors.ink : AppColors.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initialName});

  final String initialName;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final _ctrl = TextEditingController(text: widget.initialName);
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      Navigator.pop(context, _ctrl.text);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Đổi tên hiển thị', style: displayStyle(22)),
    content: Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tên mới hiện trên hộ chiếu, bảng xếp hạng và các bài cảm nhận '
            'không ẩn danh.',
            style: bodyStyle(13, color: AppColors.inkSoft, height: 1.4),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _ctrl,
            autofocus: true,
            maxLength: nameMaxLength,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Tên hiển thị'),
            validator: validateName,
            onFieldSubmitted: (_) => _submit(),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Lưu')),
    ],
  );
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog({required this.store});

  final PassportStore store;

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _currentCtrl = TextEditingController();
  final _nextCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _nextCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.store.changePassword(
        currentPassword: _currentCtrl.text,
        newPassword: _nextCtrl.text,
      );
      if (mounted) Navigator.pop(context, true);
    } on AuthFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Đổi mật khẩu', style: displayStyle(22)),
    content: Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _currentCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Mật khẩu hiện tại'),
              validator: (v) =>
                  (v ?? '').isEmpty ? 'Nhập mật khẩu hiện tại' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _nextCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Mật khẩu mới'),
              validator: validatePassword,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _confirmCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Nhập lại mật khẩu mới',
              ),
              validator: (v) => validatePasswordConfirm(_nextCtrl.text, v),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: bodyStyle(13, color: const Color(0xFFB91C1C)),
              ),
            ],
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton(
        onPressed: _busy ? null : _submit,
        child: Text(_busy ? 'Đang lưu…' : 'Cập nhật'),
      ),
    ],
  );
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog({required this.store});

  final PassportStore store;

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _passwordCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final needPassword = widget.store.hasPasswordProvider;
    if (needPassword && !_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.store.deleteAccount(
        password: needPassword ? _passwordCtrl.text : null,
      );
      if (mounted) Navigator.pop(context, true);
    } on AuthFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final needPassword = widget.store.hasPasswordProvider;
    final providerLabel = widget.store.hasGoogleProvider
        ? 'Google'
        : widget.store.hasAppleProvider
        ? 'Apple'
        : null;
    return AlertDialog(
      title: Text('Xóa vĩnh viễn tài khoản?', style: displayStyle(22)),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hành động này sẽ xóa hoàn toàn tài khoản, hộ chiếu, toàn bộ chuyến thăm, thông báo, bài cảm nhận và vị trí trên bảng xếp hạng. Không thể khôi phục.',
                style: bodyStyle(14),
              ),
              if (needPassword) ...[
                const SizedBox(height: 14),
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: true,
                  enabled: !_busy,
                  decoration: const InputDecoration(
                    labelText: 'Mật khẩu hiện tại để xác nhận',
                  ),
                  validator: (v) => (v ?? '').isEmpty
                      ? 'Nhập mật khẩu hiện tại để tiếp tục'
                      : null,
                ),
              ] else if (providerLabel != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Bạn sẽ được yêu cầu xác thực lại bằng $providerLabel trước khi dữ liệu và tài khoản bị xóa.',
                  style: bodyStyle(13, color: AppColors.inkSoft),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: bodyStyle(13, color: const Color(0xFFB91C1C)),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('Hủy'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFB91C1C),
          ),
          onPressed: _busy ? null : _submit,
          child: Text(_busy ? 'Đang xóa…' : 'Xóa vĩnh viễn'),
        ),
      ],
    );
  }
}
