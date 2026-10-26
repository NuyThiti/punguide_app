import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_colors.dart';
import '../providers/profile_providers.dart';

/// The four icon tabs under the hero, each with the underline that marks the
/// one in force (Figma 1539-8068).
class ProfileTabBar extends StatelessWidget {
  const ProfileTabBar({
    super.key,
    required this.active,
    required this.onSelected,
  });

  final ProfileTab active;
  final ValueChanged<ProfileTab> onSelected;

  /// Named for the tab it serves rather than the glyph, so swapping the art
  /// later does not leave the filenames lying about what they are for.
  ///
  /// Albums is the one drawn from a Material glyph — there is no supplied
  /// asset for it.
  static const _tabs = <_TabSpec>[
    _TabSpec.asset(
      ProfileTab.all,
      'assets/icons/profile_tab_all.svg',
      'ทั้งหมด',
    ),
    _TabSpec.asset(
      ProfileTab.content,
      'assets/icons/profile_tab_content.svg',
      'โพสต์',
    ),
    _TabSpec.asset(
      ProfileTab.plans,
      'assets/icons/profile_tab_plans.svg',
      'แผนทริป',
    ),
    _TabSpec.asset(
      ProfileTab.clips,
      'assets/icons/profile_tab_clips.svg',
      'Puntok',
    ),
    _TabSpec.glyph(
      ProfileTab.albums,
      Icons.photo_library_outlined,
      'อัลบั้ม',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          for (final spec in _tabs)
            Expanded(
              child: _Tab(
                spec: spec,
                selected: spec.tab == active,
                onTap: () => onSelected(spec.tab),
              ),
            ),
        ],
      ),
    );
  }
}

/// One tab's art: either a bundled SVG or a Material glyph, never both.
class _TabSpec {
  const _TabSpec.asset(this.tab, String this.asset, this.tooltip)
      : icon = null;
  const _TabSpec.glyph(this.tab, IconData this.icon, this.tooltip)
      : asset = null;

  final ProfileTab tab;
  final String? asset;
  final IconData? icon;
  final String tooltip;
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.spec,
    required this.selected,
    required this.onTap,
  });

  final _TabSpec spec;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.foreground : AppColors.navIconMuted;

    final asset = spec.asset;

    return Tooltip(
      message: spec.tooltip,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Expanded(
              child: Center(
                // Height only: the four glyphs are drawn on different widths,
                // so pinning both would squash the tall ones.
                child: asset == null
                    ? Icon(spec.icon, size: 22, color: color)
                    : SvgPicture.asset(
                        asset,
                        height: 21,
                        colorFilter:
                            ColorFilter.mode(color, BlendMode.srcIn),
                      ),
              ),
            ),
            // The rule runs the full width of the tab, as in the reference,
            // and stays laid out when idle so nothing shifts on select.
            Container(
              height: 2,
              color: selected ? AppColors.foreground : Colors.transparent,
            ),
          ],
        ),
      ),
    );
  }
}
