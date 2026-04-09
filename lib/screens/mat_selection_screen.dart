import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../db_helpers/db_gym_class.dart';
import '../db_helpers/db_reservations.dart';
import '../main.dart';
import '../models/gym_class.dart';
import '../models/reservation.dart';
import '../providers/provider_reservations.dart';
import '../theme/app_colors.dart';
import 'reservation_confirmation_screen.dart';

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

  List<List<int>> _buildMatRows(int capacity) {
    final safeCapacity = capacity <= 0 ? 1 : capacity;
    final mats = List<int>.generate(safeCapacity, (index) => index + 1);
    final rowSize = safeCapacity <= 8
        ? 4
        : safeCapacity <= 15
            ? 5
            : 6;

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
        );
        reservedMat = groupResult.hostMatNumber;
        inviteCount = groupResult.invitesSent;
        skippedInviteCount = groupResult.skippedInviteeUids.length;
      } else {
        reservedMat = await ref.read(reservationsProvider).registerForClass(
              gClass,
              matNumber: matNumbers.first,
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
              'Reserved $reservedMat plus ${inviteCount} more mat${inviteCount == 1 ? '' : 's'} and sent $inviteCount invite${inviteCount == 1 ? '' : 's'}.$skippedText',
            ),
          ),
        );
      }

      context.pushNamed(
        ReservationConfirmationScreen.routeName,
        extra: {
          'gymClass': gClass,
          'reservation': reservation,
        },
      );
    } catch (e) {
      if (!mounted) return;
      var message = e.toString();
      if (message.startsWith('Exception: ')) {
        message = message.replaceFirst('Exception: ', '');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
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

  String _selectionSummary() {
    if (_selectedMats.isEmpty) {
      return _groupSize == 1
          ? 'No mat selected'
          : 'Select $_groupSize mats for your group';
    }
    final labels = _selectedMats.map((mat) => 'Mat $mat').join(', ');
    return _groupSize == 1
        ? labels
        : '$labels selected (${_selectedMats.length}/$_groupSize)';
  }

  @override
  Widget build(BuildContext context) {
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
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final matRows = _buildMatRows(gClass.capacity);
        return StreamBuilder<int>(
          stream: DBReservations.getReservationCountForClassStream(gClass.id),
          builder: (context, countSnapshot) {
            final liveFilled = countSnapshot.data ?? gClass.filled;
            final isFull = liveFilled >= gClass.capacity;

            return StreamBuilder<bool>(
              stream: DBReservations.isUserInStandby(
                ref.read(reservationsProvider).userId ?? '',
                gClass.id,
              ),
              builder: (context, standbySnapshot) {
                final isInStandby = standbySnapshot.data ?? false;

                return Scaffold(
                  appBar: AppBar(title: const Text('Choose Your Spot')),
                  body: Container(
                    color: colorScheme.surface,
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                      Container(
                        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: isDark
                                ? const [
                                    AppColors.gradientStartDark,
                                    AppColors.gradientEndDark,
                                  ]
                                : const [
                                    AppColors.gradientStart,
                                    AppColors.gradientEnd,
                                  ],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.14),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              gClass.title,
                              style: textTheme.headlineSmall?.copyWith(
                                color: AppColors.headerOnBrand,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            StreamBuilder<Set<int>>(
                              stream: DBReservations.getReservedMatNumbersStream(
                                gClass.id,
                              ),
                              initialData: const <int>{},
                              builder: (context, snapshot) {
                                final reservedCount =
                                    (snapshot.data ?? const <int>{}).length;
                                return Text(
                                  _groupSize == 1
                                      ? 'Choose the mat spot you want before confirming. $reservedCount/${gClass.capacity} are already taken.'
                                      : 'Choose $_groupSize mats for your group. The first mat you tap is yours, and the rest are held for your invited friends. $reservedCount/${gClass.capacity} are already taken.',
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: AppColors.headerOnBrand.withValues(
                                      alpha: 0.88,
                                    ),
                                    height: 1.4,
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                const _LegendPill(
                                  label: 'Available',
                                  color: AppColors.success,
                                ),
                                _LegendPill(
                                  label: 'Selected',
                                  color: colorScheme.primary,
                                ),
                                _LegendPill(
                                  label: 'Reserved',
                                  color: colorScheme.outline,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: colorScheme.outlineVariant),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.self_improvement,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'INSTRUCTOR FRONT',
                                style: textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: colorScheme.primary,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      StreamBuilder<Set<int>>(
                        stream: DBReservations.getReservedMatNumbersStream(
                          gClass.id,
                        ),
                        initialData: const <int>{},
                        builder: (context, snapshot) {
                          final reservedMats = snapshot.data ?? <int>{};
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                            child: Container(
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainer,
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(
                                  color: colorScheme.outlineVariant,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: matRows
                                    .asMap()
                                    .entries
                                    .map(
                                      (entry) => Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: entry.key.isEven ? 16 : 28,
                                          vertical: 10,
                                        ),
                                        child: LayoutBuilder(
                                          builder: (context, constraints) {
                                            final rowCount = entry.value.length;
                                            const horizontalPaddingPerMat = 8.0;
                                            final availableWidth =
                                                constraints.maxWidth -
                                                    (rowCount *
                                                        horizontalPaddingPerMat);
                                            final maxTileWidth =
                                                availableWidth / rowCount;
                                            final tileWidth = maxTileWidth.clamp(
                                              32.0,
                                              54.0,
                                            );

                                            return Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: entry.value.map((matNumber) {
                                                final isReserved = reservedMats
                                                    .contains(matNumber);
                                                final isSelected = _selectedMats
                                                    .contains(matNumber);

                                                return Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                    horizontal: 4,
                                                  ),
                                                  child: SizedBox(
                                                    width: tileWidth,
                                                    child: AspectRatio(
                                                      aspectRatio: 0.52,
                                                      child: _YogaMatTile(
                                                        number: matNumber,
                                                        reserved: isReserved,
                                                        selected: isSelected,
                                                        onTap: isReserved ||
                                                                isFull ||
                                                                isInStandby
                                                            ? null
                                                            : () {
                                                                setState(() {
                                                                  if (isSelected) {
                                                                    _selectedMats.remove(
                                                                      matNumber,
                                                                    );
                                                                    return;
                                                                  }
                                                                  if (_selectedMats
                                                                          .length >=
                                                                      _groupSize) {
                                                                    return;
                                                                  }
                                                                  _selectedMats.add(
                                                                    matNumber,
                                                                  );
                                                                });
                                                              },
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              }).toList(),
                                            );
                                          },
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                          );
                        },
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
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _selectedInviteeUids.isEmpty
                                            ? (_selectedMats.isEmpty
                                                ? 'No mat selected'
                                                : _selectionSummary())
                                            : '${_selectedInviteeUids.length} friend${_selectedInviteeUids.length == 1 ? '' : 's'} selected, so choose $_groupSize mats',
                                        style: textTheme.bodyMedium?.copyWith(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                    ),
                                    TextButton.icon(
                                      onPressed: _isSubmitting || isFull || isInStandby
                                          ? null
                                          : _openInviteSheet,
                                      icon: const Icon(Icons.group_add_outlined),
                                      label: Text(
                                        _selectedInviteeUids.isEmpty
                                            ? 'Invite Friends'
                                            : 'Edit Group',
                                      ),
                                    ),
                                  ],
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
                                      : (_selectedMats.length != 1 ||
                                              _isSubmitting ||
                                              _selectedInviteeUids.isNotEmpty)
                                          ? null
                                          : () async {
                                              if (liveFilled >=
                                                  gClass.capacity) {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Class just filled up',
                                                    ),
                                                  ),
                                                );
                                                return;
                                              }

                                              final matNumbers = <String>[
                                                'Mat #${_selectedMats.first}',
                                              ];
                                              await _submitReservation(
                                                gClass,
                                                matNumbers: matNumbers,
                                                sendInvites: false,
                                              );
                                            },
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
                                          isFull
                                              ? (isInStandby
                                                  ? "You're on Standby"
                                                  : 'Join Standby Queue')
                                              : _selectedMats.isEmpty
                                                  ? 'Select a Mat'
                                                  : 'Reserve ${_selectionSummary()}',
                                          style:
                                              textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.w800,
                                            color: colorScheme.onPrimary,
                                          ),
                                        ),
                                ),
                              ),
                              if (_selectedInviteeUids.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  height: 54,
                                  child: FilledButton.icon(
                                    onPressed: (_selectedMats.length != _groupSize ||
                                            _isSubmitting ||
                                            isFull ||
                                            isInStandby)
                                        ? null
                                        : () async {
                                            if (liveFilled >= gClass.capacity) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Class just filled up',
                                                  ),
                                                ),
                                              );
                                              return;
                                            }
                                            final matNumbers = _selectedMats
                                                .map((mat) => 'Mat #$mat')
                                                .toList();
                                            await _submitReservation(
                                              gClass,
                                              matNumbers: matNumbers,
                                              sendInvites: true,
                                            );
                                          },
                                    icon: const Icon(Icons.groups_2_outlined),
                                    label: Text(
                                      _selectedMats.length != _groupSize
                                          ? 'Select $_groupSize Mats'
                                          : 'Reserve ${_selectedMats.length} Group Mats',
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
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _YogaMatTile extends StatelessWidget {
  final int number;
  final bool reserved;
  final bool selected;
  final VoidCallback? onTap;

  const _YogaMatTile({
    required this.number,
    required this.reserved,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final fill = reserved
        ? colorScheme.outline
        : selected
            ? colorScheme.primary
            : AppColors.success;
    final border = reserved
        ? colorScheme.onSurfaceVariant.withValues(alpha: 0.7)
        : selected
            ? colorScheme.primary.withValues(alpha: 0.88)
            : AppColors.success.withValues(alpha: 0.88);

    return GestureDetector(
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
                  ? colorScheme.primary.withValues(alpha: 0.22)
                  : Colors.black.withValues(alpha: 0.08),
              blurRadius: selected ? 16 : 8,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color.lerp(fill, Colors.white, 0.10)!,
                      fill,
                      Color.lerp(fill, Colors.black, 0.12)!,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: border, width: 1.5),
                ),
              ),
            ),
            Positioned(
              top: 8,
              left: 10,
              right: 10,
              child: Container(
                height: 7,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Positioned(
              top: 18,
              left: 16,
              right: 16,
              child: Container(
                height: 1.5,
                color: Colors.white.withValues(alpha: 0.16),
              ),
            ),
            Positioned(
              bottom: 16,
              left: 14,
              right: 14,
              child: Container(
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Center(
              child: RotatedBox(
                quarterTurns: 3,
                child: Text(
                  '$number',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
            if (selected)
              const Positioned(
                top: 10,
                right: 10,
                child: Icon(Icons.check_circle, color: Colors.white, size: 18),
              ),
            if (reserved)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LegendPill extends StatelessWidget {
  final String label;
  final Color color;

  const _LegendPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.headerOnBrand,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _InviteFriend {
  final String uid;
  final String wholeName;
  final String bio;

  const _InviteFriend({
    required this.uid,
    required this.wholeName,
    required this.bio,
  });
}

class _GroupInviteSheet extends StatefulWidget {
  final String currentUid;
  final Set<String> initiallySelectedUids;

  const _GroupInviteSheet({
    required this.currentUid,
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
              'Choose friends now, then pick the group mats you want to book.',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 360,
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('user_profiles')
                    .doc(widget.currentUid)
                    .collection('friends')
                    .snapshots(),
                builder: (context, friendsSnapshot) {
                  if (friendsSnapshot.hasError) {
                    return const Center(
                      child: Text('Unable to load your friends right now.'),
                    );
                  }
                  if (friendsSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final friendIds = friendsSnapshot.data?.docs
                          .map((doc) => (doc.data()['uid'] ?? doc.id).toString())
                          .where((uid) => uid.trim().isNotEmpty)
                          .map((uid) => uid.trim())
                          .toSet() ??
                      <String>{};

                  if (friendIds.isEmpty) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: colorScheme.outlineVariant),
                      ),
                      child: Text(
                        'Add a few friends first, then you can invite them to join from this screen.',
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    );
                  }

                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('user_profiles')
                        .snapshots(),
                    builder: (context, usersSnapshot) {
                      if (usersSnapshot.hasError) {
                        return const Center(
                          child: Text('Unable to load members right now.'),
                        );
                      }
                      if (usersSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final friends = usersSnapshot.data?.docs
                              .where((doc) => friendIds.contains(doc.id))
                              .map(
                                (doc) => _InviteFriend(
                                  uid: doc.id,
                                  wholeName:
                                      '${(doc.data()['first_name'] ?? '').toString().trim()} ${(doc.data()['last_name'] ?? '').toString().trim()}'
                                          .trim(),
                                  bio: (doc.data()['bio'] ?? '').toString(),
                                ),
                              )
                              .toList() ??
                          <_InviteFriend>[];

                      friends.sort(
                        (a, b) => a.wholeName.toLowerCase().compareTo(
                          b.wholeName.toLowerCase(),
                        ),
                      );
                      _friendsById
                        ..clear()
                        ..addEntries(
                          friends.map((friend) => MapEntry(friend.uid, friend)),
                        );

                      return ListView.separated(
                        itemCount: friends.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final friend = friends[index];
                          final isSelected = _selectedUids.contains(friend.uid);
                          return InkWell(
                            onTap: () {
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
                                color: isSelected
                                    ? colorScheme.primaryContainer
                                    : colorScheme.surfaceContainer,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: isSelected
                                      ? colorScheme.primary
                                      : colorScheme.outlineVariant,
                                ),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: colorScheme.primary,
                                    child: Text(
                                      _initialsFromName(friend.wholeName),
                                      style: TextStyle(
                                        color: colorScheme.onPrimary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
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
                                            color: colorScheme.onSurface,
                                          ),
                                        ),
                                        if (friend.bio.trim().isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            friend.bio.trim(),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: textTheme.bodySmall?.copyWith(
                                              color: colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
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

  String _initialsFromName(String wholeName) {
    final parts = wholeName
        .split(' ')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return '?';
    }
    final first = parts.first[0].toUpperCase();
    final last = parts.length > 1 ? parts.last[0].toUpperCase() : '';
    return '$first$last';
  }
}
