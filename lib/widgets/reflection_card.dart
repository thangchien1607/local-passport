import 'dart:convert';

import 'package:flutter/material.dart';

import '../data/community.dart';
import '../data/routes.dart';
import '../theme.dart';

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
          if (photo != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                base64Decode(photo),
                height: 134,
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
