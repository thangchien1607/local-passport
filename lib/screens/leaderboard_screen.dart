import 'package:flutter/material.dart';

import '../data/community.dart';
import '../data/routes.dart';
import '../state/passport_store.dart';
import '../theme.dart';

const _podium = [Color(0xFFC9A227), Color(0xFF9CA3AF), Color(0xFFB4703E)];

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = PassportScope.of(context);
    final me = LeaderEntry(
      'me',
      store.user!.name,
      store.xp,
      store.totalStamps,
      isMe: true,
    );
    final rows = [...leaderboard, me]
      ..sort(
        (a, b) =>
            b.xp != a.xp ? b.xp.compareTo(a.xp) : b.stamps.compareTo(a.stamps),
      );
    final myRank = rows.indexWhere((r) => r.isMe) + 1;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
      children: [
        Text('Bảng xếp hạng', style: displayStyle(30)),
        Text(
          'Bảng xếp hạng demo · dữ liệu mẫu theo XP và dấu mộc',
          style: bodyStyle(14, color: AppColors.inkSoft),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.ink,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'VỊ TRÍ CỦA BẠN',
                style: bodyStyle(
                  12,
                  color: AppColors.goldLight,
                  letterSpacing: 2,
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '#$myRank',
                    style: displayStyle(32, color: AppColors.paper),
                  ),
                  const Spacer(),
                  Text(
                    '${rankForXp(store.xp).current.title} · ${store.xp} XP',
                    style: bodyStyle(14, color: AppColors.paper),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: cardDecoration(),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (final (i, r) in rows.indexed) ...[
                if (i > 0) const Divider(height: 1, color: AppColors.line),
                Container(
                  color: r.isMe ? AppColors.gold.withValues(alpha: 0.1) : null,
                  constraints: const BoxConstraints(minHeight: 60),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 28,
                        child: i < 3
                            ? Icon(
                                Icons.workspace_premium_rounded,
                                color: _podium[i],
                                semanticLabel: 'Hạng ${i + 1}',
                              )
                            : Text(
                                '${i + 1}',
                                textAlign: TextAlign.center,
                                style: bodyStyle(
                                  14,
                                  weight: FontWeight.w700,
                                  color: AppColors.inkSoft,
                                ),
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${r.name}${r.isMe ? ' (bạn)' : ''}',
                              style: bodyStyle(15, weight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              rankForXp(r.xp).current.title,
                              style: bodyStyle(12, color: AppColors.inkSoft),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.verified_outlined,
                        size: 14,
                        color: AppColors.inkSoft,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${r.stamps}',
                        style: bodyStyle(12, color: AppColors.inkSoft),
                      ),
                      SizedBox(
                        width: 76,
                        child: Text(
                          '${r.xp} XP',
                          textAlign: TextAlign.right,
                          style: bodyStyle(14, weight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text('Danh hiệu', style: displayStyle(20)),
        const SizedBox(height: 12),
        Row(
          children: [
            for (final (i, r) in ranks.indexed) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: store.xp >= r.minXp
                        ? AppColors.gold.withValues(alpha: 0.1)
                        : AppColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: store.xp >= r.minXp
                          ? AppColors.gold.withValues(alpha: 0.4)
                          : AppColors.line,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Bậc ${i + 1}',
                        style: bodyStyle(12, color: AppColors.inkSoft),
                      ),
                      Text(
                        r.title,
                        textAlign: TextAlign.center,
                        style: displayStyle(
                          15,
                          color: store.xp >= r.minXp
                              ? AppColors.gold
                              : AppColors.inkSoft,
                        ),
                      ),
                      Text(
                        '${r.minXp}+ XP',
                        style: bodyStyle(12, color: AppColors.inkSoft),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
