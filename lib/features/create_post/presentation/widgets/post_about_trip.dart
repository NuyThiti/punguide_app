import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/extensions/currency_extensions.dart';
import 'composer_sheet.dart';

/// What the traveller says the whole trip was about, and what it cost them.
///
/// Both halves are optional — a post with neither is still publishable, which
/// is why the row shows its own placeholder rather than a validation error.
@immutable
class PostAboutTrip {
  const PostAboutTrip({
    this.overview = '',
    this.budget,
    this.currency = 'THB',
  });

  final String overview;

  /// Per person, as the design labels it. `budgetLimit` is stored exactly as
  /// typed — the server does no per-head arithmetic — so the per-person
  /// reading is the app's to keep.
  final double? budget;

  /// ISO 4217. Absent on the wire means THB, so that is what this starts as.
  final String currency;

  bool get isEmpty => overview.trim().isEmpty && budget == null;
}

/// The currencies the picker offers, baht first.
const aboutTripCurrencies = <String>['THB', 'USD', 'EUR', 'JPY', 'GBP', 'SGD'];

/// The "+ About trip (Overview & Budget)" row between the title card and the
/// spots. Once filled it reads back the overview and the budget on one line.
class PostAboutTripRow extends StatelessWidget {
  const PostAboutTripRow({
    super.key,
    required this.about,
    required this.onTap,
  });

  final PostAboutTrip about;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final filled = !about.isEmpty;
    final overview = about.overview.trim();
    final budget = about.budget;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.postPurpleSoft,
              ),
              child:
                  const Icon(Icons.add, size: 15, color: AppColors.postPurple),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                filled && overview.isNotEmpty
                    ? overview
                    : 'About trip (Overview & Budget)',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: filled && overview.isNotEmpty
                      ? AppColors.foreground
                      : AppColors.postFieldHint,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (budget != null) ...[
              const SizedBox(width: 10),
              Container(
                width: 1,
                height: 14,
                color: AppColors.line,
              ),
              const SizedBox(width: 10),
              Text(
                about.currency == 'THB'
                    ? budget.asBaht
                    : '${about.currency} ${budget.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: AppColors.foreground,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The About trip sheet: the overview in its own box, then the budget with a
/// currency beside it. Returns null when the traveller backed out — ยกเลิก and
/// the scrim both leave what was there untouched.
Future<PostAboutTrip?> showAboutTripSheet(
  BuildContext context, {
  required PostAboutTrip current,
}) {
  return showModalBottomSheet<PostAboutTrip>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AboutTripSheet(current: current),
  );
}

class _AboutTripSheet extends StatefulWidget {
  const _AboutTripSheet({required this.current});

  final PostAboutTrip current;

  @override
  State<_AboutTripSheet> createState() => _AboutTripSheetState();
}

class _AboutTripSheetState extends State<_AboutTripSheet> {
  late final TextEditingController _overview =
      TextEditingController(text: widget.current.overview);
  late final TextEditingController _budget = TextEditingController(
    text: widget.current.budget == null ? '' : _plain(widget.current.budget!),
  );

  late String _currency = widget.current.currency;

  static String _plain(double value) =>
      value == value.roundToDouble() ? value.round().toString() : '$value';

  double? get _typedBudget {
    final parsed = double.tryParse(_budget.text.trim().replaceAll(',', ''));
    return parsed != null && parsed > 0 ? parsed : null;
  }

  @override
  void dispose() {
    _overview.dispose();
    _budget.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ComposerSheet(
      title: 'About trip',
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const _SheetLabel('Trip Overview'),
            Container(
              height: 128,
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              decoration: BoxDecoration(
                color: AppColors.screen,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.line),
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
                  hintStyle: TextStyle(color: AppColors.postFieldHint),
                ),
                style: const TextStyle(fontSize: 14, height: 1.45),
              ),
            ),
            const SizedBox(height: 16),
            const _SheetLabel('Budget'),
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 13),
              decoration: BoxDecoration(
                color: AppColors.screen,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.line),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _budget,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9.,]'),
                        ),
                      ],
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: '0.00',
                        hintStyle: TextStyle(color: AppColors.postFieldHint),
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
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 10),
                  PopupMenuButton<String>(
                    tooltip: 'สกุลเงิน',
                    initialValue: _currency,
                    position: PopupMenuPosition.under,
                    onSelected: (value) => setState(() => _currency = value),
                    itemBuilder: (context) => [
                      for (final code in aboutTripCurrencies)
                        PopupMenuItem<String>(value: code, child: Text(code)),
                    ],
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.line),
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
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.line),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                      child: const Text(
                        'ยกเลิก',
                        style: TextStyle(
                          color: AppColors.foreground,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(
                        PostAboutTrip(
                          overview: _overview.text.trim(),
                          budget: _typedBudget,
                          currency: _currency,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.sheetConfirm,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                      child: const Text(
                        'ตกลง',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetLabel extends StatelessWidget {
  const _SheetLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
