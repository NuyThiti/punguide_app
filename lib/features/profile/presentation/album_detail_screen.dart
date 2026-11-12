import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/pluno_api.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_frame.dart';
import '../../../shared/widgets/cover_image.dart';
import '../../../shared/widgets/full_image_viewer.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../trips/presentation/itinerary_display.dart' show dayMonthYear;
import '../../trips/presentation/providers/trip_providers.dart';
import 'providers/profile_providers.dart';

/// An album opened from the profile's อัลบั้ม tab.
///
/// The trip gives the cover, the title and the date; the pictures come from
/// the trip's **gallery**, not from `contents` — see [albumGalleryProvider]
/// for why that distinction matters.
class AlbumDetailScreen extends ConsumerWidget {
  const AlbumDetailScreen({super.key, required this.albumId});

  final String albumId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final album = ref.watch(apiTripProvider(albumId));

    return AppFrame(
      background: AppColors.screen,
      child: album.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _AlbumMessage(
          message: 'เปิดอัลบั้มไม่สำเร็จ',
          actionLabel: 'ลองอีกครั้ง',
          onAction: () => ref.invalidate(apiTripProvider(albumId)),
          onBack: () => _close(context),
        ),
        data: (trip) => _AlbumBody(trip: trip),
      ),
    );
  }

  static void _close(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.goNamed(AppRoute.profile.name);
    }
  }
}

class _AlbumBody extends ConsumerWidget {
  const _AlbumBody({required this.trip});

  final ApiTrip trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avatar = ref.watch(authSessionProvider)?.avatarImage;
    final gallery = ref.watch(albumGalleryProvider(trip.id));
    final notifier = ref.read(albumGalleryProvider(trip.id).notifier);
    final photos = gallery.valueOrNull ?? const <GalleryImage>[];

    // The server's own count, so the header is right even while only the
    // first page is on screen. The trip's summary stands in until then.
    final count =
        gallery.hasValue ? notifier.total : trip.mediaSummary.totalImages;

    void unavailable(String message) => ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));

    return Column(
      children: [
        Expanded(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _AlbumHeader(
                  trip: trip,
                  photoCount: count,
                  avatar: avatar,
                  onBack: () => AlbumDetailScreen._close(context),
                  onMore: () => unavailable('ตัวเลือกอัลบั้มยังไม่เปิดใช้งาน'),
                  onSelect: () => unavailable('เลือกรูปยังไม่เปิดใช้งาน'),
                ),
              ),
              if (gallery.isLoading && photos.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                )
              else if (gallery.hasError && photos.isEmpty)
                SliverToBoxAdapter(
                  child: _AlbumMessage(
                    message: 'โหลดรูปไม่สำเร็จ',
                    actionLabel: 'ลองอีกครั้ง',
                    onAction: notifier.refresh,
                  ),
                )
              else if (photos.isEmpty)
                const SliverToBoxAdapter(
                  child: _AlbumMessage(message: 'อัลบั้มนี้ยังไม่มีรูป'),
                )
              else
                SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 3,
                    mainAxisSpacing: 3,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _PhotoTile(
                      photo: photos[index],
                      onTap: () => showFullImages(
                        context,
                        urls: [for (final photo in photos) photo.urls.large],
                        initialIndex: index,
                      ),
                    ),
                    childCount: photos.length,
                  ),
                ),
              if (photos.isNotEmpty && notifier.hasMore)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Center(
                      child: TextButton(
                        onPressed: gallery.isLoading ? null : notifier.loadMore,
                        child: Text(
                          gallery.isLoading ? 'กำลังโหลด…' : 'โหลดรูปเพิ่ม',
                        ),
                      ),
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
            ],
          ),
        ),
        _ShareAlbumBar(
          onShare: () => unavailable('แชร์อัลบั้มยังไม่เปิดใช้งาน'),
        ),
      ],
    );
  }
}

class _AlbumHeader extends StatelessWidget {
  const _AlbumHeader({
    required this.trip,
    required this.photoCount,
    required this.avatar,
    required this.onBack,
    required this.onMore,
    required this.onSelect,
  });

  final ApiTrip trip;
  final int photoCount;
  final String? avatar;
  final VoidCallback onBack;
  final VoidCallback onMore;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final cover = trip.coverImage?.urls.large;

    return SizedBox(
      height: 320,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (cover == null)
            const ColoredBox(color: AppColors.optionIconBg)
          else
            CoverImage(source: cover, fit: BoxFit.cover),
          // Two scrims: the top one carries the buttons, the bottom one the
          // title, so neither depends on how bright the photo happens to be.
          const _HeaderScrim(
            alignment: Alignment.topCenter,
            extent: 0.35,
            strength: 0.55,
          ),
          // Heavier than the top one: the title is white and a cover can be
          // as bright as a plate of toast under a flash.
          const _HeaderScrim(
            alignment: Alignment.bottomCenter,
            extent: 0.62,
            strength: 0.82,
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              MediaQuery.of(context).padding.top + 10,
              16,
              18,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _RoundButton(
                      icon: Icons.chevron_left,
                      tooltip: 'ย้อนกลับ',
                      onTap: onBack,
                    ),
                    const Spacer(),
                    _RoundButton(
                      icon: Icons.more_vert,
                      tooltip: 'ตัวเลือก',
                      onTap: onMore,
                    ),
                    const SizedBox(width: 10),
                    _SelectButton(onTap: onSelect),
                  ],
                ),
                const Spacer(),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            trip.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              height: 1.2,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${dayMonthYear(trip.createdAt)} • $photoCount รูป',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.82),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // The design stacks everyone who can see the album. There
                    // is no collaborator API, so this is the one face we can
                    // name: the traveller whose album it is.
                    if (avatar != null && avatar!.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      Container(
                        width: 38,
                        height: 38,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: CoverImage(source: avatar!, fit: BoxFit.cover),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.photo, required this.onTap});

  final GalleryImage photo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: CoverImage(source: photo.urls.thumbnail, fit: BoxFit.cover),
    );
  }
}

class _ShareAlbumBar extends StatelessWidget {
  const _ShareAlbumBar({required this.onShare});

  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      child: Material(
        color: AppColors.createHeroStart,
        borderRadius: BorderRadius.circular(99),
        child: InkWell(
          onTap: onShare,
          borderRadius: BorderRadius.circular(99),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.share_outlined, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Text(
                  'Share Album',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.foreground, size: 24),
        ),
      ),
    );
  }
}

class _SelectButton extends StatelessWidget {
  const _SelectButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(99),
        ),
        child: const Text(
          'Select',
          style: TextStyle(
            color: AppColors.foreground,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _HeaderScrim extends StatelessWidget {
  const _HeaderScrim({
    required this.alignment,
    required this.extent,
    required this.strength,
  });

  final Alignment alignment;
  final double extent;
  final double strength;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: FractionallySizedBox(
        heightFactor: extent,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: alignment,
              end: alignment == Alignment.topCenter
                  ? Alignment.bottomCenter
                  : Alignment.topCenter,
              colors: [
                Colors.black.withValues(alpha: strength),
                Colors.black.withValues(alpha: 0),
              ],
            ),
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _AlbumMessage extends StatelessWidget {
  const _AlbumMessage({
    required this.message,
    this.actionLabel,
    this.onAction,
    this.onBack,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 64, 32, 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: 8),
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
          if (onBack != null)
            TextButton(onPressed: onBack, child: const Text('ย้อนกลับ')),
        ],
      ),
    );
  }
}
