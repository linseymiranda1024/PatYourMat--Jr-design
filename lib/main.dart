// -----------------------------------------------------------------------
// Filename: main.dart
// Original Author: Emily Ehrenberg
// Creation Date: 5/18/2024
// Copyright: (c) 2024 Pat Your Mat!
// Description: This file is the main entry point for the app and
//              initializes the app and the router.

//////////////////////////////////////////////////////////////////////////
// Imports
//////////////////////////////////////////////////////////////////////////
// Dart imports

// Flutter external package imports
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:pat_your_mat/screens/class_detail_screen.dart';
import 'package:pat_your_mat/screens/reservation_confirmation_screen.dart';
import 'models/gym_class.dart';

// App relative file imports
import 'screens/general/screen_alternate.dart';
import 'screens/home_screen.dart';
import 'widgets/navigation/widget_app_outline.dart';
import 'screens/auth/screen_login_validation.dart';
import 'screens/settings/screen_profile_edit.dart';
import 'providers/provider_user_profile.dart';
import 'providers/provider_gym_class.dart';
import 'screens/settings/screen_settings.dart';
import 'screens/staff/screen_staff_profile.dart';
import 'screens/staff/screen_staff_class_list.dart';
import 'screens/staff/screen_create_class.dart';
import 'providers/provider_auth.dart';
import 'util/file/util_file.dart';
import 'util/message_display/snackbar.dart';
import 'firebase_options.dart';
import 'theme/theme.dart';

//////////////////////////////////////////////////////////////////////////
// Providers
//////////////////////////////////////////////////////////////////////////
// Create a ProviderContainer to hold the providers
final ProviderContainer providerContainer = ProviderContainer();

// Create providers
final providerUserProfile = ChangeNotifierProvider<ProviderUserProfile>(
  (ref) => ProviderUserProfile(),
);
final providerAuth = ChangeNotifierProvider<ProviderAuth>(
  (ref) => ProviderAuth(),
);
final providerGymClass = ChangeNotifierProvider<ProviderGymClass>(
  (ref) => ProviderGymClass(),
);
final providerThemePreviewMode = StateProvider<bool?>((ref) => null);

//////////////////////////////////////////////////////////////////////////
// MAIN entry point to start app.
//////////////////////////////////////////////////////////////////////////
Future<void> main() async {
  // Initialize widgets and firebase
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with the default options
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize the app directory
  await UtilFile.init();

  // Get references to providers that will be needed in other providers
  final ProviderUserProfile userProfileProvider = providerContainer.read(
    providerUserProfile,
  );
  final ProviderAuth authProvider = providerContainer.read(providerAuth);

  // Initialize providers
  await userProfileProvider.initProviders(authProvider);
  authProvider.initProviders(userProfileProvider);

  // Run the app
  runApp(
    UncontrolledProviderScope(container: providerContainer, child: MyApp()),
  );
}

//////////////////////////////////////////////////////////////////////////
// Main class which is the root of the app.
//////////////////////////////////////////////////////////////////////////
class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

//////////////////////////////////////////////////////////////////////////
// The actual STATE which is managed by the above widget.
//////////////////////////////////////////////////////////////////////////
class _MyAppState extends ConsumerState<MyApp> {
  // Router
  final GoRouter _router = GoRouter(
    initialLocation: ScreenLoginValidation.routeName,
    routes: [
      GoRoute(
        path: ScreenLoginValidation.routeName,
        builder: (context, state) => const ScreenLoginValidation(),
      ),
      GoRoute(
        path: ScreenSettings.routeName,
        builder: (context, state) => ScreenSettings(),
      ),
      GoRoute(
        path: ScreenProfileEdit.routeName,
        builder: (context, state) => const ScreenProfileEdit(),
      ),
      GoRoute(
        path: WidgetAppOutline.routeName,
        builder: (context, state) {
          final index = int.tryParse(state.uri.queryParameters['tab'] ?? '');
          return WidgetAppOutline(initialIndex: index);
        },
      ),
      GoRoute(
        path: HomeScreen.routeName,
        builder: (context, state) => HomeScreen(),
      ),
      GoRoute(
        path: ScreenStaffProfile.routeName,
        builder: (context, state) => const ScreenStaffProfile(),
      ),
      GoRoute(
        path: ScreenStaffClassList.routeName,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return ScreenStaffClassList(
            showPast: extra['showPast'] as bool? ?? false,
          );
        },
      ),
      GoRoute(
        path: ScreenCreateClass.routeName,
        builder: (context, state) => const ScreenCreateClass(),
      ),
      GoRoute(
        path: ScreenAlternate.routeName,
        builder: (context, state) => ScreenAlternate(),
      ),
      GoRoute(
        path: ClassDetailScreen.routeName,
        builder: (context, state) {
          final gymClass = state.extra as GymClass;
          return ClassDetailScreen(gymClass: gymClass);
        },
      ),
      GoRoute(
        path: ReservationConfirmationScreen.routeName,
        name: ReservationConfirmationScreen.routeName,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return ReservationConfirmationScreen(
            className: extra['className'] as String? ?? 'Class',
            instructor: extra['instructor'] as String? ?? 'Instructor',
            dateTime: extra['dateTime'] as String? ?? 'Date & Time',
            matNumber: extra['matNumber'] as String? ?? 'Mat #?',
          );
        },
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final previewDarkModeEnabled = ref.watch(providerThemePreviewMode);
    final savedDarkModeEnabled = ref.watch(
      providerUserProfile.select((profile) => profile.darkModeEnabled),
    );
    final darkModeEnabled = previewDarkModeEnabled ?? savedDarkModeEnabled;

    return MaterialApp.router(
      scaffoldMessengerKey: appScaffoldMessengerKey,
      routerConfig: _router,
      title: 'Pat Your Mat!',
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: darkModeEnabled ? ThemeMode.dark : ThemeMode.light,
      themeAnimationDuration: Duration.zero,
      debugShowCheckedModeBanner: false,
    );
  }
}
