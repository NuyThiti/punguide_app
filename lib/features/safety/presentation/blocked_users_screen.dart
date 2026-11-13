import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_providers.dart';
import '../../../core/api/pluno_api.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_frame.dart';
import '../../../shared/widgets/cover_image.dart';
import '../../../shared/widgets/dark_sheet_header.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../profile/presentation/profile_screen.dart' show profileCoverImage;
import 'safety_actions.dart';

/// ผู้ใช้ที่ถูกบล็อก at `/profile/blocked` — reached from จัดการบัญชี.
///
/// `GET /users/me/blocks`, newest block first, a page of [pageSize] at a time
/// until `total`. Each row has เลิกบล็อก, which takes it off the list and the
/// total at once.
class BlockedUsersScreen extends ConsumerStatefulWidget {
  const BlockedUsersScreen({super.key});

  static const pageSize = 20;

  @override
  ConsumerState<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends ConsumerState<BlockedUsersScreen> {
  final _scroll = ScrollController();
  final _rows = <BlockedUser>[];
  int _total = 0;

  /// What the server has handed out so far — the next page's offset. Not
  /// `_rows.length`: an unblock takes a row out without moving the window.
  int _fetched = 0;
  bool _loading = true;
  bool _loadingMore = false;
  Object? _error;

  bool get _hasMore => _fetched < _total;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_maybeLoadMore);
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (ref.read(authSessionProvider) == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = await ref.read(plunoApiProvider.future);
      final page = await api.safety.blocked(limit: BlockedUsersScreen.pageSize);
      if (!mounted) return;
      setState(() {
        _rows
          ..clear()
          ..addAll(page.items);
        _total = page.total;
        _fetched = page.items.length;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  void _maybeLoadMore() {
    if (!_hasMore || _loadingMore || !_scroll.hasClients) return;
    if (_scroll.position.extentAfter > 300) return;
    _loadMore();
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    try {
      final api = await ref.read(plunoApiProvider.future);
      final page = await api.safety.blocked(
        limit: BlockedUsersScreen.pageSize,
        offset: _fetched,
      );
      if (!mounted) return;
      final seen = {for (final row in _rows) row.id};
      setState(() {
        _rows.addAll(page.items.where((row) => !seen.contains(row.id)));
        _total = page.total;
        _fetched += page.items.length;
        // A short page ends it whatever the total said.
        if (page.items.isEmpty) _fetched = _total;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _unblock(BlockedUser user) async {
    final label = userHandle(username: user.username, name: user.name);
    final done = await unblockUser(
      context,
      ref,
      userId: user.id,
      label: label.isEmpty ? 'ผู้ใช้นี้' : label,
    );
    if (!done || !mounted) return;
    setState(() {
      _rows.removeWhere((row) => row.id == user.id);
      _total = (_total - 1).clamp(0, 1 << 30);
      _fetched = (_fetched - 1).clamp(0, 1 << 30);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppFrame(
      background: AppColors.screen,
      child: Column(
        children: [
          DarkSheetHeader(
            title: 'ผู้ใช้ที่ถูกบล็อก',
            coverImage: profileCoverImage,
            onBack: () => context.canPop()
                ? context.pop()
                : context.goNamed(AppRoute.profileAccount.name),
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (ref.watch(authSessionProvider) == null) {
      return const _Notice(
        icon: Icons.lock_outline,
        message: 'เข้าสู่ระบบเพื่อจัดการผู้ใช้ที่ถูกบล็อก',
      );
    }
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return _Notice(
        icon: Icons.cloud_off,
        message: 'โหลดรายชื่อไม่สำเร็จ',
        actionLabel: 'ลองอีกครั้ง',
        onAction: _load,
      );
    }
    if (_rows.isEmpty) {
      return const _Notice(
        icon: Icons.block,
        message: 'คุณยังไม่ได้บล็อกใคร',
      );
    }
    return RefreshIndicator(
      color: AppColors.loading,
      onRefresh: _load,
      child: ListView.separated(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          MediaQuery.of(context).padding.bottom + 24,
        ),
        itemCount: _rows.length + (_hasMore ? 1 : 0),
        separatorBuilder: (_, __) =>
            const Divider(height: 1, color: AppColors.line),
        itemBuilder: (context, index) {
          if (index == _rows.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }
          final user = _rows[index];
          return _BlockedRow(user: user, onUnblock: () => _unblock(user));
        },
      ),
    );
  }
}

class _BlockedRow extends StatelessWidget {
  const _BlockedRow({required this.user, required this.onUnblock});

  final BlockedUser user;
  final VoidCallback onUnblock;

  @override
  Widget build(BuildContext context) {
    final avatar = user.avatarUrl;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            clipBehavior: Clip.antiAlias,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.optionIconBg,
            ),
            child: avatar != null && avatar.isNotEmpty
                ? CoverImage(source: avatar, fit: BoxFit.cover)
                : const Icon(Icons.person, color: AppColors.navIconMuted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.foreground,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (user.username.isNotEmpty)
                  Text(
                    '@${user.username}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12.5,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton(
            onPressed: onUnblock,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.foreground,
              side: const BorderSide(color: AppColors.line, width: 1.4),
              minimumSize: const Size(92, 34),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              shape: const StadiumBorder(),
            ),
            child: const Text(
              'เลิกบล็อก',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 34, color: AppColors.navIconMuted),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (actionLabel case final label?) ...[
              const SizedBox(height: 10),
              TextButton(onPressed: onAction, child: Text(label)),
            ],
          ],
        ),
      ),
    );
  }
}
