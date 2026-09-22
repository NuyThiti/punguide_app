import 'package:flutter/material.dart';

import '../../../../core/api/models/trip_content.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/formatting/spot_detail_text.dart';
import '../../../../shared/widgets/cover_image.dart';
import '../../../../shared/widgets/full_image_viewer.dart';

/// A post's spots, as a reader sees them.
///
/// The mirror of the composer's spot cards (`PostSpotDetailRows`), minus every
/// editing affordance the design shows there — no "ใช้เป็นหน้าปก", no
/// "ย้ายรูป", no dashed add-chips, and no distance, because the reader is not
/// standing where the writer was.
class TripContentSections extends StatelessWidget {
  const TripContentSections({super.key, required this.sections});

  final List<TripContent> sections;

  /// Consecutive sections sharing a title are one spot.
  ///
  /// The assistant writes one section per photo, so a spot the writer added
  /// four pictures to comes back as four sections under the same heading.
  List<_ContentGroup> get _groups {
    final groups = <_ContentGroup>[];
    for (final section in sections) {
      if (section.title.isNotEmpty &&
          groups.isNotEmpty &&
          groups.last.title == section.title) {
        groups.last.sections.add(section);
      } else {
        groups.add(_ContentGroup(section.title, [section]));
      }
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groups;
    if (groups.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < groups.length; i++) ...[
          if (i > 0) const SizedBox(height: 28),
          _SpotGroup(group: groups[i], position: i + 1),
        ],
      ],
    );
  }
}

class _SpotGroup extends StatelessWidget {
  const _SpotGroup({required this.group, required this.position});

  final _ContentGroup group;
  final int position;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'จุด $position',
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (group.title.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            group.title,
            style: const TextStyle(
              color: AppColors.foreground,
              fontSize: 19,
              height: 1.25,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
        for (final section in group.sections) _SpotSection(section: section),
      ],
    );
  }
}

class _SpotSection extends StatelessWidget {
  const _SpotSection({required this.section});

  final TripContent section;

  @override
  Widget build(BuildContext context) {
    // A suggested pin is the assistant's guess and the server hides it from a
    // public read; only a place the writer confirmed is theirs to publish.
    final location = section.location;
    final pinned =
        location != null && location.status == ContentLocationStatus.confirmed;
    final placeName = pinned ? _placeLabel(location) : null;

    final time = spotTimeText(
      visitedAt: section.visitedAt,
      opensAt: section.opensAt,
      closesAt: section.closesAt,
    );
    final transport =
        transportText(section.transportModes, section.transportCost);
    final contact = section.contactInfo?.trim() ?? '';
    final hack = section.tripHack?.trim() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (placeName != null) ...[
          const SizedBox(height: 8),
          _PlaceRow(name: placeName),
        ],
        if (section.content.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            section.content,
            style: const TextStyle(
              color: AppColors.foreground,
              fontSize: 15,
              height: 1.6,
            ),
          ),
        ],
        for (final image in _images) ...[
          const SizedBox(height: 12),
          image,
        ],
        if (time.isNotEmpty ||
            transport.isNotEmpty ||
            contact.isNotEmpty) ...[
          const SizedBox(height: 12),
          // A Wrap rather than the composer's Row: a reader has the vertical
          // room the composer does not, so a long phone number drops to its
          // own line instead of ellipsising.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (time.isNotEmpty)
                _DetailChip(icon: Icons.schedule, text: time),
              if (transport.isNotEmpty)
                _DetailChip(
                  icon: Icons.directions_bus_filled_outlined,
                  text: transport,
                ),
              if (contact.isNotEmpty)
                _DetailChip(icon: Icons.call_outlined, text: contact),
            ],
          ),
        ],
        // Not a chip like the composer's: a hack is worth reading in full, and
        // a chip would ellipsise it away.
        if (hack.isNotEmpty) ...[
          const SizedBox(height: 12),
          _TripHackNote(text: hack),
        ],
      ],
    );
  }

  /// Photos, preferring uploaded media over the legacy URL-only sections.
  ///
  /// A photo that failed to load still holds its place in the list but is left
  /// out of the gallery, so tapping the third of four opens the third one the
  /// reader can actually see.
  List<Widget> get _images {
    final urls = section.mediaIds != null
        ? [
            for (final image in section.images)
              image.unavailable ? null : image.urls?.full,
          ]
        : [for (final url in section.imageUrls) url];

    final gallery = [for (final url in urls) if (url != null) url];

    var position = 0;
    return [
      for (final url in urls)
        _SpotPhoto(
          url: url,
          gallery: gallery,
          galleryIndex: url == null ? -1 : position++,
          total: gallery.length,
        ),
    ];
  }

  /// A confirmed pin carries a name almost always; coordinates are the last
  /// resort so a pin never renders as an empty row.
  static String? _placeLabel(ContentLocation location) {
    final name = location.name?.trim();
    if (name != null && name.isNotEmpty) return name;
    final id = location.placeId?.trim();
    if (id != null && id.isNotEmpty) return id;
    if (location.latitude != null && location.longitude != null) {
      return '${location.latitude}, ${location.longitude}';
    }
    return null;
  }
}

/// Where the spot is.
///
/// The name only — a stored [ContentLocation] has no address, so the street
/// line the composer shows comes from its live place search and is not
/// readable here.
class _PlaceRow extends StatelessWidget {
  const _PlaceRow({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.location_on_outlined,
          size: 16,
          color: AppColors.postPurple,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            name,
            style: const TextStyle(
              color: AppColors.foreground,
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// One photo in the list, cropped so the spots read evenly.
///
/// The crop is why it opens: tapping shows the whole picture at full size,
/// and swipes through the rest of the spot's photos from there.
class _SpotPhoto extends StatelessWidget {
  const _SpotPhoto({
    required this.url,
    required this.gallery,
    required this.galleryIndex,
    required this.total,
  });

  /// Null when the upload is gone — the server can outlive a photo.
  final String? url;

  /// Every loadable photo on this spot, in order.
  final List<String> gallery;

  /// This photo's place in [gallery], or -1 when it is not in it.
  final int galleryIndex;
  final int total;

  @override
  Widget build(BuildContext context) {
    final image = url;

    if (image == null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: const AspectRatio(
          aspectRatio: 1.6,
          child: ColoredBox(
            color: AppColors.line,
            child: Center(
              child: Text(
                'รูปนี้ไม่พร้อมใช้งาน',
                style: TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ),
          ),
        ),
      );
    }

    return Semantics(
      button: true,
      label: 'ดูรูปเต็ม',
      child: GestureDetector(
        onTap: () => showFullImages(
          context,
          urls: gallery,
          initialIndex: galleryIndex < 0 ? 0 : galleryIndex,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: 1.6,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CoverImage(source: image),
                // The cue that the crop is not all there is.
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: _PhotoBadge(
                    icon: Icons.fullscreen,
                    // Which of how many, so a spot with four photos says so
                    // without the reader having to open one to find out.
                    label: total > 1 ? '${galleryIndex + 1}/$total' : null,
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

/// The dark pill over a photo's corner.
class _PhotoBadge extends StatelessWidget {
  const _PhotoBadge({required this.icon, this.label});

  final IconData icon;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final text = label;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: text == null ? 6 : 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          if (text != null) ...[
            const SizedBox(width: 4),
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The same pill the composer fills in, without the tap target.
///
/// **The text wraps rather than ellipsising.** `contactInfo` is free text —
/// "นายบุญนันต์ หมัดเชี่ยว ชมรม… 084-xxx-xxxx" is a real value — and clipping
/// it would drop the phone number, which is the whole point of the row. A long
/// one turns the pill into a rounded block over two or three lines; the hours
/// and transport are short enough that they never reach the edge.
class _DetailChip extends StatelessWidget {
  const _DetailChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.postPurpleSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sits on the first line rather than the top of a block that may
          // now run to two or three of them.
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 13, color: AppColors.postPurple),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.postPurple,
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TripHackNote extends StatelessWidget {
  const _TripHackNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.postPurpleWell,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.info_outline,
                size: 14,
                color: AppColors.postPurple,
              ),
              const SizedBox(width: 5),
              Text(
                'Trip Hack',
                style: const TextStyle(
                  color: AppColors.postPurple,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            text,
            style: const TextStyle(
              color: AppColors.foreground,
              fontSize: 13.5,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContentGroup {
  _ContentGroup(this.title, this.sections);

  final String title;
  final List<TripContent> sections;
}
