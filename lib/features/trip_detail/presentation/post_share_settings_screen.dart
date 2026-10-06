import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_providers.dart';
import '../../../core/api/pluno_api.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/extensions/currency_extensions.dart';
import '../../../shared/widgets/cover_image.dart';
import '../../auth/domain/auth_session.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../create_post/domain/models/post_draft.dart';
import '../../create_post/presentation/widgets/post_about_trip.dart';
import '../../create_post/presentation/widgets/post_audience_chip.dart';
import '../../create_post/presentation/widgets/post_title_field.dart';
import '../../create_post/presentation/widgets/trip_link_picker.dart';
import '../../trips/presentation/providers/trip_providers.dart';
import 'widgets/connect_plan_section.dart';

/// "เชื่อมแพลนของฉัน" and the rest of a post's share settings: visibility,
/// name, activities and whether it may be remixed — reached from
/// `TripDetailScreen`'s "แก้ไขโพสต์" action instead of the full composer.
///
/// Every field here is staged locally and only reaches the server on "Share"
/// — "Back" discards whatever was changed, same as the plan picker's own
/// ยกเลิก a level down.
class PostShareSettingsScreen extends ConsumerStatefulWidget {
  const PostShareSettingsScreen({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<PostShareSettingsScreen> createState() =>
      _PostShareSettingsScreenState();
}

class _PostShareSettingsScreenState
    extends ConsumerState<PostShareSettingsScreen> {
  bool _seeded = false;
  bool _sharing = false;

  late PostAudience _audience;
  late PostTripLink? _trip;
  late String _title;
  late List<TravelStyle> _styles;
  late List<String> _customStyles;
  late PostAboutTrip _about;
  late bool _allowRemix;

  // Richer display-only data for the connected plan's card — the trip's own
  // `linkedTrip` has it; a freshly picked `PostTripLink` does not, so this is
  // re-derived (see `_resolveConnectedPreview`) whenever the selection changes.
  LinkedTrip? _connectedPreview;

  void _seed(ApiTrip trip) {
    if (_seeded) return;
    _seeded = true;
    _audience =
        trip.visibility == TripVisibility.public ? PostAudience.public : PostAudience.onlyMe;
    final linked = trip.linkedTrip;
    _trip = linked == null ? null : PostTripLink(id: linked.id, title: linked.title);
    _connectedPreview = linked;
    _title = trip.title;
    _styles = List.of(trip.brief?.styles ?? const <TravelStyle>[]);
    _customStyles = List.of(trip.brief?.customStyles ?? const <String>[]);
    _about = PostAboutTrip(
      overview: trip.description ?? '',
      budget: trip.budgetLimit,
      currency: trip.budgetCurrency ?? 'THB',
    );
    _allowRemix = trip.allowRemix;
  }

  Future<void> _pickAudience() async {
    final picked = await showAudiencePicker(context, _audience);
    if (picked == null || !mounted) return;
    setState(() => _audience = picked);
  }

  Future<void> _editTitle() async {
    final result = await showPostTitleSheet(
      context,
      title: _title,
      styles: _styles,
      customStyles: _customStyles,
      about: _about,
    );
    if (result == null || !mounted) return;
    setState(() {
      _title = result.title;
      _styles = List.unmodifiable(result.styles);
      _customStyles = List.unmodifiable(result.customStyles);
      _about = result.about;
    });
  }

  Future<void> _connectPlan() async {
    final picked = await showTripLinkPicker(context, current: _trip);
    if (picked == null || !mounted) return; // ยกเลิก — nothing changes
    setState(() {
      if (picked.id.isEmpty) {
        // noTripLink: confirmed with nothing selected — an explicit removal.
        _trip = null;
        _connectedPreview = null;
        return;
      }
      _trip = picked;
      _connectedPreview = _matchPreview(picked.id);
    });
  }

  /// `showTripLinkPicker` only hands back an id and a title; the fuller
  /// cover/schedule/placeCount for the card comes from the same
  /// `myPlansProvider` rows the picker itself just read, when they are still
  /// cached. Absent that, the card falls back to showing just the title.
  LinkedTrip? _matchPreview(String planId) {
    final rows = ref.read(myPlansProvider).valueOrNull;
    if (rows == null) return null;
    for (final row in rows) {
      if (row.id == planId) {
        return LinkedTrip(
          id: row.id,
          title: row.title,
          schedule: row.schedule,
          placeCount: row.placeCount,
          coverImage: row.coverImage,
        );
      }
    }
    return null;
  }

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final api = await ref.read(plunoApiProvider.future);
      await api.trips.update(
        widget.tripId,
        title: _title,
        travelStyles: _styles,
        customStyles: _customStyles,
        description: _about.overview.isEmpty ? null : _about.overview,
        budgetLimit: _about.budget,
        budgetCurrency: _about.currency,
        linkedTripId: _trip == null
            ? const Patch<String>.clear()
            : Patch<String>.value(_trip!.id),
        visibility: _audience == PostAudience.public
            ? TripVisibility.public
            : TripVisibility.private,
        allowRemix: _allowRemix,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() => _sharing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('แชร์โพสต์ไม่สำเร็จ ลองอีกครั้ง')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final trip = ref.watch(apiTripProvider(widget.tripId));
    final session = ref.watch(authSessionProvider);

    return Scaffold(
      backgroundColor: AppColors.screen,
      body: trip.when(
        data: (loaded) {
          _seed(loaded);
          return _body(loaded, session);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
      ),
    );
  }

  Widget _body(ApiTrip trip, AuthSession? session) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              _ShareHero(trip: trip),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  children: [
                    PostIdentityCard(
                      session: session,
                      audience: _audience,
                      onChangeAudience: _pickAudience,
                      title: _title,
                      styles: _styles,
                      customStyles: _customStyles,
                      onEditTitle: _editTitle,
                      about: const PostAboutTrip(),
                      onEditAbout: _editTitle,
                    ),
                    const SizedBox(height: 12),
                    ConnectPlanSection(
                      connected: _trip != null,
                      onTap: _connectPlan,
                      title: _trip?.title,
                      coverUrl: _connectedPreview?.coverImage?.urls.large,
                      factsLine: _connectedPreview == null
                          ? null
                          : _planFactsLine(_connectedPreview!),
                    ),
                    const SizedBox(height: 12),
                    _RemixToggleRow(
                      value: _allowRemix,
                      onChanged: (value) => setState(() => _allowRemix = value),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
        _BottomBar(
          busy: _sharing,
          onBack: () => Navigator.of(context).pop(),
          onShare: _share,
        ),
      ],
    );
  }
}

/// "1 วัน • 11 สถานที่" — the same shape `trip_link_picker.dart`'s own plan
/// rows use, off whichever plan is currently connected.
String _planFactsLine(LinkedTrip plan) {
  final parts = <String>[];
  final days = plan.schedule.durationDays;
  if (days != null && days > 0) parts.add('$days วัน');
  if (plan.placeCount > 0) parts.add('${plan.placeCount} สถานที่');
  return parts.join(' • ');
}

class _ShareHero extends StatelessWidget {
  const _ShareHero({required this.trip});

  final ApiTrip trip;

  @override
  Widget build(BuildContext context) {
    final cover = trip.coverImage?.urls.large ??
        trip.linkedTrip?.coverImage?.urls.large ??
        AppConstants.defaultCoverImage;
    final heads = trip.customer?.groupSize ?? 1;
    final perHead = trip.totalBudget > 0 && heads > 0
        ? '${(trip.totalBudget / heads).asBaht}/คน'
        : null;
    final linked = trip.linkedTrip;
    final schedule = linked?.schedule ?? trip.schedule;
    final days = schedule.durationDays;
    final places = linked?.placeCount ?? trip.contents.length;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      child: Stack(
        children: [
          SizedBox(
            height: 220,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CoverImage(source: cover),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.35),
                        Colors.black.withValues(alpha: 0.55),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _RoundIcon(icon: Icons.arrow_back, onTap: () => Navigator.of(context).pop()),
                  // Changing the cover photo is out of scope here — the icon
                  // is shown to match the design but has no behavior yet.
                  const _RoundIcon(icon: Icons.add_photo_alternate_outlined),
                ],
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 14,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (trip.destination.isNotEmpty) ...[
                      const Icon(Icons.location_on_outlined,
                          size: 14, color: Colors.white),
                      Text(trip.destination, style: _pillTextStyle),
                    ],
                    if (days != null && days > 0) ...[
                      const Text('•', style: _pillTextStyle),
                      Text('$days วัน', style: _pillTextStyle),
                    ],
                    if (places > 0) ...[
                      const Text('•', style: _pillTextStyle),
                      Text('$places สถานที่', style: _pillTextStyle),
                    ],
                    if (perHead != null) ...[
                      const Text('•', style: _pillTextStyle),
                      Text(perHead, style: _pillTextStyle),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const _pillTextStyle = TextStyle(
  color: Colors.white,
  fontSize: 12.5,
  fontWeight: FontWeight.w600,
);

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.35),
        ),
        child: Icon(icon, size: 18, color: Colors.white),
      ),
    );
  }
}

class _RemixToggleRow extends StatelessWidget {
  const _RemixToggleRow({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.screen,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.chipBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  'เปิดให้ remix',
                  style: TextStyle(
                    color: AppColors.foreground,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'เปิดการรีมิกซ์แพลนทริปนี้',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.postPurple,
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.busy,
    required this.onBack,
    required this.onShare,
  });

  final bool busy;
  final VoidCallback onBack;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: busy ? null : onBack,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.line),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  child: const Text(
                    'Back',
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
                  onPressed: busy ? null : onShare,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.postPurple,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  child: busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Share',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
