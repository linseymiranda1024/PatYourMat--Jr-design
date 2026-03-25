// -----------------------------------------------------------------------
// Filename: screen_settings.dart
// Original Author: Wyatt Bodle
// Updated By: Codex
// Copyright: (c) 2024 Pat Your Mat!
// Description: This file contains the screen for optional settings.

//////////////////////////////////////////////////////////////////////////
// Imports
//////////////////////////////////////////////////////////////////////////
// Flutter external package imports
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// App relative file imports
import '../../main.dart';
import '../../providers/provider_user_profile.dart';
import '../../theme/app_colors.dart';
import '../../util/message_display/snackbar.dart';

//////////////////////////////////////////////////////////////////
// StateFUL widget which manages state. Simply initializes the
// state object.
//////////////////////////////////////////////////////////////////
class ScreenSettings extends ConsumerStatefulWidget {
  const ScreenSettings({super.key});

  static const routeName = '/settings';

  @override
  ConsumerState<ScreenSettings> createState() => _ScreenSettingsState();
}

//////////////////////////////////////////////////////////////////
// The actual STATE which is managed by the above widget.
//////////////////////////////////////////////////////////////////
class _ScreenSettingsState extends ConsumerState<ScreenSettings> {
  late final dynamic _themePreviewController;
  bool _didLoadInitialState = false;
  bool _pushNotifications = true;
  bool _standbyAlerts = true;
  bool _darkMode = false;
  bool _saveInProgress = false;
  bool _initialPushNotifications = true;
  bool _initialStandbyAlerts = true;
  bool _initialDarkMode = false;

  @override
  void initState() {
    super.initState();
    _themePreviewController = ref.read(providerThemePreviewMode.notifier);
  }

  bool get _hasChanges {
    return _pushNotifications != _initialPushNotifications ||
        _standbyAlerts != _initialStandbyAlerts ||
        _darkMode != _initialDarkMode;
  }

  void _loadInitialState(ProviderUserProfile profile) {
    if (_didLoadInitialState) {
      return;
    }

    _pushNotifications = profile.pushNotificationsEnabled;
    _standbyAlerts = profile.standbyAlertsEnabled;
    _darkMode = profile.darkModeEnabled;
    _initialPushNotifications = profile.pushNotificationsEnabled;
    _initialStandbyAlerts = profile.standbyAlertsEnabled;
    _initialDarkMode = profile.darkModeEnabled;
    _didLoadInitialState = true;
  }

  void _setDarkModePreview(bool value) {
    final savedDarkModeEnabled = ref.read(providerUserProfile).darkModeEnabled;
    _themePreviewController.state = value == savedDarkModeEnabled
        ? null
        : value;
  }

  void _clearDarkModePreview() {
    _themePreviewController.state = null;
  }

  @override
  void dispose() {
    _clearDarkModePreview();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    if (_saveInProgress) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _saveInProgress = true);

    final profile = ref.read(providerUserProfile);
    final originalPushNotifications = profile.pushNotificationsEnabled;
    final originalStandbyAlerts = profile.standbyAlertsEnabled;
    final originalDarkMode = profile.darkModeEnabled;

    profile.pushNotificationsEnabled = _pushNotifications;
    profile.standbyAlertsEnabled = _standbyAlerts;
    profile.darkModeEnabled = _darkMode;

    final success = await profile.writeUserProfileToDb();

    if (!mounted) {
      return;
    }

    if (!success) {
      profile.pushNotificationsEnabled = originalPushNotifications;
      profile.standbyAlertsEnabled = originalStandbyAlerts;
      profile.darkModeEnabled = originalDarkMode;
      _setDarkModePreview(_darkMode);
      Snackbar.show(
        SnackbarDisplayType.SB_ERROR,
        'Unable to save settings. Please try again.',
        context,
      );
      setState(() => _saveInProgress = false);
      return;
    }

    _initialPushNotifications = _pushNotifications;
    _initialStandbyAlerts = _standbyAlerts;
    _initialDarkMode = _darkMode;
    _clearDarkModePreview();
    Snackbar.show(SnackbarDisplayType.SB_SUCCESS, 'Settings saved.', context);
    setState(() => _saveInProgress = false);
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(providerUserProfile);
    _loadInitialState(profile);

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final saveEnabled = _hasChanges && !_saveInProgress;
    final headerGradient = theme.brightness == Brightness.dark
        ? const [AppColors.gradientStartDark, AppColors.gradientEndDark]
        : const [AppColors.gradientStart, AppColors.gradientEnd];

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(
                top: 16,
                left: 16,
                right: 16,
                bottom: 52,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: headerGradient,
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(40),
                  bottomRight: Radius.circular(40),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back,
                      color: AppColors.headerOnBrand,
                    ),
                    onPressed: _saveInProgress ? null : () => context.pop(),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(left: 12, top: 8),
                    child: Text(
                      'Settings',
                      style: TextStyle(
                        color: AppColors.headerOnBrand,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Text(
                      'Manage preferences for alerts and appearance.',
                      style: TextStyle(
                        color: AppColors.headerOnBrandMuted,
                        fontSize: 14,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle(
                      'App Preferences',
                      textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildCard(theme, [
                      _buildSettingTile(
                        icon: Icons.notifications_active_outlined,
                        iconColor: colorScheme.primary,
                        title: 'Push Notifications',
                        subtitle: 'Receive alerts for class updates',
                        value: _pushNotifications,
                        titleStyle: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                        subtitleStyle: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        onChanged: (value) {
                          setState(() => _pushNotifications = value);
                        },
                      ),
                      const Divider(height: 1),
                      _buildSettingTile(
                        icon: Icons.timer_outlined,
                        iconColor: colorScheme.tertiary,
                        title: 'Standby Alerts',
                        subtitle: 'Notify me when a spot opens up',
                        value: _standbyAlerts,
                        titleStyle: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                        subtitleStyle: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        onChanged: (value) {
                          setState(() => _standbyAlerts = value);
                        },
                      ),
                    ]),
                    const SizedBox(height: 32),
                    _buildSectionTitle(
                      'Display',
                      textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildCard(theme, [
                      _buildSettingTile(
                        icon: Icons.dark_mode_outlined,
                        iconColor: colorScheme.secondary,
                        title: 'Dark Mode',
                        subtitle: 'Reduce glare and use the darker theme',
                        value: _darkMode,
                        titleStyle: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                        subtitleStyle: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        onChanged: (value) {
                          setState(() => _darkMode = value);
                          _setDarkModePreview(value);
                        },
                      ),
                    ]),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: saveEnabled ? _saveSettings : null,
                        style: theme.elevatedButtonTheme.style?.copyWith(
                          minimumSize: const WidgetStatePropertyAll(
                            Size.fromHeight(54),
                          ),
                        ),
                        child: _saveInProgress
                            ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    colorScheme.onPrimary,
                                  ),
                                ),
                              )
                            : Text(_hasChanges ? 'Save Changes' : 'Saved'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String text, TextStyle? style) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Text(
        text,
        style:
            style ?? const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildCard(ThemeData theme, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.16 : 0.05,
            ),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required TextStyle? titleStyle,
    required TextStyle? subtitleStyle,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: iconColor),
      ),
      title: Text(title, style: titleStyle),
      subtitle: Text(subtitle, style: subtitleStyle),
      trailing: Switch(
        value: value,
        onChanged: _saveInProgress ? null : onChanged,
      ),
    );
  }
}
