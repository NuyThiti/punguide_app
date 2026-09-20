import 'package:flutter/material.dart';

import '../../../../core/api/pluno_api.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../create_trip/domain/plan_labels.dart';

/// The post's own name, at the top of the composer. Tapping it — or the
/// pencil — opens the Title sheet, where the trip's activities are set too.
class PostTitleField extends StatelessWidget {
  const PostTitleField({super.key, required this.title, required this.onTap});

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final written = title.trim().isNotEmpty;

    return Material(
      color: AppColors.screen,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 15, 12, 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.chipBorder),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  written ? title.trim() : 'Title',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: written
                        ? AppColors.foreground
                        : AppColors.postFieldHint,
                    fontSize: 15,
                    fontWeight: written ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.edit_outlined,
                  size: 20, color: AppColors.postPurple),
            ],
          ),
        ),
      ),
    );
  }
}

/// What the Title sheet came back with.
class PostTitleResult {
  const PostTitleResult({
    required this.title,
    required this.styles,
    this.customStyles = const [],
  });

  final String title;

  /// The chosen Trip Activity chips, as the travel styles `POST /trips` and
  /// `PATCH /trips/:id` take.
  final List<TravelStyle> styles;

  /// Anything the traveller typed under "+ เพิ่ม", which goes up as
  /// `customStyles` on the same two calls.
  final List<String> customStyles;
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
    ),
  );
}

class _PostTitleSheet extends StatefulWidget {
  const _PostTitleSheet({
    required this.title,
    required this.styles,
    required this.customStyles,
  });

  final String title;
  final List<TravelStyle> styles;
  final List<String> customStyles;

  @override
  State<_PostTitleSheet> createState() => _PostTitleSheetState();
}

class _PostTitleSheetState extends State<_PostTitleSheet> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.title);
  late final Set<TravelStyle> _picked = {...widget.styles};
  late final List<String> _custom = [...widget.customStyles];

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
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
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
                      borderSide: const BorderSide(color: AppColors.chipBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppColors.chipBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                          color: AppColors.postPurple, width: 1.3),
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
                        onTap: () => setState(() => _custom.remove(label)),
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
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(PostTitleResult(
                      title: _controller.text.trim(),
                      styles: _picked.toList(growable: false),
                      customStyles: List<String>.unmodifiable(_custom),
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
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
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
