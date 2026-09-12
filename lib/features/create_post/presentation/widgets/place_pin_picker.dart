import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/models/post_draft.dart';
import '../providers/place_pin_providers.dart';
import 'composer_sheet.dart';

/// Asks for the place a topic is about. Returns null when dismissed.
Future<PostPlace?> showPlacePinPicker(BuildContext context) {
  return showModalBottomSheet<PostPlace>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.42),
    builder: (_) => const _PlacePinPicker(),
  );
}

class _PlacePinPicker extends ConsumerStatefulWidget {
  const _PlacePinPicker();

  @override
  ConsumerState<_PlacePinPicker> createState() => _PlacePinPickerState();
}

class _PlacePinPickerState extends ConsumerState<_PlacePinPicker> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(placePinQueryProvider).trim();
    final searching = query.length >= minPlaceQueryLength;
    final results = ref.watch(placePinResultsProvider);
    final rows = results.valueOrNull ?? const <PostPlace>[];

    return ComposerSheet(
      title: 'สถานที่ของหัวข้อนี้',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            maxLength: 200,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onChanged: (value) =>
                ref.read(placePinQueryProvider.notifier).state = value,
            style: const TextStyle(fontSize: 14, color: AppColors.foreground),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: AppColors.postField,
              hintText: 'ค้นหาคาเฟ่ ร้านอาหาร หรือจุดเที่ยว',
              hintStyle: const TextStyle(
                color: AppColors.postFieldHint,
                fontSize: 13,
              ),
              prefixIcon: const Icon(
                Icons.search,
                size: 20,
                color: AppColors.muted,
              ),
              suffixIcon: searching && results.isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          if (query.isNotEmpty && query.length <= 200)
            TextButton.icon(
              onPressed: () =>
                  Navigator.of(context).pop(PostPlace(id: '', name: query)),
              icon: const Icon(Icons.edit_location_alt_outlined),
              label: const Text('ใช้ชื่อที่พิมพ์เอง'),
            ),
          const SizedBox(height: 14),
          Flexible(
            child: _Results(
              searching: searching,
              results: results,
              rows: rows,
              onPick: (place) => Navigator.of(context).pop(place),
            ),
          ),
        ],
      ),
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({
    required this.searching,
    required this.results,
    required this.rows,
    required this.onPick,
  });

  final bool searching;
  final AsyncValue<List<PostPlace>> results;
  final List<PostPlace> rows;
  final ValueChanged<PostPlace> onPick;

  @override
  Widget build(BuildContext context) {
    if (!searching) {
      return const _PickerNote('พิมพ์ชื่อสถานที่อย่างน้อย 2 ตัวอักษร');
    }
    if (results.hasError && rows.isEmpty) {
      return const _PickerNote('ค้นหาสถานที่ไม่สำเร็จ ลองอีกครั้ง');
    }
    if (rows.isEmpty) {
      return _PickerNote(
        results.isLoading ? 'กำลังค้นหา…' : 'ไม่พบสถานที่ที่ตรงกับคำค้น',
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemCount: rows.length,
      separatorBuilder: (_, __) => const Divider(
        height: 1,
        color: AppColors.line,
      ),
      itemBuilder: (context, index) {
        final place = rows[index];
        return ListTile(
          onTap: () => onPick(place),
          contentPadding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          leading: Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.postIconWell,
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.map,
              size: 19,
              color: AppColors.brandOrange,
            ),
          ),
          title: Text(
            place.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.foreground,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: place.area == null
              ? null
              : Text(
                  place.area!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                  ),
                ),
        );
      },
    );
  }
}

class _PickerNote extends StatelessWidget {
  const _PickerNote(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.muted, fontSize: 13),
      ),
    );
  }
}
