import 'package:flutter/material.dart';

import '../data/community.dart';
import '../data/routes.dart';
import '../state/passport_store.dart';
import '../theme.dart';

const _podium = [AppColors.gold, AppColors.inkSoft, Color(0xFFB45309)];

String _displayName(LeaderEntry r) => r.isMe ? '${r.name} (Bạn)' : r.name;

String _initials(String name) => name
    .split(' ')
    .where((w) => w.isNotEmpty)
    .take(2)
    .map((w) => w[0].toUpperCase())
    .join();

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
    final current = rankForXp(store.xp).current;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
      children: [
        Semantics(
          header: true,
          child: Text('Bảng xếp hạng', style: displayStyle(28)),
        ),
        const SizedBox(height: 4),
        Text(
          'Nhà khám phá Đà Nẵng · theo XP và dấu mộc',
          style: bodyStyle(13, color: AppColors.inkSoft),
        ),
        const SizedBox(height: 16),
        _MyRankCard(
          rank: myRank,
          name: me.name,
          subtitle: '${current.title} · ${store.xp} XP',
        ),
        const SizedBox(height: 18),
        _Podium(top: rows.take(3).toList()),
        const SizedBox(height: 22),
        Container(
          decoration: cardDecoration(),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (final (i, r) in rows.indexed.skip(3)) ...[
                if (i > 3)
                  const Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: AppColors.line,
                  ),
                _RankRow(rank: i + 1, entry: r),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        Semantics(
          header: true,
          child: Text('Danh hiệu', style: displayStyle(20)),
        ),
        const SizedBox(height: 14),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, r) in ranks.indexed) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: _RankTier(
                    level: i + 1,
                    rank: r,
                    current: r.id == current.id,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MyRankCard extends StatelessWidget {
  const _MyRankCard({
    required this.rank,
    required this.name,
    required this.subtitle,
  });

  final int rank;
  final String name;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'VỊ TRÍ CỦA BẠN',
            style: bodyStyle(
              10,
              weight: FontWeight.w700,
              color: AppColors.goldLight,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              SizedBox(
                width: 64,
                child: Text(
                  '#$rank',
                  style: displayStyle(
                    32,
                    weight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$name (Bạn)',
                      style: bodyStyle(
                        16,
                        weight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: bodyStyle(12, color: AppColors.goldLight),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.workspace_premium_rounded,
                size: 32,
                color: AppColors.goldLight,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Bục 3 hạng đầu: hạng 2 bên trái, hạng 1 ở giữa cao nhất, hạng 3 bên phải.
class _Podium extends StatelessWidget {
  const _Podium({required this.top});

  final List<LeaderEntry> top;

  @override
  Widget build(BuildContext context) {
    const heights = [134.0, 114.0, 104.0];
    Widget step(int i) => Expanded(
      child: _PodiumStep(
        rank: i + 1,
        entry: top[i],
        color: _podium[i],
        minHeight: heights[i],
      ),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        step(1),
        const SizedBox(width: 14),
        step(0),
        const SizedBox(width: 14),
        step(2),
      ],
    );
  }
}

class _PodiumStep extends StatelessWidget {
  const _PodiumStep({
    required this.rank,
    required this.entry,
    required this.color,
    required this.minHeight,
  });

  final int rank;
  final LeaderEntry entry;
  final Color color;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Hạng $rank: ${_displayName(entry)}, ${entry.xp} XP',
      excludeSemantics: true,
      child: Container(
        constraints: BoxConstraints(minHeight: minHeight),
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 12),
        decoration: entry.isMe
            ? cardDecoration(
                borderColor: AppColors.gold,
              ).copyWith(color: AppColors.goldLight.withValues(alpha: 0.25))
            : cardDecoration(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.2),
                border: Border.all(color: color, width: 2),
              ),
              child: Text(
                '$rank',
                style: displayStyle(18, weight: FontWeight.w700, color: color),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _displayName(entry),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: bodyStyle(13, weight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text(
              '${entry.xp} XP',
              style: bodyStyle(12, color: AppColors.inkSoft),
            ),
          ],
        ),
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({required this.rank, required this.entry});

  final int rank;
  final LeaderEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: entry.isMe ? AppColors.goldLight.withValues(alpha: 0.25) : null,
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '$rank',
              style: bodyStyle(
                15,
                weight: FontWeight.w700,
                color: AppColors.inkSoft,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.paper2,
            ),
            child: Text(
              _initials(entry.name),
              style: bodyStyle(
                11,
                weight: FontWeight.w700,
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
                  _displayName(entry),
                  style: bodyStyle(14, weight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${entry.stamps} dấu mộc',
                  style: bodyStyle(12, color: AppColors.inkSoft),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${entry.xp} XP',
            style: bodyStyle(
              14,
              weight: FontWeight.w700,
              color: AppColors.gold,
            ),
          ),
        ],
      ),
    );
  }
}

class _RankTier extends StatelessWidget {
  const _RankTier({
    required this.level,
    required this.rank,
    required this.current,
  });

  final int level;
  final Rank rank;
  final bool current;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: current ? AppColors.goldLight : AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: current ? AppColors.gold : AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bậc $level',
            style: bodyStyle(
              10,
              weight: FontWeight.w700,
              color: AppColors.inkSoft,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(rank.title, style: bodyStyle(13, weight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            '${rank.minXp}+ XP',
            style: bodyStyle(
              11,
              color: current ? AppColors.primaryDark : AppColors.inkSoft,
            ),
          ),
        ],
      ),
    );
  }
}
