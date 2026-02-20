// -----------------------------------------------------------------------
// Filename: provider_auth.dart
// Original Author: Dan Grissom
// Creation Date: 5/22/2024
// Copyright: (c) 2024 CSC322
// Description: This file contains the screen for authenticating users
//              (login, account creation).

//////////////////////////////////////////////////////////////////////////
// Imports
//////////////////////////////////////////////////////////////////////////
// Flutter external package imports
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// App relative file imports
import '../../util/message_display/popup_dialogue.dart';
import '../../widgets/auth/widget_password_strength_indicator.dart';
import '../../providers/provider_user_profile.dart';
import '../../util/message_display/snackbar.dart';
import '../../util/logging/app_logger.dart';
import '../../providers/provider_auth.dart';
import '../../models/user_profile.dart';
import '../../theme/app_colors.dart';
import '../../main.dart';
import '../../widgets/auth/custom_text_field.dart';

//////////////////////////////////////////////////////////////////
// StateFUL widget which manages state. Simply initializes the
// state object.
//////////////////////////////////////////////////////////////////
class ScreenAuth extends ConsumerStatefulWidget {
  static const routeName = '/auth';

  const ScreenAuth({super.key});

  @override
  ConsumerState<ScreenAuth> createState() => _ScreenAuthState();
}

//////////////////////////////////////////////////////////////////
// The actual STATE which is managed by the above widget.
//////////////////////////////////////////////////////////////////
class _ScreenAuthState extends ConsumerState<ScreenAuth> {
  // The "instance variables" managed in this state
  bool _signInMode = true;
  UserRole _selectedRole = UserRole.MEMBER;
  bool _passwordVisible = false;
  var _isInit = true;
  late ProviderUserProfile _providerUserProfile;
  late ProviderAuth _providerAuth;
  String _strengthText = "";
  Color _strengthColor = AppColors.textLight;
  double _passwordStrength = 0;
  bool _isLoading = false;

  // Finals used in this widget
  final _auth = FirebaseAuth.instance;
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  ////////////////////////////////////////////////////////////////
  // Runs the following code once upon initialization
  ////////////////////////////////////////////////////////////////
  @override
  void didChangeDependencies() {
    // If first time running this code, update provider settings
    if (_isInit) {
      _init();

      // Now initialized; run super method
      _isInit = false;
      super.didChangeDependencies();
    }
  }

  ////////////////////////////////////////////////////////////////
  // Gets the current state of the providers for consumption on
  // this page
  ////////////////////////////////////////////////////////////////
  _init() async {
    _providerUserProfile = ref.watch(providerUserProfile);
    _providerAuth = ref.watch(providerAuth);
  }

  @override
  void initState() {
    super.initState();
    _passwordVisible = false;
  }

  ////////////////////////////////////////////////////////////////
  // Attempts to either login to existing account or signup for
  // new account.
  ////////////////////////////////////////////////////////////////
  void _submitAuthForm(String email, String password, bool isLogin, BuildContext ctx) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // If in "login mode", attempt to login with email/password...
      User? user = _auth.currentUser;
      if (isLogin) {
        // Attempt login
        String errorMessage = (await _providerAuth.signinWithPassword(email, password)).trim();

        // If there was an error, display it...otherwise load the profile
        if (errorMessage.isNotEmpty) {
          if (mounted) {
            Snackbar.show(SnackbarDisplayType.SB_ERROR, errorMessage, context);
          }
        } else {
          await _providerAuth.loadAuthedUserDetailsUponSignin();
        }
      } else {
        // ...otherwise, attempt to create a new account
        await _auth.createUserWithEmailAndPassword(email: email, password: password);

        // Send verification e-mail and create initial user profile
        try {
          if (ENFORCE_EMAIL_VERIFICATION) {
            await FirebaseAuth.instance.currentUser?.sendEmailVerification();
          }
          _providerUserProfile.email = user?.email ?? email;
          _providerUserProfile.role = _selectedRole;
          _providerUserProfile.accountCreationStep = AccountCreationStep.ACC_STEP_ONBOARDING_PROFILE_CONTACT_INFO;
          await _providerUserProfile.writeUserProfileToDb();
          _providerAuth.isSigningIn = false;
        } catch (e) {
          AppLogger.warning("Issue with sending email verification or writing to user profile.  email: $e");
        }

        // ...and send verification email
        if (user != null && !user.emailVerified) {
          await user.sendEmailVerification();

          // ...and display to user as "Snack bar" pop-up at bottom of screen
          if (mounted) {
            Snackbar.show(SnackbarDisplayType.SB_INFO, 'Check ${user.email} for verification link.', context);
          }
        }
      }
    } on FirebaseAuthException catch (err) {
      // If error occurs, gather error message...
      var message = 'An error occurred, please check your credentials!';
      if (err.message != null) message = err.message!;
      if (mounted) {
        Snackbar.show(SnackbarDisplayType.SB_ERROR, message, ctx);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  ////////////////////////////////////////////////////////////////
  // Does basic validation and attempts to authenticate
  ////////////////////////////////////////////////////////////////
  void _trySubmit() {
    FocusScope.of(context).unfocus();
    final isValid = _formKey.currentState!.validate();
    if (!isValid) {
      return;
    }
    if (!_signInMode && _passwordStrength < 0.6) {
      Snackbar.show(SnackbarDisplayType.SB_ERROR, "Please improve your password strength.", context);
      return;
    }
    _formKey.currentState!.save();
    _submitAuthForm(_emailController.text.trim(), _passwordController.text.trim(), _signInMode, context);
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty || !value.contains('@') || !value.contains('.')) {
      return 'Please enter a valid email address.';
    }
    return null;
  }

  /* ---------------------------- validatePassword ---------------------------- */
  String? validatePasssword(String? value) {
    if (_signInMode) return null;
    if (value == null || value.isEmpty) {
      return 'Enter a password.';
    }
    if (value.length < 6) {
      return "Password must have at least 6 characters.";
    }
    return null;
  }

  /* ------------------------- validateConfirmPassword ------------------------ */
  String? validateConfirmPassword(String? value) {
    if (_signInMode) {
      return null;
    }
    if ((value == null || value.isEmpty)) {
      return 'Confirm your password.';
    }
    if (_confirmPasswordController.text != _passwordController.text) {
      return "Passwords do not match.";
    }
    return null;
  }

  void showPopup() {
    PopupDialogue.showTextField(
      "Reset Password",
      "Email",
      context,
      (email) async {
        bool success = await resetPassword(email);
        if (success && mounted) {
          Navigator.of(context).pop();
          AppLogger.print("Reset password email sent to $email");
        }
      },
      buttonText: "Reset Password",
      defaultValue: _emailController.text,
    );
  }

  Future<bool> resetPassword(String email) async {
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'If you have an account, a Reset Password Email will be sent to you. Remember to check your spam folder.',
            ),
          ),
        );
      }
      return true;
    } on FirebaseAuthException catch (e) {
      AppLogger.error("Failed to send a reset password email: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Enter a valid email")));
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.deepPurple,
      extendBodyBehindAppBar: true,
      extendBody: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primaryPurple,
              AppColors.darkPurple,
              AppColors.deepPurple,
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 60),

                const Icon(
                  Icons.fitness_center,
                  size: 100,
                  color: AppColors.textLight,
                ),

                const SizedBox(height: 24),

                const Text(
                  'Pat Your Mat!',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textLight,
                    letterSpacing: 1.2,
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  'Reserve your spot in group exercise classes',
                  style: TextStyle(
                    fontSize: 18,
                    color: AppColors.textLight70,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 40),

                // User/Staff Toggle
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedRole = UserRole.MEMBER),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _selectedRole == UserRole.MEMBER ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                'Gym Member',
                                style: TextStyle(
                                  color: _selectedRole == UserRole.MEMBER ? AppColors.deepPurple : Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedRole = UserRole.STAFF),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _selectedRole == UserRole.STAFF ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                'Staff',
                                style: TextStyle(
                                  color: _selectedRole == UserRole.STAFF ? AppColors.deepPurple : Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                CustomTextField(
                  controller: _emailController,
                  hintText: 'Email',
                  prefixIcon: Icons.email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: _validateEmail,
                ),

                const SizedBox(height: 20),

                CustomTextField(
                  controller: _passwordController,
                  hintText: 'Password',
                  prefixIcon: Icons.lock,
                  obscureText: !_passwordVisible,
                  textInputAction: _signInMode ? TextInputAction.done : TextInputAction.next,
                  validator: validatePasssword,
                  onChanged: (value) {
                    if (!_signInMode) {
                      setState(() {
                        _passwordStrength = getPasswordStrength(value);
                        _strengthText = getPasswordStrengthText(_passwordStrength);
                        _strengthColor = getPasswordStrengthColor(_passwordStrength);
                      });
                    }
                  },
                  onFieldSubmitted: (_) {
                    if (_signInMode) _trySubmit();
                  },
                ),

                if (!_signInMode) ...[
                  const SizedBox(height: 20),
                  CustomTextField(
                    controller: _confirmPasswordController,
                    hintText: 'Confirm Password',
                    prefixIcon: Icons.lock,
                    obscureText: !_passwordVisible,
                    textInputAction: TextInputAction.done,
                    validator: validateConfirmPassword,
                    onFieldSubmitted: (_) => _trySubmit(),
                  ),
                ],

                if (!_signInMode && _passwordController.text.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: WidgetPasswordStrengthIndicator(
                      passwordStrength: _passwordStrength,
                      passwordText: _strengthText,
                      passwordColor: _strengthColor,
                    ),
                  ),

                const SizedBox(height: 40),

                ElevatedButton(
                  onPressed: _isLoading ? null : _trySubmit,
                  child: _isLoading
                      ? const CircularProgressIndicator(
                          color: Colors.white,
                        )
                      : Text(
                          _signInMode ? 'Sign In' : 'Create Account',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),

                const SizedBox(height: 16),

                TextButton(
                  onPressed: showPopup,
                  child: const Text(
                    'Forgot Password?',
                    style: TextStyle(
                      color: AppColors.textLight70,
                      fontSize: 16,
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                GestureDetector(
                  onTap: () {
                    setState(() {
                      _signInMode = !_signInMode;
                    });
                  },
                  child: Text(
                    _signInMode ? 'Create an account' : 'I already have an account',
                    style: const TextStyle(
                      color: AppColors.textLight,
                      fontSize: 16,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
