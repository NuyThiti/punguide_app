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

/// One photo of an album, at both the sizes the page needs.
typedef AlbumPhoto = ({String thumbnail, String full});

/// Every photo filed under a post, in the order the server sent them.
///
/// A section carries its pictures twice over: [TripContent.images] are the
/// ones the server resolved, and [TripContent.imageUrls] are the raw links a
/// draft was written with. The resolved list wins where it exists — the model
/// says to display those and never the gallery order — and the raw links only
/// stand in for a section the server has not resolved yet.
List<AlbumPhoto> albumPhotos(ApiTrip trip) {
  final photos = <AlbumPhoto>[];
  final seen = <String>{};

  void add(String thumbnail, String full) {
    if (seen.add(full)) photos.add((thumbnail: thumbnail, full: full));
  }

  for (final section in trip.contents) {
    final resolved = section.images.where((image) => !image.unavailable);
    if (resolved.isNotEmpty) {
      for (final image in resolved) {
        final urls = image.urls;
        if (urls == null) continue;
        add(urls.thumbnail, urls.large);
      }
      continue;
    }
    for (final url in section.imageUrls) {
      add(url, url);
    }
  }

  return List<AlbumPhoto>.unmodifiable(photos);
}

/// An album opened from the profile's อัลบั้ม tab.
///
/// An album *is* a post, so this reads the same `GET /trips/:id` the post page
/// does — the cover and title off the trip, the grid out of its sections.
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
        data: (trip) => _AlbumBody(trip: trip, photos: albumPhotos(trip)),
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
  const _AlbumBody({required this.trip, required this.photos});

  final ApiTrip trip;
  final List<AlbumPhoto> photos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avatar = ref.watch(authSessionProvider)?.avatarImage;

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
                  photoCount: photos.length,
                  avatar: avatar,
                  onBack: () => AlbumDetailScreen._close(context),
                  onMore: () => unavailable('ตัวเลือกอัลบั้มยังไม่เปิดใช้งาน'),
                  onSelect: () => unavailable('เลือกรูปยังไม่เปิดใช้งาน'),
                ),
              ),
              if (photos.isEmpty)
                const SliverToBoxAdapter(
                  child: _AlbumMessage(message: 'อัลบั้มนี้ยังไม่มีรูป'),
                )
              else
                SliverGrid(
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 3,
                    mainAxisSpacing: 3,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _PhotoTile(
                      photo: photos[index],
                      onTap: () => showFullImages(
                        context,
                        urls: [for (final photo in photos) photo.full],
                        initialIndex: index,
                      ),
                    ),
                    childCount: photos.length,
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

  final AlbumPhoto photo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: CoverImage(source: photo.thumbnail, fit: BoxFit.cover),
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
