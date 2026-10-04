import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/cover_image.dart';
import '../../domain/nearby_trip.dart';

/// The cap of the ไปกัน board (Figma 2480-67909): back button, title, and the
/// card holding where "near me" is measured from and the search box over it.
///
/// Photo and scrim are Home's, so the two boards read as one family — see
/// [HomeHero], whose gradient stops these match.
class PaigunHeader extends StatelessWidget {
  const PaigunHeader({
    super.key,
    required this.origin,
    required this.onBack,
    required this.onEditLocation,
    required this.query,
    required this.onSearch,
    this.coverImage = coverAsset,
  });

  /// The same photo Home puts behind its hero.
  static const String coverAsset = 'assets/images/home_hero.jpg';

  final PaigunOrigin origin;
  final String coverImage;
  final VoidCallback onBack;

  /// Tapping the address itself — opens the map picker to move the origin.
  final VoidCallback onEditLocation;

  /// What is already narrowing the wall, so the field reads back what was
  /// submitted rather than opening blank on every visit.
  final String query;

  /// Submitting the search box. Empty clears it.
  final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      child: Stack(
        children: [
          Positioned.fill(
            // Biased upward for the same reason Home's is: the wide crop keeps
            // the traveller and the mountains in frame.
            child: CoverImage(
              source: coverImage,
              fit: BoxFit.cover,
              alignment: const Alignment(0, -0.3),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0, 0.32, 0.62, 1],
                  colors: [
                    Colors.black.withValues(alpha: 0.34),
                    Colors.black.withValues(alpha: 0.14),
                    Colors.black.withValues(alpha: 0.70),
                    Colors.black.withValues(alpha: 0.94),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(18, topInset + 10, 18, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 44,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Text(
                        'ไปกัน',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _CircleButton(
                          icon: Icons.chevron_left,
                          onTap: onBack,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _LocationCard(
                  origin: origin,
                  onEdit: onEditLocation,
                  query: query,
                  onSearch: onSearch,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.22),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.55)),
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }
}

/// The peach plate under the title: where the board measures from, and the
/// box that narrows it.
///
/// Translucent white over the photo rather than solid: the design lets the
/// cover read through it, and the search box inside is the only opaque part.
class _LocationCard extends StatelessWidget {
  const _LocationCard({
    required this.origin,
    required this.onEdit,
    required this.query,
    required this.onSearch,
  });

  final PaigunOrigin origin;
  final VoidCallback onEdit;
  final String query;
  final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onEdit,
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.location_on,
                    size: 14,
                    color: AppColors.brandOrange,
                  ),
                ),
                const SizedBox(width: 8),
                // The whole address on one line now, with the chevron saying
                // it can be changed — the caption above it said nothing the
                // pin did not already say.
                Flexible(
                  child: Text(
                    origin.address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 22,
                  color: Colors.white,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SearchField(query: query, onSubmit: onSearch),
        ],
      ),
    );
  }
}

/// "สถานที่ใกล้คุณ" — narrows the wall by destination without leaving it.
class _SearchField extends StatefulWidget {
  const _SearchField({required this.query, required this.onSubmit});

  final String query;
  final ValueChanged<String> onSubmit;

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.query);

  @override
  void didUpdateWidget(_SearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only when the board itself cleared it: overwriting on every rebuild
    // would fight whoever is typing.
    if (widget.query != oldWidget.query && widget.query != _controller.text) {
      _controller.text = widget.query;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    widget.onSubmit(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, size: 19, color: AppColors.brandOrange),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _submit(),
              style: const TextStyle(
                color: AppColors.foreground,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'สถานที่ใกล้คุณ',
                hintStyle: TextStyle(
                  color: AppColors.postFieldHint,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: _submit,
            child: Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: AppColors.paigunControl,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
                size: 19,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
