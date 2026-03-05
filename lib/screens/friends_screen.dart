import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../main.dart';
import '../theme/app_colors.dart';

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  final Set<String> _pendingFollowUids = <String>{};

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

    if (currentUid.isEmpty) {
      return const SafeArea(child: _CenteredMessage('Log in to view friends.'));
    }

    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF8FBFF), Color(0xFFFFFFFF)],
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  const Icon(Icons.group, color: AppColors.deepPurple),
                  const SizedBox(width: 8),
                  const Text(
                    'Friends',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1F2A44),
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
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE3EAF7)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE3EAF7)),
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

                  final friendIdsFromProfile = _extractFriendIdsFromProfileDoc(
                    snapshot.data?.data(),
                  );

                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('user_profiles')
                        .doc(currentUid)
                        .collection('friends')
                        .snapshots(),
                    builder: (context, friendLinkSnapshot) {
                      if (friendLinkSnapshot.hasError) {
                        final err = friendLinkSnapshot.error;
                        return _CenteredMessage(
                          err == null
                              ? 'Unable to load friends right now.'
                              : 'Unable to load friends right now.\n$err',
                        );
                      }
                      final friendIds = <String>{
                        ...friendIdsFromProfile,
                        ..._extractFriendIdsFromSubcollection(
                          friendLinkSnapshot.data?.docs ?? const [],
                        ),
                      };

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

                          final friendUsers = filteredUsers
                              .where((user) => friendIds.contains(user.uid))
                              .toList();
                          final otherUsers = filteredUsers
                              .where((user) => !friendIds.contains(user.uid))
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
                                      onFollow: _pendingFollowUids.contains(user.uid)
                                          ? null
                                          : () => _handleFollowTap(
                                                currentUid: currentUid,
                                                currentName: currentName,
                                                targetUser: user,
                                              ),
                                      followPending: _pendingFollowUids
                                          .contains(user.uid),
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

  Set<String> _extractFriendIdsFromProfileDoc(Map<String, dynamic>? data) {
    if (data == null) return <String>{};
    final ids = <String>{};

    void addFromDynamic(dynamic value) {
      if (value is String && value.trim().isNotEmpty) {
        ids.add(value.trim());
      } else if (value is Iterable) {
        for (final item in value) {
          addFromDynamic(item);
        }
      } else if (value is Map) {
        final candidates = [
          value['uid'],
          value['user_id'],
          value['friend_uid'],
          value['id'],
        ];
        for (final candidate in candidates) {
          addFromDynamic(candidate);
        }
      }
    }

    addFromDynamic(data['friend_uids']);
    addFromDynamic(data['friend_ids']);
    addFromDynamic(data['friends']);
    return ids;
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
      await _followUser(
        currentUid: currentUid,
        currentName: currentName,
        targetUser: targetUser,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Now following ${targetUser.firstName}.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to follow user right now.')),
      );
    } finally {
      if (mounted) {
        setState(() => _pendingFollowUids.remove(targetUser.uid));
      }
    }
  }

  Future<void> _followUser({
    required String currentUid,
    required String currentName,
    required _FriendEntry targetUser,
  }) async {
    final db = FirebaseFirestore.instance;
    final timestamp = FieldValue.serverTimestamp();
    final batch = db.batch();

    final friendRef = db
        .collection('user_profiles')
        .doc(currentUid)
        .collection('friends')
        .doc(targetUser.uid);
    batch.set(friendRef, <String, dynamic>{
      'uid': targetUser.uid,
      'created_at': timestamp,
      'display_name': '${targetUser.firstName} ${targetUser.lastName}'.trim(),
      'email': targetUser.email,
    }, SetOptions(merge: true));

    final notificationRef = db
        .collection('user_profiles')
        .doc(targetUser.uid)
        .collection('notifications')
        .doc();
    batch.set(notificationRef, <String, dynamic>{
      'title': 'New follower',
      'message': '$currentName started following you.',
      'type': 'friend',
      'is_read': false,
      'from_uid': currentUid,
      'created_at': timestamp,
    });

    await batch.commit();
  }
}

class _FriendEntry {
  final String uid;
  final String firstName;
  final String lastName;
  final String email;
  final String role;
  final String bio;

  _FriendEntry({
    required this.uid,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.role,
    required this.bio,
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
    );
  }
}

class _FriendCard extends StatelessWidget {
  final _FriendEntry user;
  final bool isFriend;
  final VoidCallback? onFollow;
  final bool followPending;

  const _FriendCard({
    required this.user,
    this.isFriend = false,
    this.onFollow,
    this.followPending = false,
  });

  @override
  Widget build(BuildContext context) {
    final initials = _initials(user.firstName, user.lastName);
    final fullName = '${user.firstName} ${user.lastName}'.trim();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5ECF8)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: const Color(0xFF2F7BFF),
            child: Text(
              initials,
              style: const TextStyle(
                color: Colors.white,
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
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  user.email.isEmpty ? 'No email provided' : user.email,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (user.bio.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    user.bio,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.black54),
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
                    backgroundColor: AppColors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: Text(followPending ? 'Following...' : 'Follow'),
                ),
        ],
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

class _Pill extends StatelessWidget {
  final String label;

  const _Pill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF3FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.deepPurple,
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
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1F2A44),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF3FF),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.deepPurple,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5ECF8)),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: Colors.black54,
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black54,
          ),
        ),
      ),
    );
  }
}
