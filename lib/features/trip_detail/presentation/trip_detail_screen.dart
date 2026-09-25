import '../../create_post/presentation/create_post_screen.dart';
import 'widgets/trip_content_sections.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_providers.dart';
import '../../../core/api/pluno_api.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/extensions/currency_extensions.dart';
import '../../../shared/layout/screen_class.dart';
import '../../../shared/widgets/cover_image.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../create_trip/domain/plan_labels.dart';
import '../../saved_trips/presentation/saved_trips_notifier.dart';
import '../../trips/presentation/itinerary_display.dart';
import '../../trips/presentation/providers/trip_providers.dart';

/// The deep green behind a day number, shared with the plan editor's design.
const _planGreen = Color(0xFF2E6B4C);
const _planBlack = Color.fromARGB(255, 0, 0, 0);

/// How much cover photo shows above the trip title.
///
/// This is the hero's height knob — everything else in it is sized by its own
/// text, so the photo is only as tall as this gap makes it. The design hangs
/// the title off the bottom of the cover with the picture above it. A tablet
/// gets a taller cover so the photo keeps its share of a bigger screen.
double _heroPhotoGap(ScreenClass screen) =>
    screen.pick(compact: 108.0, medium: 150.0, expanded: 190.0);

/// Side padding for the page's one content column.
///
/// The column stops widening past a comfortable reading measure and centres
/// itself instead, so a tablet does not stretch a paragraph across 1,000px.
/// The cover photo deliberately ignores this and stays full-bleed.
double _gutter(BuildContext context) => contentGutter(
      MediaQuery.sizeOf(context).width,
      maxWidth: ScreenClass.of(context).pick(
        compact: double.infinity,
        medium: 620.0,
        expanded: 720.0,
      ),
      minPadding: _edgeInset(context),
    );

/// The margin things that belong to the screen's edge keep — the app bar's
/// back button and avatar. Centring the column must not push those into the
/// middle of a tablet the way it does the title.
double _edgeInset(BuildContext context) =>
    ScreenClass.of(context).pick(compact: 16.0, medium: 24.0, expanded: 32.0);

/// Viewing a plan: whose trip it is, what it costs, and the stops day by day.
///
/// Built 2026-09-10 from Figma node `1414-7446`. The sibling editor at
/// `/trips/:tripId/edit` renders the same days as editable rows; this page is
/// the public face — read-only apart from saving and remixing.
///
/// It reads [apiTripProvider] rather than the local `Trip`, which flattens
/// away the schedule, the brief and the whole itinerary.
class TripDetailScreen extends ConsumerStatefulWidget {
  const TripDetailScreen({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends ConsumerState<TripDetailScreen> {
  int _selectedDay = 0;

  @override
  Widget build(BuildContext context) {
    final trip = ref.watch(apiTripProvider(widget.tripId));

    return Scaffold(
      backgroundColor: AppColors.screen,
      bottomNavigationBar: _actionBar(trip),
      body: trip.when(
        data: _body,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorBody(
          error: error,
          onRetry: () => ref.invalidate(apiTripProvider(widget.tripId)),
        ),
      ),
    );
  }

  /// Your own plan offers `แก้ไข`; anyone else's offers `Remix Trip`.
  ///
  /// Nothing else in the app watches [currentUserProvider], so `/auth/me`
  /// starts fresh here — waiting for it to settle keeps a purple Remix button
  /// from flashing on your own trip before it flips to the orange edit one. A
  /// viewer who is signed out, or whose session read failed, is not the owner
  /// and gets Remix.
  Widget? _actionBar(AsyncValue<ApiTrip> trip) {
    final viewer = ref.watch(currentUserProvider);
    if (!trip.hasValue || viewer.isLoading) return null;

    final owned = viewer.valueOrNull?.id == trip.requireValue.ownerId;

    if (trip.requireValue.type == TripType.content) {
      if (!owned) return null;
      return _PlanActionBar(
          label: 'แก้ไขโพสต์',
          color: AppColors.createTop,
          onTap: () async {
            await Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) =>
                    CreatePostScreen(initialTrip: trip.requireValue)));
            if (mounted) ref.invalidate(apiTripProvider(widget.tripId));
          });
    }
    return _PlanActionBar(
      label: owned ? 'แก้ไข' : 'Remix Trip',
      color: owned ? AppColors.brandOrange : AppColors.brandPurple,
      onTap: () => context.goNamed(
        owned ? AppRoute.editTrip.name : AppRoute.remixTrip.name,
        params: {'tripId': widget.tripId},
      ),
    );
  }

  /// A post, in the order the composer collects it: who wrote it, what it is
  /// called, where, what kind of trip, the blurb, then the spots.
  /// A post, in the order Figma 2183-21784 sets it: a dark cover hero with the
  /// author, the title and the trip's facts, the plan this post links to, then
  /// Trip Overview and the spots.
  Widget _contentBody(ApiTrip trip) {
    final blurb = trip.description?.trim() ?? '';
    final linked = trip.linkedTrip;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: _PostHero(
            trip: trip,
            onBack: _leave,
            onShare: () => _todo('แชร์โพสต์ยังไม่เปิดใช้งาน'),
            onFollow: () => _todo('ติดตามยังไม่เปิดใช้งาน'),
            onOpenPlan: linked == null
                ? null
                : () => context.goNamed(
                      AppRoute.tripDetail.name,
                      params: {'tripId': linked.id},
                    ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(_gutter(context), 20, _gutter(context), 0),
          sliver: SliverToBoxAdapter(
            child: _PostOverview(
              trip: trip,
              blurb: blurb,
              saved: ref
                      .watch(selectedTripProvider(widget.tripId))
                      .valueOrNull
                      ?.isSaved ??
                  trip.isSaved,
              onSave: () => _toggleSaved(trip),
            ),
          ),
        ),
        // No horizontal padding here: the spot photos run to the screen's
        // edge, and the section widget puts the gutter back on the headings
        // and the card text so they line up with Trip Overview above.
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 32),
            child: TripContentSections(
              sections: trip.contents,
              gutter: _gutter(context),
            ),
          ),
        ),
      ],
    );
  }


  Widget _body(ApiTrip trip) {
    if (trip.type == TripType.content) return _contentBody(trip);
    final plan = _PlanView.of(trip);
    // A trip whose days were deleted must not leave the tab strip pointing
    // past the end of the list.
    final dayIndex =
        plan.days.isEmpty ? 0 : _selectedDay.clamp(0, plan.days.length - 1);
    final day = plan.days.isEmpty ? null : plan.days[dayIndex];
    final stops = day?.activities ?? const <Activity>[];
    // The bookmark writes to the local saved list, so the icon has to read
    // from there too — `ApiTrip.isSaved` is the server's answer and would not
    // change when you tap. It stands in until the local read lands.
    final saved =
        ref.watch(selectedTripProvider(widget.tripId)).valueOrNull?.isSaved ??
            trip.isSaved;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: _ViewHero(
            plan: plan,
            saved: saved,
            avatarImage: ref.watch(authSessionProvider)?.avatarImage,
            onBack: _leave,
            onSave: () => _toggleSaved(trip),
            onShare: () => _todo('แชร์ทริปยังไม่เปิดใช้งาน'),
            onFollow: () => _todo('ติดตามยังไม่เปิดใช้งาน'),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            _gutter(context),
            22,
            _gutter(context),
            28,
          ),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              TripContentSections(sections: trip.contents, gutter: 0),
              _OverviewSection(plan: plan),
              const SizedBox(height: 20),
              _DayTabs(
                days: plan.days,
                selectedIndex: dayIndex,
                onSelect: (index) => setState(() => _selectedDay = index),
              ),
              const SizedBox(height: 16),
              if (plan.days.isEmpty)
                const _EmptyNote(text: 'ทริปนี้ยังไม่มีแผนการเดินทาง')
              else if (stops.isEmpty)
                const _EmptyNote(text: 'วันนี้ยังไม่มีสถานที่')
              else
                for (var i = 0; i < stops.length; i++) ...[
                  _StopCard(
                    stop: stops[i],
                    position: i + 1,
                    segment: day!.segmentInto(stops[i]),
                    onAdd: () => _todo('เพิ่มลงแผนของฉันยังไม่เปิดใช้งาน'),
                    onSave: () => _todo('บันทึกสถานที่ยังไม่เปิดใช้งาน'),
                    onMap: () => _todo('ดูบนแผนที่ยังไม่เปิดใช้งาน'),
                  ),
                  if (i < stops.length - 1) const SizedBox(height: 16),
                ],
            ]),
          ),
        ),
      ],
    );
  }

  /// Home is the safe fallback: the page is reachable from four places, and
  /// from a cold deep link there is nothing to pop back to.
  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.goNamed(AppRoute.home.name);
    }
  }

  /// Saving still goes through the local list the Saved tab reads, so the
  /// bookmark keeps working the way it does everywhere else in the app.
  /// `api.trips.save` / `unsave` exist and are still unused by any screen.
  Future<void> _toggleSaved(ApiTrip trip) async {
    final notifier = ref.read(savedTripsNotifierProvider.notifier);
    final local = await ref.read(selectedTripProvider(trip.id).future);
    if (local == null) return;

    if (local.isSaved) {
      await notifier.unsaveTrip(local.id);
    } else {
      await notifier.saveTrip(local);
    }
  }

  void _todo(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

/// Who wrote the post.
///
/// The trip's owner, not the signed-in viewer — `customer` is the account the
/// trip belongs to.
/// The cover hero: who wrote the post, what it is called, the trip's facts,
/// and the plan it links to.
class _PostHero extends StatelessWidget {
  const _PostHero({
    required this.trip,
    required this.onBack,
    required this.onShare,
    required this.onFollow,
    required this.onOpenPlan,
  });

  final ApiTrip trip;
  final VoidCallback onBack;
  final VoidCallback onShare;
  final VoidCallback onFollow;

  /// Null when the post links no plan, which is when the design's call to
  /// action has nowhere to go.
  final VoidCallback? onOpenPlan;

  @override
  Widget build(BuildContext context) {
    final cover = trip.coverImage?.urls.large ??
        trip.linkedTrip?.coverImage?.urls.large ??
        AppConstants.defaultCoverImage;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
        child: Stack(
          children: [
            Positioned.fill(child: CoverImage(source: cover)),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0, 0.45, 1],
                    colors: [
                      Colors.black.withValues(alpha: 0.55),
                      Colors.black.withValues(alpha: 0.45),
                      Colors.black.withValues(alpha: 0.82),
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  _edgeInset(context),
                  10,
                  _edgeInset(context),
                  16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        _RoundGlassButton(
                          icon: Icons.arrow_back_ios_new,
                          tooltip: 'ย้อนกลับ',
                          onTap: onBack,
                        ),
                        Expanded(child: _PostAuthor(trip: trip, onFollow: onFollow)),
                        _RoundGlassButton(
                          icon: Icons.ios_share,
                          tooltip: 'แชร์',
                          onTap: onShare,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      trip.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        height: 1.25,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _PostFacts(trip: trip),
                    if (onOpenPlan != null) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton(
                          onPressed: onOpenPlan,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.brandPurple,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'ดูแผนเที่ยวรายวันของทริปนี้',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
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

/// The author, centred between the two round buttons.
class _PostAuthor extends StatelessWidget {
  const _PostAuthor({required this.trip, required this.onFollow});

  final ApiTrip trip;
  final VoidCallback onFollow;

  @override
  Widget build(BuildContext context) {
    final avatar = trip.customer?.avatarUrl;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 26,
          height: 26,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.25),
            border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
          ),
          child: avatar == null || avatar.isEmpty
              ? const Icon(Icons.person, size: 15, color: Colors.white)
              : CoverImage(source: avatar),
        ),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            trip.customer?.name ?? 'ไม่ระบุผู้เขียน',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 7),
        GestureDetector(
          onTap: onFollow,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
            ),
            child: const Text(
              'ติดตาม',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Where, how long, how many places and what per head.
///
/// The duration and the place count describe the **linked plan** when there is
/// one — a post has no schedule of its own — and fall back to the post's own
/// figures otherwise.
class _PostFacts extends StatelessWidget {
  const _PostFacts({required this.trip});

  final ApiTrip trip;

  @override
  Widget build(BuildContext context) {
    final linked = trip.linkedTrip;
    final schedule = linked?.schedule ?? trip.schedule;
    final start = schedule.startDate;
    final end = schedule.endDate;
    final days = schedule.durationDays ??
        (start != null && end != null ? end.difference(start).inDays + 1 : 0);

    final places = linked?.placeCount ?? trip.contents.length;
    final heads = trip.customer?.groupSize ?? 1;
    final perHead = trip.totalBudget > 0 && heads > 0
        ? '${(trip.totalBudget / heads).asBaht} /คน'
        : null;

    final facts = <String>[
      if (days > 0) '$days วัน',
      if (places > 0) '$places สถานที่',
      if (perHead != null) perHead,
    ];

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      runSpacing: 4,
      children: [
        if (trip.destination.isNotEmpty) ...[
          Icon(
            Icons.location_on_outlined,
            size: 13,
            color: Colors.white.withValues(alpha: 0.9),
          ),
          _FactText(trip.destination),
        ],
        for (final fact in facts) ...[
          _FactText('·'),
          _FactText(fact),
        ],
      ],
    );
  }
}

class _FactText extends StatelessWidget {
  const _FactText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.92),
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _RoundGlassButton extends StatelessWidget {
  const _RoundGlassButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.9),
          ),
          child: Icon(icon, size: 16, color: AppColors.foreground),
        ),
      ),
    );
  }
}

/// "Trip Overview": the counts, the bookmark, and the post's own blurb.
class _PostOverview extends StatelessWidget {
  const _PostOverview({
    required this.trip,
    required this.blurb,
    required this.saved,
    required this.onSave,
  });

  final ApiTrip trip;
  final String blurb;
  final bool saved;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Trip Overview',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.foreground,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _CountChip(icon: Icons.shuffle, value: trip.remixCount),
            const SizedBox(width: 6),
            // The design's glyph is a bookmark, but the only count the API
            // returns is likes — there is no saveCount on a trip.
            _CountChip(icon: Icons.bookmark_border, value: trip.likeCount),
            const SizedBox(width: 6),
            Tooltip(
              message: saved ? 'เลิกบันทึก' : 'บันทึกทริป',
              child: GestureDetector(
                onTap: onSave,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.chipBorder),
                  ),
                  child: Icon(
                    saved ? Icons.bookmark : Icons.bookmark_border,
                    size: 16,
                    color: AppColors.postPurple,
                  ),
                ),
              ),
            ),
          ],
        ),
        if (blurb.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            blurb,
            style: const TextStyle(
              color: Color(0xFF5F6864),
              fontSize: 14,
              height: 1.6,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final missing = error is ApiException &&
        ((error as ApiException).isNotFound ||
            (error as ApiException).isForbidden);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              missing ? Icons.explore_off_outlined : Icons.cloud_off_outlined,
              size: 44,
              color: AppColors.muted,
            ),
            const SizedBox(height: 14),
            Text(
              missing ? 'ไม่พบทริปนี้' : 'โหลดทริปไม่สำเร็จ',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.foreground,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (!missing) ...[
              const SizedBox(height: 16),
              OutlinedButton(
                  onPressed: onRetry, child: const Text('ลองอีกครั้ง')),
            ],
          ],
        ),
      ),
    );
  }
}

/// The cover block: app bar, creator, title, the four facts, and Remix Trip.
class _ViewHero extends StatelessWidget {
  const _ViewHero({
    required this.plan,
    required this.saved,
    required this.avatarImage,
    required this.onBack,
    required this.onSave,
    required this.onShare,
    required this.onFollow,
  });

  final _PlanView plan;
  final bool saved;

  /// The signed-in user's own photo, for the app bar — not the creator's.
  final String? avatarImage;
  final VoidCallback onBack;
  final VoidCallback onSave;
  final VoidCallback onShare;
  final VoidCallback onFollow;

  @override
  Widget build(BuildContext context) {
    final screen = ScreenClass.of(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
        child: Stack(
          children: [
            Positioned.fill(
              child: CoverImage(source: plan.coverImage, fit: BoxFit.cover),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0, 0.34, 1],
                    colors: [
                      Colors.black.withValues(alpha: 0.66),
                      Colors.black.withValues(alpha: 0.34),
                      Colors.black.withValues(alpha: 0.86),
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  _edgeInset(context),
                  8,
                  _edgeInset(context),
                  18,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TopBar(
                      avatarImage: avatarImage,
                      saved: saved,
                      onBack: onBack,
                      onSave: onSave,
                    ),
                    // const SizedBox(height: 18),
                    // _CreatorRow(
                    //   plan: plan,
                    //   saved: saved,
                    //   onFollow: onFollow,
                    //   onSave: onSave,
                    //   onShare: onShare,
                    // ),
                    SizedBox(height: _heroPhotoGap(screen)),
                    // The title and facts line up with the content column
                    // below, while the bar above stays at the screen's edge.
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: _gutter(context) - _edgeInset(context),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            plan.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: screen.pick(
                                compact: 25.0,
                                medium: 30.0,
                                expanded: 34.0,
                              ),
                              height: 1.2,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _HeroFacts(plan: plan),
                        ],
                      ),
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

/// The app bar the design puts over the cover.
///
/// The design's leading control is a hamburger, but the app has no drawer to
/// open and this page is always arrived at from somewhere else — so the slot
/// carries the back button instead.
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.avatarImage,
    required this.saved,
    required this.onBack,
    required this.onSave,
  });

  final String? avatarImage;
  final bool saved;
  final VoidCallback onBack;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _GlassCircleButton(
          icon: Icons.arrow_back_ios_new,
          tooltip: 'ย้อนกลับ',
          onTap: onBack,
        ),
      ],
    );
  }
}

/// Whose trip this is, with follow on the left and save/share on the right.
class _CreatorRow extends StatelessWidget {
  const _CreatorRow({
    required this.plan,
    required this.saved,
    required this.onFollow,
    required this.onSave,
    required this.onShare,
  });

  final _PlanView plan;
  final bool saved;
  final VoidCallback onFollow;
  final VoidCallback onSave;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.24),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.85),
              width: 1.5,
            ),
          ),
          child: plan.creatorAvatar == null
              ? const Icon(Icons.person, size: 16, color: Colors.white)
              : CoverImage(source: plan.creatorAvatar!, fit: BoxFit.cover),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            plan.creatorName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onFollow,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
            ),
            child: const Text(
              'ติดตาม',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const Spacer(),
        _GlassCircleButton(
          icon: saved ? Icons.bookmark : Icons.bookmark_border,
          tooltip: saved ? 'เลิกบันทึก' : 'บันทึกทริป',
          onTap: onSave,
          size: 34,
        ),
        const SizedBox(width: 8),
        _GlassCircleButton(
          icon: Icons.ios_share,
          tooltip: 'แชร์',
          onTap: onShare,
          size: 34,
        ),
      ],
    );
  }
}

/// Destination, duration, stop count and the per-head budget, on one wrapping
/// row so a long place name cannot push the price off screen.
class _HeroFacts extends StatelessWidget {
  const _HeroFacts({required this.plan});

  final _PlanView plan;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _Fact(icon: Icons.place_outlined, label: plan.destination),
        if (plan.durationLabel.isNotEmpty)
          _Fact(icon: Icons.schedule, label: plan.durationLabel),
        if (plan.stopCount > 0)
          _Fact(
            icon: Icons.pin_drop_outlined,
            label: '${plan.stopCount} สถานที่',
          ),
        if (plan.perHeadLabel != null)
          Text(
            plan.perHeadLabel!,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.9)),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.92),
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// The pinned action bar: one pill, the width of the screen — purple
/// `Remix Trip` on someone else's plan, orange `แก้ไข` on your own.
///
/// It paints its own background, so the bottom inset goes in its padding —
/// wrapping this in a `SafeArea` leaves the button where it is and only the
/// painted panel short of the edge.
class _PlanActionBar extends StatelessWidget {
  const _PlanActionBar({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      // The panel itself is what has to reach the bottom edge, so a test needs
      // to be able to measure it rather than the button inside it.
      key: const Key('plan-action-bar'),
      // The panel spans the screen so it reads as an edge; the pill inside it
      // lines up with the content column rather than stretching across a
      // tablet.
      padding: EdgeInsets.fromLTRB(
        _gutter(context),
        10,
        _gutter(context),
        10 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.screen,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          child: Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }
}

class _GlassCircleButton extends StatelessWidget {
  const _GlassCircleButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.size = 38,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withValues(alpha: 0.34),
            border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
          ),
          child: Icon(icon, size: size * 0.45, color: Colors.white),
        ),
      ),
    );
  }
}

/// "Trip Overview": the heading, the two counts, and the trip's own blurb.
class _OverviewSection extends StatelessWidget {
  const _OverviewSection({required this.plan});

  final _PlanView plan;

  @override
  Widget build(BuildContext context) {
    final screen = ScreenClass.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Trip Overview',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.foreground,
                  fontSize: screen.pick(
                    compact: 19.0,
                    medium: 22.0,
                    expanded: 24.0,
                  ),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _CountChip(
              icon: Icons.shuffle,
              value: plan.remixCount,
            ),
            const SizedBox(width: 8),
            // The design's glyph is a bookmark, but the only count the API
            // returns is likes — there is no saveCount on a trip.
            _CountChip(
              icon: Icons.bookmark_border,
              value: plan.likeCount,
            ),
          ],
        ),
        if (plan.blurb.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            plan.blurb,
            style: TextStyle(
              color: const Color(0xFF5F6864),
              fontSize:
                  screen.pick(compact: 14.5, medium: 15.5, expanded: 16.0),
              height: 1.55,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({required this.icon, required this.value});

  final IconData icon;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.line,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.muted),
          const SizedBox(width: 4),
          Text(
            _grouped(value),
            style: const TextStyle(
              color: AppColors.foreground,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// `วันที่ 1 · วันที่ 2 · …` with the selected day lifted onto a white pill.
///
/// Read-only: adding a day belongs to the editor, not here.
class _DayTabs extends StatelessWidget {
  const _DayTabs({
    required this.days,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<ItineraryDay> days;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.createBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            for (var i = 0; i < days.length; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              _DayPill(
                label: 'วันที่ ${days[i].dayNumber}',
                selected: i == selectedIndex,
                onTap: () => onSelect(i),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DayPill extends StatelessWidget {
  const _DayPill({
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
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
        decoration: BoxDecoration(
          color: selected ? AppColors.screen : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: selected ? Border.all(color: AppColors.chipBorder) : null,
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? _planGreen : AppColors.muted,
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

/// One stop: thumbnail and position, the time it starts, how you get there,
/// and whatever the planner wrote about it.
///
/// The design also shows opening hours and a "Trip hack" note. Neither exists
/// on [Activity] — nor does a street address — so those rows are left out
/// rather than filled with invented copy. See the class doc on
/// [TripDetailScreen].
class _StopCard extends StatelessWidget {
  const _StopCard({
    required this.stop,
    required this.position,
    required this.segment,
    required this.onAdd,
    required this.onSave,
    required this.onMap,
  });

  final Activity stop;
  final int position;
  final TravelSegment? segment;
  final VoidCallback onAdd;
  final VoidCallback onSave;
  final VoidCallback onMap;

  @override
  Widget build(BuildContext context) {
    final place = stop.location?.name;
    // A stop linked to a place repeats its name in [Activity.title], and the
    // design has no room to say the same thing twice.
    final showPlace = place != null && place.isNotEmpty && place != stop.title;
    final notes = stop.notes;
    final screen = ScreenClass.of(context);

    return Container(
      padding: EdgeInsets.all(screen.pick(compact: 12.0, medium: 16.0)),
      decoration: BoxDecoration(
        color: AppColors.screen,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.chipBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StopThumbnail(stop: stop, position: position),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (stop.time != null)
                          Text(
                            clockLabel(stop.time!),
                            style: const TextStyle(
                              color: AppColors.brandOrange,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        const Spacer(),
                        _AddButton(onTap: onAdd),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      stop.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.foreground,
                        fontSize: screen.pick(
                          compact: 14.0,
                          medium: 16.0,
                          expanded: 17.0,
                        ),
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _LegChip(stop: stop, segment: segment),
                  ],
                ),
              ),
            ],
          ),
          if (showPlace) ...[
            const SizedBox(height: 12),
            _StopInfoRow(icon: Icons.place_outlined, text: place),
          ],
          if (notes != null && notes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              notes,
              style: const TextStyle(
                color: Color(0xFF5F6864),
                fontSize: 12,
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _StopAction(
                  icon: Icons.bookmark_border,
                  label: 'บันทึก',
                  onTap: onSave,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StopAction(
                  icon: Icons.place_outlined,
                  label: 'Map',
                  onTap: onMap,
                  filled: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The stop's photo with its position in the day pinned to the corner.
class _StopThumbnail extends StatelessWidget {
  const _StopThumbnail({required this.stop, required this.position});

  final Activity stop;
  final int position;

  @override
  Widget build(BuildContext context) {
    final image = stop.location?.imageUrl;
    final scale =
        ScreenClass.of(context).pick(compact: 1.0, medium: 1.2, expanded: 1.32);

    return SizedBox(
      width: 105 * scale,
      height: 84 * scale,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: image != null && image.isNotEmpty
                  ? CoverImage(source: image, fit: BoxFit.cover)
                  : ColoredBox(
                      color: AppColors.createBg,
                      child: Center(
                        child: Icon(
                          categoryIcon(stop.category),
                          size: 26,
                          color: _planBlack,
                        ),
                      ),
                    ),
            ),
          ),
          Positioned(
            top: -1,
            left: -1,
            child: Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _planBlack,
                border: Border.all(color: AppColors.screen, width: 2),
              ),
              child: Text(
                '$position',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// How you reach this stop from the one before it.
///
/// The first stop of a day has nothing to travel from, so it shows the stop's
/// own category instead of an empty leg.
class _LegChip extends StatelessWidget {
  const _LegChip({required this.stop, required this.segment});

  final Activity stop;
  final TravelSegment? segment;

  @override
  Widget build(BuildContext context) {
    final hasLeg = stop.travelFromPrevious != null || segment != null;
    final icon = hasLeg ? legIcon(stop, segment) : categoryIcon(stop.category);
    final label =
        hasLeg ? legShortLabel(stop, segment) : categoryLabel(stop.category);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.createBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.handleChipRing),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: _planGreen),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _planGreen,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StopInfoRow extends StatelessWidget {
  const _StopInfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: AppColors.muted),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 12.5,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'เพิ่มลงแผนของฉัน',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 26,
          height: 26,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.brandPurple,
          ),
          child: const Icon(Icons.add, size: 16, color: Colors.white),
        ),
      ),
    );
  }
}

/// The pair at the foot of a stop card: an outlined save, a filled map.
class _StopAction extends StatelessWidget {
  const _StopAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final foreground = filled ? Colors.white : AppColors.brandPurple;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? AppColors.searchButton : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: filled
              ? null
              : Border.all(color: AppColors.brandPurple, width: 1.4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: foreground),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: foreground,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyNote extends StatelessWidget {
  const _EmptyNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.createBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Icon(Icons.map_outlined, size: 30, color: AppColors.muted),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Everything the page renders, derived once from the API trip.
class _PlanView {
  const _PlanView({
    required this.title,
    required this.coverImage,
    required this.destination,
    required this.durationLabel,
    required this.stopCount,
    required this.perHeadLabel,
    required this.blurb,
    required this.remixCount,
    required this.likeCount,
    required this.creatorName,
    required this.creatorAvatar,
    required this.days,
  });

  factory _PlanView.of(ApiTrip trip) {
    final schedule = trip.schedule;
    final start = schedule.startDate;
    final end = schedule.endDate;

    // The server derives the duration from the dates whenever it has both, so
    // the stored figures are only trusted on a trip that has none. Mirrors
    // the plan editor's hero.
    final dayCount = schedule.durationDays ??
        (start != null && end != null ? end.difference(start).inDays + 1 : 0);
    final nightCount =
        schedule.durationNights ?? (dayCount > 0 ? dayCount - 1 : 0);

    var stops = 0;
    for (final day in trip.days) {
      stops += day.activities.length;
    }

    // The wizard multiplies a per-person-per-day figure up into the stored
    // whole-trip total, so the design's `/คน` divides one of those back out.
    final heads = trip.customer?.groupSize ?? 1;
    final perHead = trip.totalBudget > 0 && heads > 0
        ? '${(trip.totalBudget / heads).asBaht} /คน'
        : null;

    return _PlanView(
      title: trip.title,
      coverImage: trip.coverImage?.urls.large ?? AppConstants.defaultCoverImage,
      destination: trip.destination,
      durationLabel: dayCount > 0 ? '$dayCount วัน $nightCount คืน' : '',
      stopCount: stops,
      perHeadLabel: perHead,
      blurb: _blurb(trip.brief),
      remixCount: trip.remixCount,
      likeCount: trip.likeCount,
      creatorName: trip.customer?.name ?? 'ไม่ระบุผู้สร้าง',
      creatorAvatar: trip.customer?.avatarUrl,
      days: trip.days,
    );
  }

  final String title;
  final String coverImage;
  final String destination;

  /// "3 วัน 2 คืน", or empty on a trip with neither dates nor a duration.
  final String durationLabel;
  final int stopCount;

  /// "฿3,000 /คน", or null on a trip that adds up to nothing yet.
  final String? perHeadLabel;

  /// The trip's own blurb for Trip Overview.
  ///
  /// `GET /trips/:id` returns no prose: `ApiTrip` has no `description`, and
  /// `specialNotes` is write-only — `createDraft` and `update` send it and
  /// nothing parses it back. Until one of those is readable this is the
  /// brief's styles, which is what the page showed before.
  final String blurb;
  final int remixCount;
  final int likeCount;
  final String creatorName;
  final String? creatorAvatar;

  /// Ordered by day number; empty before an itinerary exists.
  final List<ItineraryDay> days;

  static String _blurb(TripPlanBrief? brief) {
    if (brief == null) return '';
    return <String>[
      ...brief.styles.map((style) => styleLabel(style) ?? style.wire),
      ...brief.customStyles,
    ].join(' · ');
  }
}

/// "1721" as the design's "1,721".
String _grouped(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer(value < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    final remaining = digits.length - i;
    buffer.write(digits[i]);
    if (remaining > 1 && remaining % 3 == 1) buffer.write(',');
  }
  return buffer.toString();
}
