import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../main.dart';
import '../models/gym_class.dart';
import '../models/reservation.dart';
import '../models/user_profile.dart';
import '../providers/provider_reservations.dart';
import '../theme/app_colors.dart';
import 'class_detail_screen.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late DateTime _selectedDay;
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    _selectedDay = _dateOnly(DateTime.now());
    _visibleMonth = DateTime(_selectedDay.year, _selectedDay.month);
  }

  @override
  Widget build(BuildContext context) {
    final userProfile = ref.watch(providerUserProfile);
    final isStaff = userProfile.role == UserRole.STAFF;
    final colorScheme = Theme.of(context).colorScheme;
    final reservations = ref.watch(reservationsProvider).reservations;
    final classes = ref.watch(providerGymClass).classes;
    final reservedClassIds = reservations
        .map((r) => r.id)
        .whereType<String>()
        .toSet();
    final selectedReservations =
        reservations
            .where((reservation) => _isSameDay(reservation.date, _selectedDay))
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    final selectedClasses =
        classes
            .where((gymClass) => _isSameDay(gymClass.dateTime, _selectedDay))
            .toList()
          ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    final upcomingReservations = reservations.where((reservation) {
      return !reservation.date.isBefore(_dateOnly(DateTime.now()));
    }).length;

    if (isStaff) {
      final selectedClasses =
          classes
              .where((gymClass) => _isSameDay(gymClass.dateTime, _selectedDay))
              .toList()
            ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
      final monthClasses = classes
          .where(
            (gymClass) =>
                gymClass.dateTime.year == _visibleMonth.year &&
                gymClass.dateTime.month == _visibleMonth.month,
          )
          .toList();

      return SafeArea(
        child: Container(
          color: colorScheme.surface,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _StaffCalendarHero(
                visibleMonth: _visibleMonth,
                monthlyClassCount: monthClasses.length,
              ),
              const SizedBox(height: 14),
              _StaffMonthCard(
                visibleMonth: _visibleMonth,
                selectedDay: _selectedDay,
                classes: classes,
                onPreviousMonth: () => setState(() {
                  _visibleMonth = DateTime(
                    _visibleMonth.year,
                    _visibleMonth.month - 1,
                  );
                  _clampSelectionToVisibleMonth();
                }),
                onNextMonth: () => setState(() {
                  _visibleMonth = DateTime(
                    _visibleMonth.year,
                    _visibleMonth.month + 1,
                  );
                  _clampSelectionToVisibleMonth();
                }),
                onSelectDay: (day) => setState(() => _selectedDay = day),
              ),
              const SizedBox(height: 18),
              _SectionTitle(
                title: 'Classes On ${DateFormat.MMMd().format(_selectedDay)}',
                subtitle: selectedClasses.isEmpty
                    ? 'No classes scheduled for this day.'
                    : '${selectedClasses.length} class${selectedClasses.length == 1 ? '' : 'es'} scheduled. Tap a class to open details.',
              ),
              const SizedBox(height: 10),
              if (selectedClasses.isEmpty)
                const _EmptyCard(
                  icon: Icons.calendar_view_month,
                  title: 'No classes scheduled',
                  message:
                      'Select another day in the month view to check class coverage.',
                )
              else
                ...selectedClasses.map(
                  (gymClass) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ClassTile(
                      gymClass: gymClass,
                      isReserved: false,
                      showTapHint: true,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return SafeArea(
      child: Container(
        color: colorScheme.surface,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _CalendarHero(
              selectedDay: _selectedDay,
              upcomingReservations: upcomingReservations,
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 102,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 14,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final day = _dateOnly(
                    DateTime.now().add(Duration(days: index - 3)),
                  );
                  final isSelected = _isSameDay(day, _selectedDay);
                  final hasReservation = reservations.any(
                    (reservation) => _isSameDay(reservation.date, day),
                  );
                  return _DayChip(
                    day: day,
                    isSelected: isSelected,
                    hasReservation: hasReservation,
                    onTap: () => setState(() => _selectedDay = day),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            _SectionTitle(
              title: 'Your Schedule',
              subtitle: selectedReservations.isEmpty
                  ? 'No reservations on ${DateFormat.MMMMd().format(_selectedDay)}'
                  : '${selectedReservations.length} reserved class${selectedReservations.length == 1 ? '' : 'es'}',
            ),
            const SizedBox(height: 10),
            if (selectedReservations.isEmpty)
              const _EmptyCard(
                icon: Icons.event_busy,
                title: 'Nothing booked yet',
                message: 'Reserve a class from Home and it will show up here.',
              )
            else
              ...selectedReservations.map(
                (reservation) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ReservationTile(reservation: reservation),
                ),
              ),
            const SizedBox(height: 18),
            _SectionTitle(
              title: 'Classes That Day',
              subtitle: selectedClasses.isEmpty
                  ? 'No classes scheduled'
                  : '${selectedClasses.length} class options',
            ),
            const SizedBox(height: 10),
            if (selectedClasses.isEmpty)
              const _EmptyCard(
                icon: Icons.calendar_view_day,
                title: 'No classes scheduled',
                message: 'Try another day to browse the class calendar.',
              )
            else
              ...selectedClasses.map(
                (gymClass) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ClassTile(
                    gymClass: gymClass,
                    isReserved: reservedClassIds.contains(gymClass.id),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _clampSelectionToVisibleMonth() {
    if (_selectedDay.year == _visibleMonth.year &&
        _selectedDay.month == _visibleMonth.month) {
      return;
    }

    final today = _dateOnly(DateTime.now());
    if (today.year == _visibleMonth.year &&
        today.month == _visibleMonth.month) {
      _selectedDay = today;
      return;
    }

    _selectedDay = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
  }
}

class _CalendarHero extends StatelessWidget {
  final DateTime selectedDay;
  final int upcomingReservations;

  const _CalendarHero({
    required this.selectedDay,
    required this.upcomingReservations,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [AppColors.gradientStartDark, AppColors.gradientEndDark]
              : const [Color(0xFF1D4ED8), Color(0xFF06B6D4)],
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            offset: const Offset(0, 12),
            color: Colors.black.withValues(alpha: isDark ? 0.16 : 0.13),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat('EEEE, MMMM d').format(selectedDay),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 27,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            upcomingReservations == 0
                ? 'You have no upcoming reservations.'
                : 'You have $upcomingReservations upcoming reservation${upcomingReservations == 1 ? '' : 's'}.',
            style: const TextStyle(
              color: Color(0xE8FFFFFF),
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  final DateTime day;
  final bool isSelected;
  final bool hasReservation;
  final VoidCallback onTap;

  const _DayChip({
    required this.day,
    required this.isSelected,
    required this.hasReservation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: 72,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.outlineVariant,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                DateFormat('E').format(day).toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isSelected
                      ? colorScheme.onPrimary.withValues(alpha: 0.8)
                      : colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${day.day}',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: isSelected
                      ? colorScheme.onPrimary
                      : colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: hasReservation
                      ? (isSelected ? colorScheme.onPrimary : AppColors.success)
                      : Colors.transparent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReservationTile extends StatelessWidget {
  final Reservation reservation;

  const _ReservationTile({required this.reservation});

  @override
  Widget build(BuildContext context) {
    final isPast = reservation.date.isBefore(DateTime.now());
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            blurRadius: 14,
            offset: const Offset(0, 8),
            color: Colors.black.withValues(alpha: 0.08),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: isPast
                  ? colorScheme.surface
                  : AppColors.success.withValues(
                      alpha: Theme.of(context).brightness == Brightness.dark
                          ? 0.24
                          : 0.14,
                    ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              isPast ? Icons.history : Icons.check_circle,
              color: isPast ? colorScheme.onSurfaceVariant : AppColors.success,
            ),
          ),
          const SizedBox(width: 14),
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
                  '${DateFormat.jm().format(reservation.date)} • ${reservation.matNumber}',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  reservation.instructor,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          _StatusBadge(
            label: isPast ? 'Past' : reservation.status,
            background: isPast
                ? colorScheme.surface
                : colorScheme.primaryContainer,
            foreground: isPast
                ? colorScheme.onSurfaceVariant
                : colorScheme.onPrimaryContainer,
          ),
        ],
      ),
    );
  }
}

class _ClassTile extends ConsumerWidget {
  final GymClass gymClass;
  final bool isReserved;
  final bool showTapHint;

  const _ClassTile({
    required this.gymClass,
    required this.isReserved,
    this.showTapHint = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ClassDetailScreen(
              classId: gymClass.id,
              initialGymClass: gymClass,
            ),
          ),
        ),
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                blurRadius: 14,
                offset: const Offset(0, 8),
                color: Colors.black.withValues(alpha: 0.08),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  Icons.self_improvement,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 14),
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
                      '${gymClass.timeText} • ${gymClass.location}',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${gymClass.filled}/${gymClass.capacity} registered',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusBadge(
                label: isReserved
                    ? 'Booked'
                    : gymClass.status.name.toUpperCase(),
                background: isReserved
                    ? AppColors.success.withValues(
                        alpha: Theme.of(context).brightness == Brightness.dark
                            ? 0.24
                            : 0.14,
                      )
                    : colorScheme.surface,
                foreground: isReserved
                    ? AppColors.success
                    : colorScheme.onSurfaceVariant,
              ),
              if (showTapHint) ...[
                const SizedBox(width: 8),
                Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StaffCalendarHero extends StatelessWidget {
  final DateTime visibleMonth;
  final int monthlyClassCount;

  const _StaffCalendarHero({
    required this.visibleMonth,
    required this.monthlyClassCount,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [AppColors.gradientStartDark, AppColors.gradientEndDark]
              : const [Color(0xFF0F766E), Color(0xFF2563EB)],
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            offset: const Offset(0, 12),
            color: Colors.black.withValues(alpha: isDark ? 0.16 : 0.13),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat('MMMM yyyy').format(visibleMonth),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            monthlyClassCount == 0
                ? 'No classes are scheduled this month.'
                : '$monthlyClassCount class${monthlyClassCount == 1 ? '' : 'es'} scheduled this month.',
            style: const TextStyle(
              color: Color(0xE8FFFFFF),
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _StaffMonthCard extends StatelessWidget {
  final DateTime visibleMonth;
  final DateTime selectedDay;
  final List<GymClass> classes;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final ValueChanged<DateTime> onSelectDay;

  const _StaffMonthCard({
    required this.visibleMonth,
    required this.selectedDay,
    required this.classes,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onSelectDay,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final firstDayOfMonth = DateTime(visibleMonth.year, visibleMonth.month, 1);
    final startOffset = firstDayOfMonth.weekday % 7;
    final gridStart = firstDayOfMonth.subtract(Duration(days: startOffset));
    final today = _dateOnly(DateTime.now());

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            blurRadius: 14,
            offset: const Offset(0, 8),
            color: Colors.black.withValues(alpha: 0.08),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onPreviousMonth,
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  DateFormat('MMMM yyyy').format(visibleMonth),
                  textAlign: TextAlign.center,
                  style: textTheme.titleMedium?.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              IconButton(
                onPressed: onNextMonth,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Tap any day to load that class list below.',
              style: textTheme.bodySmall?.copyWith(
                fontSize: 13,
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(7, (index) {
              final weekday = DateFormat(
                'E',
              ).format(DateTime(2024, 1, index + 7));
              return Expanded(
                child: Center(
                  child: Text(
                    weekday.substring(0, 1),
                    style: textTheme.labelSmall?.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 10),
          ...List.generate(6, (row) {
            return Padding(
              padding: EdgeInsets.only(bottom: row == 5 ? 0 : 8),
              child: Row(
                children: List.generate(7, (column) {
                  final day = _dateOnly(
                    gridStart.add(Duration(days: row * 7 + column)),
                  );
                  final classCount = classes
                      .where((gymClass) => _isSameDay(gymClass.dateTime, day))
                      .length;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: _StaffDayCell(
                        day: day,
                        isCurrentMonth: day.month == visibleMonth.month,
                        isSelected: _isSameDay(day, selectedDay),
                        isToday: _isSameDay(day, today),
                        classCount: classCount,
                        onTap: () => onSelectDay(day),
                      ),
                    ),
                  );
                }),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _StaffDayCell extends StatelessWidget {
  final DateTime day;
  final bool isCurrentMonth;
  final bool isSelected;
  final bool isToday;
  final int classCount;
  final VoidCallback onTap;

  const _StaffDayCell({
    required this.day,
    required this.isCurrentMonth,
    required this.isSelected,
    required this.isToday,
    required this.classCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = !isCurrentMonth
        ? colorScheme.onSurfaceVariant.withValues(alpha: 0.72)
        : isSelected
        ? colorScheme.onPrimary
        : colorScheme.onSurface;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: isSelected ? colorScheme.primary : colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isToday
                  ? colorScheme.primary
                  : isSelected
                  ? colorScheme.primary
                  : colorScheme.outlineVariant,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: Text(
                    '${day.day}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: foreground,
                    ),
                  ),
                ),
                if (classCount > 0)
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 14,
                        minHeight: 14,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colorScheme.onPrimary.withValues(alpha: 0.18)
                            : colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        classCount > 9 ? '9+' : '$classCount',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? colorScheme.onPrimary
                              : colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ),
                if (isToday && !isSelected)
                  Align(
                    alignment: Alignment.topRight,
                    child: Icon(
                      Icons.circle,
                      size: 8,
                      color: colorScheme.primary,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: textTheme.titleLarge?.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: textTheme.bodyMedium?.copyWith(
            fontSize: 14,
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptyCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(icon, size: 36, color: colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            title,
            style: textTheme.titleMedium?.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;

  const _StatusBadge({
    required this.label,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

bool _isSameDay(DateTime a, DateTime b) => _dateOnly(a) == _dateOnly(b);
