import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pat_your_mat/main.dart';
import 'package:pat_your_mat/providers/provider_user_profile.dart';
import 'package:pat_your_mat/screens/settings/screen_settings.dart';
import 'package:pat_your_mat/util/message_display/snackbar.dart';

class FakeProviderUserProfile extends ProviderUserProfile {
  FakeProviderUserProfile({
    required bool pushNotificationsEnabled,
    required bool standbyAlertsEnabled,
    required bool darkModeEnabled,
    this.writeSucceeds = true,
  }) {
    this.pushNotificationsEnabled = pushNotificationsEnabled;
    this.standbyAlertsEnabled = standbyAlertsEnabled;
    this.darkModeEnabled = darkModeEnabled;
  }

  final bool writeSucceeds;
  int writeCount = 0;

  @override
  Future<bool> writeUserProfileToDb({merge = true}) async {
    writeCount += 1;
    return writeSucceeds;
  }
}

void main() {
  testWidgets('dark mode toggle previews theme before save', (tester) async {
    final profile = FakeProviderUserProfile(
      pushNotificationsEnabled: true,
      standbyAlertsEnabled: true,
      darkModeEnabled: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [providerUserProfile.overrideWith((ref) => profile)],
        child: Consumer(
          builder: (context, ref, child) {
            final previewDarkModeEnabled = ref.watch(providerThemePreviewMode);
            final savedDarkModeEnabled = ref.watch(
              providerUserProfile.select((value) => value.darkModeEnabled),
            );

            return MaterialApp(
              scaffoldMessengerKey: appScaffoldMessengerKey,
              theme: ThemeData.light(),
              darkTheme: ThemeData.dark(),
              themeMode: (previewDarkModeEnabled ?? savedDarkModeEnabled)
                  ? ThemeMode.dark
                  : ThemeMode.light,
              home: const ScreenSettings(),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      Theme.of(tester.element(find.byType(ScreenSettings))).brightness,
      Brightness.light,
    );

    await tester.tap(find.byType(Switch).at(2));
    await tester.pumpAndSettle();

    expect(profile.writeCount, 0);
    expect(profile.darkModeEnabled, isFalse);
    expect(find.text('Save Changes'), findsOneWidget);
    expect(
      Theme.of(tester.element(find.byType(ScreenSettings))).brightness,
      Brightness.dark,
    );
  });

  testWidgets('settings screen loads saved values and saves updates', (
    tester,
  ) async {
    final profile = FakeProviderUserProfile(
      pushNotificationsEnabled: true,
      standbyAlertsEnabled: true,
      darkModeEnabled: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [providerUserProfile.overrideWith((ref) => profile)],
        child: const MaterialApp(home: ScreenSettings()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Saved'), findsOneWidget);

    await tester.tap(find.byType(Switch).at(2));
    await tester.pumpAndSettle();

    expect(find.text('Save Changes'), findsOneWidget);

    await tester.ensureVisible(find.text('Save Changes'));
    await tester.tap(find.text('Save Changes'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(profile.writeCount, 1);
    expect(profile.darkModeEnabled, isTrue);
    expect(find.text('Settings saved.'), findsOneWidget);
  });

  testWidgets('failed saves restore provider values', (tester) async {
    final profile = FakeProviderUserProfile(
      pushNotificationsEnabled: true,
      standbyAlertsEnabled: true,
      darkModeEnabled: false,
      writeSucceeds: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [providerUserProfile.overrideWith((ref) => profile)],
        child: const MaterialApp(home: ScreenSettings()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save Changes'));
    await tester.tap(find.text('Save Changes'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(profile.writeCount, 1);
    expect(profile.pushNotificationsEnabled, isTrue);
    expect(
      find.text('Unable to save settings. Please try again.'),
      findsOneWidget,
    );
  });

  testWidgets('dark mode save is stable during app theme rebuild', (
    tester,
  ) async {
    final profile = FakeProviderUserProfile(
      pushNotificationsEnabled: true,
      standbyAlertsEnabled: true,
      darkModeEnabled: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [providerUserProfile.overrideWith((ref) => profile)],
        child: Consumer(
          builder: (context, ref, child) {
            final darkModeEnabled = ref.watch(
              providerUserProfile.select((value) => value.darkModeEnabled),
            );

            return MaterialApp(
              scaffoldMessengerKey: appScaffoldMessengerKey,
              theme: ThemeData.light(),
              darkTheme: ThemeData.dark(),
              themeMode:
                  (ref.watch(providerThemePreviewMode) ?? darkModeEnabled)
                  ? ThemeMode.dark
                  : ThemeMode.light,
              home: const ScreenSettings(),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch).at(2));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save Changes'));
    await tester.tap(find.text('Save Changes'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(profile.darkModeEnabled, isTrue);
    expect(find.text('Settings saved.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
