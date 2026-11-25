import 'package:flutter/material.dart';

import '../data/routes.dart';
import '../services/text_search.dart';
import '../state/passport_store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/edit_reflection_dialog.dart';
import '../widgets/reflection_card.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final _scrollController = ScrollController();
  String _filter = 'all';
  String _query = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    final store = PassportScope.read(context);
    store.startWatchingCommunity();
    store.refreshCommunity();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.maxScrollExtent - pos.pixels <= 240) {
      PassportScope.read(context).loadMoreCommunity();
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = PassportScope.of(context);
    final list = store.feed
        .where(
          (r) =>
              (_filter == 'all' ||
                  locationById[r.locationId]?.routeId == _filter) &&
              reflectionMatches(r, _query),
        )
        .toList();
    final searching = _query.trim().isNotEmpty;

    return RefreshIndicator(
      onRefresh: store.refreshCommunity,
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
        children: [
          Semantics(
            header: true,
            child: Text('Bảng tin cộng đồng', style: displayStyle(28)),
          ),
          const SizedBox(height: 4),
          Text(
            'Cảm nhận thật, được AI kiểm duyệt, có thể ẩn danh.',
            style: bodyStyle(13, color: AppColors.inkSoft),
          ),
          const SizedBox(height: 16),
          SearchField(
            hint: 'Tìm theo nội dung, tác giả, địa điểm…',
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                FilterPill(
                  label: 'Tất cả',
                  selected: _filter == 'all',
                  onTap: () => setState(() => _filter = 'all'),
                ),
                for (final r in publishedRoutes) ...[
                  const SizedBox(width: 8),
                  FilterPill(
                    label: r.short,
                    icon: r.icon,
                    color: r.color,
                    selected: _filter == r.id,
                    onTap: () => setState(() => _filter = r.id),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (searching) ...[
            Text(
              '${list.length} bài khớp “${_query.trim()}”',
              style: bodyStyle(13, color: AppColors.inkSoft),
            ),
            const SizedBox(height: 12),
          ],
          if (list.isEmpty)
            searching
                ? EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'Không có bài nào khớp “${_query.trim()}”',
                    message: 'Thử từ khóa khác hoặc chọn “Tất cả” tuyến.',
                  )
                : const EmptyState(
                    icon: Icons.forum_outlined,
                    title: 'Chưa có cảm nhận nào ở tuyến này.',
                  )
          else
            for (final r in list) ...[
              ReflectionCard(
                reflection: r,
                onEdit: store.isMyReflection(r.id)
                    ? () => showEditReflectionDialog(context, r)
                    : null,
                onToggleAnonymous: store.isMyReflection(r.id)
                    ? () => store.setReflectionAnonymous(r.id, !r.isAnonymous)
                    : null,
                onDelete: store.isMyReflection(r.id)
                    ? () => store.deleteReflection(r.id)
                    : null,
              ),
              const SizedBox(height: 12),
            ],
          if (store.isLoadingMoreCommunity)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
            )
          else if (store.hasMoreCommunity)
            Center(
              child: TextButton.icon(
                onPressed: store.loadMoreCommunity,
                icon: const Icon(Icons.expand_more_rounded),
                label: const Text('Tải thêm cảm nhận'),
              ),
            ),
        ],
      ),
    );
  }
}
