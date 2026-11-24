import 'package:flutter/material.dart';

import '../data/community.dart';
import '../data/routes.dart';
import '../theme.dart';
import 'passport_photo.dart';

String _date(DateTime t) {
  final l = t.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(l.day)}/${two(l.month)}/${l.year}';
}

class ReflectionCard extends StatelessWidget {
  const ReflectionCard({
    super.key,
    required this.reflection,
    this.showLocation = true,
    this.onToggleAnonymous,
    this.onDelete,
  });

  final Reflection reflection;
  final bool showLocation;

  /// Chỉ truyền cho bài của chính người dùng; bài mẫu để null (chỉ đọc).
  final VoidCallback? onToggleAnonymous;

  /// Gọi sau khi người dùng xác nhận xóa trong hộp thoại.
  final VoidCallback? onDelete;

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Xóa bài cảm nhận?', style: displayStyle(22)),
        content: Text(
          'Bài viết sẽ bị gỡ khỏi Bảng tin. Dấu mộc và XP bạn đã nhận vẫn giữ nguyên.',
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
    if (ok == true) onDelete?.call();
  }

  @override
  Widget build(BuildContext context) {
    final loc = locationById[reflection.locationId];
    final route = loc == null ? null : routeById[loc.routeId];
    final words = reflection.displayAuthor.split(' ');
    final initials = words
        .skip(words.length > 2 ? words.length - 2 : 0)
        .map((w) => w.isEmpty ? '' : w[0])
        .join();
    final hasPhoto = reflection.hasPhoto;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: reflection.isAnonymous
                    ? AppColors.paper2
                    : AppColors.goldLight,
                child: reflection.isAnonymous
                    ? const Icon(
                        Icons.theater_comedy_outlined,
                        size: 20,
                        color: AppColors.inkSoft,
                      )
                    : Text(
                        initials,
                        style: bodyStyle(
                          12,
                          weight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reflection.displayAuthor,
                      style: bodyStyle(14, weight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    if (showLocation && loc != null)
                      Row(
                        children: [
                          Icon(
                            Icons.place_rounded,
                            size: 13,
                            color: route?.color ?? AppColors.inkSoft,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              loc.name,
                              style: bodyStyle(12, color: AppColors.inkSoft),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      )
                    else
                      Text(
                        _date(reflection.createdAt),
                        style: bodyStyle(12, color: AppColors.inkSoft),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Semantics(
                label: 'Điểm AI ${reflection.aiScore} trên 100',
                excludeSemantics: true,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
                  decoration: BoxDecoration(
                    color: AppColors.progress.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.auto_awesome,
                        size: 16,
                        color: AppColors.progressInk,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'AI ${reflection.aiScore}',
                        style: bodyStyle(
                          12,
                          weight: FontWeight.w700,
                          color: AppColors.progressInk,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(reflection.content, style: bodyStyle(13, height: 1.46)),
          if (hasPhoto) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: PassportPhoto(
                photoUrl: reflection.photoUrl,
                photoBase64: reflection.photoBase64,
                height: 134,
                width: double.infinity,
                fit: BoxFit.cover,
                semanticLabel: 'Ảnh thực tế kèm cảm nhận',
              ),
            ),
          ],
          if (onToggleAnonymous != null || onDelete != null) ...[
            const SizedBox(height: 8),
            const Divider(height: 1, color: AppColors.line),
            Wrap(
              spacing: 4,
              children: [
                if (onToggleAnonymous != null)
                  TextButton.icon(
                    onPressed: onToggleAnonymous,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.inkSoft,
                    ),
                    icon: Icon(
                      reflection.isAnonymous
                          ? Icons.person_outline
                          : Icons.theater_comedy_outlined,
                      size: 18,
                    ),
                    label: Text(
                      reflection.isAnonymous
                          ? 'Hiện tên của tôi'
                          : 'Chuyển sang ẩn danh',
                    ),
                  ),
                if (onDelete != null)
                  TextButton.icon(
                    onPressed: () => _confirmDelete(context),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                    ),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Xóa'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
