// -----------------------------------------------------------------------
// Filename: widget_app_drawer.dart
// Original Author: Wyatt Bodle
// Creation Date: 6/10/2024
// Copyright: (c) 2024 Pat Your Mat!
// Description: This file contains the primary scaffold for the app.

//////////////////////////////////////////////////////////////////////////
// Imports
//////////////////////////////////////////////////////////////////////////
// Flutter external package imports
import 'package:flutter/material.dart';
import 'package:pat_your_mat/widgets/navigation/widget_primary_app_bar.dart';

// App relative file imports
import '../auth/screen_profile_setup.dart';

//////////////////////////////////////////////////////////////////
// StateFUL widget which manages state. Simply initializes the
// state object.
//////////////////////////////////////////////////////////////////
class ScreenProfileEdit extends StatefulWidget {
  const ScreenProfileEdit({super.key});

  static const routeName = '/profileEdit';

  @override
  State<ScreenProfileEdit> createState() => _ScreenProfileEditState();
}

//////////////////////////////////////////////////////////////////
// The actual STATE which is managed by the above widget.
//////////////////////////////////////////////////////////////////
class _ScreenProfileEditState extends State<ScreenProfileEdit> {
  //////////////////////////////////////////////////////////////////////////
  // Primary Flutter method overriden which describes the layout
  // and bindings for this widget.
  //////////////////////////////////////////////////////////////////////////
  @override
  Widget build(BuildContext context) {
    // Return the widget to show
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: WidgetPrimaryAppBar(title: const Text('Edit Profile')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: ScreenProfileSetup(isAuth: false),
        ),
      ),
    );
  }
}
