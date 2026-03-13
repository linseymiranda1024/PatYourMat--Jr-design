import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../main.dart';
import '../models/gym_class.dart';
import '../models/reservation.dart';
import '../providers/provider_reservations.dart';
import 'class_detail_screen.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _dateOnly(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
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

    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF3F7FF), Color(0xFFFFFFFF)],
          ),
        ),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1D4ED8), Color(0xFF06B6D4)],
        ),
        boxShadow: const [
          BoxShadow(
            blurRadius: 18,
            offset: Offset(0, 12),
            color: Color(0x220B3A75),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: 72,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF0F172A)
                  : const Color(0xFFDCE4F2),
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
                  color: isSelected ? Colors.white70 : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${day.day}',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: hasReservation
                      ? (isSelected ? Colors.white : const Color(0xFF22C55E))
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            blurRadius: 14,
            offset: Offset(0, 8),
            color: Color(0x12000000),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: isPast ? const Color(0xFFE2E8F0) : const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              isPast ? Icons.history : Icons.check_circle,
              color: isPast ? const Color(0xFF64748B) : const Color(0xFF15803D),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reservation.className,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${DateFormat.jm().format(reservation.date)} • ${reservation.matNumber}',
                  style: const TextStyle(
                    color: Color(0xFF475569),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  reservation.instructor,
                  style: const TextStyle(color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          _StatusBadge(
            label: isPast ? 'Past' : reservation.status,
            background: isPast
                ? const Color(0xFFF1F5F9)
                : const Color(0xFFEEF2FF),
            foreground: isPast
                ? const Color(0xFF475569)
                : const Color(0xFF4338CA),
          ),
        ],
      ),
    );
  }
}

class _ClassTile extends ConsumerWidget {
  final GymClass gymClass;
  final bool isReserved;

  const _ClassTile({required this.gymClass, required this.isReserved});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ClassDetailScreen(gymClass: gymClass),
          ),
        ),
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                blurRadius: 14,
                offset: Offset(0, 8),
                color: Color(0x12000000),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.self_improvement,
                  color: Color(0xFF0369A1),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      gymClass.title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${gymClass.timeText} • ${gymClass.location}',
                      style: const TextStyle(
                        color: Color(0xFF475569),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${gymClass.filled}/${gymClass.capacity} registered',
                      style: const TextStyle(color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              _StatusBadge(
                label: isReserved
                    ? 'Booked'
                    : gymClass.status.name.toUpperCase(),
                background: isReserved
                    ? const Color(0xFFDCFCE7)
                    : const Color(0xFFF8FAFC),
                foreground: isReserved
                    ? const Color(0xFF166534)
                    : const Color(0xFF334155),
              ),
            ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF64748B),
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 36, color: const Color(0xFF64748B)),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF64748B)),
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
