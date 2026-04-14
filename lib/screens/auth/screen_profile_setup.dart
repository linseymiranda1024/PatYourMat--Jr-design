// -----------------------------------------------------------------------
// Filename: screen_provider_setup.dart
// Original Author: Emily Ehrenberg
// Creation Date: 5/27/2024
// Copyright: (c) 2024 Pat Your Mat!
// Description: This file contains the screen for setting up the user's
//              profile.

//////////////////////////////////////////////////////////////////////////
// Imports
//////////////////////////////////////////////////////////////////////////
// Flutter external package imports
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

// App relative file imports
import '../../widgets/general/widget_profile_avatar.dart';
import '../../providers/provider_user_profile.dart';
import '../../util/message_display/snackbar.dart';
import '../../util/logging/app_logger.dart';
import '../../providers/provider_auth.dart';
import '../../models/user_profile.dart';
import '../../theme/colors.dart';
import '../../main.dart';

//////////////////////////////////////////////////////////////////
// StateFUL widget which manages state. Simply initializes the
// state object.
//////////////////////////////////////////////////////////////////
class ScreenProfileSetup extends ConsumerStatefulWidget {
  static const routeName = '/profileSetup';

  // Final variables passed in as parameters
  final bool isAuth;

  const ScreenProfileSetup({super.key, required this.isAuth});

  @override
  ConsumerState<ScreenProfileSetup> createState() => _ScreenProfileSetupState();
}

//////////////////////////////////////////////////////////////////
// The actual STATE which is managed by the above widget.
//////////////////////////////////////////////////////////////////
class _ScreenProfileSetupState extends ConsumerState<ScreenProfileSetup> {
  // The "instance variables" managed in this state
  var _isInit = true;
  late ProviderUserProfile _providerUserProfile;
  late ProviderAuth _providerAuth;
  final ImagePicker _imagePicker = ImagePicker();
  Uint8List? pickedImage;
  bool editingPicture = false;
  bool _isUpdatingPhoto = false;

  // Finals used in this widget
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _bioController = TextEditingController();

  ////////////////////////////////////////////////////////////////
  // Runs the following code once upon initialization
  ////////////////////////////////////////////////////////////////
  @override
  void didChangeDependencies() {
    // If first time running this code, update provider settings
    if (_isInit) {
      _init();

      //Update text fields to contain current names if set
      if (!widget.isAuth) {
        _firstNameController.text = _providerUserProfile.firstName;
        _lastNameController.text = _providerUserProfile.lastName;
        _bioController.text = _providerUserProfile.bio;
      }

      // Now initialized; run super method
      _isInit = false;
      super.didChangeDependencies();
    }
  }

  ////////////////////////////////////////////////////////////////
  ////////////////////////////////////////////////////////////////
  /// Helper Methods (for state object)
  ////////////////////////////////////////////////////////////////
  ////////////////////////////////////////////////////////////////

  ////////////////////////////////////////////////////////////////
  // Gets the current state of the providers for consumption on
  // this page
  ////////////////////////////////////////////////////////////////
  _init() async {
    // Get the providers
    _providerUserProfile = ref.watch(providerUserProfile);
    _providerAuth = ref.watch(providerAuth);
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  ////////////////////////////////////////////////////////////////
  // Does basic validation and attempts to authenticate using the
  // method called in from the parent screen/widget.
  ////////////////////////////////////////////////////////////////
  Future<void> _trySubmit() async {
    // Unfocus from any controls that may have focus to disengage the keyboard
    FocusScope.of(context).unfocus();

    // If the form validates, save the data and then execute the callback function,
    // which attempts to either login to existing account or signup for new account.
    final isValid = _formKey.currentState!.validate();
    if (isValid) {
      _formKey.currentState!.save();

      // Update profile information and write to database
      _providerUserProfile.firstName = _firstNameController.text.trim();
      _providerUserProfile.lastName = _lastNameController.text.trim();
      _providerUserProfile.bio = _bioController.text.trim();
      _providerUserProfile.accountCreationStep =
          AccountCreationStep.ACC_STEP_ONBOARDING_COMPLETE;
      await _providerUserProfile.writeUserProfileToDb();

      //If saving a snack-bar will appear and will pop the navigator
      if (!widget.isAuth) {
        Snackbar.show(
          SnackbarDisplayType.SB_SUCCESS,
          "Profile Updated",
          context,
        );
        context.pop();
      }
    }
  }

  ////////////////////////////////////////////////////////////////
  // Upload profile image to Firebase Storage
  ////////////////////////////////////////////////////////////////
  Future<void> uploadProfileImage() async {
    if (pickedImage == null) {
      return;
    }

    final previousImage = _providerUserProfile.userImage;

    setState(() {
      _isUpdatingPhoto = true;
    });

    try {
      await _providerUserProfile.uploadAndSetNewUserProfileImage(pickedImage!);
      if (!mounted) {
        return;
      }

      setState(() {
        pickedImage = null;
        editingPicture = false;
        _isUpdatingPhoto = false;
      });

      Snackbar.show(
        SnackbarDisplayType.SB_SUCCESS,
        'Profile photo saved successfully',
        context,
      );
    } catch (e) {
      AppLogger.error('Failed to upload profile image: $e');
      _providerUserProfile.userImage = previousImage;

      if (!mounted) {
        return;
      }

      setState(() {
        pickedImage = null;
        _isUpdatingPhoto = false;
      });

      Snackbar.show(
        SnackbarDisplayType.SB_ERROR,
        'Unable to save your profile photo right now.',
        context,
      );
    }
  }

  ////////////////////////////////////////////////////////////////
  // Pick an image from the camera roll
  ////////////////////////////////////////////////////////////////
  Future pickImage() async {
    await _pickAndUploadImage(ImageSource.gallery);
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    try {
      if (!_imagePicker.supportsImageSource(source)) {
        if (mounted) {
          Snackbar.show(
            SnackbarDisplayType.SB_INFO,
            source == ImageSource.camera
                ? 'Camera is unavailable on this device or emulator.'
                : 'Photo library is unavailable on this device.',
            context,
          );
        }
        return;
      }

      final pickedImage = await _imagePicker.pickImage(
        source: source,
        maxHeight: source == ImageSource.gallery ? 300 : 1200,
        maxWidth: source == ImageSource.gallery ? 300 : 1200,
        imageQuality: source == ImageSource.gallery ? 100 : 70,
      );
      if (pickedImage == null) return;

      final imageBytes = await pickedImage.readAsBytes();
      setState(() => this.pickedImage = imageBytes);
      await uploadProfileImage();
    } on PlatformException catch (e) {
      AppLogger.error('Failed to pick image: $e');
      if (mounted) {
        Snackbar.show(
          SnackbarDisplayType.SB_ERROR,
          source == ImageSource.camera
              ? 'Unable to open the camera right now.'
              : 'Unable to open the photo library right now.',
          context,
        );
      }
    } catch (e) {
      AppLogger.error('Unexpected image picking failure: $e');
      if (mounted) {
        Snackbar.show(
          SnackbarDisplayType.SB_ERROR,
          'Something went wrong while choosing an image.',
          context,
        );
      }
    }
  }

  ////////////////////////////////////////////////////////////////
  // Pick an image from the camera
  ////////////////////////////////////////////////////////////////
  Future takeImage() async {
    await _pickAndUploadImage(ImageSource.camera);
  }

  ////////////////////////////////////////////////////////////////
  //Makes the buttons visible that allow you too take a picture or
  // select from camera roll
  ////////////////////////////////////////////////////////////////
  void setEditVisibile() {
    if (_isUpdatingPhoto) {
      return;
    }

    setState(() {
      editingPicture = !editingPicture;
      if (!editingPicture) {
        pickedImage = null;
      }
    });
  }

  ////////////////////////////////////////////////////////////////////////////////////////////
  // Helper methods to create an edit icon
  ////////////////////////////////////////////////////////////////////////////////////////////
  Widget getEditIcon(Color color) => buildCircle(
    color: Theme.of(context).inputDecorationTheme.iconColor!,
    all: 5,
    child: buildCircle(
      color: color,
      all: 8,
      child: Icon(
        editingPicture ? Icons.edit_off_rounded : Icons.edit_rounded,
        size: 22,
        color: Colors.white,
      ),
    ),
  );
  Widget buildCircle({
    required Widget child,
    required double all,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      padding: EdgeInsets.all(all),
      child: child,
    );
  }

  ////////////////////////////////////////////////////////////////////////////////////////////
  // Remove profile picture via provider
  ////////////////////////////////////////////////////////////////////////////////////////////
  Future<void> removeProfileImage() async {
    final previousImage = _providerUserProfile.userImage;

    setState(() {
      _isUpdatingPhoto = true;
    });

    try {
      await _providerUserProfile.removeUserProfileImage();
      if (!mounted) {
        return;
      }

      setState(() {
        pickedImage = null;
        editingPicture = false;
        _isUpdatingPhoto = false;
      });

      Snackbar.show(
        SnackbarDisplayType.SB_SUCCESS,
        'Profile photo removed',
        context,
      );
    } catch (e) {
      AppLogger.error('Failed to remove profile image: $e');
      _providerUserProfile.userImage = previousImage;

      if (!mounted) {
        return;
      }

      setState(() {
        _isUpdatingPhoto = false;
      });

      Snackbar.show(
        SnackbarDisplayType.SB_ERROR,
        'Unable to remove your profile photo right now.',
        context,
      );
    }
  }

  Widget _buildPhotoActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    bool isPrimary = false,
    bool isDestructive = false,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final textStyle = theme.textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w700,
    );

    if (isPrimary) {
      return FilledButton.tonalIcon(
        onPressed: _isUpdatingPhoto ? null : onPressed,
        style: FilledButton.styleFrom(
          minimumSize: const Size(122, 46),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          backgroundColor: colorScheme.primaryContainer,
          foregroundColor: colorScheme.onPrimaryContainer,
          textStyle: textStyle,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        icon: Icon(icon, size: 20),
        label: Text(label),
      );
    }

    return OutlinedButton.icon(
      onPressed: _isUpdatingPhoto ? null : onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(122, 46),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        backgroundColor: isDestructive
            ? colorScheme.errorContainer.withValues(alpha: isDark ? 0.20 : 0.12)
            : colorScheme.surface,
        foregroundColor: isDestructive
            ? colorScheme.error
            : colorScheme.onSurface,
        textStyle: textStyle,
        side: BorderSide(
          color: isDestructive
              ? colorScheme.error.withValues(alpha: 0.30)
              : colorScheme.outlineVariant.withValues(
                  alpha: isDark ? 0.55 : 0.85,
                ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      icon: Icon(icon, size: 20),
      label: Text(label),
    );
  }

  Widget _buildPhotoActionCard() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final hasCurrentPhoto =
        pickedImage != null || _providerUserProfile.userImage != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark
            ? colorScheme.surfaceContainerHigh
            : colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(
            alpha: isDark ? 0.45 : 0.75,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Icon(
                  CupertinoIcons.photo_on_rectangle,
                  color: colorScheme.onPrimaryContainer,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Profile photo',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isUpdatingPhoto
                          ? 'Updating your photo now.'
                          : 'Choose a source below. New photos save automatically.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: _isUpdatingPhoto ? null : setEditVisibile,
                child: const Text('Done'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isUpdatingPhoto)
            Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Saving your changes. This usually takes a moment.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildPhotoActionButton(
                  label: 'Gallery',
                  icon: Icons.image_outlined,
                  onPressed: pickImage,
                  isPrimary: true,
                ),
                _buildPhotoActionButton(
                  label: 'Camera',
                  icon: CupertinoIcons.camera,
                  onPressed: takeImage,
                ),
                if (hasCurrentPhoto)
                  _buildPhotoActionButton(
                    label: 'Remove',
                    icon: CupertinoIcons.delete,
                    onPressed: removeProfileImage,
                    isDestructive: true,
                  ),
              ],
            ),
        ],
      ),
    );
  }

  //////////////////////////////////////////////////////////////////////////
  // Primary Flutter method overriden which describes the layout
  // and bindings for this widget.
  //////////////////////////////////////////////////////////////////////////
  @override
  Widget build(BuildContext context) {
    final isStaff = _providerUserProfile.role == UserRole.STAFF;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Form(
      key: _formKey,
      child: AutofillGroup(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height - 160,
              ),
              child: Column(
                mainAxisAlignment: widget.isAuth
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Profile Avatar
                  ///////////////////////////////////////////////////////////////////////
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12, top: 20),
                      child: GestureDetector(
                        onTap: _isUpdatingPhoto ? null : setEditVisibile,
                        child: Stack(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(5.0),
                              child: ProfileAvatar(
                                radius: 96,
                                userImage: pickedImage == null
                                    ? _providerUserProfile.userImage
                                    : MemoryImage(pickedImage!),
                                userWholeName: _providerUserProfile.wholeName,
                              ),
                            ),
                            Positioned(
                              bottom: 10,
                              right: 10,
                              child: getEditIcon(
                                Theme.of(
                                      context,
                                    ).inputDecorationTheme.iconColor ??
                                    CustomColors.statusInfo,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: Text(
                      editingPicture
                          ? 'Choose a new photo or remove the current one. Changes save automatically.'
                          : 'Tap the avatar to update your profile photo.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ),
                  ///////////////////////////////////////////////////////////////////////
                  // Profile Image Edit Buttons
                  ///////////////////////////////////////////////////////////////////////
                  if (editingPicture) _buildPhotoActionCard(),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark
                          ? colorScheme.surfaceContainer
                          : colorScheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: colorScheme.outlineVariant.withValues(
                          alpha: isDark ? 0.45 : 0.7,
                        ),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.20 : 0.06,
                          ),
                          blurRadius: 16,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: TextFormField(
                            controller: _firstNameController,
                            autofillHints: const [AutofillHints.givenName],
                            autocorrect: false,
                            textCapitalization: TextCapitalization.sentences,
                            validator: (value) {
                              if (value!.isEmpty) {
                                return 'Please enter a first name.';
                              }
                              return null;
                            },
                            onSaved: (value) {},
                            keyboardType: TextInputType.name,
                            decoration: const InputDecoration(
                              labelText: 'First Name',
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: TextFormField(
                            controller: _lastNameController,
                            autofillHints: const [AutofillHints.familyName],
                            autocorrect: false,
                            textCapitalization: TextCapitalization.sentences,
                            validator: (value) {
                              if (value!.isEmpty) {
                                return 'Please enter a last name.';
                              }
                              return null;
                            },
                            onSaved: (value) {},
                            keyboardType: TextInputType.name,
                            decoration: const InputDecoration(
                              labelText: 'Last Name',
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: TextFormField(
                            controller: _bioController,
                            textCapitalization: TextCapitalization.sentences,
                            keyboardType: TextInputType.multiline,
                            minLines: 4,
                            maxLines: 6,
                            decoration: const InputDecoration(
                              labelText: 'Bio',
                              alignLabelWithHint: true,
                            ),
                          ),
                        ),
                        SizedBox(height: isStaff ? 12 : 6),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => _trySubmit(),
                            child: widget.isAuth
                                ? const Text("Submit")
                                : const Text("Update"),
                          ),
                        ),
                        if (widget.isAuth)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: TextButton(
                              onPressed: () => _providerAuth
                                  .clearAuthedUserDetailsAndSignout(),
                              child: const Text("Log out"),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
