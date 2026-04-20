import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pat_your_mat/main.dart';
import 'package:pat_your_mat/theme/app_colors.dart';

import '../models/achievement.dart';
import '../db_helpers/db_gym_class.dart';
import '../db_helpers/db_reservations.dart';
import '../models/gym_class.dart';
import '../models/reservation.dart';
import '../providers/provider_auth.dart';
import '../providers/provider_reservations.dart';
import '../providers/provider_user_profile.dart';
import '../util/date_time/util_attendance.dart';
import '../widgets/general/widget_profile_avatar.dart';
import 'class_detail_screen.dart';
import 'screen_member_previous_classes.dart';
import 'settings/screen_profile_edit.dart';
import 'settings/screen_settings.dart';

List<Reservation> upcomingMemberReservations(
  List<Reservation> reservations, {
  DateTime? now,
}) {
  final currentDateTime = now ?? DateTime.now();
  final upcoming = reservations.where((reservation) {
    final classEnd = attendanceWindowCloses(
      reservation.date,
      durationMinutes: reservation.durationMinutes,
    );
    return !classEnd.isBefore(currentDateTime);
  }).toList()..sort((a, b) => a.date.compareTo(b.date));
  return upcoming;
}

List<Reservation> previousMemberReservations(
  List<Reservation> reservations, {
  DateTime? now,
}) {
  final currentDateTime = now ?? DateTime.now();
  final previous = reservations.where((reservation) {
    final classEnd = attendanceWindowCloses(
      reservation.date,
      durationMinutes: reservation.durationMinutes,
    );
    return classEnd.isBefore(currentDateTime);
  }).toList()..sort((a, b) => b.date.compareTo(a.date));
  return previous;
}

GymClass? resolveFavoriteClass(
  List<GymClass> classes,
  String favoriteId, {
  DateTime? now,
}) {
  final currentDateTime = now ?? DateTime.now();
  final matchingClasses =
      classes.where((gymClass) => gymClass.favoriteKey == favoriteId).toList()
        ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

  if (matchingClasses.isEmpty) {
    return null;
  }

  for (final gymClass in matchingClasses) {
    final classEnd = attendanceWindowCloses(
      gymClass.dateTime,
      durationMinutes: gymClass.durationMinutes,
    );
    if (!classEnd.isBefore(currentDateTime)) {
      return gymClass;
    }
  }

  return matchingClasses.last;
}

class AttendanceSummaryData {
  final int attendedCount;
  final int noShowCount;
  final int totalCompletedCount;
  final double? attendanceRate;
  final List<MapEntry<String, int>> categoryBreakdown;

  const AttendanceSummaryData({
    required this.attendedCount,
    required this.noShowCount,
    required this.totalCompletedCount,
    required this.attendanceRate,
    required this.categoryBreakdown,
  });

  bool get hasHistory => totalCompletedCount > 0;

  String? get topCategory =>
      categoryBreakdown.isEmpty ? null : categoryBreakdown.first.key;
}

AttendanceSummaryData summarizeAttendance(
  List<Reservation> reservations, {
  Map<String, int> categoryAttendance = const <String, int>{},
  DateTime? now,
}) {
  final previousReservations = previousMemberReservations(
    reservations,
    now: now,
  );
  var attendedCount = 0;
  var noShowCount = 0;

  for (final reservation in previousReservations) {
    final status = effectiveReservationStatus(
      rawStatus: reservation.status,
      classStart: reservation.date,
      durationMinutes: reservation.durationMinutes,
      now: now,
    );
    if (status == ReservationStatus.attended) {
      attendedCount += 1;
    } else if (status == ReservationStatus.noShow) {
      noShowCount += 1;
    }
  }

  final sortedCategoryBreakdown = categoryAttendance.entries
      .where((entry) => entry.value > 0)
      .toList()
    ..sort((left, right) {
      final countCompare = right.value.compareTo(left.value);
      if (countCompare != 0) {
        return countCompare;
      }
      return left.key.compareTo(right.key);
    });

  final totalCompletedCount = previousReservations.length;
  final attendanceRate = totalCompletedCount == 0
      ? null
      : attendedCount / totalCompletedCount;

  return AttendanceSummaryData(
    attendedCount: attendedCount,
    noShowCount: noShowCount,
    totalCompletedCount: totalCompletedCount,
    attendanceRate: attendanceRate,
    categoryBreakdown: sortedCategoryBreakdown,
  );
}

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  static const int _reservationPreviewCount = 3;
  static const double _favoriteClassCardHeight = 132;

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(providerUserProfile);
    final auth = ref.watch(providerAuth);
    final gymClasses = ref.watch(providerGymClass).classes;
    final reservations = [...ref.watch(reservationsProvider).reservations]
      ..sort((a, b) => a.date.compareTo(b.date));
    final upcomingReservations = upcomingMemberReservations(reservations);
    final previousReservations = previousMemberReservations(reservations);

    final thisMonthCount = reservations.where((reservation) {
      final now = DateTime.now();
      return reservation.date.month == now.month &&
          reservation.date.year == now.year;
    }).length;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, profile),
              const SizedBox(height: 20),
              _buildStatsSection(
                context: context,
                reservations: reservations,
                thisMonthCount: thisMonthCount,
              ),
              if (profile.hasActiveNoShowPenalty) ...[
                const SizedBox(height: 20),
                _buildNoShowPenaltySection(context, profile),
              ],
              const SizedBox(height: 20),
              _buildAttendanceSummarySection(context, profile, reservations),
              const SizedBox(height: 20),
              _buildFavoritesSection(context, profile, gymClasses),
              const SizedBox(height: 20),
              _buildAchievementsSection(context, profile),
              const SizedBox(height: 20),
              _buildStandbyQueueSection(
                context: context,
                ref: ref,
                profile: profile,
                gymClasses: gymClasses,
              ),
              const SizedBox(height: 20),
              _buildUpcomingReservationsSection(
                context,
                ref,
                upcomingReservations,
              ),
              const SizedBox(height: 20),
              _buildPreviousClassesSection(context, previousReservations),
              const SizedBox(height: 20),
              _buildAccountSection(context, profile, auth),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ProviderUserProfile profile) {
    final memberSince = _formatMemberSince(profile.accountCreationTime);
    final headerGradient = Theme.of(context).brightness == Brightness.dark
        ? const [AppColors.gradientStartDark, AppColors.gradientEndDark]
        : const [AppColors.gradientStart, AppColors.gradientEnd];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 380;
        final avatarRadius = isCompact ? 30.0 : 34.0;

        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(isCompact ? 18 : 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(isCompact ? 24 : 28),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: headerGradient,
            ),
          ),
          child: Column(
            crossAxisAlignment: isCompact
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              Align(
                alignment: isCompact ? Alignment.center : Alignment.centerLeft,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isCompact ? 10 : 12,
                    vertical: isCompact ? 6 : 7,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.headerOnBrand.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: AppColors.headerOnBrand.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Text(
                    'Member Profile',
                    style: TextStyle(
                      fontSize: isCompact ? 11 : 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.headerOnBrand.withValues(alpha: 0.92),
                    ),
                  ),
                ),
              ),
              SizedBox(height: isCompact ? 14 : 18),
              Column(
                crossAxisAlignment: isCompact
                    ? CrossAxisAlignment.center
                    : CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.headerOnBrand.withValues(alpha: 0.50),
                        width: 3,
                      ),
                    ),
                    child: ProfileAvatar(
                      radius: avatarRadius,
                      userImage: profile.userImage,
                      userWholeName: profile.wholeName,
                    ),
                  ),
                  SizedBox(height: isCompact ? 12 : 16),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 320),
                    child: _buildHeaderText(
                      context,
                      profile,
                      memberSince,
                      isCompact: isCompact,
                    ),
                  ),
                ],
              ),
              if (profile.bio.trim().isNotEmpty) ...[
                SizedBox(height: isCompact ? 16 : 18),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(isCompact ? 14 : 16),
                  decoration: BoxDecoration(
                    color: AppColors.headerOnBrand.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppColors.headerOnBrand.withValues(alpha: 0.16),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'About You',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.headerOnBrand.withValues(
                                alpha: 0.80,
                              ),
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        profile.bio.trim(),
                        textAlign: isCompact
                            ? TextAlign.center
                            : TextAlign.start,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 14,
                          height: 1.45,
                          color: AppColors.headerOnBrand.withValues(
                            alpha: 0.92,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              SizedBox(height: isCompact ? 16 : 20),
              if (isCompact)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => context.push(ScreenProfileEdit.routeName),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.headerOnBrand,
                      side: BorderSide(
                        color: AppColors.headerOnBrand.withValues(alpha: 0.54),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text(
                      'Edit Profile',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => context.push(ScreenProfileEdit.routeName),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.headerOnBrand,
                      side: BorderSide(
                        color: AppColors.headerOnBrand.withValues(alpha: 0.54),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit Profile'),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNoShowPenaltySection(
    BuildContext context,
    ProviderUserProfile profile,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final penaltyUntil = profile.noShowPenaltyUntil;
    final penaltyLabel = penaltyUntil == null
        ? 'This lockout will lift after your penalty window ends.'
        : 'Sign-ups reopen on ${DateFormat.yMMMMd().format(penaltyUntil.toLocal())}.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.error.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.event_busy_outlined,
            color: colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Class sign-ups are paused',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onErrorContainer,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Your account reached 3 no-shows, so new class bookings and standby joins are locked for 1 month.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onErrorContainer,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  penaltyLabel,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onErrorContainer.withValues(
                      alpha: 0.86,
                    ),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection({
    required BuildContext context,
    required List<Reservation> reservations,
    required int thisMonthCount,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Snapshot',
          style: textTheme.titleLarge?.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth < 520 ? 2 : 3;
            final childAspectRatio = constraints.maxWidth < 380 ? 1.05 : 1.18;
            return GridView.count(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: childAspectRatio,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStatCard(
                  context: context,
                  label: 'Upcoming Classes',
                  value: '${upcomingMemberReservations(reservations).length}',
                  icon: Icons.event_available,
                  accent: AppColors.deepPurple,
                ),
                _buildStatCard(
                  context: context,
                  label: 'Classes This Month',
                  value: '$thisMonthCount',
                  icon: Icons.calendar_month_outlined,
                  accent: AppColors.success,
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildAttendanceSummarySection(
    BuildContext context,
    ProviderUserProfile profile,
    List<Reservation> reservations,
  ) {
    final summary = summarizeAttendance(
      reservations,
      categoryAttendance: profile.categoryAttendance,
    );
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return _buildSectionCard(
      context: context,
      title: 'Attendance Summary',
      subtitle: 'A quick look at your completed class history and check-in habits.',
      child: !summary.hasHistory
          ? Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: Text(
                'Your attendance summary will appear after your first completed class.',
                style: textTheme.bodyMedium?.copyWith(
                  height: 1.45,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 460;
                    final tiles = <Widget>[
                      _buildAttendanceMetricCard(
                        context: context,
                        label: 'Attended',
                        value: '${summary.attendedCount}',
                        icon: Icons.check_circle_outline,
                        accent: AppColors.success,
                      ),
                      _buildAttendanceMetricCard(
                        context: context,
                        label: 'No-Shows',
                        value: '${summary.noShowCount}',
                        icon: Icons.event_busy_outlined,
                        accent: AppColors.error,
                      ),
                      _buildAttendanceMetricCard(
                        context: context,
                        label: 'Attendance Rate',
                        value: _formatAttendanceRate(summary.attendanceRate),
                        icon: Icons.query_stats,
                        accent: AppColors.deepPurple,
                      ),
                    ];

                    if (compact) {
                      return Column(
                        children: tiles
                            .map(
                              (tile) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: tile,
                              ),
                            )
                            .toList(),
                      );
                    }

                    return Row(
                      children: [
                        for (var index = 0; index < tiles.length; index++) ...[
                          Expanded(child: tiles[index]),
                          if (index != tiles.length - 1)
                            const SizedBox(width: 10),
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: colorScheme.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        summary.topCategory == null
                            ? 'Class Type Breakdown'
                            : 'Most Attended: ${summary.topCategory}',
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        summary.categoryBreakdown.isEmpty
                            ? 'Checked-in class types will appear here once your attendance starts building.'
                            : 'Your attended classes by category.',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                      if (summary.categoryBreakdown.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: summary.categoryBreakdown
                              .take(6)
                              .map(
                                (entry) => _buildAttendanceCategoryChip(
                                  context,
                                  entry,
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildAchievementsSection(
    BuildContext context,
    ProviderUserProfile profile,
  ) {
    final unlockedIds = profile.achievements.toSet();
    final unlockedAchievements = Achievement.all
        .where((achievement) => unlockedIds.contains(achievement.id))
        .toList();
    final previewAchievements = unlockedAchievements.take(4).toList();
    final remainingCount =
        unlockedAchievements.length - previewAchievements.length;

    return _buildSectionCard(
      context: context,
      title: 'Achievements',
      subtitle:
          '${unlockedIds.length} of ${Achievement.all.length} badges unlocked.',
      headerAction: TextButton(
        onPressed: () => _showAchievementsSheet(context, unlockedIds),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          'View All',
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      child: unlockedAchievements.isEmpty
          ? _buildEmptyAchievementPreview(context)
          : Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final achievement in previewAchievements)
                        _buildAchievementPreviewIcon(context, achievement),
                      if (remainingCount > 0)
                        _buildAchievementOverflowChip(context, remainingCount),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildFavoritesSection(
    BuildContext context,
    ProviderUserProfile profile,
    List<GymClass> gymClasses,
  ) {
    final favoriteIds = profile.favoriteClassIds;

    return _buildSectionCard(
      context: context,
      title: 'Favorite Classes',
      subtitle:
          'Recurring favorites open the next scheduled occurrence automatically.',
      child: favoriteIds.isEmpty
          ? Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Text(
                'You have not favorited any classes yet. Tap the heart on a class to save it here.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.4,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            )
          : SizedBox(
              height: _favoriteClassCardHeight,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: favoriteIds.length,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final favoriteId = favoriteIds[index];
                  final favoriteClass = resolveFavoriteClass(
                    gymClasses,
                    favoriteId,
                  );
                  if (favoriteClass == null) {
                    return const SizedBox.shrink();
                  }

                  return _buildFavoriteClassCard(context, favoriteClass);
                },
              ),
            ),
    );
  }

  Widget _buildFavoriteClassCard(BuildContext context, GymClass gymClass) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () =>
          context.push(ClassDetailScreen.routeName, extra: gymClass.id),
      child: Container(
        width: 172,
        height: _favoriteClassCardHeight,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.favorite,
              size: 18,
              color: AppColors.error.withValues(alpha: 0.85),
            ),
            const Spacer(),
            Text(
              gymClass.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              gymClass.instructor,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              gymClass.dateText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAchievementPreviewIcon(
    BuildContext context,
    Achievement achievement,
  ) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: achievement.color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(color: achievement.color.withValues(alpha: 0.28)),
      ),
      child: Icon(achievement.iconData, color: achievement.color, size: 24),
    );
  }

  Widget _buildAchievementOverflowChip(
    BuildContext context,
    int remainingCount,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        shape: BoxShape.circle,
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Center(
        child: Text(
          '+$remainingCount',
          style: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyAchievementPreview(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.stars_outlined,
              color: colorScheme.onSurfaceVariant,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Your badges will show up here as you build class history.',
              style: textTheme.bodyMedium?.copyWith(
                height: 1.4,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAchievementsSheet(
    BuildContext context,
    Set<String> unlockedIds,
  ) async {
    final colorScheme = Theme.of(context).colorScheme;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: colorScheme.surface,
      builder: (context) {
        return SafeArea(
          child: FractionallySizedBox(
            heightFactor: 0.82,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'All Achievements',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  );
                }

                final achievement = Achievement.all[index - 1];
                return _buildAchievementBadge(
                  context,
                  achievement,
                  isUnlocked: unlockedIds.contains(achievement.id),
                );
              },
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemCount: Achievement.all.length + 1,
            ),
          ),
        );
      },
    );
  }

  Widget _buildAchievementBadge(
    BuildContext context,
    Achievement achievement, {
    required bool isUnlocked,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final badgeColor = isUnlocked ? achievement.color : colorScheme.outline;
    final backgroundColor = isUnlocked
        ? achievement.color.withValues(alpha: 0.12)
        : colorScheme.surface;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isUnlocked
              ? achievement.color.withValues(alpha: 0.28)
              : colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: backgroundColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: badgeColor.withValues(alpha: isUnlocked ? 0.35 : 0.20),
              ),
            ),
            child: Icon(
              isUnlocked ? achievement.iconData : Icons.lock_outline,
              color: badgeColor,
              size: 26,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            achievement.title,
            textAlign: TextAlign.center,
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            achievement.description,
            textAlign: TextAlign.center,
            style: textTheme.bodySmall?.copyWith(
              height: 1.35,
              color: isUnlocked
                  ? colorScheme.onSurfaceVariant
                  : colorScheme.onSurfaceVariant.withValues(alpha: 0.82),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required BuildContext context,
    required String label,
    required String value,
    required IconData icon,
    required Color accent,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: isDark ? 0.18 : 0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accent.withValues(alpha: isDark ? 0.3 : 0.14),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.14 : 0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const Spacer(),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.headlineSmall?.copyWith(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall?.copyWith(
              fontSize: 12,
              height: 1.25,
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceMetricCard({
    required BuildContext context,
    required String label,
    required String value,
    required IconData icon,
    required Color accent,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: isDark ? 0.16 : 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: accent.withValues(alpha: isDark ? 0.28 : 0.16),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: isDark ? 0.20 : 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceCategoryChip(
    BuildContext context,
    MapEntry<String, int> entry,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            entry.key,
            style: textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '${entry.value}',
              style: textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatAttendanceRate(double? attendanceRate) {
    if (attendanceRate == null) {
      return '--';
    }
    return '${(attendanceRate * 100).round()}%';
  }

  Widget _buildUpcomingReservationsSection(
    BuildContext context,
    WidgetRef ref,
    List<Reservation> reservations,
  ) {
    final shouldCollapse = reservations.length > _reservationPreviewCount;
    final visibleReservations = _visibleReservationsForSection(
      reservations,
      sectionKey: 'upcoming',
    );

    return _buildSectionCard(
      context: context,
      title: 'Upcoming Reservations',
      subtitle: 'Your next classes and assigned mat spots.',
      headerAction: shouldCollapse
          ? _buildShowAllButton(
              context: context,
              isExpanded: _isSectionExpanded('upcoming'),
              onTap: () => _toggleSectionExpansion('upcoming'),
            )
          : null,
      child: reservations.isEmpty
          ? Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Text(
                'No upcoming reservations yet. Reserve a class to build out your history here.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.45,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            )
          : Column(
              children: visibleReservations
                  .map(
                    (reservation) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildReservationCard(
                        context,
                        ref,
                        reservation,
                        showCancelAction: true,
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _buildStandbyQueueSection({
    required BuildContext context,
    required WidgetRef ref,
    required ProviderUserProfile profile,
    required List<GymClass> gymClasses,
  }) {
    final currentUserId = ref.read(reservationsProvider).userId ?? profile.uid;

    return StreamBuilder<Set<String>>(
      stream: DBReservations.getStandbyClassIdsStream(currentUserId),
      initialData: const <String>{},
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildSectionCard(
            context: context,
            title: 'Standby Queue',
            subtitle: 'Classes you are currently queued for when mats open up.',
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Text(
                'Unable to load your standby classes right now.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.45,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          );
        }

        final standbyClassIds = snapshot.data ?? const <String>{};
        final classesById = <String, GymClass>{
          for (final gymClass in gymClasses) gymClass.id: gymClass,
        };
        final standbyClassIdsList = standbyClassIds.toList()
          ..sort((left, right) {
            final leftClass = classesById[left];
            final rightClass = classesById[right];
            if (leftClass != null && rightClass != null) {
              return leftClass.dateTime.compareTo(rightClass.dateTime);
            }
            if (leftClass != null) {
              return -1;
            }
            if (rightClass != null) {
              return 1;
            }
            return left.compareTo(right);
          });

        return _buildSectionCard(
          context: context,
          title: 'Standby Queue',
          subtitle: 'Classes you are currently queued for when mats open up.',
          child: standbyClassIds.isEmpty
              ? Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: Text(
                    'You are not on standby for any classes right now.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.45,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : Column(
                  children: standbyClassIdsList
                      .map(
                        (classId) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildStandbyClassCardForId(
                            context,
                            ref,
                            classId,
                            initialGymClass: classesById[classId],
                          ),
                        ),
                      )
                      .toList(),
                ),
        );
      },
    );
  }

  Widget _buildPreviousClassesSection(
    BuildContext context,
    List<Reservation> reservations,
  ) {
    return _buildSectionCard(
      context: context,
      title: 'Previous Classes',
      subtitle: 'Past reservations show your recorded attendance history.',
      child: reservations.isEmpty
          ? Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Text(
                'No previous classes yet.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.45,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            )
          : Center(
              child: OutlinedButton.icon(
                onPressed: () =>
                    context.push(ScreenMemberPreviousClasses.routeName),
                icon: const Icon(Icons.history),
                label: const Text('Show Previous Classes'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildReservationCard(
    BuildContext context,
    WidgetRef? ref,
    Reservation reservation, {
    required bool showCancelAction,
    String? statusOverride,
  }) {
    final displayStatus = statusOverride ?? reservation.status;
    final normalizedStatus = displayStatus.toUpperCase();
    final isConfirmed = normalizedStatus == 'CONFIRMED';
    final isAttended = normalizedStatus == 'ATTENDED';
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final statusAccent = isAttended
        ? AppColors.deepPurple
        : (isConfirmed ? AppColors.success : AppColors.warning);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reservation.className,
                      style: textTheme.titleMedium?.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      reservation.instructor,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusAccent.withValues(
                    alpha: Theme.of(context).brightness == Brightness.dark
                        ? 0.24
                        : 0.14,
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  displayStatus,
                  style: textTheme.labelSmall?.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: statusAccent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              _buildInfoPill(context, Icons.schedule, reservation.dateTime),
              _buildInfoPill(
                context,
                Icons.place_outlined,
                reservation.matNumber,
              ),
            ],
          ),
          if (showCancelAction && ref != null) ...[
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () async {
                  try {
                    await ref
                        .read(reservationsProvider)
                        .cancelReservation(reservation);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Reservation cancelled')),
                    );
                  } catch (error) {
                    if (!context.mounted) return;
                    var message = error.toString();
                    if (message.startsWith('Exception: ')) {
                      message = message.replaceFirst('Exception: ', '');
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Cancel failed: $message')),
                    );
                  }
                },
                style: TextButton.styleFrom(foregroundColor: colorScheme.error),
                child: const Text(
                  'Cancel Reservation',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStandbyClassCardForId(
    BuildContext context,
    WidgetRef ref,
    String classId, {
    GymClass? initialGymClass,
  }) {
    return StreamBuilder<GymClass?>(
      stream: DBGymClass.getClassStream(classId),
      initialData: initialGymClass,
      builder: (context, snapshot) {
        final gymClass = snapshot.data;
        if (gymClass == null) {
          return Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Text(
              'This standby class is no longer available.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }

        return _buildStandbyClassCard(context, ref, gymClass);
      },
    );
  }

  Widget _buildStandbyClassCard(
    BuildContext context,
    WidgetRef ref,
    GymClass gymClass,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return StreamBuilder<int?>(
      stream: ref
          .read(reservationsProvider)
          .standbyQueuePositionStream(gymClass.id),
      builder: (context, snapshot) {
        final queuePosition = snapshot.data;

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          gymClass.title,
                          style: textTheme.titleMedium?.copyWith(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          gymClass.instructor,
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(
                        alpha: Theme.of(context).brightness == Brightness.dark
                            ? 0.24
                            : 0.14,
                      ),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'STANDBY',
                      style: textTheme.labelSmall?.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.warning,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 18,
                runSpacing: 8,
                children: [
                  _buildInfoPill(
                    context,
                    Icons.schedule,
                    '${gymClass.dateText} at ${gymClass.timeText}',
                  ),
                  _buildInfoPill(
                    context,
                    Icons.format_list_numbered_rounded,
                    queuePosition == null
                        ? 'Position updating...'
                        : 'Position #$queuePosition',
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () async {
                      try {
                        await ref
                            .read(reservationsProvider)
                            .leaveStandbyQueue(gymClass.id);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Left standby queue'),
                          ),
                        );
                      } catch (error) {
                        if (!context.mounted) return;
                        var message = error.toString();
                        if (message.startsWith('Exception: ')) {
                          message = message.replaceFirst('Exception: ', '');
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Failed to leave standby queue: $message',
                            ),
                          ),
                        );
                      }
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: colorScheme.error,
                    ),
                    child: const Text(
                      'Leave Queue',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push(
                      ClassDetailScreen.routeName,
                      extra: gymClass.id,
                    ),
                    child: const Text(
                      'View Class',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAccountSection(
    BuildContext context,
    ProviderUserProfile profile,
    ProviderAuth auth,
  ) {
    return _buildSectionCard(
      context: context,
      title: 'Account & Info',
      subtitle: 'Account details and quick actions.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Column(
              children: [
                _buildAccountRow(
                  context: context,
                  icon: Icons.mail_outline,
                  label: 'Email',
                  value: profile.email.isEmpty ? 'Not provided' : profile.email,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Quick Actions',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          _buildActionTile(
            context: context,
            icon: Icons.tune,
            label: 'Settings',
            subtitle: 'Manage app preferences and account options.',
            onTap: () => context.push(ScreenSettings.routeName),
          ),
          const SizedBox(height: 10),
          _buildActionTile(
            context: context,
            icon: Icons.logout,
            label: 'Log Out',
            subtitle: 'Sign out of your Pat Your Mat account.',
            isDestructive: true,
            onTap: () => auth.promptAndClearAuthedUserDetailsAndSignout(
              context: context,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required Widget child,
    Widget? headerAction,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final hasSubtitle = subtitle.trim().isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: Theme.of(context).brightness == Brightness.dark
                  ? 0.14
                  : 0.06,
            ),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: textTheme.titleLarge?.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              if (headerAction != null) ...[
                const SizedBox(width: 12),
                headerAction,
              ],
            ],
          ),
          if (hasSubtitle) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
          ] else
            const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  bool _isSectionExpanded(String sectionKey) {
    switch (sectionKey) {
      case 'upcoming':
        return _showAllUpcoming;
      default:
        return false;
    }
  }

  List<Reservation> _visibleReservationsForSection(
    List<Reservation> reservations, {
    required String sectionKey,
  }) {
    if (_isSectionExpanded(sectionKey)) {
      return reservations;
    }
    return reservations.take(_reservationPreviewCount).toList();
  }

  Widget _buildShowAllButton({
    required BuildContext context,
    required bool isExpanded,
    required VoidCallback onTap,
  }) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        isExpanded ? 'Show Less' : 'Show All',
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }

  bool _showAllUpcoming = false;

  void _toggleSectionExpansion(String sectionKey) {
    setState(() {
      switch (sectionKey) {
        case 'upcoming':
          _showAllUpcoming = !_showAllUpcoming;
          break;
      }
    });
  }

  Widget _buildInfoPill(BuildContext context, IconData icon, String text) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Text(
          text,
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildAccountRow({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    String? supportingText,
    Color? valueColor,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 18, color: colorScheme.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: textTheme.labelSmall?.copyWith(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              _buildScaledSingleLineText(
                value,
                alignment: Alignment.centerLeft,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.15,
                  color: valueColor ?? colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (supportingText != null) ...[
                const SizedBox(height: 4),
                Text(
                  supportingText,
                  style: textTheme.bodySmall?.copyWith(
                    fontSize: 13,
                    color: colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderText(
    BuildContext context,
    ProviderUserProfile profile,
    String? memberSince, {
    required bool isCompact,
  }) {
    return Column(
      crossAxisAlignment: isCompact
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Text(
          profile.wholeName.trim().isEmpty ? 'Your Profile' : profile.wholeName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: isCompact ? TextAlign.center : TextAlign.start,
          style: TextStyle(
            fontSize: isCompact ? 24 : 28,
            height: 1.08,
            fontWeight: FontWeight.w800,
            color: AppColors.headerOnBrand,
          ),
        ),
        const SizedBox(height: 8),
        _buildScaledSingleLineText(
          profile.email.isEmpty ? 'No email on file' : profile.email,
          alignment: isCompact ? Alignment.center : Alignment.centerLeft,
          style: TextStyle(
            fontSize: isCompact ? 14 : 15,
            height: 1.2,
            color: AppColors.headerOnBrand.withValues(alpha: 0.88),
          ),
        ),
        if (memberSince != null) ...[
          const SizedBox(height: 4),
          Text(
            memberSince,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: isCompact ? TextAlign.center : TextAlign.start,
            style: TextStyle(
              fontSize: isCompact ? 12 : 13,
              color: AppColors.headerOnBrand.withValues(alpha: 0.72),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildScaledSingleLineText(
    String text, {
    required TextStyle style,
    required Alignment alignment,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          width: constraints.maxWidth,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: alignment,
            child: Text(text, maxLines: 1, softWrap: false, style: style),
          ),
        );
      },
    );
  }

  Widget _buildActionTile({
    required BuildContext context,
    required IconData icon,
    required String label,
    String? subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDestructive
              ? colorScheme.errorContainer.withValues(alpha: isDark ? 0.3 : 1)
              : colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isDestructive ? colorScheme.error : colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: isDestructive
                          ? colorScheme.error
                          : colorScheme.onSurface,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.3,
                        color: isDestructive
                            ? colorScheme.error.withValues(alpha: 0.76)
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: isDestructive
                  ? colorScheme.error
                  : colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  String? _formatMemberSince(int epochValue) {
    if (epochValue <= 0) {
      return null;
    }

    final isSeconds = epochValue < 100000000000;
    final date = DateTime.fromMillisecondsSinceEpoch(
      isSeconds ? epochValue * 1000 : epochValue,
    );
    return 'Member since ${DateFormat.yMMMM().format(date)}';
  }
}
