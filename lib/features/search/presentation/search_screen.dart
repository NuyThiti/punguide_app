import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/pluno_api.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_bottom_nav.dart';
import '../../../shared/widgets/app_frame.dart';
import '../../../shared/widgets/create_sheet.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../home/presentation/providers/home_feed_providers.dart';
import '../../home/presentation/widgets/destination_card.dart';
import '../../home/presentation/widgets/home_filter_bar.dart';
import '../../home/presentation/widgets/pun_guide_grid.dart';
import 'providers/search_providers.dart';

/// Search over the public trip feed.
///
/// Two faces of one screen: with an empty field it is a browse page — recent
/// queries, popular destinations, what is trending — and as soon as anything
/// is typed it becomes the result wall. Matching is local (see
/// [searchResultsProvider]), so results land on the keystroke.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.initialQuery});

  /// Prefill from a tapped destination, via `/search?q=`.
  final String? initialQuery;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final TextEditingController _controller;

  /// The live query. Local rather than a provider: it changes on every
  /// keystroke, only this screen reads it, and Riverpod forbids seeding a
  /// provider from [initState], which is where a `?q=` arrives.
  late String _query;

  @override
  void initState() {
    super.initState();

    _query = widget.initialQuery?.trim() ?? '';
    _controller = TextEditingController(text: _query);

    if (_query.isNotEmpty) {
      // A provider write has to wait for the tree to finish building.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(recentSearchesProvider.notifier).record(_query);
      });
    }
  }

  @override
  void didUpdateWidget(SearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Tapping a second destination reuses this route — go_router keys a page
    // by its GoRoute, not by its query string — so the new `q` arrives as a
    // widget update rather than a fresh State. Deferred a frame: recording a
    // recent search mid-build would rebuild widgets that are already laid out.
    final next = widget.initialQuery?.trim();
    if (next == null ||
        next.isEmpty ||
        next == oldWidget.initialQuery?.trim()) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _applyQuery(next);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim();
    final results = ref.watch(searchResultsProvider(query));

    return AppFrame(
      background: AppColors.screen,
      child: Stack(
        children: [
          Column(
            children: [
              _SearchHeader(
                controller: _controller,
                onChanged: (value) => setState(() => _query = value),
                onSubmitted: (value) =>
                    ref.read(recentSearchesProvider.notifier).record(value),
                onClear: _clear,
                onBack: _close,
              ),
              // Pinned under the field: scrolling the wall of results must
              // not take the sort control off screen with it.
              if (query.isNotEmpty &&
                  (results.valueOrNull?.isNotEmpty ?? false))
                _SortRow(
                  selected: ref.watch(searchSortProvider),
                  onSelected: (option) =>
                      ref.read(searchSortProvider.notifier).state = option,
                ),
              Expanded(
                child: results.when(
                  data: (trips) => query.isEmpty
                      ? _buildBrowse()
                      : _buildResults(query, trips),
                  loading: () => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  error: (error, _) => _SearchErrorState(
                    error: error,
                    onRetry: () =>
                        ref.read(homeFeedProvider.notifier).refresh(),
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            // Search is reached from a tab rather than being one, so no item
            // lights up — `active` matches nothing on purpose.
            child: AppBottomNav(
              active: AppRoute.search,
              onTap: (route) => context.goNamed(route.name),
              onCreate: () => openCreateSheet(
                context,
                onOwnPlan: () => context.goNamed(AppRoute.createTrip.name),
                onPost: () => context.goNamed(AppRoute.createPost.name),
                onUnavailable: (message) => ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(message))),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The empty-field face: recent queries, destinations, trending trips.
  Widget _buildBrowse() {
    final recents = ref.watch(recentSearchesProvider);
    final destinations = ref.watch(topDestinationsProvider);
    final trending = ref.watch(trendingTripsProvider);

    return ListView(
      padding: EdgeInsets.only(bottom: AppBottomNav.heightOf(context) + 16),
      physics: const BouncingScrollPhysics(),
      children: [
        if (recents.isNotEmpty) ...[
          const SizedBox(height: 6),
          _SectionHeading(
            title: 'ค้นหาล่าสุด',
            action: 'ล้างทั้งหมด',
            onAction: () => ref.read(recentSearchesProvider.notifier).clear(),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final recent in recents)
                  _RecentChip(
                    label: recent,
                    onTap: () => _applyQuery(recent),
                    onRemove: () => ref
                        .read(recentSearchesProvider.notifier)
                        .remove(recent),
                  ),
              ],
            ),
          ),
        ],
        if (destinations.isNotEmpty) ...[
          const SizedBox(height: 22),
          const _SectionHeading(title: 'จุดหมายยอดนิยม'),
          const SizedBox(height: 12),
          SizedBox(
            height: DestinationCard.height,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: destinations.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final destination = destinations[index];
                return DestinationCard(
                  destination: destination,
                  onTap: () => _applyQuery(destination.name),
                );
              },
            ),
          ),
        ],
        if (trending.isNotEmpty) ...[
          const SizedBox(height: 24),
          const _SectionHeading(title: 'กำลังมาแรง'),
          const SizedBox(height: 12),
          PunGuideGrid(
            trips: trending,
            onOpen: _openTrip,
            onSave: _toggleSaved,
          ),
        ],
        if (recents.isEmpty && destinations.isEmpty && trending.isEmpty)
          const _SearchEmptyState(
            title: 'ยังไม่มีทริปให้ค้นหา',
            subtitle: 'กลับมาใหม่เมื่อมีคนปันไกด์ทริปแรก',
          ),
      ],
    );
  }

  /// The typing face: a count and the result wall. The sort chips are pinned
  /// above this by [build], so they are deliberately absent here.
  Widget _buildResults(String query, List<TripListItem> trips) {
    return ListView(
      padding: EdgeInsets.only(bottom: AppBottomNav.heightOf(context) + 16),
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      children: [
        if (trips.isEmpty)
          _SearchEmptyState(
            title: 'ไม่พบทริปสำหรับ "$query"',
            subtitle: 'ลองค้นด้วยชื่อเมือง ประเทศ หรือชื่อผู้ปันไกด์',
          )
        else ...[
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'พบ ${trips.length} ทริป',
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),
          PunGuideGrid(
            trips: trips,
            onOpen: _openTrip,
            onSave: _toggleSaved,
          ),
        ],
      ],
    );
  }

  void _applyQuery(String query) {
    _controller.text = query;
    _controller.selection =
        TextSelection.collapsed(offset: _controller.text.length);
    setState(() => _query = query);
    ref.read(recentSearchesProvider.notifier).record(query);
  }

  void _clear() {
    _controller.clear();
    setState(() => _query = '');
  }

  void _close() {
    if (Navigator.of(context).canPop()) {
      context.pop();
      return;
    }

    context.goNamed(AppRoute.home.name);
  }

  void _openTrip(TripListItem trip) {
    // The query that led here is worth keeping, but only once it has paid off.
    ref.read(recentSearchesProvider.notifier).record(_query);
    context.goNamed(AppRoute.tripDetail.name, params: {'tripId': trip.id});
  }

  Future<void> _toggleSaved(TripListItem trip) async {
    // Results are rows of the shared feed, so the flip shows up here and on
    // Home at once. Saving is the one thing here that needs an account.
    if (!ref.read(isSignedInProvider)) {
      _promptSignIn();
      return;
    }

    try {
      await ref.read(homeFeedProvider.notifier).toggleSaved(trip.id);
    } on ApiException catch (failure) {
      if (!mounted) return;
      if (failure.isUnauthorized) {
        _promptSignIn();
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            failure.isNetworkFailure
                ? 'เชื่อมต่อไม่ได้ ลองใหม่อีกครั้ง'
                : 'บันทึกทริปไม่สำเร็จ: ${failure.message}',
          ),
        ),
      );
    }
  }

  void _promptSignIn() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('เข้าสู่ระบบก่อนเพื่อบันทึกทริป'),
        action: SnackBarAction(
          label: 'เข้าสู่ระบบ',
          onPressed: () => context.goNamed(AppRoute.login.name),
        ),
      ),
    );
  }
}

/// Back arrow plus the pill-shaped field, on the same row as Home's own
/// search button so the two screens line up when one replaces the other.
class _SearchHeader extends StatelessWidget {
  const _SearchHeader({
    required this.controller,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
    required this.onBack,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;

    return Padding(
      padding: EdgeInsets.fromLTRB(12, topInset + 10, 16, 10),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back),
            color: AppColors.foreground,
            iconSize: 22,
            tooltip: 'ย้อนกลับ',
          ),
          Expanded(
            child: Container(
              height: 44,
              padding: const EdgeInsets.only(left: 14, right: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: AppColors.chipBorder),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.search,
                    size: 19,
                    color: AppColors.navIconMuted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      autofocus: true,
                      textInputAction: TextInputAction.search,
                      onChanged: onChanged,
                      onSubmitted: onSubmitted,
                      style: const TextStyle(
                        color: AppColors.foreground,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: 'ค้นหาเมือง ประเทศ หรือชื่อทริป',
                        hintStyle: TextStyle(
                          color: AppColors.muted,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  // Rebuilds on every keystroke without rebuilding the screen,
                  // so the X appears the moment there is something to clear.
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: controller,
                    builder: (context, value, _) => value.text.isEmpty
                        ? const SizedBox(width: 8)
                        : GestureDetector(
                            onTap: onClear,
                            behavior: HitTestBehavior.opaque,
                            child: const Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(
                                Icons.close,
                                size: 18,
                                color: AppColors.muted,
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Section heading with an optional trailing text action.
///
/// [HomeSectionHeader] always carries the ดูทั้งหมด link; here most sections
/// have nothing to link to.
class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.foreground,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              behavior: HitTestBehavior.opaque,
              child: Text(
                action!,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RecentChip extends StatelessWidget {
  const _RecentChip({
    required this.label,
    required this.onTap,
    required this.onRemove,
  });

  final String label;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 34,
        padding: const EdgeInsets.only(left: 12, right: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: AppColors.chipBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.history, size: 15, color: AppColors.muted),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 180),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.foreground,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            GestureDetector(
              onTap: onRemove,
              behavior: HitTestBehavior.opaque,
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(Icons.close, size: 14, color: AppColors.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The sort chips, pinned under the search field.
///
/// Carries its own background and hairline so results scrolling underneath
/// stay behind it rather than showing through.
class _SortRow extends StatelessWidget {
  const _SortRow({required this.selected, required this.onSelected});

  final SearchSort selected;
  final ValueChanged<SearchSort> onSelected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.screen,
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: SizedBox(
        height: 48,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: SearchSort.values.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final option = SearchSort.values[index];
            return _SortChip(
              label: option.label,
              selected: option == selected,
              onTap: () => onSelected(option),
            );
          },
        ),
      ),
    );
  }
}

/// Same pill as the Home category chips, filled when active so the sort in
/// force is readable at a glance next to the result count.
class _SortChip extends StatelessWidget {
  const _SortChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.chipBorderActive : Colors.white,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color:
                  selected ? AppColors.chipBorderActive : AppColors.chipBorder,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.muted,
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchEmptyState extends StatelessWidget {
  const _SearchEmptyState({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 56, 24, 40),
      child: Column(
        children: [
          // A glyph rather than an emoji: the app ships no emoji font, so a 🔍
          // renders as a tofu box on an iOS device.
          const Icon(Icons.search_off, size: 38, color: AppColors.muted),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _SearchErrorState extends StatelessWidget {
  const _SearchErrorState({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final failure = error is ApiException ? error as ApiException : null;
    final message = failure == null
        ? 'ค้นหาไม่สำเร็จ'
        : failure.isNetworkFailure
            ? 'เชื่อมต่อเซิร์ฟเวอร์ไม่ได้'
            : 'ค้นหาไม่สำเร็จ (${failure.statusCode})';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off, size: 34, color: AppColors.muted),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          OutlinedButton(onPressed: onRetry, child: const Text('ลองใหม่')),
        ],
      ),
    );
  }
}
