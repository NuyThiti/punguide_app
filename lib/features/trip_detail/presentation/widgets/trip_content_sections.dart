import 'package:flutter/material.dart';
import '../../../../core/api/models/trip_content.dart';
import '../../../../shared/widgets/cover_image.dart';

class TripContentSections extends StatelessWidget {
  const TripContentSections({super.key, required this.sections});
  final List<TripContent> sections;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final section in sections) ...[
          if (section.title.isNotEmpty)
            Text(section.title,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          if (section.content.isNotEmpty)
            Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(section.content,
                    style: const TextStyle(fontSize: 16, height: 1.6))),
          if (section.mediaIds != null)
            for (final image in section.images)
              Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: AspectRatio(
                          aspectRatio: 1.6,
                          child: image.unavailable || image.urls == null
                              ? const ColoredBox(
                                  color: Color(0xFFF0EDE9),
                                  child: Center(
                                      child: Text('รูปนี้ไม่พร้อมใช้งาน')))
                              : CoverImage(source: image.urls!.full))))
          else
            for (final url in section.imageUrls)
              Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: AspectRatio(
                          aspectRatio: 1.6, child: CoverImage(source: url)))),
          // Legacy mapId and suggested locations are not confirmed public pins.
          if (section.location?.status == ContentLocationStatus.confirmed)
            ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.location_on_outlined),
                title: Text(section.location!.name ??
                    section.location!.placeId ??
                    '${section.location!.latitude}, ${section.location!.longitude}')),
          const SizedBox(height: 24),
        ],
      ]);
}
