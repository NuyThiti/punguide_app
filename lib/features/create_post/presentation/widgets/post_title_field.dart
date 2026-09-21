import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/api/pluno_api.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/cover_image.dart';
import '../../../auth/domain/auth_session.dart';
import '../../../create_trip/domain/plan_labels.dart';
import '../../domain/models/post_draft.dart';
import 'place_pin_picker.dart';
import 'post_about_trip.dart';
import 'post_audience_chip.dart';

/// The card at the top of the composer: who is posting, what the post is
/// called, and what kind of trip it was.
///
/// One card rather than three stacked rows — the design groups them because
/// they all describe the post itself, while everything below describes a spot.
class PostIdentityCard extends StatelessWidget {
  const PostIdentityCard({
    super.key,
    required this.session,
    required this.audience,
    required this.onChangeAudience,
    required this.title,
    required this.styles,
    required this.customStyles,
    required this.onEditTitle,
    required this.about,
    required this.onEditAbout,
    this.place,
  });

  /// Null while signed out — the guest path still reaches the composer.
  final AuthSession? session;
  final PostAudience audience;
  final VoidCallback onChangeAudience;
  final String title;
  final List<TravelStyle> styles;
  final List<String> customStyles;
  final VoidCallback onEditTitle;

  /// About trip is set in the Title sheet now, so the card only reads it back.
  final PostAboutTrip about;
  final VoidCallback onEditAbout;

  /// Where the post is about, when the Title sheet has been given one.
  final PostPlace? place;

  @override
  Widget build(BuildContext context) {
    final written = title.trim().isNotEmpty;
    final avatar = session?.avatarImage;
    final chosen = [
      for (final style in styles)
        (styleLabel(style) ?? style.name, styleIcon(style)),
      for (final label in customStyles) (label, Icons.local_activity_outlined),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.screen,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.chipBorder),
        // The same lift the feed's cards use, so this reads as one object on
        // the page's off-white rather than a box drawn on it.
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(
                  color: AppColors.postField,
                  shape: BoxShape.circle,
                ),
                clipBehavior: Clip.antiAlias,
                child: avatar == null || avatar.isEmpty
                    ? const Icon(Icons.person, size: 18, color: AppColors.muted)
                    : CoverImage(source: avatar),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  session?.displayName ?? 'ผู้ใช้ PunGuide',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.foreground,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              PostAudienceChip(audience: audience, onTap: onChangeAudience),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.chipBorder),
          const SizedBox(height: 12),
          InkWell(
            onTap: onEditTitle,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    written ? title.trim() : 'Title..',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: written
                          ? AppColors.foreground
                          : AppColors.postFieldHint,
                      fontSize: 16,
                      fontWeight: written ? FontWeight.w800 : FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.edit_outlined,
                    size: 20, color: AppColors.postPurple),
              ],
            ),
          ),
          if (place != null) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: onEditTitle,
              borderRadius: BorderRadius.circular(8),
              child: Row(
                children: [
                  const Icon(Icons.location_on_outlined,
                      size: 15, color: AppColors.postPurple),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      // The locality is what the trip stores; the place's own
                      // name is what the traveller recognises, so both show.
                      place!.area?.trim().isNotEmpty == true &&
                              place!.area!.trim() != place!.name.trim()
                          ? '${place!.name} · ${place!.area!.trim()}'
                          : place!.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (chosen.isNotEmpty) ...[
            const SizedBox(height: 10),
            // Only the chosen activities: the Title sheet opens from the title
            // row itself, so an add chip would be a second door onto it.
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final (label, icon) in chosen)
                  _ChosenActivityChip(label: label, icon: icon),
              ],
            ),
          ],
          if (!about.isEmpty)
            PostAboutTripRow(about: about, onTap: onEditAbout),
        ],
      ),
    );
  }
}

class _ChosenActivityChip extends StatelessWidget {
  const _ChosenActivityChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.postPurpleSoft,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.postPurple),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.postPurple,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// The Title sheet's ตกลง. Named so a test can reach it without depending on
/// where the sheet's footer happens to land.
const postTitleConfirmKey = Key('post-title-confirm');

/// What the Title sheet came back with.
class PostTitleResult {
  const PostTitleResult({
    required this.title,
    required this.styles,
    this.customStyles = const [],
    this.about = const PostAboutTrip(),
    this.place,
    this.clearedPlace = false,
  });

  final String title;

  /// The chosen Trip Activity chips, as the travel styles `POST /trips` and
  /// `PATCH /trips/:id` take.
  final List<TravelStyle> styles;

  /// Anything the traveller typed under "+ เพิ่ม", which goes up as
  /// `customStyles` on the same two calls.
  final List<String> customStyles;

  /// The overview and the budget, set in the same sheet — they describe the
  /// post just as its name and its activities do.
  final PostAboutTrip about;

  /// Where the post is about as a whole. Null when none was set; publishing
  /// then falls back to the linked plan, and then to the first pinned spot.
  final PostPlace? place;

  /// True when the traveller took the place off here, which is a different
  /// answer from never having set one.
  final bool clearedPlace;
}

/// Names the post and says what kind of trip it was.
///
/// The activities are the same ten the plan wizard offers, and go up as
/// `travelStyles`; anything typed under "+ เพิ่ม" goes up as `customStyles`.
Future<PostTitleResult?> showPostTitleSheet(
  BuildContext context, {
  required String title,
  required List<TravelStyle> styles,
  List<String> customStyles = const [],
  PostAboutTrip about = const PostAboutTrip(),
  PostPlace? place,
}) {
  return showModalBottomSheet<PostTitleResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.42),
    builder: (_) => _PostTitleSheet(
      title: title,
      styles: styles,
      customStyles: customStyles,
      about: about,
      place: place,
    ),
  );
}

class _PostTitleSheet extends StatefulWidget {
  const _PostTitleSheet({
    required this.title,
    required this.styles,
    required this.customStyles,
    required this.about,
    required this.place,
  });

  final String title;
  final List<TravelStyle> styles;
  final List<String> customStyles;
  final PostAboutTrip about;
  final PostPlace? place;

  @override
  State<_PostTitleSheet> createState() => _PostTitleSheetState();
}

class _PostTitleSheetState extends State<_PostTitleSheet> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.title);
  late final Set<TravelStyle> _picked = {...widget.styles};
  late final List<String> _custom = [...widget.customStyles];

  late final TextEditingController _overview =
      TextEditingController(text: widget.about.overview);
  late final TextEditingController _budget = TextEditingController(
    text: widget.about.budget == null ? '' : _plainAmount(widget.about.budget!),
  );
  late String _currency = widget.about.currency;

  late PostPlace? _place = widget.place;
  bool _clearedPlace = false;

  Future<void> _pickPlace() async {
    final picked = await showPlacePinPicker(context, hasPlace: _place != null);
    if (picked == null || !mounted) return;
    setState(() {
      // The picker answers with a cleared pin rather than null when the
      // traveller took it off, so the two stay apart.
      final removed = picked == clearedPlacePin;
      _place = removed ? null : picked;
      _clearedPlace = removed;
    });
  }

  static String _plainAmount(double value) =>
      value == value.roundToDouble() ? value.round().toString() : '$value';

  double? get _typedBudget {
    final parsed = double.tryParse(_budget.text.trim().replaceAll(',', ''));
    return parsed != null && parsed > 0 ? parsed : null;
  }

  Future<void> _addCustom() async {
    final added = await showDialog<String>(
      context: context,
      builder: (_) => const _AddActivityDialog(),
    );
    final value = added?.trim() ?? '';
    if (value.isEmpty || _custom.contains(value)) return;
    setState(() => _custom.add(value));
  }

  @override
  void dispose() {
    _controller.dispose();
    _overview.dispose();
    _budget.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Material(
        color: AppColors.screen,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.86,
            ),
            // The fields scroll; ตกลง does not. A primary action that can
            // scroll out of reach is a sheet you cannot finish on a short
            // screen.
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 44,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFFD9D6D1),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const SizedBox(width: 34),
                            const Expanded(
                              child: Text(
                                'Title',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.foreground,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Material(
                              color: AppColors.postDraftBg,
                              shape: const CircleBorder(),
                              child: InkWell(
                                onTap: () => Navigator.of(context).pop(),
                                customBorder: const CircleBorder(),
                                child: const SizedBox(
                                  width: 34,
                                  height: 34,
                                  child: Icon(Icons.close,
                                      size: 19, color: AppColors.foreground),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _controller,
                          maxLength: 200,
                          autofocus: widget.title.trim().isEmpty,
                          textInputAction: TextInputAction.done,
                          style: const TextStyle(
                            color: AppColors.foreground,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: InputDecoration(
                            counterText: '',
                            hintText: 'Title',
                            hintStyle: const TextStyle(
                              color: AppColors.postFieldHint,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                            suffixIcon: const Icon(Icons.edit_outlined,
                                size: 20, color: AppColors.postPurple),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 15),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide:
                                  const BorderSide(color: AppColors.chipBorder),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide:
                                  const BorderSide(color: AppColors.chipBorder),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                  color: AppColors.postPurple, width: 1.3),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        InkWell(
                          onTap: _pickPlace,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 13, vertical: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.chipBorder),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.location_on_outlined,
                                    size: 18, color: AppColors.postPurple),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: Text(
                                    _place?.name ?? 'Add Location',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: _place == null
                                          ? AppColors.postFieldHint
                                          : AppColors.foreground,
                                      fontSize: 14,
                                      fontWeight: _place == null
                                          ? FontWeight.w500
                                          : FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const Icon(Icons.chevron_right,
                                    size: 20, color: AppColors.muted),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Trip Activity',
                            style: TextStyle(
                              color: AppColors.foreground,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Only the chosen activities: the Title sheet is opened from the
                        // title row itself, so a "+ Trip activity" chip would be a second
                        // door onto the same sheet.
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            for (final entry in styleByLabel.entries)
                              _ActivityChip(
                                label: entry.key,
                                icon: styleIcon(entry.value),
                                selected: _picked.contains(entry.value),
                                onTap: () => setState(() =>
                                    _picked.contains(entry.value)
                                        ? _picked.remove(entry.value)
                                        : _picked.add(entry.value)),
                              ),
                            for (final label in _custom)
                              _ActivityChip(
                                label: label,
                                icon: Icons.close,
                                selected: true,
                                onTap: () =>
                                    setState(() => _custom.remove(label)),
                              ),
                            _ActivityChip(
                              label: 'เพิ่ม',
                              icon: Icons.add,
                              outlined: true,
                              selected: false,
                              onTap: _addCustom,
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        const _SheetSection('About trip'),
                        const SizedBox(height: 10),
                        Container(
                          height: 96,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 13, vertical: 11),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.chipBorder),
                          ),
                          child: TextField(
                            controller: _overview,
                            maxLines: null,
                            expands: true,
                            textAlignVertical: TextAlignVertical.top,
                            decoration: const InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              hintText: 'ภาพรวมของทริป',
                              hintStyle:
                                  TextStyle(color: AppColors.postFieldHint),
                            ),
                            style: const TextStyle(fontSize: 14, height: 1.45),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 13),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.chipBorder),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _budget,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                        RegExp(r'[0-9.,]')),
                                  ],
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    border: InputBorder.none,
                                    hintText: '0.00',
                                    hintStyle: TextStyle(
                                        color: AppColors.postFieldHint),
                                  ),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const Text(
                                'ต่อคน',
                                style: TextStyle(
                                    color: AppColors.postFieldHint,
                                    fontSize: 12),
                              ),
                              const SizedBox(width: 10),
                              PopupMenuButton<String>(
                                tooltip: 'สกุลเงิน',
                                initialValue: _currency,
                                position: PopupMenuPosition.under,
                                onSelected: (value) =>
                                    setState(() => _currency = value),
                                itemBuilder: (context) => [
                                  for (final code in aboutTripCurrencies)
                                    PopupMenuItem<String>(
                                        value: code, child: Text(code)),
                                ],
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border:
                                        Border.all(color: AppColors.chipBorder),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _currency,
                                        style: const TextStyle(
                                          color: AppColors.foreground,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const Icon(Icons.keyboard_arrow_down,
                                          size: 16, color: AppColors.muted),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                  child: SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton(
                      key: postTitleConfirmKey,
                      onPressed: () =>
                          Navigator.of(context).pop(PostTitleResult(
                        title: _controller.text.trim(),
                        styles: _picked.toList(growable: false),
                        customStyles: List<String>.unmodifiable(_custom),
                        about: PostAboutTrip(
                          overview: _overview.text.trim(),
                          budget: _typedBudget,
                          currency: _currency,
                        ),
                        place: _place,
                        clearedPlace: _clearedPlace,
                      )),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.postShare,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(27)),
                      ),
                      child: const Text(
                        'ตกลง',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                    ),
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

class _ActivityChip extends StatelessWidget {
  const _ActivityChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.outlined = false,
  });

  final String label;
  final IconData icon;
  final bool selected;

  /// The "+ เพิ่ม" chip, which is an action rather than a choice.
  final bool outlined;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final border = outlined
        ? AppColors.postPurple
        : selected
            ? AppColors.postPurple
            : AppColors.chipBorder;

    return Material(
      color: selected ? AppColors.postPurpleWell : AppColors.screen,
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 16,
                  color: selected || outlined
                      ? AppColors.postPurple
                      : AppColors.muted),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: selected || outlined
                      ? AppColors.postPurple
                      : AppColors.foreground,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A heading inside the Title sheet, the same weight as "Trip Activity".
class _SheetSection extends StatelessWidget {
  const _SheetSection(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.foreground,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// Owns its controller so the field survives the dialog's exit animation.
class _AddActivityDialog extends StatefulWidget {
  const _AddActivityDialog();

  @override
  State<_AddActivityDialog> createState() => _AddActivityDialogState();
}

class _AddActivityDialogState extends State<_AddActivityDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('เพิ่มกิจกรรม'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 100,
        decoration: const InputDecoration(hintText: 'เช่น ดำน้ำ'),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('ยกเลิก'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('เพิ่ม'),
        ),
      ],
    );
  }
}
