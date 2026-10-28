import 'dart:convert';

import 'package:flutter/material.dart';

import '../data/community.dart';
import '../data/routes.dart';
import '../theme.dart';

String timeAgo(DateTime t) {
  final diff = DateTime.now().difference(t);
  if (diff.inMinutes < 1) return 'Vừa xong';
  if (diff.inHours < 1) return '${diff.inMinutes} phút trước';
  if (diff.inDays < 1) return '${diff.inHours} giờ trước';
  return '${diff.inDays} ngày trước';
}

class ReflectionCard extends StatelessWidget {
  const ReflectionCard({
    super.key,
    required this.reflection,
    this.showLocation = true,
  });

  final Reflection reflection;
  final bool showLocation;

  @override
  Widget build(BuildContext context) {
    final loc = locationById[reflection.locationId];
    final route = loc == null ? null : routeById[loc.routeId];
    final words = reflection.displayAuthor.split(' ');
    final initials = words
        .skip(words.length > 2 ? words.length - 2 : 0)
        .map((w) => w.isEmpty ? '' : w[0])
        .join();
    final photo = reflection.photoBase64;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: reflection.isAnonymous
                    ? AppColors.ink
                    : AppColors.paper2,
                child: reflection.isAnonymous
                    ? const Icon(
                        Icons.theater_comedy_outlined,
                        size: 18,
                        color: AppColors.paper,
                      )
                    : Text(
                        initials,
                        style: bodyStyle(
                          13,
                          weight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reflection.displayAuthor,
                      style: bodyStyle(14, weight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text.rich(
                      TextSpan(
                        children: [
                          if (showLocation && loc != null) ...[
                            TextSpan(
                              text: loc.name,
                              style: bodyStyle(
                                12,
                                weight: FontWeight.w500,
                                color: route?.color,
                              ),
                            ),
                            const TextSpan(text: ' · '),
                          ],
                          TextSpan(text: timeAgo(reflection.createdAt)),
                        ],
                      ),
                      style: bodyStyle(12, color: AppColors.inkSoft),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (reflection.aiScore >= 70)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.auto_awesome,
                        size: 12,
                        color: AppColors.gold,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Tri kỷ',
                        style: bodyStyle(
                          11,
                          weight: FontWeight.w600,
                          color: AppColors.gold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(reflection.content, style: bodyStyle(15, height: 1.55)),
          if (photo != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                base64Decode(photo),
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
                semanticLabel: 'Ảnh thực tế kèm cảm nhận',
              ),
            ),
          ],
        ],
      ),
    );
  }
}
