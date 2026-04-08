import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db_helpers/db_friends.dart';
import '../main.dart';
import '../models/achievement.dart';

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  final Set<String> _pendingFollowUids = <String>{};
  final Set<String> _optimisticFriendUids = <String>{};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userProfile = ref.watch(providerUserProfile);
    final currentUid = userProfile.uid;
    final currentName = userProfile.wholeName.trim().isEmpty
        ? 'Someone'
        : userProfile.wholeName.trim();
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (currentUid.isEmpty) {
      return const SafeArea(child: _CenteredMessage('Log in to view friends.'));
    }

    return SafeArea(
      child: Container(
        color: colorScheme.surface,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Icon(Icons.group, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Friends',
                    style: textTheme.headlineSmall?.copyWith(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  _Pill(label: 'Members'),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by name or email',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.close),
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onChanged: (value) =>
                    setState(() => _query = value.trim().toLowerCase()),
              ),
            ),
            Expanded(
              child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('user_profiles')
                    .doc(currentUid)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const _CenteredMessage(
                      'Unable to load friends right now.',
                    );
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('user_profiles')
                        .doc(currentUid)
                        .collection('friends')
                        .snapshots(),
                    builder: (context, friendsSnapshot) {
                      if (friendsSnapshot.hasError) {
                        final err = friendsSnapshot.error;
                        return _CenteredMessage(
                          err == null
                              ? 'Unable to load friends right now.'
                              : 'Unable to load friends right now.\n$err',
                        );
                      }
                      final friendIds = _extractFriendIdsFromSubcollection(
                        friendsSnapshot.data?.docs ?? const [],
                      );

                      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('user_profiles')
                            .snapshots(),
                        builder: (context, usersSnapshot) {
                          if (usersSnapshot.hasError) {
                            final err = usersSnapshot.error;
                            return _CenteredMessage(
                              err == null
                                  ? 'Unable to load members right now.'
                                  : 'Unable to load members right now.\n$err',
                            );
                          }
                          if (usersSnapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          final docs = usersSnapshot.data?.docs ?? [];
                          final allUsers = docs
                              .where((doc) => doc.id != currentUid)
                              .map((doc) => _FriendEntry.fromDoc(doc))
                              .toList();

                          final filteredUsers =
                              allUsers.where((user) {
                                if (_query.isEmpty) return true;
                                final name =
                                    '${user.firstName} ${user.lastName}'
                                        .toLowerCase();
                                return name.contains(_query) ||
                                    user.email.toLowerCase().contains(_query);
                              }).toList()..sort(
                                (a, b) => a.sortKey.compareTo(b.sortKey),
                              );

                          final combinedFriendIds = <String>{
                            ...friendIds,
                            ..._optimisticFriendUids,
                          };

                          final friendUsers = filteredUsers
                              .where((user) => combinedFriendIds.contains(user.uid))
                              .toList();
                          final otherUsers = filteredUsers
                              .where((user) => !combinedFriendIds.contains(user.uid))
                              .toList();

                          if (filteredUsers.isEmpty) {
                            return const _CenteredMessage('No members found.');
                          }

                          return ListView(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                            children: [
                              _SectionHeader(
                                label: 'Your Friends',
                                count: friendUsers.length,
                              ),
                              const SizedBox(height: 8),
                              if (friendUsers.isEmpty)
                                const _InlineHint('No friends found yet.')
                              else
                                ...friendUsers.map(
                                  (user) => Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: _FriendCard(
                                      user: user,
                                      isFriend: true,
                                      onTap: () => _openFriendProfile(user),
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 8),
                              _SectionHeader(
                                label: _query.isEmpty
                                    ? 'All Members'
                                    : 'Search Results',
                                count: otherUsers.length,
                              ),
                              const SizedBox(height: 8),
                              if (otherUsers.isEmpty)
                                const _InlineHint(
                                  'No additional members match your search.',
                                )
                              else
                                ...otherUsers.map(
                                  (user) => Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: _FriendCard(
                                      user: user,
                                      onTap: () => _openFriendProfile(user),
                                      actionLabel: 'Add',
                                      onFollow: _pendingFollowUids.contains(
                                        user.uid,
                                      )
                                          ? null
                                          : () => _handleFollowTap(
                                              currentUid: currentUid,
                                              currentName: currentName,
                                              targetUser: user,
                                            ),
                                      followPending: _pendingFollowUids.contains(
                                        user.uid,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
  Set<String> _extractFriendIdsFromSubcollection(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final ids = <String>{};
    for (final doc in docs) {
      ids.add(doc.id);
      final data = doc.data();
      final candidates = [
        data['uid'],
        data['user_id'],
        data['friend_uid'],
        data['id'],
      ];
      for (final candidate in candidates) {
        if (candidate is String && candidate.trim().isNotEmpty) {
          ids.add(candidate.trim());
        }
      }
    }
    return ids;
  }

  Future<void> _handleFollowTap({
    required String currentUid,
    required String currentName,
    required _FriendEntry targetUser,
  }) async {
    if (_pendingFollowUids.contains(targetUser.uid)) {
      return;
    }

    setState(() => _pendingFollowUids.add(targetUser.uid));
    try {
      await _addFriend(
        currentUid: currentUid,
        currentName: currentName,
        targetUser: targetUser,
      );
      if (!mounted) return;
      setState(() => _optimisticFriendUids.add(targetUser.uid));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${targetUser.firstName} added to friends.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      var message = error.toString();
      if (message.startsWith('Exception: ')) {
        message = message.replaceFirst('Exception: ', '');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) {
        setState(() => _pendingFollowUids.remove(targetUser.uid));
      }
    }
  }

  Future<void> _addFriend({
    required String currentUid,
    required String currentName,
    required _FriendEntry targetUser,
  }) async {
    await DBFriends.addFriend(
      fromUid: currentUid,
      fromName: currentName,
      toUid: targetUser.uid,
    );
  }

  void _openFriendProfile(_FriendEntry user) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _FriendProfileScreen(user: user),
      ),
    );
  }
}

class _FriendEntry {
  final String uid;
  final String firstName;
  final String lastName;
  final String email;
  final String role;
  final String bio;
  final List<String> achievements;

  _FriendEntry({
    required this.uid,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.role,
    required this.bio,
    required this.achievements,
  });

  String get sortKey => '${firstName.toLowerCase()} ${lastName.toLowerCase()}';

  factory _FriendEntry.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return _FriendEntry(
      uid: doc.id,
      firstName: (data['first_name'] ?? '').toString(),
      lastName: (data['last_name'] ?? '').toString(),
      email: (data['email'] ?? '').toString(),
      role: (data['role'] ?? 'Member').toString(),
      bio: (data['bio'] ?? '').toString(),
      achievements: List<String>.from(data['achievements'] ?? const []),
    );
  }

  String get wholeName => '${firstName.trim()} ${lastName.trim()}'.trim();
}

class _FriendCard extends StatelessWidget {
  final _FriendEntry user;
  final bool isFriend;
  final String actionLabel;
  final VoidCallback? onTap;
  final VoidCallback? onFollow;
  final bool followPending;

  const _FriendCard({
    required this.user,
    this.isFriend = false,
    this.actionLabel = 'Follow',
    this.onTap,
    this.onFollow,
    this.followPending = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final initials = _initials(user.firstName, user.lastName);
    final fullName = user.wholeName;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colorScheme.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: colorScheme.primary,
                child: Text(
                  initials,
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
                      fullName.isEmpty ? 'Member' : fullName,
                      style: textTheme.titleMedium?.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.email.isEmpty ? 'No email provided' : user.email,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (user.bio.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        user.bio,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              isFriend
                  ? const _Pill(label: 'Friend')
                  : FilledButton(
                      onPressed: followPending ? null : onFollow,
                      style: FilledButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        textStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: Text(actionLabel),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  String _initials(String firstName, String lastName) {
    final f = firstName.isEmpty ? '' : firstName[0].toUpperCase();
    final l = lastName.isEmpty ? '' : lastName[0].toUpperCase();
    final initials = '$f$l';
    return initials.isEmpty ? '?' : initials;
  }
}

class _FriendProfileScreen extends StatelessWidget {
  final _FriendEntry user;

  const _FriendProfileScreen({required this.user});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final fullName = user.wholeName.isEmpty ? 'Member Profile' : user.wholeName;
    final bio = user.bio.trim();
    final unlockedAchievements = Achievement.all
        .where((achievement) => user.achievements.contains(achievement.id))
        .toList();

    return Scaffold(
      appBar: AppBar(title: Text(fullName)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colorScheme.primaryContainer,
                      colorScheme.surfaceContainerHigh,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.shadow.withValues(alpha: 0.10),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: colorScheme.onPrimaryContainer.withValues(
                                alpha: 0.18,
                              ),
                              width: 2,
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 34,
                            backgroundColor: colorScheme.primary,
                            child: Text(
                              _initials(user.firstName, user.lastName),
                              style: textTheme.headlineSmall?.copyWith(
                                color: colorScheme.onPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fullName,
                                style: textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.surface.withValues(
                                    alpha: 0.72,
                                  ),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '${unlockedAchievements.length} achievement${unlockedAchievements.length == 1 ? '' : 's'}',
                                  style: textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'Bio',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      bio.isEmpty
                          ? 'This member has not added a bio yet.'
                          : bio,
                      style: textTheme.bodyLarge?.copyWith(
                        height: 1.55,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Achievements',
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Badges this member has unlocked so far.',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (unlockedAchievements.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: colorScheme.outlineVariant),
                        ),
                        child: Text(
                          '$fullName has not unlocked any achievements yet.',
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                      )
                    else
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: unlockedAchievements
                            .map(
                              (achievement) => _FriendAchievementBadge(
                                achievement: achievement,
                              ),
                            )
                            .toList(),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _initials(String firstName, String lastName) {
    final f = firstName.isEmpty ? '' : firstName[0].toUpperCase();
    final l = lastName.isEmpty ? '' : lastName[0].toUpperCase();
    final initials = '$f$l';
    return initials.isEmpty ? '?' : initials;
  }
}

class _FriendAchievementBadge extends StatelessWidget {
  final Achievement achievement;

  const _FriendAchievementBadge({required this.achievement});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: 150,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: achievement.color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: achievement.color.withValues(alpha: 0.28),
              ),
            ),
            child: Icon(
              achievement.iconData,
              color: achievement.color,
              size: 24,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            achievement.title,
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            achievement.description,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;

  const _Pill({required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final int count;

  const _SectionHeader({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Text(
          label,
          style: textTheme.titleSmall?.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _InlineHint extends StatelessWidget {
  final String message;

  const _InlineHint(this.message);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Text(
        message,
        style: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  final String message;

  const _CenteredMessage(this.message);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: textTheme.bodyLarge?.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
