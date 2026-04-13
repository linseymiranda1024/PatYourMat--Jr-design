// Flutter imports
// -----------------------------------------------------------------------
// Filename: widget_profile_avatar.dart
// Original Author: Emily Ehrenberg
// Creation Date: 5/29/2024
// Copyright: (c) 2024 Pat Your Mat!
// Description: This file contains code for a profile avatar widget that
//              displays a user's profile image or initials.

//////////////////////////////////////////////////////////////////////////
// Imports
//////////////////////////////////////////////////////////////////////////
// Flutter external package imports
import 'package:flutter/material.dart';

// App relative file imports
import '../../db_helpers/db_user_profile.dart';

//////////////////////////////////////////////////////////////////////////
// StateFUL widget which manages state. Simply initializes the
// state object.
//////////////////////////////////////////////////////////////////////////
class ProfileAvatar extends StatefulWidget {
  const ProfileAvatar({
    super.key,
    required this.radius,
    this.initialsSize = 0,
    required this.userImage,
    required this.userWholeName,
    this.isInAppBar = false,
  });

  //radius of CircleAvatar
  final double radius;
  final double initialsSize;
  final ImageProvider? userImage;
  final String userWholeName;
  final bool isInAppBar;

  @override
  State<ProfileAvatar> createState() => _ProfileAvatarState();
}

//////////////////////////////////////////////////////////////////////////
// The actual STATE which is managed by the above widget.
//////////////////////////////////////////////////////////////////////////
class _ProfileAvatarState extends State<ProfileAvatar> {
  var _isInit = true;
  String initials = "";
  String selectedUid = "";
  double textSize = 0;

  @override
  void initState() {
    super.initState();
  }

  ////////////////////////////////////////////////////////////////////////
  // Gets the current state of the providers for consumption on
  // this page
  ////////////////////////////////////////////////////////////////////////
  getProviderSettings() async {
    getInitials();
  }

  ////////////////////////////////////////////////////////////////////////
  // Runs the following code once upon initialization
  ////////////////////////////////////////////////////////////////////////
  @override
  void didChangeDependencies() {
    // If first time running this code, update provider settings
    if (_isInit) {
      getProviderSettings();
    }

    // Now initialized; run super method
    _isInit = false;
    super.didChangeDependencies();
  }

  void getInitials() {
    // Update initial size, if needed
    textSize = widget.initialsSize == 0
        ? (widget.radius * .7)
        : widget.initialsSize;

    // Now, get the initials themselves
    try {
      //Store first and last names from _userProfileProvider
      String fn = widget.userWholeName.split(' ')[0];
      String ln = widget.userWholeName.split(' ')[1];

      //Extract initials
      String i1 = fn.isEmpty ? "" : fn.substring(0, 1);
      String i2 = ln.isEmpty ? "" : ln.substring(0, 1);

      // Update initials
      initials = (i1 + i2).trim();
      initials = initials.isEmpty ? "ME" : initials;
    } catch (e) {
      // If an exception occurred during parsing, just load "ME" for Me (myself)
      initials = "ME";
    }
  }

  @override
  Widget build(BuildContext context) {
    // If current image is null, set to intials. Else, display user's photo
    // If no user data is loaded, the profile photo will default to "ME" initials
    if (widget.userImage == null && initials != "") {
      return Stack(
        children: [
          CircleAvatar(
            radius: widget.radius,
            backgroundColor: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest,
            child: Text(
              initials,
              style: TextStyle(
                fontSize: textSize,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      );
    } else if (!widget.isInAppBar) {
      // This version of the avatar has the gapless playback feature
      // enabled to prevent the image from flickering when the user
      // updates the screen for any reason.
      return ClipRRect(
        borderRadius: BorderRadius.circular(widget.radius),
        child: Image(
          image: widget.userImage!,
          gaplessPlayback: true,
          height: widget.radius * 2,
          width: widget.radius * 2,
          fit: BoxFit.cover,
        ),
      );
    } else {
      // This version of the avatar does NOT have the gapless playback
      // feature b/c the ClipRRect did not work properly in the app bar.
      return CircleAvatar(
        radius: widget.radius,
        backgroundImage: Image(
          image: widget.userImage!,
          gaplessPlayback: true,
        ).image,
      );
    }
  }
}

class UserUidAvatar extends StatefulWidget {
  const UserUidAvatar({
    super.key,
    required this.uid,
    required this.userWholeName,
    required this.radius,
    this.initialsSize = 0,
    this.attemptFetch = true,
    this.backgroundColor,
    this.foregroundColor,
    this.borderColor,
    this.borderWidth = 0,
  });

  final String uid;
  final String userWholeName;
  final double radius;
  final double initialsSize;
  final bool attemptFetch;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? borderColor;
  final double borderWidth;

  @override
  State<UserUidAvatar> createState() => _UserUidAvatarState();
}

class _UserUidAvatarState extends State<UserUidAvatar> {
  late Future<ImageProvider?> _imageFuture;

  @override
  void initState() {
    super.initState();
    _imageFuture = _loadImage();
  }

  @override
  void didUpdateWidget(covariant UserUidAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uid != widget.uid ||
        oldWidget.attemptFetch != widget.attemptFetch) {
      _imageFuture = _loadImage();
    }
  }

  Future<ImageProvider?> _loadImage() {
    return DBUserProfile.fetchUserProfileImageFromUid(
      widget.uid,
      widget.attemptFetch,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cachedImage = DBUserProfile.getCachedUserProfileImage(widget.uid);

    return FutureBuilder<ImageProvider?>(
      future: _imageFuture,
      initialData: cachedImage,
      builder: (context, snapshot) {
        return _AvatarShell(
          radius: widget.radius,
          initialsSize: widget.initialsSize,
          userWholeName: widget.userWholeName,
          userImage: snapshot.data ?? cachedImage,
          backgroundColor: widget.backgroundColor,
          foregroundColor: widget.foregroundColor,
          borderColor: widget.borderColor,
          borderWidth: widget.borderWidth,
        );
      },
    );
  }
}

class _AvatarShell extends StatelessWidget {
  final double radius;
  final double initialsSize;
  final String userWholeName;
  final ImageProvider? userImage;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? borderColor;
  final double borderWidth;

  const _AvatarShell({
    required this.radius,
    required this.initialsSize,
    required this.userWholeName,
    required this.userImage,
    this.backgroundColor,
    this.foregroundColor,
    this.borderColor,
    this.borderWidth = 0,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final resolvedBackgroundColor =
        backgroundColor ?? colorScheme.surfaceContainerHighest;
    final resolvedForegroundColor = foregroundColor ?? colorScheme.onSurface;
    final resolvedInitialsSize = initialsSize == 0
        ? radius * 0.7
        : initialsSize;

    return Container(
      width: (radius * 2) + (borderWidth * 2),
      height: (radius * 2) + (borderWidth * 2),
      padding: EdgeInsets.all(borderWidth),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: borderWidth > 0 && borderColor != null
            ? Border.all(color: borderColor!, width: borderWidth)
            : null,
      ),
      child: ClipOval(
        child: userImage == null
            ? ColoredBox(
                color: resolvedBackgroundColor,
                child: Center(
                  child: Text(
                    _initialsFromLabel(userWholeName),
                    style: TextStyle(
                      fontSize: resolvedInitialsSize,
                      color: resolvedForegroundColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              )
            : Image(
                image: userImage!,
                gaplessPlayback: true,
                fit: BoxFit.cover,
              ),
      ),
    );
  }
}

String _initialsFromLabel(String label) {
  final trimmedLabel = label.trim();
  if (trimmedLabel.isEmpty) {
    return '?';
  }

  if (trimmedLabel.contains('@')) {
    final localPart = trimmedLabel.split('@').first.trim();
    if (localPart.isEmpty) {
      return '?';
    }
    final parts = localPart
        .split(RegExp(r'[^A-Za-z0-9]+'))
        .where((part) => part.trim().isNotEmpty)
        .toList();
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
    }
    return localPart.substring(0, localPart.length >= 2 ? 2 : 1).toUpperCase();
  }

  final parts = trimmedLabel
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
