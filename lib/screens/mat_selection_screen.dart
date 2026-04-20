import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rxdart/rxdart.dart';

import '../db_helpers/db_friends.dart';
import '../db_helpers/db_gym_class.dart';
import '../db_helpers/db_reservations.dart';
import '../main.dart';
import '../models/gym_class.dart';
import '../models/reservation.dart';
import '../providers/provider_reservations.dart';
import '../theme/app_colors.dart';
import '../widgets/general/widget_profile_avatar.dart';
import 'reservation_confirmation_screen.dart';

final _socialMatOccupancyProvider = StreamProvider.autoDispose
    .family<_SocialMatOccupancy, String>((ref, classId) {
      final currentUid = ref.watch(
        providerUserProfile.select((profile) => profile.uid.trim()),
      );
      final friendsStream = currentUid.isEmpty
          ? Stream.value(const <String>{})
          : DBFriends.getFriendUidsStream(currentUid);

      return Rx.combineLatest3<
        List<Reservation>,
        Set<String>,
        Set<int>,
        _SocialMatOccupancy
      >(
        DBReservations.getReservationsForClassStream(classId),
        friendsStream,
        DBReservations.getReservedMatNumbersStream(classId),
        (reservations, friendUids, reservedMatNumbers) {
          return _SocialMatOccupancy.fromReservations(
            reservations: reservations,
            friendUids: friendUids,
            reservedMatNumbers: reservedMatNumbers,
          );
        },
      );
    });

class MatSelectionScreen extends ConsumerStatefulWidget {
  static const String routeName = '/mat_selection';
  final String classId;
  final GymClass? initialGymClass;

  const MatSelectionScreen({
    super.key,
    required this.classId,
    this.initialGymClass,
  });

  @override
  ConsumerState<MatSelectionScreen> createState() => _MatSelectionScreenState();
}

class _MatSelectionScreenState extends ConsumerState<MatSelectionScreen> {
  final List<int> _selectedMats = <int>[];
  bool _isSubmitting = false;
  final Set<String> _selectedInviteeUids = <String>{};
  String _selectedRole = '';
  String _selectedZoneId = '';

  List<List<int>> _buildMatRows(int capacity) {
    final safeCapacity = capacity <= 0 ? 1 : capacity;
    final mats = List<int>.generate(safeCapacity, (index) => index + 1);
    final rowSize = safeCapacity <= 8 ? 4 : 5;

    final rows = <List<int>>[];
    for (var i = 0; i < mats.length; i += rowSize) {
      rows.add(
        mats.sublist(
          i,
          (i + rowSize) > mats.length ? mats.length : i + rowSize,
        ),
      );
    }
    return rows;
  }

  Future<void> _joinStandbyQueue(GymClass gClass) async {
    setState(() => _isSubmitting = true);

    try {
      await DBReservations.joinStandbyQueue(
        ref.read(reservationsProvider).userId ?? '',
        gClass,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Joined standby queue successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        var message = e.toString();
        if (message.startsWith('Exception: ')) {
          message = message.replaceFirst('Exception: ', '');
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to join standby: $message')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _submitReservation(
    GymClass gClass, {
    required List<String> matNumbers,
    required bool sendInvites,
    String bookingRole = '',
  }) async {
    setState(() => _isSubmitting = true);
    try {
      String? reservedMat;
      var inviteCount = 0;
      var skippedInviteCount = 0;

      if (sendInvites && _selectedInviteeUids.isNotEmpty) {
        final currentUser = ref.read(providerUserProfile);
        final currentName = currentUser.wholeName.trim().isEmpty
            ? 'Someone'
            : currentUser.wholeName.trim();
        final groupResult =
            await DBReservations.registerForClassWithGroupInvites(
              hostUserId: currentUser.uid,
              hostName: currentName,
              gymClass: gClass,
              selectedMatNumbers: matNumbers,
              inviteeUids: _selectedInviteeUids.toList(),
              hostBookingRole: bookingRole,
            );
        reservedMat = groupResult.hostMatNumber;
        inviteCount = groupResult.invitesSent;
        skippedInviteCount = groupResult.skippedInviteeUids.length;
      } else {
        reservedMat = await ref
            .read(reservationsProvider)
            .registerForClass(
              gClass,
              matNumber: matNumbers.first,
              bookingRole: bookingRole,
            );
      }

      if (!mounted || reservedMat == null) {
        return;
      }

      final reservation = Reservation(
        id: gClass.id,
        className: gClass.title,
        instructor: gClass.instructor,
        dateTime: '${gClass.dateText} at ${gClass.timeText}',
        matNumber: reservedMat,
        bookingRole: bookingRole,
        status: 'CONFIRMED',
        date: gClass.dateTime,
        durationMinutes: gClass.durationMinutes,
      );

      if (sendInvites && _selectedInviteeUids.isNotEmpty) {
        final skippedText = skippedInviteCount == 0
            ? ''
            : ' $skippedInviteCount already had a spot.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Confirmed ${matNumbers.length} spot${matNumbers.length == 1 ? '' : 's'} and sent $inviteCount invite${inviteCount == 1 ? '' : 's'}. Invites expire after 10 minutes.$skippedText',
            ),
          ),
        );
      }

      context.pushNamed(
        ReservationConfirmationScreen.routeName,
        extra: {'gymClass': gClass, 'reservation': reservation},
      );
    } catch (e) {
      if (!mounted) return;
      var message = e.toString();
      if (message.startsWith('Exception: ')) {
        message = message.replaceFirst('Exception: ', '');
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _openInviteSheet() async {
    final currentUid = ref.read(providerUserProfile).uid;
    if (currentUid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Log in to invite friends.')),
      );
      return;
    }

    final selectedInvitees = await showModalBottomSheet<List<_InviteFriend>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _GroupInviteSheet(
        currentUid: currentUid,
        classId: widget.classId,
        initiallySelectedUids: _selectedInviteeUids,
      ),
    );

    if (!mounted || selectedInvitees == null) {
      return;
    }

    setState(() {
      _selectedInviteeUids
        ..clear()
        ..addAll(selectedInvitees.map((friend) => friend.uid));
      final maxSelections = _groupSize;
      if (_selectedMats.length > maxSelections) {
        _selectedMats.removeRange(maxSelections, _selectedMats.length);
      }
    });
  }

  int get _groupSize => _selectedInviteeUids.length + 1;

  String _confirmLabel(int count) =>
      'Confirm $count Spot${count == 1 ? '' : 's'}';

  bool _usesOpenFloorLayout(GymClass gClass) {
    switch (normalizeGymClassType(gClass.type)) {
      case 'Dance':
      case 'Soccer':
      case 'Sport':
        return true;
      default:
        return false;
    }
  }

  String _openFloorActionLabel(GymClass gClass) {
    switch (normalizeGymClassType(gClass.type)) {
      case 'Dance':
        return 'Join the Dance Floor';
      case 'Soccer':
      case 'Sport':
        return 'Join the Field';
      default:
        return 'Join the Floor';
    }
  }

  String _openFloorSurfaceLabel(GymClass gClass) {
    switch (normalizeGymClassType(gClass.type)) {
      case 'Dance':
        return 'dance floor';
      case 'Soccer':
      case 'Sport':
        return 'field';
      default:
        return 'floor';
    }
  }

  String _openFloorParticipantLabel(GymClass gClass) {
    switch (normalizeGymClassType(gClass.type)) {
      case 'Dance':
        return 'dancers';
      case 'Soccer':
      case 'Sport':
        return 'players';
      default:
        return 'members';
    }
  }

  String _bookingModeLabel(GymClass gClass) {
    return _usesOpenFloorLayout(gClass)
        ? 'OPEN FLOOR'
        : gClass.bookingMode.storageValue;
  }

  String _headerDescriptionFor(GymClass gClass) {
    if (_usesOpenFloorLayout(gClass)) {
      return 'This class uses one-tap floor registration. There are no mat numbers or role selections to manage here.';
    }

    switch (gClass.bookingMode) {
      case BookingMode.open:
        return 'Roster booking fits full-floor classes better. Pick a role, then confirm and we will place you on the floor automatically.';
      case BookingMode.zone:
        return 'Choose a neighborhood first. We will keep your booking inside that zone so the room still feels intentional.';
      case BookingMode.spot:
        return 'The staggered neighborhood map mirrors a studio floor. Avatars show occupied spots, and friends stay highlighted.';
    }
  }

  String _screenTitleFor(GymClass gClass) {
    if (_usesOpenFloorLayout(gClass)) {
      return normalizeGymClassType(gClass.type) == 'Dance'
          ? 'Join The Dance Floor'
          : 'Join The Field';
    }

    switch (gClass.bookingMode) {
      case BookingMode.open:
        return normalizeGymClassType(gClass.type) == 'Dance'
            ? 'Join The Floor'
            : 'Join The Field';
      case BookingMode.zone:
        return 'Choose Your Zone';
      case BookingMode.spot:
        return 'Choose Your Spot';
    }
  }

  List<String> _roleOptionsForClass(GymClass gClass) {
    if (_usesOpenFloorLayout(gClass)) {
      return const <String>[];
    }

    switch (normalizeGymClassType(gClass.type)) {
      case 'Dance':
        return const <String>['Lead', 'Follow', 'Solo'];
      case 'Soccer':
      case 'Sport':
        return const <String>['Striker', 'Midfielder', 'Defense'];
      default:
        return const <String>[];
    }
  }

  List<_ZoneOption> _zoneOptionsForClass(GymClass gClass) {
    final normalizedType = normalizeGymClassType(gClass.type);
    final templates = switch (normalizedType) {
      'HIIT' => const <_ZoneOptionTemplate>[
        _ZoneOptionTemplate(
          id: 'front-row',
          label: 'Front Row',
          description: 'Closest to the demo lane and mirror line.',
          icon: Icons.bolt_rounded,
        ),
        _ZoneOptionTemplate(
          id: 'center-circuit',
          label: 'Center Circuit',
          description: 'Balanced visibility with room to rotate.',
          icon: Icons.grid_view_rounded,
        ),
        _ZoneOptionTemplate(
          id: 'back-line',
          label: 'Back Line',
          description: 'A quieter pocket with extra reset space.',
          icon: Icons.waves_rounded,
        ),
      ],
      'Cardio' => const <_ZoneOptionTemplate>[
        _ZoneOptionTemplate(
          id: 'sprint-lane',
          label: 'Sprint Lane',
          description: 'Fast starts and direct access to the front.',
          icon: Icons.directions_run_rounded,
        ),
        _ZoneOptionTemplate(
          id: 'center-grid',
          label: 'Center Grid',
          description: 'Steady rhythm through the middle of the room.',
          icon: Icons.blur_circular_rounded,
        ),
        _ZoneOptionTemplate(
          id: 'recovery-edge',
          label: 'Recovery Edge',
          description: 'More room to pace and reset between rounds.',
          icon: Icons.favorite_border_rounded,
        ),
      ],
      _ => const <_ZoneOptionTemplate>[
        _ZoneOptionTemplate(
          id: 'front-row',
          label: 'Front Row',
          description: 'Closest to the coach and demo cues.',
          icon: Icons.visibility_rounded,
        ),
        _ZoneOptionTemplate(
          id: 'center-field',
          label: 'Center Field',
          description: 'Even spacing through the middle of the floor.',
          icon: Icons.crop_square_rounded,
        ),
        _ZoneOptionTemplate(
          id: 'goal-side',
          label: 'Goal Side',
          description: 'An edge lane with more room to flow or recover.',
          icon: Icons.flag_circle_rounded,
        ),
      ],
    };

    final zoneSize = (gClass.capacity / templates.length).ceil();
    final zones = <_ZoneOption>[];
    for (var index = 0; index < templates.length; index++) {
      final startSlot = index * zoneSize + 1;
      if (startSlot > gClass.capacity) {
        break;
      }
      final rawEndSlot = (index + 1) * zoneSize;
      final endSlot = rawEndSlot > gClass.capacity
          ? gClass.capacity
          : rawEndSlot;
      final template = templates[index];
      zones.add(
        _ZoneOption(
          id: template.id,
          label: template.label,
          description: template.description,
          icon: template.icon,
          startSlot: startSlot,
          endSlot: endSlot,
        ),
      );
    }
    return zones;
  }

  _ZoneOption? _selectedZoneForClass(GymClass gClass) {
    for (final zone in _zoneOptionsForClass(gClass)) {
      if (zone.id == _selectedZoneId) {
        return zone;
      }
    }
    return null;
  }

  List<int> _availableSlotNumbers(
    GymClass gClass,
    _SocialMatOccupancy socialMatOccupancy, {
    _ZoneOption? zone,
  }) {
    final available = <int>[];
    final startSlot = zone?.startSlot ?? 1;
    final endSlot = zone?.endSlot ?? gClass.capacity;
    for (var slot = startSlot; slot <= endSlot; slot++) {
      if (!socialMatOccupancy.reservedMatNumbers.contains(slot)) {
        available.add(slot);
      }
    }
    return available;
  }

  List<String> _slotLabels(Iterable<int> slotNumbers) {
    return slotNumbers.map((slot) => 'Mat #$slot').toList();
  }

  String _selectionSummary(
    GymClass gClass,
    _SocialMatOccupancy socialMatOccupancy,
    int liveFilled,
  ) {
    if (_usesOpenFloorLayout(gClass)) {
      final remaining = _availableSlotNumbers(
        gClass,
        socialMatOccupancy,
      ).length;
      return '$liveFilled ${_openFloorParticipantLabel(gClass)} currently registered - $remaining spot${remaining == 1 ? '' : 's'} remaining';
    }

    final roleOptions = _roleOptionsForClass(gClass);
    switch (gClass.bookingMode) {
      case BookingMode.open:
        final hasRoleRequirement = roleOptions.isNotEmpty;
        final roleSummary = hasRoleRequirement && _selectedRole.isNotEmpty
            ? 'Role: $_selectedRole'
            : hasRoleRequirement
            ? 'Choose a role'
            : 'Open roster ready';
        final surface = normalizeGymClassType(gClass.type) == 'Dance'
            ? 'studio'
            : 'field';
        return '$roleSummary • ${_availableSlotNumbers(gClass, socialMatOccupancy).length} spots left on the $surface';
      case BookingMode.zone:
        final zone = _selectedZoneForClass(gClass);
        if (zone == null) {
          return 'Choose a zone for $_groupSize spot${_groupSize == 1 ? '' : 's'}';
        }
        final zoneRemaining = _availableSlotNumbers(
          gClass,
          socialMatOccupancy,
          zone: zone,
        ).length;
        return '${zone.label} • $zoneRemaining spots left in zone';
      case BookingMode.spot:
        if (_selectedMats.isEmpty) {
          return _groupSize == 1
              ? 'Select a spot'
              : 'Select $_groupSize spots for your group';
        }
        if (_selectedMats.length < _groupSize) {
          return '${_selectedMats.length} of $_groupSize spots selected';
        }
        return _confirmLabel(_groupSize);
    }
  }

  bool _hasCompleteSelection(
    GymClass gClass,
    _SocialMatOccupancy socialMatOccupancy,
  ) {
    if (_usesOpenFloorLayout(gClass)) {
      return _availableSlotNumbers(gClass, socialMatOccupancy).length >=
          _groupSize;
    }

    switch (gClass.bookingMode) {
      case BookingMode.open:
        final roleOptions = _roleOptionsForClass(gClass);
        if (roleOptions.isNotEmpty && _selectedRole.isEmpty) {
          return false;
        }
        return _availableSlotNumbers(gClass, socialMatOccupancy).length >=
            _groupSize;
      case BookingMode.zone:
        final selectedZone = _selectedZoneForClass(gClass);
        if (selectedZone == null) {
          return false;
        }
        return _availableSlotNumbers(
              gClass,
              socialMatOccupancy,
              zone: selectedZone,
            ).length >=
            _groupSize;
      case BookingMode.spot:
        return _selectedMats.length == _groupSize;
    }
  }

  String _primaryActionLabel(
    GymClass gClass,
    _SocialMatOccupancy socialMatOccupancy, {
    required bool isFull,
    required bool isInStandby,
  }) {
    if (isFull) {
      return isInStandby ? "You're on Standby" : 'Join Standby Queue';
    }

    if (_usesOpenFloorLayout(gClass)) {
      if (_availableSlotNumbers(gClass, socialMatOccupancy).length <
          _groupSize) {
        return 'Not Enough Spots Left';
      }
      return _groupSize == 1
          ? _openFloorActionLabel(gClass)
          : _confirmLabel(_groupSize);
    }

    switch (gClass.bookingMode) {
      case BookingMode.open:
        final roleOptions = _roleOptionsForClass(gClass);
        if (roleOptions.isNotEmpty && _selectedRole.isEmpty) {
          return 'Choose a Role';
        }
        if (_availableSlotNumbers(gClass, socialMatOccupancy).length <
            _groupSize) {
          return 'Not Enough Spots Left';
        }
        return _confirmLabel(_groupSize);
      case BookingMode.zone:
        final zone = _selectedZoneForClass(gClass);
        if (zone == null) {
          return 'Choose a Zone';
        }
        if (_availableSlotNumbers(
              gClass,
              socialMatOccupancy,
              zone: zone,
            ).length <
            _groupSize) {
          return 'Zone Is Too Full';
        }
        return _confirmLabel(_groupSize);
      case BookingMode.spot:
        if (_selectedMats.length < _groupSize) {
          return _groupSize == 1 ? 'Select a Spot' : 'Select $_groupSize Spots';
        }
        return _confirmLabel(_groupSize);
    }
  }

  Future<void> _handleConfirmBooking(
    GymClass gClass,
    _SocialMatOccupancy socialMatOccupancy, {
    required int liveFilled,
  }) async {
    if (!_hasCompleteSelection(gClass, socialMatOccupancy)) {
      return;
    }
    if (liveFilled >= gClass.capacity) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Class just filled up')));
      return;
    }

    late final List<String> matNumbers;
    if (_usesOpenFloorLayout(gClass)) {
      final availableSlots = _availableSlotNumbers(gClass, socialMatOccupancy);
      matNumbers = _slotLabels(availableSlots.take(_groupSize));
      await _submitReservation(
        gClass,
        matNumbers: matNumbers,
        sendInvites: _selectedInviteeUids.isNotEmpty,
        bookingRole: '',
      );
      return;
    }

    switch (gClass.bookingMode) {
      case BookingMode.open:
        final availableSlots = _availableSlotNumbers(
          gClass,
          socialMatOccupancy,
        );
        matNumbers = _slotLabels(availableSlots.take(_groupSize));
      case BookingMode.zone:
        final zone = _selectedZoneForClass(gClass);
        if (zone == null) {
          return;
        }
        final availableSlots = _availableSlotNumbers(
          gClass,
          socialMatOccupancy,
          zone: zone,
        );
        matNumbers = _slotLabels(availableSlots.take(_groupSize));
      case BookingMode.spot:
        final sortedSelections = <int>[..._selectedMats]..sort();
        matNumbers = _slotLabels(sortedSelections);
    }

    await _submitReservation(
      gClass,
      matNumbers: matNumbers,
      sendInvites: _selectedInviteeUids.isNotEmpty,
      bookingRole: _selectedRole,
    );
  }

  @override
  Widget build(BuildContext context) {
    final socialMatOccupancyAsync = ref.watch(
      _socialMatOccupancyProvider(widget.classId),
    );

    return StreamBuilder<GymClass?>(
      stream: DBGymClass.getClassStream(widget.classId),
      initialData: widget.initialGymClass,
      builder: (context, classSnapshot) {
        final gClass = classSnapshot.data;
        if (gClass == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Choose Your Spot')),
            body: const Center(
              child: Text('This class is no longer available.'),
            ),
          );
        }

        final colorScheme = Theme.of(context).colorScheme;
        final textTheme = Theme.of(context).textTheme;
        final usesOpenFloorLayout = _usesOpenFloorLayout(gClass);
        final spotRows =
            !usesOpenFloorLayout && gClass.bookingMode == BookingMode.spot
            ? _buildMatRows(gClass.capacity)
            : const <List<int>>[];
        final socialMatOccupancy =
            socialMatOccupancyAsync.asData?.value ??
            const _SocialMatOccupancy();
        final invalidSelectedInviteeUids = _selectedInviteeUids
            .where(socialMatOccupancy.registeredUserIds.contains)
            .toSet();
        final friendCount = socialMatOccupancy.friendCount;
        final liveFilled = socialMatOccupancyAsync.hasValue
            ? socialMatOccupancy.reservedMatNumbers.length
            : gClass.filled;
        final isFull = liveFilled >= gClass.capacity;
        final roleOptions = _roleOptionsForClass(gClass);
        final zoneOptions = _zoneOptionsForClass(gClass);
        final headerDescription = _headerDescriptionFor(gClass);

        if (invalidSelectedInviteeUids.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) {
              return;
            }

            setState(() {
              _selectedInviteeUids.removeAll(invalidSelectedInviteeUids);
              final maxSelections = _groupSize;
              if (_selectedMats.length > maxSelections) {
                _selectedMats.removeRange(maxSelections, _selectedMats.length);
              }
            });

            final removedCount = invalidSelectedInviteeUids.length;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  removedCount == 1
                      ? 'A selected friend already booked this class and was removed from your group.'
                      : '$removedCount selected friends already booked this class and were removed from your group.',
                ),
              ),
            );
          });
        }

        return StreamBuilder<bool>(
          stream: DBReservations.isUserInStandby(
            ref.read(reservationsProvider).userId ?? '',
            gClass.id,
          ),
          builder: (context, standbySnapshot) {
            final isInStandby = standbySnapshot.data ?? false;
            final bookingSummary = _selectionSummary(
              gClass,
              socialMatOccupancy,
              liveFilled,
            );
            final canSubmit =
                !_isSubmitting &&
                !isInStandby &&
                !isFull &&
                _hasCompleteSelection(gClass, socialMatOccupancy);

            final layout = usesOpenFloorLayout
                ? _OpenFloorLayout(
                    gymClass: gClass,
                    liveFilled: liveFilled,
                    groupSize: _groupSize,
                    socialMatOccupancy: socialMatOccupancy,
                    actionLabel: _openFloorActionLabel(gClass),
                    surfaceLabel: _openFloorSurfaceLabel(gClass),
                    participantLabel: _openFloorParticipantLabel(gClass),
                  )
                : switch (gClass.bookingMode) {
                    BookingMode.open => _OpenRosterLayout(
                      gymClass: gClass,
                      liveFilled: liveFilled,
                      socialMatOccupancy: socialMatOccupancy,
                      roleOptions: roleOptions,
                      selectedRole: _selectedRole,
                      onRoleSelected: (role) {
                        setState(() {
                          _selectedRole = role;
                        });
                      },
                    ),
                    BookingMode.zone => _ZoneMapLayout(
                      gymClass: gClass,
                      socialMatOccupancy: socialMatOccupancy,
                      zoneOptions: zoneOptions,
                      selectedZoneId: _selectedZoneId,
                      onZoneSelected: (zoneId) {
                        setState(() {
                          _selectedZoneId = zoneId;
                        });
                      },
                    ),
                    BookingMode.spot => _SpotMapLayout(
                      matRows: spotRows,
                      socialMatOccupancy: socialMatOccupancy,
                      selectedMats: _selectedMats,
                      groupSize: _groupSize,
                      isLocked: isFull || isInStandby,
                      onToggleMat: (matNumber) {
                        setState(() {
                          if (_selectedMats.contains(matNumber)) {
                            _selectedMats.remove(matNumber);
                            return;
                          }
                          if (_selectedMats.length >= _groupSize) {
                            return;
                          }
                          _selectedMats.add(matNumber);
                        });
                      },
                    ),
                  };

            return Scaffold(
              appBar: AppBar(title: Text(_screenTitleFor(gClass))),
              body: Container(
                color: colorScheme.surface,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: colorScheme.outlineVariant),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    gClass.title,
                                    style: textTheme.headlineSmall?.copyWith(
                                      color: colorScheme.onSurface,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                _SummaryPill(
                                  icon: Icons.event_seat_outlined,
                                  label: '$liveFilled/${gClass.capacity} taken',
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              headerDescription,
                              style: textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _SummaryPill(
                                  icon: Icons.layers_outlined,
                                  label: _bookingModeLabel(gClass),
                                ),
                                if (friendCount > 0)
                                  _SummaryPill(
                                    icon: Icons.people_outline_rounded,
                                    label:
                                        '$friendCount friend${friendCount == 1 ? '' : 's'} here',
                                  ),
                                if (!usesOpenFloorLayout &&
                                    gClass.bookingMode == BookingMode.open &&
                                    roleOptions.isNotEmpty)
                                  _SummaryPill(
                                    icon: Icons.tune_rounded,
                                    label: _selectedRole.isEmpty
                                        ? 'Role required'
                                        : 'Role ${_selectedRole.isEmpty ? 'ready' : _selectedRole}',
                                  ),
                              ],
                            ),
                            if (!usesOpenFloorLayout &&
                                gClass.bookingMode == BookingMode.spot) ...[
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  const _LegendPill(
                                    label: 'Open',
                                    color: AppColors.success,
                                  ),
                                  _LegendPill(
                                    label: 'Selected',
                                    color: colorScheme.primary,
                                  ),
                                  const _LegendPill(
                                    label: 'Occupied',
                                    color: AppColors.secondaryBlue,
                                    marker: _LegendAvatarMarker(),
                                  ),
                                  const _LegendPill(
                                    label: 'Friend',
                                    color: AppColors.primaryPurple,
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                        child: layout,
                      ),
                      SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerHigh,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: colorScheme.outlineVariant,
                                  ),
                                ),
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    final summaryText = Text(
                                      _selectedInviteeUids.isEmpty
                                          ? bookingSummary
                                          : '${_selectedInviteeUids.length} friend${_selectedInviteeUids.length == 1 ? '' : 's'} added. $bookingSummary',
                                      style: textTheme.bodyMedium?.copyWith(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: colorScheme.onSurface,
                                      ),
                                    );
                                    final inviteButton = TextButton.icon(
                                      onPressed:
                                          _isSubmitting || isFull || isInStandby
                                          ? null
                                          : _openInviteSheet,
                                      icon: const Icon(
                                        Icons.group_add_outlined,
                                      ),
                                      label: Text(
                                        _selectedInviteeUids.isEmpty
                                            ? 'Invite Friends'
                                            : 'Edit Group',
                                      ),
                                    );

                                    if (constraints.maxWidth < 380) {
                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          summaryText,
                                          const SizedBox(height: 8),
                                          inviteButton,
                                        ],
                                      );
                                    }

                                    return Row(
                                      children: [
                                        Expanded(child: summaryText),
                                        const SizedBox(width: 8),
                                        inviteButton,
                                      ],
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: isFull
                                      ? (_isSubmitting || isInStandby
                                            ? null
                                            : () => _joinStandbyQueue(gClass))
                                      : canSubmit
                                      ? () => _handleConfirmBooking(
                                          gClass,
                                          socialMatOccupancy,
                                          liveFilled: liveFilled,
                                        )
                                      : null,
                                  child: _isSubmitting
                                      ? SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: colorScheme.onPrimary,
                                          ),
                                        )
                                      : Text(
                                          _primaryActionLabel(
                                            gClass,
                                            socialMatOccupancy,
                                            isFull: isFull,
                                            isInStandby: isInStandby,
                                          ),
                                          style: textTheme.titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                                color: colorScheme.onPrimary,
                                              ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _SpotMapLayout extends StatelessWidget {
  final List<List<int>> matRows;
  final _SocialMatOccupancy socialMatOccupancy;
  final List<int> selectedMats;
  final int groupSize;
  final bool isLocked;
  final ValueChanged<int> onToggleMat;

  const _SpotMapLayout({
    required this.matRows,
    required this.socialMatOccupancy,
    required this.selectedMats,
    required this.groupSize,
    required this.isLocked,
    required this.onToggleMat,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    const gap = 10.0;
    const rowOffsetAmount = 26.0;
    final maxRowLength = matRows.fold<int>(
      0,
      (currentMax, row) => row.length > currentMax ? row.length : currentMax,
    );
    final hasOffsetRows = matRows.asMap().keys.any((index) => index.isOdd);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 18),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Divider(color: colorScheme.outlineVariant, thickness: 1),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.self_improvement,
                      size: 18,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Instructor Front',
                      style: textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colorScheme.primary,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Divider(color: colorScheme.outlineVariant, thickness: 1),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final safeMaxRowLength = maxRowLength == 0 ? 1 : maxRowLength;
              final maxRowOffset = hasOffsetRows ? rowOffsetAmount : 0.0;
              final totalGapWidth = gap * (safeMaxRowLength - 1);
              final availableWidth =
                  constraints.maxWidth - maxRowOffset - totalGapWidth;
              final tileWidth = (availableWidth / safeMaxRowLength)
                  .clamp(42.0, 62.0)
                  .toDouble();

              return Column(
                children: matRows.asMap().entries.map((entry) {
                  final row = entry.value;
                  final rowOffset = entry.key.isOdd ? rowOffsetAmount : 0.0;
                  final rowWidth =
                      rowOffset +
                      (tileWidth * row.length) +
                      (gap * (row.length - 1));

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Center(
                      child: SizedBox(
                        width: rowWidth,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (rowOffset > 0) SizedBox(width: rowOffset),
                            ...row.asMap().entries.expand((rowEntry) {
                              final matNumber = rowEntry.value;
                              final isLast = rowEntry.key == row.length - 1;
                              final isReserved = socialMatOccupancy
                                  .reservedMatNumbers
                                  .contains(matNumber);
                              final isSelected = selectedMats.contains(
                                matNumber,
                              );
                              final occupantInfo = socialMatOccupancy
                                  .occupantInfoByNumber[matNumber];

                              return <Widget>[
                                SizedBox(
                                  width: tileWidth,
                                  child: AspectRatio(
                                    aspectRatio: 0.78,
                                    child: _YogaMatTile(
                                      number: matNumber,
                                      reserved: isReserved,
                                      selected: isSelected,
                                      occupantUid: occupantInfo?.userId,
                                      occupantName:
                                          occupantInfo?.displayName ?? '',
                                      isFriendOccupant:
                                          occupantInfo?.isFriend ?? false,
                                      onTap: isReserved || isLocked
                                          ? null
                                          : () => onToggleMat(matNumber),
                                    ),
                                  ),
                                ),
                                if (!isLast) const SizedBox(width: gap),
                              ];
                            }),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _OpenRosterLayout extends StatelessWidget {
  final GymClass gymClass;
  final int liveFilled;
  final _SocialMatOccupancy socialMatOccupancy;
  final List<String> roleOptions;
  final String selectedRole;
  final ValueChanged<String> onRoleSelected;

  const _OpenRosterLayout({
    required this.gymClass,
    required this.liveFilled,
    required this.socialMatOccupancy,
    required this.roleOptions,
    required this.selectedRole,
    required this.onRoleSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final normalizedType = normalizeGymClassType(gymClass.type);
    final isDance = normalizedType == 'Dance';
    final surfaceLabel = isDance ? 'studio' : 'field';
    final participantLabel = isDance ? 'dancers' : 'players';
    final progress = gymClass.capacity == 0
        ? 0.0
        : liveFilled / gymClass.capacity;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1.75,
            child: _OpenFloorIllustration(
              isDance: isDance,
              colorScheme: colorScheme,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '$liveFilled $participantLabel on the $surfaceLabel',
            style: textTheme.titleLarge?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${(gymClass.capacity - liveFilled).clamp(0, gymClass.capacity)} spots left',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                AppColors.secondaryBlue,
              ),
            ),
          ),
          if (roleOptions.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(
              'Pick your role',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: roleOptions.map((role) {
                final isSelected = selectedRole == role;
                return ChoiceChip(
                  label: Text(role),
                  selected: isSelected,
                  onSelected: (_) => onRoleSelected(role),
                  selectedColor: AppColors.primaryPurple.withValues(
                    alpha: 0.18,
                  ),
                  side: BorderSide(
                    color: isSelected
                        ? AppColors.primaryPurple
                        : colorScheme.outlineVariant,
                  ),
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: isSelected
                        ? AppColors.primaryPurple
                        : colorScheme.onSurface,
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 18),
          _OccupantRosterStrip(
            socialMatOccupancy: socialMatOccupancy,
            emptyLabel:
                'The roster is still open. You could be the first one out there.',
          ),
        ],
      ),
    );
  }
}

class _OpenFloorLayout extends StatelessWidget {
  final GymClass gymClass;
  final int liveFilled;
  final int groupSize;
  final _SocialMatOccupancy socialMatOccupancy;
  final String actionLabel;
  final String surfaceLabel;
  final String participantLabel;

  const _OpenFloorLayout({
    required this.gymClass,
    required this.liveFilled,
    required this.groupSize,
    required this.socialMatOccupancy,
    required this.actionLabel,
    required this.surfaceLabel,
    required this.participantLabel,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final normalizedType = normalizeGymClassType(gymClass.type);
    final isDance = normalizedType == 'Dance';
    final remaining = (gymClass.capacity - liveFilled).clamp(
      0,
      gymClass.capacity,
    );
    final progress = gymClass.capacity == 0
        ? 0.0
        : liveFilled / gymClass.capacity;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1.75,
            child: _OpenFloorIllustration(
              isDance: isDance,
              colorScheme: colorScheme,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            actionLabel,
            style: textTheme.titleLarge?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$liveFilled $participantLabel currently registered - $remaining spot${remaining == 1 ? '' : 's'} remaining',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                AppColors.secondaryBlue,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isDance
                        ? AppColors.primaryPurple.withValues(alpha: 0.14)
                        : AppColors.success.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    isDance ? Icons.music_note_rounded : Icons.sports_soccer,
                    color: isDance
                        ? AppColors.primaryPurple
                        : AppColors.success.withValues(alpha: 0.92),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    groupSize == 1
                        ? 'Tap the button below to join the $surfaceLabel immediately.'
                        : 'Your $groupSize spots will be placed automatically on the $surfaceLabel.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _OccupantRosterStrip(
            socialMatOccupancy: socialMatOccupancy,
            emptyLabel:
                'The $surfaceLabel is still open. You could be the first one out there.',
          ),
        ],
      ),
    );
  }
}

class _ZoneMapLayout extends StatelessWidget {
  final GymClass gymClass;
  final _SocialMatOccupancy socialMatOccupancy;
  final List<_ZoneOption> zoneOptions;
  final String selectedZoneId;
  final ValueChanged<String> onZoneSelected;

  const _ZoneMapLayout({
    required this.gymClass,
    required this.socialMatOccupancy,
    required this.zoneOptions,
    required this.selectedZoneId,
    required this.onZoneSelected,
  });

  int _zoneOccupancy(_ZoneOption zone) {
    return socialMatOccupancy.reservedMatNumbers
        .where((slot) => slot >= zone.startSlot && slot <= zone.endSlot)
        .length;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choose a zone',
            style: textTheme.titleLarge?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Each zone holds a slice of the room. We will place your booking inside the area you tap.',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          ...zoneOptions.map((zone) {
            final occupiedCount = _zoneOccupancy(zone);
            final isSelected = selectedZoneId == zone.id;
            final isFull = occupiedCount >= zone.capacity;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: () => onZoneSelected(zone.id),
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primaryPurple.withValues(alpha: 0.12)
                        : colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primaryPurple
                          : colorScheme.outlineVariant,
                      width: isSelected ? 1.6 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primaryPurple.withValues(alpha: 0.16)
                              : colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          zone.icon,
                          color: isSelected
                              ? AppColors.primaryPurple
                              : colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              zone.label,
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              zone.description,
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '$occupiedCount/${zone.capacity}',
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isFull
                                ? 'Full'
                                : '${zone.capacity - occupiedCount} left',
                            style: textTheme.bodySmall?.copyWith(
                              color: isFull
                                  ? colorScheme.error
                                  : colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _OpenFloorIllustration extends StatelessWidget {
  final bool isDance;
  final ColorScheme colorScheme;

  const _OpenFloorIllustration({
    required this.isDance,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final accent = isDance
        ? AppColors.primaryPurple.withValues(alpha: 0.18)
        : AppColors.success.withValues(alpha: 0.18);
    final border = isDance ? AppColors.primaryPurple : AppColors.success;

    return Container(
      decoration: BoxDecoration(
        color: accent,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: border.withValues(alpha: 0.55), width: 1.2),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: border.withValues(alpha: 0.32),
                    width: 1.2,
                  ),
                ),
              ),
            ),
          ),
          if (!isDance) ...[
            Positioned.fill(
              child: Center(
                child: Container(
                  width: 74,
                  height: 74,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: border.withValues(alpha: 0.28),
                      width: 1.2,
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Center(
                child: Container(
                  width: 1.2,
                  color: border.withValues(alpha: 0.24),
                ),
              ),
            ),
          ] else ...[
            Positioned(
              top: 18,
              left: 24,
              right: 24,
              child: Container(
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Positioned.fill(
              child: Center(
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.62),
                      width: 1.1,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OccupantRosterStrip extends StatelessWidget {
  final _SocialMatOccupancy socialMatOccupancy;
  final String emptyLabel;

  const _OccupantRosterStrip({
    required this.socialMatOccupancy,
    required this.emptyLabel,
  });

  @override
  Widget build(BuildContext context) {
    final entries = socialMatOccupancy.occupantInfoByNumber.entries.toList()
      ..sort((left, right) => left.key.compareTo(right.key));
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (entries.isEmpty) {
      return Text(
        emptyLabel,
        style: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
          height: 1.4,
        ),
      );
    }

    final previewEntries = entries.take(8).toList();
    final remainingCount = entries.length - previewEntries.length;
    return Row(
      children: [
        Expanded(
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: previewEntries.map((entry) {
              final info = entry.value;
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: info.isFriend
                        ? AppColors.primaryPurple.withValues(alpha: 0.55)
                        : colorScheme.outlineVariant,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    UserUidAvatar(
                      uid: info.userId,
                      userWholeName: info.displayName,
                      radius: 12,
                      backgroundColor: info.isFriend
                          ? AppColors.primaryPurple
                          : AppColors.secondaryBlue,
                      foregroundColor: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      info.displayName,
                      style: textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        if (remainingCount > 0) ...[
          const SizedBox(width: 10),
          _SummaryPill(
            icon: Icons.more_horiz_rounded,
            label: '+$remainingCount more',
          ),
        ],
      ],
    );
  }
}

class _ZoneOptionTemplate {
  final String id;
  final String label;
  final String description;
  final IconData icon;

  const _ZoneOptionTemplate({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
  });
}

class _ZoneOption {
  final String id;
  final String label;
  final String description;
  final IconData icon;
  final int startSlot;
  final int endSlot;

  const _ZoneOption({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
    required this.startSlot,
    required this.endSlot,
  });

  int get capacity => endSlot - startSlot + 1;
}

class _SocialMatOccupancy {
  final Set<int> reservedMatNumbers;
  final Set<String> registeredUserIds;
  final Map<int, _MatOccupantInfo> occupantInfoByNumber;

  const _SocialMatOccupancy({
    this.reservedMatNumbers = const <int>{},
    this.registeredUserIds = const <String>{},
    this.occupantInfoByNumber = const <int, _MatOccupantInfo>{},
  });

  int get friendCount =>
      occupantInfoByNumber.values.where((info) => info.isFriend).length;

  factory _SocialMatOccupancy.fromReservations({
    required List<Reservation> reservations,
    required Set<String> friendUids,
    required Set<int> reservedMatNumbers,
  }) {
    final allReservedMatNumbers = <int>{...reservedMatNumbers};
    final registeredUserIds = <String>{};
    final occupantInfoByNumber = <int, _MatOccupantInfo>{};

    for (final reservation in reservations) {
      final userId = reservation.userId.trim();
      final matNumber = DBReservations.parseMatNumber(reservation.matNumber);
      if (matNumber == null) {
        continue;
      }

      allReservedMatNumbers.add(matNumber);
      if (userId.isNotEmpty) {
        registeredUserIds.add(userId);
      }

      final isFriend = userId.isNotEmpty && friendUids.contains(userId);
      final rawDisplayName = _occupantDisplayNameForReservation(reservation);
      if (userId.isEmpty && rawDisplayName.isEmpty) {
        continue;
      }

      occupantInfoByNumber[matNumber] = _MatOccupantInfo(
        userId: userId,
        displayName: rawDisplayName.isNotEmpty
            ? rawDisplayName
            : (isFriend ? 'Friend' : 'Member'),
        isFriend: isFriend,
      );
    }

    return _SocialMatOccupancy(
      reservedMatNumbers: allReservedMatNumbers,
      registeredUserIds: registeredUserIds,
      occupantInfoByNumber: occupantInfoByNumber,
    );
  }
}

class _MatOccupantInfo {
  final String userId;
  final String displayName;
  final bool isFriend;

  const _MatOccupantInfo({
    required this.userId,
    required this.displayName,
    this.isFriend = false,
  });
}

class _YogaMatTile extends StatelessWidget {
  final int number;
  final bool reserved;
  final bool selected;
  final String? occupantUid;
  final String occupantName;
  final bool isFriendOccupant;
  final VoidCallback? onTap;

  const _YogaMatTile({
    required this.number,
    required this.reserved,
    required this.selected,
    this.occupantUid,
    this.occupantName = '',
    this.isFriendOccupant = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasOccupantAvatar =
        reserved && (occupantUid?.trim().isNotEmpty ?? false);
    final isFriendMat = hasOccupantAvatar && isFriendOccupant;
    final fill = selected
        ? colorScheme.primary
        : isFriendMat
        ? AppColors.primaryPurple
        : reserved
        ? AppColors.secondaryBlue
        : AppColors.success;
    final border = selected
        ? colorScheme.primary
        : isFriendMat
        ? AppColors.primaryPurple.withValues(alpha: 0.9)
        : reserved
        ? AppColors.secondaryBlue.withValues(alpha: 0.92)
        : AppColors.success.withValues(alpha: 0.9);
    final avatarBackground = isFriendMat
        ? AppColors.primaryPurple
        : AppColors.secondaryBlue;
    final trimmedOccupantName = occupantName.trim();
    final label = hasOccupantAvatar
        ? (trimmedOccupantName.isEmpty
              ? 'Occupied mat $number'
              : '$trimmedOccupantName on mat $number')
        : reserved
        ? 'Reserved mat $number'
        : 'Mat $number';

    return Tooltip(
      message: label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: selected
                    ? colorScheme.primary.withValues(alpha: 0.24)
                    : Colors.black.withValues(alpha: 0.08),
                blurRadius: selected ? 16 : 8,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final shortestSide = math
                  .min(constraints.maxWidth, constraints.maxHeight)
                  .toDouble();
              final edgeInset = (shortestSide * 0.18)
                  .clamp(8.0, 12.0)
                  .toDouble();
              final badgeSize = (shortestSide * 0.28)
                  .clamp(16.0, 22.0)
                  .toDouble();
              final statusIconSize = (shortestSide * 0.30)
                  .clamp(14.0, 18.0)
                  .toDouble();
              final numberFontSize = (shortestSide * 0.54)
                  .clamp(18.0, 28.0)
                  .toDouble();

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _YogaMatPainter(
                        fill: fill,
                        border: border,
                        borderWidth: selected ? 1.8 : 1.5,
                      ),
                    ),
                  ),
                  if (hasOccupantAvatar)
                    Center(
                      child: UserUidAvatar(
                        uid: occupantUid ?? '',
                        userWholeName: occupantName,
                        radius: 15,
                        backgroundColor: avatarBackground,
                        foregroundColor: Colors.white,
                        borderColor: Colors.white,
                        borderWidth: 1.5,
                      ),
                    )
                  else
                    Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: shortestSide * 0.12,
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '$number',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: numberFontSize,
                              letterSpacing: 0.6,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (hasOccupantAvatar)
                    Positioned(
                      top: edgeInset,
                      right: edgeInset,
                      child: Container(
                        width: badgeSize,
                        height: badgeSize,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.96),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: border.withValues(alpha: 0.42),
                            width: 1,
                          ),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '$number',
                            style: TextStyle(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w900,
                              fontSize: badgeSize * 0.52,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (selected)
                    Positioned(
                      top: edgeInset,
                      left: edgeInset,
                      child: Icon(
                        Icons.check_circle,
                        color: Colors.white,
                        size: statusIconSize,
                      ),
                    ),
                  if (reserved && !hasOccupantAvatar)
                    Positioned(
                      top: edgeInset,
                      right: edgeInset,
                      child: Container(
                        padding: EdgeInsets.all(statusIconSize * 0.16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: statusIconSize * 0.78,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _YogaMatPainter extends CustomPainter {
  final Color fill;
  final Color border;
  final double borderWidth;

  const _YogaMatPainter({
    required this.fill,
    required this.border,
    required this.borderWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final radius = Radius.circular(
      (math.min(size.width, size.height) * 0.34).toDouble(),
    );
    final shell = RRect.fromRectAndRadius(rect, radius);

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.lerp(fill, Colors.white, 0.1)!,
          fill,
          Color.lerp(fill, Colors.black, 0.12)!,
        ],
      ).createShader(rect);
    canvas.drawRRect(shell, fillPaint);

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..color = border;
    canvas.drawRRect(shell.deflate(borderWidth / 2), borderPaint);

    final topGlossRect = RRect.fromLTRBR(
      size.width * 0.18,
      size.height * 0.11,
      size.width * 0.82,
      size.height * 0.19,
      Radius.circular(size.height * 0.06),
    );
    canvas.drawRRect(
      topGlossRect,
      Paint()..color = Colors.white.withValues(alpha: 0.28),
    );

    final seamPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.16)
      ..strokeWidth = math.max(1.4, size.height * 0.02).toDouble()
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * 0.25, size.height * 0.42),
      Offset(size.width * 0.75, size.height * 0.42),
      seamPaint,
    );

    final baseShadowRect = RRect.fromLTRBR(
      size.width * 0.22,
      size.height * 0.75,
      size.width * 0.78,
      size.height * 0.87,
      Radius.circular(size.height * 0.08),
    );
    canvas.drawRRect(
      baseShadowRect,
      Paint()..color = Colors.black.withValues(alpha: 0.1),
    );
  }

  @override
  bool shouldRepaint(covariant _YogaMatPainter oldDelegate) {
    return oldDelegate.fill != fill ||
        oldDelegate.border != border ||
        oldDelegate.borderWidth != borderWidth;
  }
}

class _SummaryPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SummaryPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: colorScheme.primary),
          const SizedBox(width: 5),
          Text(
            label,
            style: textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendPill extends StatelessWidget {
  final String label;
  final Color color;
  final Widget? marker;

  const _LegendPill({required this.label, required this.color, this.marker});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          marker ??
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendAvatarMarker extends StatelessWidget {
  const _LegendAvatarMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.secondaryBlue.withValues(alpha: 0.86),
        border: Border.all(color: Colors.white, width: 1.2),
      ),
      child: const Icon(Icons.person, size: 8, color: Colors.white),
    );
  }
}

String _occupantDisplayNameForReservation(Reservation reservation) {
  final trimmedUserName = reservation.userName.trim();
  if (trimmedUserName.isNotEmpty) {
    return trimmedUserName;
  }

  final trimmedEmail = reservation.userEmail.trim();
  if (trimmedEmail.isNotEmpty) {
    return trimmedEmail;
  }

  return '';
}

bool _isStaffRole(String role) {
  return role.trim().toLowerCase() == 'staff';
}

class _InviteFriend {
  final String uid;
  final String wholeName;
  final String bio;
  final String role;
  final bool isAlreadyRegistered;

  const _InviteFriend({
    required this.uid,
    required this.wholeName,
    required this.bio,
    required this.role,
    this.isAlreadyRegistered = false,
  });

  bool get canInvite => !_isStaffRole(role) && !isAlreadyRegistered;
}

class _GroupInviteSheet extends StatefulWidget {
  final String currentUid;
  final String classId;
  final Set<String> initiallySelectedUids;

  const _GroupInviteSheet({
    required this.currentUid,
    required this.classId,
    this.initiallySelectedUids = const <String>{},
  });

  @override
  State<_GroupInviteSheet> createState() => _GroupInviteSheetState();
}

class _GroupInviteSheetState extends State<_GroupInviteSheet> {
  late final Set<String> _selectedUids = <String>{
    ...widget.initiallySelectedUids,
  };
  final Map<String, _InviteFriend> _friendsById = <String, _InviteFriend>{};

  Stream<Map<String, Map<String, dynamic>>> _friendProfilesStream(
    List<String> friendIds,
  ) {
    final profileStreams = friendIds
        .map(
          (uid) => FirebaseFirestore.instance
              .collection('user_profiles')
              .doc(uid)
              .snapshots(),
        )
        .toList();

    if (profileStreams.length == 1) {
      return profileStreams.first.map(
        (snapshot) => _profilesByIdFromDocuments([snapshot]),
      );
    }

    return Rx.combineLatestList<DocumentSnapshot<Map<String, dynamic>>>(
      profileStreams,
    ).map(_profilesByIdFromDocuments);
  }

  Map<String, Map<String, dynamic>> _profilesByIdFromDocuments(
    Iterable<DocumentSnapshot<Map<String, dynamic>>> snapshots,
  ) {
    final profilesById = <String, Map<String, dynamic>>{};
    for (final snapshot in snapshots) {
      final data = snapshot.data();
      if (!snapshot.exists || data == null) {
        continue;
      }
      profilesById[snapshot.id] = data;
    }
    return profilesById;
  }

  Stream<List<_InviteFriend>> _inviteOptionsStream() {
    return DBFriends.getFriendUidsStream(widget.currentUid).switchMap((
      friendIds,
    ) {
      final sortedFriendIds =
          friendIds
              .map((uid) => uid.trim())
              .where((uid) => uid.isNotEmpty)
              .toSet()
              .toList()
            ..sort();
      if (sortedFriendIds.isEmpty) {
        return Stream.value(const <_InviteFriend>[]);
      }

      return Rx.combineLatest2<
        Map<String, Map<String, dynamic>>,
        List<Reservation>,
        List<_InviteFriend>
      >(
        _friendProfilesStream(sortedFriendIds),
        DBReservations.getReservationsForClassStream(widget.classId),
        (profilesById, reservations) {
          final registeredUserIds = reservations
              .map((reservation) => reservation.userId.trim())
              .where((userId) => userId.isNotEmpty)
              .toSet();

          final friends =
              sortedFriendIds
                  .map((uid) {
                    final data = profilesById[uid];
                    if (data == null) {
                      return null;
                    }

                    return _InviteFriend(
                      uid: uid,
                      wholeName: DBReservations.resolveUserDisplayName(data),
                      bio: (data['bio'] ?? '').toString(),
                      role: (data['role'] ?? 'Member').toString(),
                      isAlreadyRegistered: registeredUserIds.contains(uid),
                    );
                  })
                  .whereType<_InviteFriend>()
                  .where((friend) => !_isStaffRole(friend.role))
                  .toList()
                ..sort(
                  (a, b) => a.wholeName.toLowerCase().compareTo(
                    b.wholeName.toLowerCase(),
                  ),
                );

          return friends;
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Build Your Group',
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose friends now, then confirm the spots you want to book together. Friends who already have a spot stay unavailable here.',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 360,
              child: StreamBuilder<List<_InviteFriend>>(
                stream: _inviteOptionsStream(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Unable to load your friends right now.',
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final friends = snapshot.data ?? const <_InviteFriend>[];
                  if (friends.isEmpty) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: colorScheme.outlineVariant),
                      ),
                      child: Text(
                        'Add a few member friends first, then you can invite them to join from this screen.',
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    );
                  }

                  final selectableUids = friends
                      .where((friend) => friend.canInvite)
                      .map((friend) => friend.uid)
                      .toSet();
                  final invalidSelectedUids = _selectedUids
                      .where((uid) => !selectableUids.contains(uid))
                      .toSet();

                  if (invalidSelectedUids.isNotEmpty) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) {
                        return;
                      }
                      setState(
                        () => _selectedUids.removeAll(invalidSelectedUids),
                      );
                    });
                  }

                  _friendsById
                    ..clear()
                    ..addEntries(
                      friends
                          .where((friend) => friend.canInvite)
                          .map((friend) => MapEntry(friend.uid, friend)),
                    );

                  return ListView.separated(
                    itemCount: friends.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final friend = friends[index];
                      final isSelected = _selectedUids.contains(friend.uid);
                      final isDisabled = !friend.canInvite;
                      final cardColor = isDisabled
                          ? colorScheme.surfaceContainerLow
                          : isSelected
                          ? colorScheme.primaryContainer
                          : colorScheme.surfaceContainer;
                      final borderColor = isDisabled
                          ? colorScheme.outlineVariant
                          : isSelected
                          ? colorScheme.primary
                          : colorScheme.outlineVariant;
                      final titleColor = isDisabled
                          ? colorScheme.onSurfaceVariant
                          : colorScheme.onSurface;

                      return InkWell(
                        onTap: isDisabled
                            ? null
                            : () {
                                setState(() {
                                  if (isSelected) {
                                    _selectedUids.remove(friend.uid);
                                  } else {
                                    _selectedUids.add(friend.uid);
                                  }
                                });
                              },
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: borderColor),
                          ),
                          child: Row(
                            children: [
                              UserUidAvatar(
                                uid: friend.uid,
                                userWholeName: friend.wholeName,
                                radius: 20,
                                backgroundColor: colorScheme.primary,
                                foregroundColor: colorScheme.onPrimary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      friend.wholeName.isEmpty
                                          ? 'Member'
                                          : friend.wholeName,
                                      style: textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: titleColor,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      friend.isAlreadyRegistered
                                          ? 'Already registered for this class'
                                          : friend.bio.trim().isEmpty
                                          ? 'Available to add to your group'
                                          : friend.bio.trim(),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: textTheme.bodySmall?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (friend.isAlreadyRegistered)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colorScheme.surface,
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: colorScheme.outlineVariant,
                                    ),
                                  ),
                                  child: Text(
                                    'Booked',
                                    style: textTheme.labelMedium?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                )
                              else
                                Checkbox(
                                  value: isSelected,
                                  onChanged: (_) {
                                    setState(() {
                                      if (isSelected) {
                                        _selectedUids.remove(friend.uid);
                                      } else {
                                        _selectedUids.add(friend.uid);
                                      }
                                    });
                                  },
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.of(context).pop(
                    _selectedUids
                        .map((uid) => _friendsById[uid])
                        .whereType<_InviteFriend>()
                        .toList(),
                  );
                },
                child: Text(
                  _selectedUids.isEmpty
                      ? 'Continue Without Friends'
                      : 'Use ${_selectedUids.length} Friend${_selectedUids.length == 1 ? '' : 's'}',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
