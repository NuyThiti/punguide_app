import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/extensions/currency_extensions.dart';

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

/// The overview and the budget, read back under the post's name.
///
/// Tapping it reopens the Title sheet, which is where both are written.
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
    // Only drawn once there is something to read: the card builds it under
    // that condition, and the Title sheet is where it gets written.
    if (about.isEmpty) return const SizedBox.shrink();

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
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.postPurpleSoft,
              ),
              child:
                  const Icon(Icons.add, size: 15, color: AppColors.postPurple),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                overview.isNotEmpty ? overview : 'About trip',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: overview.isNotEmpty
                      ? AppColors.foreground
                      : AppColors.postFieldHint,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (budget != null) ...[
              const SizedBox(width: 10),
              Container(width: 1, height: 14, color: AppColors.line),
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
