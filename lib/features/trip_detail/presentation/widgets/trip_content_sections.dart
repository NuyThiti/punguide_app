import 'package:flutter/material.dart';

import '../../../../core/api/models/trip_content.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/formatting/spot_detail_text.dart';
import '../../../../shared/widgets/cover_image.dart';
import '../../../../shared/widgets/full_image_viewer.dart';

/// A post's spots, as a reader sees them.
///
/// Built 2026-09-24 from Figma `2183-21784` ("case มีหัวข้อ"). Its sibling
/// frame, "case ไม่มีหัวข้อ", is the same page with the headings absent — which
/// is what a section with an empty title produces here.
///
/// The mirror of the composer's spot cards, minus every editing affordance:
/// no "ใช้เป็นหน้าปก", no "ย้ายรูป", no dashed add-chips, and no distance,
/// because the reader is not standing where the writer was.
class TripContentSections extends StatelessWidget {
  const TripContentSections({
    super.key,
    required this.sections,
    required this.gutter,
  });

  final List<TripContent> sections;

  /// The page's side margin. Headings and a card's text keep it; the photos
  /// deliberately break out of it and run to the screen's edge.
  final double gutter;

  /// Consecutive sections sharing a title are one heading's worth.
  ///
  /// The assistant writes one section per photo, so a spot the writer added
  /// four pictures to comes back as four sections under the same heading —
  /// each its own card, all inside the one collapsible group.
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
        // Keyed by position as well as title: "case ไม่มีหัวข้อ" gives every
        // group the same empty title, and duplicate keys in one Column throw.
        for (var i = 0; i < groups.length; i++)
          _SpotGroup(
            key: ValueKey('$i:${groups[i].title}'),
            group: groups[i],
            gutter: gutter,
          ),
      ],
    );
  }
}

/// One heading and the cards under it.
///
/// The heading collapses the group. A group with no title — "case ไม่มีหัวข้อ"
/// — has nothing to tap, so its cards are always open.
class _SpotGroup extends StatefulWidget {
  const _SpotGroup({
    super.key,
    required this.group,
    required this.gutter,
  });

  final _ContentGroup group;
  final double gutter;

  @override
  State<_SpotGroup> createState() => _SpotGroupState();
}

class _SpotGroupState extends State<_SpotGroup> {
  bool _open = true;

  @override
  Widget build(BuildContext context) {
    final titled = widget.group.title.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (titled) ...[
          const SizedBox(height: 20),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: widget.gutter),
            child: _GroupHeading(
              title: widget.group.title,
              open: _open,
              onTap: () => setState(() => _open = !_open),
            ),
          ),
        ],
        if (!titled || _open)
          for (final section in widget.group.sections) ...[
            const SizedBox(height: 16),
            _SpotCard(section: section, gutter: widget.gutter),
          ],
      ],
    );
  }
}

class _GroupHeading extends StatelessWidget {
  const _GroupHeading({
    required this.title,
    required this.open,
    required this.onTap,
  });

  final String title;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.postPurple,
                    fontSize: 18,
                    height: 1.3,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.postPurpleWell,
                ),
                child: Icon(
                  open ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  size: 18,
                  color: AppColors.postPurple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: AppColors.line),
        ],
      ),
    );
  }
}

/// One spot: its photos, what it is called, where, the story, and the notes
/// beside it.
class _SpotCard extends StatelessWidget {
  const _SpotCard({required this.section, required this.gutter});

  final TripContent section;
  final double gutter;

  @override
  Widget build(BuildContext context) {
    // A suggested pin is the assistant's guess and the server hides it from a
    // public read; only a place the writer confirmed is theirs to publish.
    final location = section.location;
    final place = location != null &&
            location.status == ContentLocationStatus.confirmed
        ? _placeLabel(location)
        : null;

    final time = _timeLine;
    final transport =
        transportText(section.transportModes, section.transportCost);
    final contact = section.contactInfo?.trim() ?? '';
    final hack = section.tripHack?.trim() ?? '';
    final photos = _photos;

    return ColoredBox(
      color: AppColors.screen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (photos.isNotEmpty) _SpotCarousel(photos: photos),
          Padding(
            padding: EdgeInsets.fromLTRB(gutter, 14, gutter, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // The place, not the title. The design's purple heading is the
                // category ("ร้านอาหารที่ต้องแวะ") and the card's name is the
                // spot itself ("On Lok Yun") — printing `title` here as well
                // would say the same thing twice under its own heading.
                if (place != null)
                  Text(
                    place,
                    style: const TextStyle(
                      color: AppColors.foreground,
                      fontSize: 18,
                      height: 1.25,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                // Nothing to put under it: a stored `ContentLocation` has no
                // address, so the design's purple street line has no field
                // behind it. The place name is the whole of what is known.
                if (section.content.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    section.content,
                    style: const TextStyle(
                      color: Color(0xFF3F4642),
                      fontSize: 14,
                      height: 1.55,
                    ),
                  ),
                ],
                if (time.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _InfoRow(icon: Icons.schedule, text: time),
                ],
                if (transport.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _InfoRow(
                    icon: Icons.directions_bus_filled_outlined,
                    text: transport,
                  ),
                ],
                // Not in the Figma frame, which shows no contact row at all —
                // kept because the writer's own `contactInfo` would otherwise
                // be collected and never read back.
                if (contact.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _InfoRow(icon: Icons.call_outlined, text: contact),
                ],
                if (hack.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _TripHackRow(text: hack),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// "ไปตอน 06.00 น. | เปิด/ปิด 06.00 - 14.30 น."
  ///
  /// The design prints **both** halves, unlike the composer's chip, which has
  /// room for one and prefers the hour the writer went.
  String get _timeLine {
    final parts = <String>[
      if (section.visitedAt != null)
        'ไปตอน ${section.visitedAt!.replaceAll(':', '.')} น.',
      if (hoursRangeText(section.opensAt, section.closesAt) != null)
        'เปิด/ปิด ${hoursRangeText(section.opensAt, section.closesAt)}',
    ];
    return parts.join(' | ');
  }

  /// Photos, preferring uploaded media over the legacy URL-only sections.
  List<String?> get _photos {
    if (section.mediaIds != null) {
      return [
        for (final image in section.images)
          image.unavailable ? null : image.urls?.full,
      ];
    }
    return [for (final url in section.imageUrls) url];
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

/// The spot's photos, swiped through in place.
///
/// Tapping one opens it full-size — the card crops to a fixed ratio so the
/// spots read evenly, and this is where the whole picture is.
class _SpotCarousel extends StatefulWidget {
  const _SpotCarousel({required this.photos});

  /// In order; null where the upload is gone.
  final List<String?> photos;

  @override
  State<_SpotCarousel> createState() => _SpotCarouselState();
}

class _SpotCarouselState extends State<_SpotCarousel> {
  final _pages = PageController();
  int _index = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  /// Only loadable photos can open, so tapping the third of four opens the
  /// third one the reader can actually see.
  List<String> get _gallery =>
      [for (final url in widget.photos) if (url != null) url];

  int _galleryIndexOf(int index) {
    var seen = 0;
    for (var i = 0; i < widget.photos.length; i++) {
      if (widget.photos[i] == null) continue;
      if (i == index) return seen;
      seen++;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.photos.length;

    return Column(
      children: [
        Stack(
          children: [
            AspectRatio(
              aspectRatio: 1.4,
              child: PageView.builder(
                controller: _pages,
                itemCount: total,
                onPageChanged: (index) => setState(() => _index = index),
                itemBuilder: (_, index) {
                  final url = widget.photos[index];
                  if (url == null) return const _MissingPhoto();
                  return Semantics(
                    button: true,
                    label: 'ดูรูปเต็ม',
                    child: GestureDetector(
                      onTap: () => showFullImages(
                        context,
                        urls: _gallery,
                        initialIndex: _galleryIndexOf(index),
                      ),
                      child: CoverImage(source: url),
                    ),
                  );
                },
              ),
            ),
            if (total > 1)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '${_index + 1}/$total',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (total > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < total; i++) ...[
                if (i > 0) const SizedBox(width: 5),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == _index
                        ? AppColors.postPurple
                        : AppColors.chipBorder,
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _MissingPhoto extends StatelessWidget {
  const _MissingPhoto();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.line,
      child: Center(
        child: Text(
          'รูปนี้ไม่พร้อมใช้งาน',
          style: TextStyle(color: AppColors.muted, fontSize: 13),
        ),
      ),
    );
  }
}

/// A note beside the story: an icon in the post's purple, then plain text.
///
/// Rows rather than the chips an earlier pass used — the values run long
/// (a whole sentence of directions, a name and a phone number), and a chip
/// clips what a reader came for.
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 14, color: AppColors.postPurple),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFF3F4642),
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}

/// The one tip worth passing on, with its label on the left the way the
/// design sets it.
class _TripHackRow extends StatelessWidget {
  const _TripHackRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.softScreen,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.handleChip,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.handleChipRing),
            ),
            child: const Text(
              'Trip Hack',
              style: TextStyle(
                color: Color(0xFF3F4642),
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF3F4642),
                fontSize: 12.5,
                height: 1.45,
              ),
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
