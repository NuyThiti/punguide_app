import 'package:flutter/material.dart';

import '../../domain/models/puntok_post.dart';

/// Puntok's header, drawn over the clip: a back disc, the title, a search
/// disc, and the three feed tabs beneath them.
class PuntokTopBar extends StatelessWidget {
  const PuntokTopBar({
    super.key,
    required this.activeTab,
    required this.onTab,
    required this.onBack,
    required this.onSearch,
  });

  final PuntokFeed activeTab;
  final ValueChanged<PuntokFeed> onTab;
  final VoidCallback onBack;
  final VoidCallback onSearch;

  /// Height the bar occupies below the status bar, so the feed can inset by it.
  static const double contentHeight = 44 + 12 + 28;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 44,
              child: Row(
                children: [
                  _Disc(icon: Icons.arrow_back_ios_new, onTap: onBack),
                  const Expanded(
                    child: Text(
                      'Puntok',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        shadows: [
                          Shadow(color: Colors.black54, blurRadius: 6),
                        ],
                      ),
                    ),
                  ),
                  _Disc(icon: Icons.search, onTap: onSearch),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 28,
              // Three labels fit the 430pt frame comfortably; scaleDown keeps
              // them on one line on a narrower phone or a large text scale.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final tab in PuntokFeed.values)
                      _Tab(
                        label: tab.label,
                        selected: tab == activeTab,
                        onTap: () => onTab(tab),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Disc extends StatelessWidget {
  const _Disc({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.3),
        ),
        child: Icon(icon, color: Colors.white, size: 19),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: selected ? 1 : 0.66),
            fontSize: 15,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            shadows: const [Shadow(color: Colors.black54, blurRadius: 6)],
          ),
        ),
      ),
    );
  }
}
