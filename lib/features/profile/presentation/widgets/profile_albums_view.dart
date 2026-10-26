import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/pluno_api.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/cover_image.dart';
import '../../domain/album.dart';
import '../providers/profile_providers.dart';

/// The albums tab: the Personal / Share shelves, then a two-column grid of
/// covers with the title burned into the bottom of each (album.jpg).
class ProfileAlbumsView extends ConsumerStatefulWidget {
  const ProfileAlbumsView({super.key, required this.onOpen});

  final ValueChanged<TripListItem> onOpen;

  @override
  ConsumerState<ProfileAlbumsView> createState() => _ProfileAlbumsViewState();
}

class _ProfileAlbumsViewState extends ConsumerState<ProfileAlbumsView> {
  AlbumShelf _shelf = AlbumShelf.personal;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ShelfTabs(
          active: _shelf,
          onSelected: (shelf) => setState(() => _shelf = shelf),
        ),
        const SizedBox(height: 14),
        _PersonalShelf(onOpen: widget.onOpen),
      ],
    );
  }
}

class _PersonalShelf extends ConsumerWidget {
  const _PersonalShelf({required this.onOpen});

  final ValueChanged<TripListItem> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albums = ref.watch(myAlbumsProvider);
    final rows = albums.valueOrNull;

    // A page in flight keeps the grid on screen underneath it, so loading
    // more never blanks what is already there.
    if (rows == null) {
      if (albums.hasError) {
        return _AlbumsNotice(
          message: 'โหลดอัลบั้มไม่สำเร็จ',
          actionLabel: 'ลองอีกครั้ง',
          onAction: () => ref.read(myAlbumsProvider.notifier).refresh(),
        );
      }
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (rows.isEmpty) {
      return const _AlbumsNotice(message: 'ยังไม่มีอัลบั้มของคุณ');
    }

    final notifier = ref.read(myAlbumsProvider.notifier);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          GridView.builder(
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: rows.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              // Fixed shape, unlike the trip walls: every card prints one
              // line of title over the image, so none can outgrow its row.
              childAspectRatio: 0.92,
            ),
            itemBuilder: (context, index) => _AlbumCard(
              album: rows[index],
              onTap: () => onOpen(rows[index]),
            ),
          ),
          if (notifier.hasMore) ...[
            const SizedBox(height: 4),
            TextButton(
              onPressed: albums.isLoading ? null : notifier.loadMore,
              child: Text(albums.isLoading ? 'กำลังโหลด…' : 'โหลดเพิ่ม'),
            ),
          ],
        ],
      ),
    );
  }
}

class _ShelfTabs extends StatelessWidget {
  const _ShelfTabs({required this.active, required this.onSelected});

  final AlbumShelf active;
  final ValueChanged<AlbumShelf> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (final shelf in visibleAlbumShelves)
            Padding(
              padding: const EdgeInsets.only(right: 24),
              child: GestureDetector(
                onTap: () => onSelected(shelf),
                behavior: HitTestBehavior.opaque,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      shelf.label,
                      style: TextStyle(
                        color: shelf == active
                            ? AppColors.foreground
                            : AppColors.navIconMuted,
                        fontSize: 15,
                        fontWeight: shelf == active
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Laid out either way so selecting never shifts the row.
                    Container(
                      height: 2,
                      width: 56,
                      color: shelf == active
                          ? AppColors.foreground
                          : Colors.transparent,
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

class _AlbumCard extends StatelessWidget {
  const _AlbumCard({required this.album, required this.onTap});

  final TripListItem album;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Documented as sometimes absent, so the card draws a well rather than a
    // broken box.
    final thumbnail = album.coverImage?.urls.thumbnail;

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (thumbnail == null)
              const ColoredBox(
                color: AppColors.optionIconBg,
                child: Center(
                  child: Icon(
                    Icons.photo_outlined,
                    size: 28,
                    color: AppColors.navIconMuted,
                  ),
                ),
              )
            else
              CoverImage(source: thumbnail, fit: BoxFit.cover),
            // The title sits on the photo, so it carries its own scrim
            // rather than trusting the image to be dark down there.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0),
                      Colors.black.withValues(alpha: 0.72),
                    ],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 22, 10, 10),
                  child: Text(
                    album.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlbumsNotice extends StatelessWidget {
  const _AlbumsNotice({
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 32, 32, 48),
      child: Column(
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
        ],
      ),
    );
  }
}
