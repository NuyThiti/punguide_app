import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/extensions/currency_extensions.dart';
import '../../../shared/widgets/cover_image.dart';
import '../../saved_trips/presentation/saved_trips_notifier.dart';
import '../../trips/domain/models/trip.dart';
import '../../trips/presentation/providers/trip_providers.dart';

class TripDetailScreen extends ConsumerStatefulWidget {
  const TripDetailScreen({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends ConsumerState<TripDetailScreen> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    final trip = ref.watch(selectedTripProvider(widget.tripId));

    return Scaffold(
      backgroundColor: AppColors.softScreen,
      body: trip.when(
        data: (trip) {
          if (trip == null) {
            return const Center(child: Text('Trip not found.'));
          }

          final meta = _DetailMeta.fromTrip(trip);

          return Stack(
            children: [
              CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: _HeroSection(
                      trip: trip,
                      meta: meta,
                      onBack: () => context.goNamed(AppRoute.home.name),
                      onSave: () => _toggleSaved(trip),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 124),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate(
                        [
                          _CreatorRow(meta: meta),
                          const SizedBox(height: 18),
                          _StatsCard(trip: trip, meta: meta),
                          const SizedBox(height: 18),
                          Text(
                            trip.description,
                            style: const TextStyle(
                              color: Color(0xFF5F6864),
                              fontSize: 16,
                              height: 1.45,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 24),
                          _DetailTabs(
                            selectedIndex: _selectedTab,
                            onChanged: (index) {
                              setState(() => _selectedTab = index);
                            },
                          ),
                          const SizedBox(height: 24),
                          _TabContent(
                            trip: trip,
                            meta: meta,
                            selectedIndex: _selectedTab,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: 18,
                child: SafeArea(
                  top: false,
                  child: _BottomActions(
                    trip: trip,
                    onSave: () => _toggleSaved(trip),
                    onRemix: () => context.goNamed(
                      AppRoute.remixTrip.name,
                      params: {'tripId': trip.id},
                    ),
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
      ),
    );
  }

  void _toggleSaved(Trip trip) {
    final notifier = ref.read(savedTripsNotifierProvider.notifier);
    if (trip.isSaved) {
      notifier.unsaveTrip(trip.id);
    } else {
      notifier.saveTrip(trip);
    }
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({
    required this.trip,
    required this.meta,
    required this.onBack,
    required this.onSave,
  });

  final Trip trip;
  final _DetailMeta meta;
  final VoidCallback onBack;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 300,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CoverImage(source: trip.coverImage, fit: BoxFit.cover),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.06),
                  Colors.black.withOpacity(0.12),
                  Colors.black.withOpacity(0.62),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _CircleIconButton(
                    icon: Icons.arrow_back,
                    onTap: onBack,
                    background: Colors.white.withOpacity(0.92),
                    color: AppColors.foreground,
                  ),
                  Row(
                    children: [
                      _CircleIconButton(
                        icon: Icons.ios_share,
                        onTap: () {},
                        background: Colors.white.withOpacity(0.92),
                        color: AppColors.foreground,
                      ),
                      const SizedBox(width: 10),
                      _CircleIconButton(
                        icon: trip.isSaved
                            ? Icons.bookmark
                            : Icons.bookmark_border,
                        onTap: onSave,
                        background: Colors.white.withOpacity(0.92),
                        color: trip.isSaved
                            ? AppColors.primary
                            : AppColors.foreground,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 22,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: meta.tags
                      .map((tag) => _TagPill(label: tag, color: _tagColor(tag)))
                      .toList(),
                ),
                const SizedBox(height: 12),
                Text(
                  trip.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        trip.destination,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.90),
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.onTap,
    required this.background,
    required this.color,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color background;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(color: background, shape: BoxShape.circle),
        child: Icon(icon, size: 20, color: color),
      ),
    );
  }
}

class _TagPill extends StatelessWidget {
  const _TagPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.34),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white.withOpacity(0.68)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _CreatorRow extends StatelessWidget {
  const _CreatorRow({required this.meta});

  final _DetailMeta meta;

  @override
  Widget build(BuildContext context) {
    return Container(
      transform: Matrix4.translationValues(0, -14, 0),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Text(meta.avatar, style: const TextStyle(fontSize: 22)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meta.creator,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.foreground,
                    fontSize: 15,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  meta.handle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          _MiniSignal(icon: Icons.bookmark_border, label: meta.saves),
          const SizedBox(width: 12),
          _MiniSignal(icon: Icons.call_split, label: '${meta.remixes}'),
        ],
      ),
    );
  }
}

class _MiniSignal extends StatelessWidget {
  const _MiniSignal({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.muted),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.trip, required this.meta});

  final Trip trip;
  final _DetailMeta meta;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatItem(
              icon: Icons.access_time,
              value: '${trip.duration} days',
              label: 'DURATION',
            ),
          ),
          _StatDivider(),
          Expanded(
            child: _StatItem(
              icon: Icons.attach_money,
              value: trip.budget.asBudget,
              label: 'BUDGET',
            ),
          ),
          _StatDivider(),
          Expanded(
            child: _StatItem(
              icon: Icons.group_outlined,
              value: meta.travelers,
              label: 'TRAVELERS',
            ),
          ),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 72,
      color: Colors.black.withOpacity(0.06),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
      child: Column(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.foreground,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 10,
              letterSpacing: 0,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailTabs extends StatelessWidget {
  const _DetailTabs({
    required this.selectedIndex,
    required this.onChanged,
  });

  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const labels = ['Itinerary', 'Budget', 'Places'];

    return Row(
      children: List.generate(labels.length, (index) {
        final selected = selectedIndex == index;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              height: 50,
              margin: EdgeInsets.only(
                right: index == labels.length - 1 ? 0 : 10,
              ),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppColors.foreground : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(selected ? 0.18 : 0.05),
                    blurRadius: selected ? 18 : 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Text(
                labels[index],
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.muted,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _TabContent extends StatelessWidget {
  const _TabContent({
    required this.trip,
    required this.meta,
    required this.selectedIndex,
  });

  final Trip trip;
  final _DetailMeta meta;
  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    if (selectedIndex == 1) {
      return _BudgetPanel(trip: trip);
    }
    if (selectedIndex == 2) {
      return _PlacesPanel(meta: meta);
    }
    return _ItineraryPanel(trip: trip, meta: meta);
  }
}

class _ItineraryPanel extends StatelessWidget {
  const _ItineraryPanel({required this.trip, required this.meta});

  final Trip trip;
  final _DetailMeta meta;

  @override
  Widget build(BuildContext context) {
    final days = _TripDay.samplesFor(trip, meta);

    return Column(
      children: days.map((day) {
        final isExpanded = day.day == 1;
        return _DayCard(day: day, expanded: isExpanded);
      }).toList(),
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({required this.day, required this.expanded});

  final _TripDay day;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 18,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(expanded ? 1 : 0.10),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${day.day}',
                  style: TextStyle(
                    color: expanded ? Colors.white : AppColors.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DAY ${day.day}',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      day.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.foreground,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.04),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
          if (expanded) ...[
            const SizedBox(height: 18),
            Column(
              children: day.items
                  .map((item) => _TimelineItem(item: item))
                  .toList(),
            ),
            if (day.tip.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  day.tip,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({required this.item});

  final _TripStop item;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 56,
            child: Text(
              item.time,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Column(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: item.color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
              Expanded(
                child: Container(
                  width: 1,
                  color: Colors.black.withOpacity(0.07),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFAFBFA),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.black.withOpacity(0.04)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: item.color.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(item.icon, size: 17, color: item.color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.foreground,
                            fontSize: 14,
                            height: 1.2,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          item.place,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _TypeChip(label: item.type, color: item.color),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _BudgetPanel extends StatelessWidget {
  const _BudgetPanel({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final lodging = trip.budget * 0.42;
    final food = trip.budget * 0.24;
    final transport = trip.budget * 0.20;
    final buffer = trip.budget - lodging - food - transport;

    return Column(
      children: [
        _BudgetLine(label: 'Stays', value: lodging, color: AppColors.primary),
        _BudgetLine(label: 'Food', value: food, color: AppColors.accent),
        _BudgetLine(label: 'Transport', value: transport, color: Colors.blue),
        _BudgetLine(label: 'Flex fund', value: buffer, color: Colors.purple),
      ],
    );
  }
}

class _BudgetLine extends StatelessWidget {
  const _BudgetLine({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.payments_outlined, color: color, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.foreground,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            value.asBudget,
            style: const TextStyle(
              color: AppColors.foreground,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlacesPanel extends StatelessWidget {
  const _PlacesPanel({required this.meta});

  final _DetailMeta meta;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: meta.places.map((place) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.place_outlined,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  place,
                  style: const TextStyle(
                    color: AppColors.foreground,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.muted),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _BottomActions extends StatelessWidget {
  const _BottomActions({
    required this.trip,
    required this.onSave,
    required this.onRemix,
  });

  final Trip trip;
  final VoidCallback onSave;
  final VoidCallback onRemix;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.14),
            blurRadius: 26,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _ActionButton(
              icon: trip.isSaved ? Icons.bookmark : Icons.bookmark_border,
              label: trip.isSaved ? 'Saved' : 'Save Trip',
              filled: true,
              onTap: onSave,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ActionButton(
              icon: Icons.call_split,
              label: 'Remix Trip',
              filled: false,
              onTap: onRemix,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.filled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled
              ? AppColors.primary
              : AppColors.primary.withOpacity(0.10),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: filled ? Colors.white : AppColors.primary,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: filled ? Colors.white : AppColors.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailMeta {
  const _DetailMeta({
    required this.tags,
    required this.avatar,
    required this.creator,
    required this.handle,
    required this.saves,
    required this.remixes,
    required this.travelers,
    required this.places,
  });

  final List<String> tags;
  final String avatar;
  final String creator;
  final String handle;
  final String saves;
  final int remixes;
  final String travelers;
  final List<String> places;

  factory _DetailMeta.fromTrip(Trip trip) {
    final text = '${trip.title} ${trip.destination} ${trip.description}'
        .toLowerCase();

    if (text.contains('maldives')) {
      return const _DetailMeta(
        tags: ['Beach', 'Luxury', 'Romance'],
        avatar: 'M',
        creator: 'Sofia Chen',
        handle: '@sofiatravel',
        saves: '1.2k',
        remixes: 87,
        travelers: '2 people',
        places: ['Conrad Maldives Rangali', 'Ithaa Undersea', 'Dhigurah Island'],
      );
    }
    if (text.contains('swiss') || text.contains('alpine')) {
      return const _DetailMeta(
        tags: ['Mountain', 'Adventure', 'Nature'],
        avatar: 'A',
        creator: 'Marco Weiss',
        handle: '@marcohikes',
        saves: '892',
        remixes: 124,
        travelers: '2 people',
        places: ['Zermatt Village', 'Gornergrat Ridge', 'Matterhorn Viewpoint'],
      );
    }
    if (text.contains('brussels')) {
      return const _DetailMeta(
        tags: ['City', 'Culture', 'Food'],
        avatar: 'B',
        creator: 'Lea Martin',
        handle: '@leaexplores',
        saves: '567',
        remixes: 43,
        travelers: '2 people',
        places: ['Grand Place', 'Magritte Museum', 'Sablon Quarter'],
      );
    }
    return const _DetailMeta(
      tags: ['Adventure', 'Culture', 'Local'],
      avatar: 'P',
      creator: 'Pluno',
      handle: '@pluno',
      saves: '128',
      remixes: 12,
      travelers: '2 people',
      places: ['Old Town', 'Local Market', 'Sunset Point'],
    );
  }
}

class _TripDay {
  const _TripDay({
    required this.day,
    required this.title,
    required this.items,
    required this.tip,
  });

  final int day;
  final String title;
  final List<_TripStop> items;
  final String tip;

  static List<_TripDay> samplesFor(Trip trip, _DetailMeta meta) {
    return [
      _TripDay(
        day: 1,
        title: 'Arrival & First Look',
        tip: 'Book the first dinner ahead so day one stays easy.',
        items: [
          _TripStop(
            time: '2:00 PM',
            title: 'Check-in and settle down',
            place: meta.places[0],
            type: 'Stay',
            icon: Icons.hotel_outlined,
            color: AppColors.primary,
          ),
          _TripStop(
            time: '5:00 PM',
            title: 'Golden hour walk',
            place: meta.places[1],
            type: 'View',
            icon: Icons.wb_sunny_outlined,
            color: AppColors.accent,
          ),
          _TripStop(
            time: '7:30 PM',
            title: 'Dinner near the main square',
            place: meta.places[2],
            type: 'Dining',
            icon: Icons.restaurant_outlined,
            color: const Color(0xFF7E57C2),
          ),
        ],
      ),
      _TripDay(
        day: 2,
        title: 'Explore ${trip.destination}',
        tip: '',
        items: const [],
      ),
      const _TripDay(
        day: 3,
        title: 'Local Favorites',
        tip: '',
        items: [],
      ),
    ];
  }
}

class _TripStop {
  const _TripStop({
    required this.time,
    required this.title,
    required this.place,
    required this.type,
    required this.icon,
    required this.color,
  });

  final String time;
  final String title;
  final String place;
  final String type;
  final IconData icon;
  final Color color;
}

Color _tagColor(String tag) {
  switch (tag) {
    case 'Beach':
      return const Color(0xFF0288D1);
    case 'Luxury':
      return const Color(0xFF9B59B6);
    case 'Mountain':
    case 'Nature':
      return AppColors.primary;
    case 'Adventure':
      return AppColors.accent;
    case 'Culture':
      return const Color(0xFFF57C00);
    case 'Food':
      return const Color(0xFF8D6E63);
    default:
      return AppColors.foreground;
  }
}
