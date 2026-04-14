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
        reservedMat = await ref
            .read(reservationsProvider)
            .registerForClass(gClass, matNumber: matNumbers.first);
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

  String _reserveLabel(int count) =>
      'Reserve $count Mat${count == 1 ? '' : 's'}';

  String _selectionSummary() {
    if (_selectedMats.isEmpty) {
      return _groupSize == 1
          ? 'No mat selected'
          : 'Select $_groupSize mats for your group';
    }
    if (_groupSize == 1 || _selectedMats.length == _groupSize) {
      return _reserveLabel(_selectedMats.length);
    }
    return '${_selectedMats.length} of $_groupSize mats selected';
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
        final matRows = _buildMatRows(gClass.capacity);
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

            return Scaffold(
              appBar: AppBar(title: const Text('Choose Your Spot')),
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
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
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
                              _groupSize == 1
                                  ? 'Tap an open mat. Occupied mats show avatars, and friends stay highlighted.'
                                  : 'Select $_groupSize open mats. Occupied mats show avatars, and friends stay highlighted.',
                              style: textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                height: 1.4,
                              ),
                            ),
                            if (friendCount > 0) ...[
                              const SizedBox(height: 10),
                              _SummaryPill(
                                icon: Icons.people_outline_rounded,
                                label:
                                    '$friendCount friend${friendCount == 1 ? '' : 's'} on the floor',
                              ),
                            ],
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                const _LegendPill(
                                  label: 'Available',
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
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Divider(
                                color: colorScheme.outlineVariant,
                                thickness: 1,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
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
                              child: Divider(
                                color: colorScheme.outlineVariant,
                                thickness: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
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
                                          children: entry.value.map((
                                            matNumber,
                                          ) {
                                            final isReserved =
                                                socialMatOccupancy
                                                    .reservedMatNumbers
                                                    .contains(matNumber);
                                            final isSelected = _selectedMats
                                                .contains(matNumber);
                                            final occupantInfo = socialMatOccupancy
                                                .occupantInfoByNumber[matNumber];

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
                                                    occupantUid:
                                                        occupantInfo?.userId,
                                                    occupantName:
                                                        occupantInfo
                                                            ?.displayName ??
                                                        '',
                                                    isFriendOccupant:
                                                        occupantInfo
                                                            ?.isFriend ??
                                                        false,
                                                    onTap:
                                                        isReserved ||
                                                            isFull ||
                                                            isInStandby
                                                        ? null
                                                        : () {
                                                            setState(() {
                                                              if (isSelected) {
                                                                _selectedMats
                                                                    .remove(
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
                                            ? _selectionSummary()
                                            : '${_selectedInviteeUids.length} friend${_selectedInviteeUids.length == 1 ? '' : 's'} added. ${_selectionSummary()}',
                                        style: textTheme.bodyMedium?.copyWith(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                    ),
                                    TextButton.icon(
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
                                          if (liveFilled >= gClass.capacity) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
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
                                              : _reserveLabel(
                                                  _selectedMats.length,
                                                ),
                                          style: textTheme.titleMedium
                                              ?.copyWith(
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
                                    onPressed:
                                        (_selectedMats.length != _groupSize ||
                                            _isSubmitting ||
                                            isFull ||
                                            isInStandby)
                                        ? null
                                        : () async {
                                            if (liveFilled >= gClass.capacity) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
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
                                          : _reserveLabel(_selectedMats.length),
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
  }
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
    final friendFill = Color.lerp(AppColors.primaryPurple, Colors.white, 0.58)!;
    final fill = isFriendMat
        ? friendFill
        : reserved
        ? colorScheme.outline
        : selected
        ? colorScheme.primary
        : AppColors.success;
    final border = isFriendMat
        ? AppColors.accentPurple.withValues(alpha: 0.92)
        : reserved
        ? colorScheme.onSurfaceVariant.withValues(alpha: 0.7)
        : selected
        ? colorScheme.primary.withValues(alpha: 0.88)
        : AppColors.success.withValues(alpha: 0.88);
    final foregroundColor = isFriendMat || reserved
        ? colorScheme.onSurface
        : Colors.white;
    final avatarBackground = Color.lerp(
      AppColors.secondaryBlue,
      Colors.black,
      0.10,
    )!;
    final trimmedOccupantName = occupantName.trim();
    final label = hasOccupantAvatar
        ? (trimmedOccupantName.isEmpty
              ? 'Occupied mat $number'
              : '$trimmedOccupantName on mat $number')
        : reserved
        ? 'Reserved mat $number'
        : 'Mat $number';
    final numberBadgeColor = colorScheme.surface;
    final numberBadgeTextColor = colorScheme.onSurface;

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
                    ? colorScheme.primary.withValues(alpha: 0.22)
                    : Colors.black.withValues(alpha: 0.08),
                blurRadius: selected ? 16 : 8,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color.lerp(fill, Colors.white, 0.08)!,
                        fill,
                        Color.lerp(fill, Colors.black, 0.10)!,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: border, width: 1.5),
                  ),
                ),
              ),
              Positioned(
                top: hasOccupantAvatar ? 30 : 10,
                left: 10,
                right: 10,
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: (isFriendMat ? foregroundColor : Colors.white)
                        .withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Positioned(
                top: hasOccupantAvatar ? 40 : 20,
                left: 16,
                right: 16,
                child: Container(
                  height: 1.5,
                  color: foregroundColor.withValues(
                    alpha: isFriendMat || reserved ? 0.12 : 0.16,
                  ),
                ),
              ),
              Positioned(
                bottom: 16,
                left: 14,
                right: 14,
                child: Container(
                  height: 9,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(
                      alpha: isFriendMat ? 0.06 : 0.10,
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              if (hasOccupantAvatar)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: numberBadgeColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.92),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.16),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      '$number',
                      style: TextStyle(
                        color: numberBadgeTextColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              if (hasOccupantAvatar)
                Center(
                  child: UserUidAvatar(
                    uid: occupantUid ?? '',
                    userWholeName: occupantName,
                    radius: 14,
                    backgroundColor: avatarBackground,
                    foregroundColor: Colors.white,
                    borderColor: Colors.white,
                    borderWidth: 1.5,
                  ),
                )
              else
                Center(
                  child: Text(
                    '$number',
                    style: TextStyle(
                      color: foregroundColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 26,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              if (selected)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Icon(
                    Icons.check_circle,
                    color: foregroundColor,
                    size: 18,
                  ),
                ),
              if (reserved)
                Positioned(
                  top: hasOccupantAvatar ? 12 : 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: foregroundColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      color: foregroundColor,
                      size: 14,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
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
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final inviteOptionsStream =
        Rx.combineLatest3<
          QuerySnapshot<Map<String, dynamic>>,
          List<Reservation>,
          QuerySnapshot<Map<String, dynamic>>,
          List<_InviteFriend>
        >(
          FirebaseFirestore.instance
              .collection('user_profiles')
              .doc(widget.currentUid)
              .collection('friends')
              .snapshots(),
          DBReservations.getReservationsForClassStream(widget.classId),
          FirebaseFirestore.instance.collection('user_profiles').snapshots(),
          (friendsSnapshot, reservations, usersSnapshot) {
            final friendIds = friendsSnapshot.docs
                .map((doc) => (doc.data()['uid'] ?? doc.id).toString().trim())
                .where((uid) => uid.isNotEmpty)
                .toSet();

            if (friendIds.isEmpty) {
              return const <_InviteFriend>[];
            }

            final registeredUserIds = reservations
                .map((reservation) => reservation.userId.trim())
                .where((userId) => userId.isNotEmpty)
                .toSet();

            final friends =
                usersSnapshot.docs
                    .where((doc) => friendIds.contains(doc.id))
                    .map(
                      (doc) => _InviteFriend(
                        uid: doc.id,
                        wholeName:
                            '${(doc.data()['first_name'] ?? '').toString().trim()} ${(doc.data()['last_name'] ?? '').toString().trim()}'
                                .trim(),
                        bio: (doc.data()['bio'] ?? '').toString(),
                        role: (doc.data()['role'] ?? 'Member').toString(),
                        isAlreadyRegistered: registeredUserIds.contains(doc.id),
                      ),
                    )
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
              'Choose friends now, then pick the group mats you want to book. Friends who already have a spot stay unavailable here.',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 360,
              child: StreamBuilder<List<_InviteFriend>>(
                stream: inviteOptionsStream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(
                      child: Text('Unable to load your friends right now.'),
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
