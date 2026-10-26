import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/cover_image.dart';
import '../../data/mock_albums.dart';
import '../../domain/album.dart';

/// The albums tab: the Personal / Share shelves, then a two-column grid of
/// album covers with the title burned into the bottom of each (album.jpg).
class ProfileAlbumsView extends StatefulWidget {
  const ProfileAlbumsView({super.key, required this.onOpen});

  final ValueChanged<Album> onOpen;

  @override
  State<ProfileAlbumsView> createState() => _ProfileAlbumsViewState();
}

class _ProfileAlbumsViewState extends State<ProfileAlbumsView> {
  AlbumShelf _shelf = AlbumShelf.personal;

  @override
  Widget build(BuildContext context) {
    final albums = albumsFor(_shelf);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ShelfTabs(
          active: _shelf,
          onSelected: (shelf) => setState(() => _shelf = shelf),
        ),
        const SizedBox(height: 14),
        if (albums.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(32, 32, 32, 48),
            child: Center(
              child: Text(
                'ยังไม่มีอัลบั้มในชั้นนี้',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.builder(
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: albums.length,
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                // The covers are a fixed shape here, unlike the trip walls:
                // every card prints one line of title over the image, so
                // nothing can grow taller than its neighbour.
                childAspectRatio: 0.92,
              ),
              itemBuilder: (context, index) => _AlbumCard(
                album: albums[index],
                onTap: () => widget.onOpen(albums[index]),
              ),
            ),
          ),
      ],
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
          for (final shelf in AlbumShelf.values)
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

  final Album album;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CoverImage(source: album.cover, fit: BoxFit.cover),
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
