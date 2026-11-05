import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_providers.dart';
import '../../../core/api/pluno_api.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/extensions/currency_extensions.dart';
import '../../../shared/formatting/compact_count.dart';
import '../../../shared/layout/screen_class.dart';
import '../../../shared/widgets/cover_image.dart';
import '../../../shared/widgets/action_sheet.dart';
import '../../../shared/widgets/full_image_viewer.dart';
import '../../create_trip/domain/plan_labels.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../follow/presentation/follow_actions.dart';
import '../../follow/presentation/providers/follow_providers.dart';
import '../../trips/presentation/providers/trip_like_providers.dart';
import '../../trips/presentation/providers/trip_providers.dart';
import '../../trips/presentation/trip_like_action.dart';
import '../../create_post/presentation/widgets/trip_link_picker.dart';
import '../../my_trips/presentation/delete_trip.dart';
import '../../my_trips/presentation/providers/my_trips_providers.dart';
import '../../paigun/presentation/providers/paigun_providers.dart';
import '../../profile/presentation/providers/profile_providers.dart';
import 'share_trip.dart';
import 'widgets/add_to_trip_sheet.dart';
import 'widgets/plan_stop_card.dart';
import 'widgets/remix_sheet.dart';
import 'widgets/trip_content_sections.dart';

/// The deep green behind a day number, shared with the plan editor's design.
const _planGreen = Color(0xFF2E6B4C);

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

/// The pinned bar's own height, above the status-bar inset.
const _topBarHeight = 44.0;

class _TripDetailScreenState extends ConsumerState<TripDetailScreen> {
  int _selectedDay = 0;

  /// Shared with the sticky bar so it can fade its background in as the
  /// cover scrolls out from under it. Both faces use it; only one is ever up.
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trip = ref.watch(apiTripProvider(widget.tripId));

    return Scaffold(
      backgroundColor: AppColors.screen,
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

  Widget _body(ApiTrip trip) {
    final post = trip.type.isPost;
    // The bar is stacked over the scroll view rather than slivered into it:
    // it has to stay put while the cover and the stops slide under it, and a
    // `SliverAppBar` would squash the Remix pill as it collapsed.
    return Stack(
      children: [
        post ? _contentScroll(trip) : _planScroll(trip),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _StickyTopBar(
            scroll: _scroll,
            trip: trip,
            owned: _owns(trip),
            onBack: _leave,
            onMenu: (action) => switch (action) {
              _TripMenuAction.edit => _edit(trip),
              _TripMenuAction.delete => _delete(trip),
              // Only the owner can mint a link; a visitor's แชร์ waits on a
              // public URL the web can serve for anyone's trip.
              _TripMenuAction.share => _owns(trip) == true
                  ? shareTripLink(
                      context,
                      ref,
                      tripId: trip.id,
                      title: trip.title,
                    )
                  : _snack(
                      post
                          ? 'แชร์โพสต์ยังไม่เปิดใช้งาน'
                          : 'แชร์ทริปยังไม่เปิดใช้งาน',
                    ),
            },
          ),
        ),
      ],
    );
  }

  /// Whether the viewer owns this trip, or null while `/auth/me` is still
  /// answering — guessing "visitor" there would flash Remix on the owner's
  /// own trip before it flips to edit. Signed out, or a failed session read,
  /// is not the owner.
  bool? _owns(ApiTrip trip) {
    final viewer = ref.watch(currentUserProvider);
    if (viewer.isLoading) return null;
    return viewer.valueOrNull?.id == trip.ownerId;
  }

  /// Trip Overview with the viewer's own heart and bookmark read through the
  /// app-wide ledgers, so a tap here shows on every wall and back again.
  Widget _overview(ApiTrip trip, {required String blurb, int? placeCount}) {
    final liked = ref.watch(tripLikedProvider)[trip.id] ?? trip.isLiked;
    final owned = _owns(trip);
    return _PostOverview(
      trip: trip,
      blurb: blurb,
      placeCount: placeCount,
      liked: liked,
      // A visitor's bookmark only, as in the bar: saving your own trip
      // changes nothing you can see.
      saved: owned == false
          ? ref.watch(paigunSavedProvider)[trip.id] ?? trip.isSaved
          : null,
      onLike: () => toggleTripLikeById(
        context,
        ref,
        tripId: trip.id,
        wasLiked: liked,
      ),
      onSave: () => _toggleSaved(trip),
    );
  }

  /// The bar's bookmark, through the app-wide ledger so Home, ไปกัน and the
  /// saved shelf flip with it. Signed out, it asks for an account instead.
  Future<void> _toggleSaved(ApiTrip trip) async {
    if (!ref.read(isSignedInProvider)) return _promptSignIn();
    final wasSaved = ref.read(paigunSavedProvider)[trip.id] ?? trip.isSaved;
    try {
      await ref
          .read(paigunSavedProvider.notifier)
          .toggle(trip.id, wasSaved: wasSaved);
      _snack(wasSaved ? 'เอาออกจากทริปที่บันทึกไว้แล้ว' : 'บันทึกทริปแล้ว');
    } on ApiException catch (failure) {
      if (failure.isUnauthorized) return _promptSignIn();
      _snack(
        failure.isNetworkFailure
            ? 'เชื่อมต่อไม่ได้ ลองใหม่อีกครั้ง'
            : 'บันทึกทริปไม่สำเร็จ: ${failure.message}',
      );
    }
  }

  void _promptSignIn() {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: const Text('เข้าสู่ระบบก่อนเพื่อบันทึกทริป'),
          action: SnackBarAction(
            label: 'เข้าสู่ระบบ',
            onPressed: () => context.goNamed(AppRoute.login.name),
          ),
        ),
      );
  }

  void _remix() => context.goNamed(
        AppRoute.remixTrip.name,
        params: {'tripId': widget.tripId},
      );

  /// Remix picks stops and puts them on the staging shelf of one of your
  /// own plans. A plan's stops are its own; a post's are its linked plan's,
  /// with the post as the source so the remix counts on it too. With nothing
  /// to pick — an empty plan, a post with no plan — it keeps the whole-trip
  /// remix route.
  Future<void> _remixStops(ApiTrip trip) async {
    var plan = trip;
    final linked = trip.linkedTrip;
    if (trip.type.isPost) {
      if (linked == null) return _remix();
      try {
        plan = await ref.read(apiTripProvider(linked.id).future);
      } catch (_) {
        _snack('อ่านแผนของโพสต์นี้ไม่สำเร็จ');
        return;
      }
      if (!mounted) return;
    }

    final days = [...plan.days]
      ..sort((a, b) => a.dayNumber.compareTo(b.dayNumber));
    final stops = [for (final day in days) ...day.activities];
    if (stops.isEmpty) return _remix();

    final result = await showRemixSheet(
      context,
      sourceTripId: trip.id,
      stops: stops,
    );
    if (result == null) return;
    final skipped =
        result.skipped > 0 ? ' · ${result.skipped} สถานที่อยู่ในทริปแล้ว' : '';
    _snack(
      result.replayed || result.added == 0
          ? 'Remix ลง ${result.tripTitle} แล้ว$skipped'
          : 'Remix ${result.added} สถานที่ลง ${result.tripTitle} แล้ว$skipped',
    );
  }

  /// A post: the cover hero, Trip Overview, then the spots.
  Widget _contentScroll(ApiTrip trip) {
    final blurb = trip.description?.trim() ?? '';

    return CustomScrollView(
      controller: _scroll,
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: _PostHero(
            trip: trip,
            owned: _owns(trip),
            onRemix: () => _remixStops(trip),
          ),
        ),
        SliverPadding(
          padding:
              EdgeInsets.fromLTRB(_gutter(context), 20, _gutter(context), 0),
          sliver: SliverToBoxAdapter(
            child: _overview(trip, blurb: blurb),
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

  /// A plan, the same way up as a post: the cover hero with its one action,
  /// Trip Overview, then ตารางแผน — the stops day by day on white.
  Widget _planScroll(ApiTrip trip) {
    final plan = _PlanView.of(trip);
    // A trip whose days were deleted must not leave the tab strip pointing
    // past the end of the list.
    final dayIndex =
        plan.days.isEmpty ? 0 : _selectedDay.clamp(0, plan.days.length - 1);
    final day = plan.days.isEmpty ? null : plan.days[dayIndex];
    final stops = day?.activities ?? const <Activity>[];
    final description = trip.description?.trim() ?? '';
    final gutter = _gutter(context);

    return CustomScrollView(
      controller: _scroll,
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: _PostHero(
            trip: trip,
            owned: _owns(trip),
            onRemix: () => _remixStops(trip),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(gutter, 20, gutter, 22),
          sliver: SliverToBoxAdapter(
            child: _overview(
              trip,
              blurb: description.isNotEmpty ? description : plan.blurb,
              placeCount: plan.stopCount,
            ),
          ),
        ),
        if (trip.contents.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 22),
              child: TripContentSections(
                sections: trip.contents,
                gutter: gutter,
              ),
            ),
          ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: ColoredBox(
            color: AppColors.screen,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                gutter,
                24,
                gutter,
                28 + MediaQuery.paddingOf(context).bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'ตารางแผน',
                    style: TextStyle(
                      color: AppColors.foreground,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // One day needs no tabs to choose between.
                  if (plan.days.length > 1) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _DayTabs(
                        days: plan.days,
                        selectedIndex: dayIndex,
                        onSelect: (index) =>
                            setState(() => _selectedDay = index),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (plan.days.isEmpty)
                    const _EmptyNote(text: 'ทริปนี้ยังไม่มีแผนการเดินทาง')
                  else if (stops.isEmpty)
                    const _EmptyNote(text: 'วันนี้ยังไม่มีสถานที่')
                  else
                    for (var i = 0; i < stops.length; i++) ...[
                      PlanStopCard(
                        key: ValueKey(stops[i].id),
                        stop: stops[i],
                        position: i + 1,
                        segment: day!.segmentInto(stops[i]),
                        onAction: (action) => _onStopAction(stops[i], action),
                      ),
                      if (i < stops.length - 1) const SizedBox(height: 14),
                    ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// A post is edited on its share settings and re-read on the way back; a
  /// plan opens its editor.
  Future<void> _edit(ApiTrip trip) async {
    if (!trip.type.isPost) {
      context.goNamed(
        AppRoute.editTrip.name,
        params: {'tripId': widget.tripId},
      );
      return;
    }
    await context.pushNamed(
      AppRoute.shareSettings.name,
      params: {'tripId': widget.tripId},
    );
    if (mounted) ref.invalidate(apiTripProvider(widget.tripId));
  }

  /// Asks in the same words as the walls, deletes, then leaves — there is
  /// nothing left on this page to show.
  Future<void> _delete(ApiTrip trip) async {
    if (!await askToDeleteTrip(context, trip.title)) return;
    try {
      final api = await ref.read(plunoApiProvider.future);
      await api.trips.delete(trip.id);
    } on ApiException catch (error) {
      _snack(
        error.statusCode == 401 ? 'เข้าสู่ระบบก่อน จึงจะลบได้' : error.message,
      );
      return;
    } catch (_) {
      _snack('ลบไม่สำเร็จ ลองอีกครั้ง');
      return;
    }
    // Every wall of the traveller's own trips would otherwise keep the row.
    ref
      ..invalidate(myTripsProvider)
      ..invalidate(myAlbumsProvider)
      ..invalidate(myPlansProvider);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    _leave();
    messenger.showSnackBar(const SnackBar(content: Text('ลบทริปแล้ว')));
  }

  Future<void> _onStopAction(Activity stop, PlanStopAction action) async {
    switch (action) {
      case PlanStopAction.map:
        await _openMap(stop);
      case PlanStopAction.save:
        _snack('บันทึกสถานที่ยังไม่เปิดใช้งาน');
      case PlanStopAction.addToTrip:
        final result = await showAddToTripSheet(context, stop: stop);
        if (!mounted) return;
        switch (result) {
          case AddedToTrip(:final tripTitle):
            _snack('เพิ่ม ${stop.title} ลง $tripTitle แล้ว');
          case AddToNewTrip():
            context.pushNamed(AppRoute.createTrip.name);
          case null:
            break;
        }
    }
  }

  /// "นำทางบน Map" — Google Maps at the stop's pin, or a search for its name
  /// when the stop was typed by hand and has no coordinates.
  Future<void> _openMap(Activity stop) async {
    final location = stop.location;
    final query = location != null && location.hasCoordinates
        ? '${location.latitude},${location.longitude}'
        : [location?.name ?? stop.title, _destination]
            .where((part) => part.isNotEmpty)
            .join(' ');
    final uri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': query,
    });
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) _snack('เปิดแผนที่ไม่สำเร็จ');
    } catch (_) {
      _snack('เปิดแผนที่ไม่สำเร็จ');
    }
  }

  String get _destination =>
      ref.read(apiTripProvider(widget.tripId)).valueOrNull?.destination ?? '';

  /// Home is the safe fallback: the page is reachable from four places, and
  /// from a cold deep link there is nothing to pop back to.
  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.goNamed(AppRoute.home.name);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

/// The post's top bar, pinned over the scrolling page.
///
/// Transparent while it sits on the cover photo, fading to a dark bar as the
/// cover slides out from under it — otherwise white text and glass buttons
/// would end up on the white content below.
class _StickyTopBar extends StatefulWidget {
  const _StickyTopBar({
    required this.scroll,
    required this.trip,
    required this.owned,
    required this.onBack,
    required this.onMenu,
  });

  final ScrollController scroll;
  final ApiTrip trip;

  /// Null while it is not yet known who is looking — the menu offers only
  /// แชร์ until it is.
  final bool? owned;
  final VoidCallback onBack;
  final ValueChanged<_TripMenuAction> onMenu;

  @override
  State<_StickyTopBar> createState() => _StickyTopBarState();
}

class _StickyTopBarState extends State<_StickyTopBar> {
  /// How far the cover has gone, 0 to 1. Only this widget rebuilds on scroll —
  /// lifting it into the screen's state would rebuild the whole page per frame.
  double _past = 0;

  /// Roughly the cover below the bar, so the background is solid by the time
  /// the page's own white has reached it.
  static const _fadeOver = 170.0;

  @override
  void initState() {
    super.initState();
    widget.scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.scroll.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (!widget.scroll.hasClients) return;
    final next = (widget.scroll.offset / _fadeOver).clamp(0.0, 1.0);
    // A hair of hysteresis: a setState per scroll frame is wasted work.
    if ((next - _past).abs() < 0.02 && next != 0 && next != 1) return;
    if (next != _past) setState(() => _past = next);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: ColoredBox(
        color: const Color(0xFF14110F).withValues(alpha: 0.92 * _past),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
                _edgeInset(context), 10, _edgeInset(context), 0),
            child: SizedBox(
              height: _topBarHeight - 2,
              child: Row(
                children: [
                  _RoundGlassButton(
                    icon: Icons.arrow_back_ios_new,
                    tooltip: 'ย้อนกลับ',
                    onTap: widget.onBack,
                  ),
                  Expanded(
                    child: _PostAuthor(
                      trip: widget.trip,
                      owned: widget.owned,
                    ),
                  ),
                  // Saving lives in Trip Overview's row, beside the heart.
                  _TripMenu(owned: widget.owned, onSelected: widget.onMenu),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The cover hero: the trip's title over its cover, and Remix for a visitor.
/// The owner gets no button here — editing lives in the header's ☰ menu. Shared by both faces; the author
/// row is the pinned bar's, drawn over the top of it.
class _PostHero extends StatelessWidget {
  const _PostHero({
    required this.trip,
    required this.owned,
    required this.onRemix,
  });

  final ApiTrip trip;

  /// Null while it is not yet known who is looking.
  final bool? owned;
  final VoidCallback onRemix;

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
                    // The row itself lives in the pinned bar above; this is
                    // the space it occupies over the cover.
                    const SizedBox(height: _topBarHeight + 14),
                    // Full width so the title centres on its own: the owner's
                    // hero has no Remix pill to stretch the column for it.
                    SizedBox(
                      width: double.infinity,
                      child: Text(
                        trip.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          height: 1.4,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    // Remix is the visitor's; the owner edits from the ☰
                    // menu instead, so their hero carries no button at all.
                    // The slot holds its height while the viewer is unknown,
                    // so a visitor's hero does not jump when Remix lands.
                    // Nor does a viewer the server says may not remix it.
                    if (owned != true && trip.canRemix != false) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: owned == false
                            ? _HeroAction(
                                label: 'Remix Trip',
                                icon: Icons.shuffle,
                                color: AppColors.brandPurple,
                                foreground: AppColors.handleChipRing,
                                onTap: onRemix,
                              )
                            : null,
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

/// The hero's one pill: Remix for a visitor, edit for the owner.
class _HeroAction extends StatelessWidget {
  const _HeroAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.foreground = Colors.white,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  /// The label and glyph — lime on Remix's purple, white on edit's coral.
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: foreground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(99),
        ),
      ),
    );
  }
}

/// The author, centred between the two round buttons. Tapping them opens
/// their profile; the chip follows them.
///
/// The trip says nothing about follows, so whether the viewer already follows
/// the author comes from their profile — read only for someone else's trip.
/// No chip on your own, or while it is not yet known whose it is.
class _PostAuthor extends ConsumerWidget {
  const _PostAuthor({required this.trip, required this.owned});

  final ApiTrip trip;
  final bool? owned;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authorId = trip.ownerId;
    final showFollow = owned == false;
    final following = showFollow &&
        resolveFollowing(
          ref,
          authorId,
          ref.watch(userProfileProvider(authorId)).valueOrNull?.isFollowing ??
              false,
        );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: GestureDetector(
            onTap: () => openUserProfile(context, authorId),
            behavior: HitTestBehavior.opaque,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
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
              ],
            ),
          ),
        ),
        if (showFollow) ...[
          const SizedBox(width: 7),
          GestureDetector(
            onTap: () => toggleFollow(
              context,
              ref,
              userId: authorId,
              following: following,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
              ),
              child: Text(
                following ? 'กำลังติดตาม' : 'ติดตาม',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Where, how long, how many places and what per head.
///
/// Under Trip Overview as of Figma 2532-82227 — it used to sit on the hero.
/// The duration and the place count describe the **linked plan** when there is
/// one (a post has no schedule of its own) and fall back to the post's own
/// figures otherwise.
class _PostFacts extends StatelessWidget {
  const _PostFacts({required this.trip, this.placeCount});

  final ApiTrip trip;

  /// A plan's own stop count; a post counts its linked plan's places.
  final int? placeCount;

  @override
  Widget build(BuildContext context) {
    // Every photo in the post, across all its spots — "ดูรูป (24)".
    final photos = postPhotoUrls(trip.contents);
    final linked = trip.linkedTrip;
    final schedule = linked?.schedule ?? trip.schedule;
    final start = schedule.startDate;
    final end = schedule.endDate;
    final days = schedule.durationDays ??
        (start != null && end != null ? end.difference(start).inDays + 1 : 0);

    final places = placeCount ?? linked?.placeCount ?? trip.contents.length;
    final heads = trip.customer?.groupSize ?? 1;
    final perHead = trip.totalBudget > 0 && heads > 0
        ? '${(trip.totalBudget / heads).asBaht}/คน'
        : null;

    final facts = <String>[
      if (days > 0) '$days วัน',
      if (places > 0) '$places สถานที่',
      if (perHead != null) perHead,
    ];

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: [
        if (photos.isNotEmpty) ...[
          _PhotosPill(
            count: photos.length,
            onTap: () => showFullImages(context, urls: photos),
          ),
          const SizedBox(width: 2),
        ],
        if (trip.destination.isNotEmpty) ...[
          const Icon(
            Icons.location_on_outlined,
            size: 14,
            color: AppColors.postPurple,
          ),
          Text(
            trip.destination,
            style: const TextStyle(
              color: AppColors.postPurple,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.underline,
            ),
          ),
        ],
        for (final fact in facts) ...[
          const _FactText('·'),
          _FactText(fact),
        ],
      ],
    );
  }
}

/// "ดูรูป (24)" — every photo in the post, opened full size in one gallery.
class _PhotosPill extends StatelessWidget {
  const _PhotosPill({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.brandPurple,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.photo_library_outlined,
                size: 15, color: Colors.white),
            const SizedBox(width: 5),
            Text(
              'ดูรูป ($count)',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
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
      style: const TextStyle(
        color: AppColors.muted,
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

/// What the header's ☰ offers.
enum _TripMenuAction { edit, delete, share }

/// ☰ in the pinned bar: แก้ไขทริป, ลบทริป and แชร์ for the owner, only แชร์
/// for anyone else — offered on a bottom sheet.
class _TripMenu extends StatelessWidget {
  const _TripMenu({required this.owned, required this.onSelected});

  final bool? owned;
  final ValueChanged<_TripMenuAction> onSelected;

  Future<void> _open(BuildContext context) async {
    final action = await showActionSheet<_TripMenuAction>(
      context,
      items: [
        if (owned == true) ...const [
          ActionSheetItem(
            value: _TripMenuAction.edit,
            icon: Icons.edit_outlined,
            label: 'แก้ไขทริป',
          ),
          ActionSheetItem(
            value: _TripMenuAction.delete,
            icon: Icons.delete_outline,
            label: 'ลบทริป',
            destructive: true,
          ),
        ],
        const ActionSheetItem(
          value: _TripMenuAction.share,
          icon: Icons.share_outlined,
          label: 'แชร์',
        ),
      ],
    );
    if (action != null) onSelected(action);
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'เมนู',
      child: GestureDetector(
        onTap: () => _open(context),
        behavior: HitTestBehavior.opaque,
        child: const _GlassCircle(
          child: Icon(Icons.menu, size: 18, color: AppColors.postHeader),
        ),
      ),
    );
  }
}

/// The bar's round button face: frosted, see-through glass rather than a
/// solid white disc, so the cover reads through it — a light wash, the
/// picture blurred behind, and a thin bright rim to hold the edge.
class _GlassCircle extends StatelessWidget {
  const _GlassCircle({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.38),
            border: Border.all(color: Colors.white.withValues(alpha: 0.55)),
          ),
          child: child,
        ),
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
        child: _GlassCircle(
          child: Icon(icon, size: 16, color: AppColors.postHeader),
        ),
      ),
    );
  }
}

/// "Trip Overview": remix · heart · bookmark, the facts, and the blurb.
///
/// The row reads like a card's counts row: `remixCount`, `likeCount` and
/// `saveCount`, the heart and the bookmark moved by one for an unsent tap.
class _PostOverview extends StatelessWidget {
  const _PostOverview({
    required this.trip,
    required this.blurb,
    required this.liked,
    required this.saved,
    required this.onLike,
    required this.onSave,
    this.placeCount,
  });

  final ApiTrip trip;
  final String blurb;
  final int? placeCount;

  /// The heart as it stands now — the ledger's answer over the trip's.
  final bool liked;

  /// Null makes the bookmark a readout: the owner's trip (nothing to save),
  /// or a viewer not yet known. It then shows only once someone has saved it.
  final bool? saved;
  final VoidCallback onLike;
  final VoidCallback onSave;

  /// The ledger stores only the bool, so an unsent flip moves the number here
  /// rather than waiting for a re-read of the trip.
  int get _likes {
    final moved = liked == trip.isLiked ? 0 : (liked ? 1 : -1);
    final count = trip.likeCount + moved;
    return count < 0 ? 0 : count;
  }

  /// [_likes] for the bookmark. With no [saved] of the viewer's own there is
  /// no tap to count, so the server's figure stands.
  int get _saves {
    final saved = this.saved;
    final moved = saved == null || saved == trip.isSaved ? 0 : (saved ? 1 : -1);
    final count = trip.saveCount + moved;
    return count < 0 ? 0 : count;
  }

  @override
  Widget build(BuildContext context) {
    final saved = this.saved;

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
            _CountChip(
              icon: Icons.shuffle,
              value: trip.remixCount,
            ),
            const SizedBox(width: 6),
            _CountChip(
              key: const Key('like-chip'),
              icon: liked ? Icons.favorite : Icons.favorite_border,
              iconColor: liked ? _heartRed : AppColors.muted,
              value: _likes,
              tooltip: liked ? 'เลิกถูกใจ' : 'ถูกใจ',
              onTap: onLike,
            ),
            if (saved != null) ...[
              const SizedBox(width: 6),
              _CountChip(
                key: const Key('save-chip'),
                icon: saved ? Icons.bookmark : Icons.bookmark_border,
                iconColor: saved ? AppColors.postPurple : AppColors.muted,
                value: _saves,
                tooltip: saved ? 'เอาออกจากที่บันทึก' : 'บันทึก',
                onTap: onSave,
              ),
            ] else if (_saves > 0) ...[
              const SizedBox(width: 6),
              _CountChip(
                key: const Key('save-chip'),
                icon: Icons.bookmark_border,
                value: _saves,
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        _PostFacts(trip: trip, placeCount: placeCount),
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

/// The heart, filled.
const _heartRed = Color(0xFFE5484D);

/// A lavender pill: a glyph and, when there is one, its count. Tappable when
/// [onTap] is given — the heart and the bookmark; the remix count is not.
class _CountChip extends StatelessWidget {
  const _CountChip({
    super.key,
    required this.icon,
    this.value,
    this.iconColor = AppColors.muted,
    this.tooltip,
    this.onTap,
  });

  final IconData icon;

  /// Null draws the glyph alone.
  final int? value;
  final Color iconColor;
  final String? tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final value = this.value;
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.postPurpleWell,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: iconColor),
          if (value != null) ...[
            const SizedBox(width: 4),
            Text(
              compactCount(value),
              style: const TextStyle(
                color: AppColors.foreground,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
    if (onTap == null) return chip;

    return Tooltip(
      message: tooltip ?? '',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: chip,
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

/// The parts of a plan the page derives rather than reads straight off it.
class _PlanView {
  const _PlanView({
    required this.stopCount,
    required this.blurb,
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

    var stops = 0;
    for (final day in trip.days) {
      stops += day.activities.length;
    }

    return _PlanView(
      stopCount: stops,
      blurb: _blurb(trip.brief),
      days: _daysOf(trip, dayCount, start),
    );
  }

  /// Every day the trip claims, not only the ones with an itinerary row.
  ///
  /// A row is created when the first stop is added to that day, so a reader
  /// looking at a four-day trip with one filled day would otherwise be told
  /// it is a one-day trip — while the hero above says "4 วัน". The days with
  /// nothing in them show their own empty note.
  static List<ItineraryDay> _daysOf(
    ApiTrip trip,
    int dayCount,
    DateTime? start,
  ) {
    // A plan with nothing in it at all keeps its own empty note — a reader is
    // better served by "ทริปนี้ยังไม่มีแผนการเดินทาง" than by a row of empty
    // day tabs. Placeholders fill gaps in a plan that has begun, nothing more.
    if (trip.days.isEmpty) return const <ItineraryDay>[];

    final rows = <int, ItineraryDay>{
      for (final day in trip.days) day.dayNumber: day,
    };
    final highest = rows.keys.fold<int>(0, (a, b) => a > b ? a : b);
    final total = dayCount > highest ? dayCount : highest;

    return [
      for (var number = 1; number <= total; number++)
        rows[number] ??
            ItineraryDay(
              id: '',
              dayNumber: number,
              date: start?.add(Duration(days: number - 1)),
              activities: const <Activity>[],
              travelSegments: const <TravelSegment>[],
            ),
    ];
  }

  final int stopCount;

  /// What Trip Overview prints when the plan has no description of its own:
  /// the brief's styles, which is what the page showed before
  /// `ApiTrip.description` was readable.
  final String blurb;

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
