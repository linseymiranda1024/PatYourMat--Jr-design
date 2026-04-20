// -----------------------------------------------------------------------
// Filename: user_profile.dart
// Original Author: Emily Ehrenberg
// Creation Date: 5/22/2024
// Copyright: (c) 2024 Pat Your Mat!
// Description: This file contains the model for the user profile

//////////////////////////////////////////////////////////////////////////
// Imports
//////////////////////////////////////////////////////////////////////////
// Flutter external package imports
import 'package:cloud_firestore/cloud_firestore.dart';

import '../util/date_time/util_no_show_penalty.dart';

// Enum definition for account creation status
enum AccountCreationStep {
  ACC_STEP_ONBOARDING_PROFILE_CONTACT_INFO,
  ACC_STEP_ONBOARDING_COMPLETE,
}

// Enum definition for user role
enum UserRole { MEMBER, STAFF }

// Enum definition for permission level
// NOTE: Do NOT change the order of these enums. They are used for permissions
// checking (e.g., Developer has access to Beta and Production, but not vice versa by
// the fact that Developer is the highest enum value)
enum PermissionLevel { PRODUCTION, BETA, DEVELOPER }

//////////////////////////////////////////////////////////////////////////
// Model class definitition
//////////////////////////////////////////////////////////////////////////
class UserProfile {
  ////////////////////////////////////////////////////////////////////////
  // Instance variables
  ////////////////////////////////////////////////////////////////////////
  String _uid = "";
  String _firstName = "";
  String _lastName = "";
  String _email = "";
  String _phoneNumber = "";
  String _bio = "";
  List<String> _achievements = [];
  List<String> _favoriteClassIds = [];
  Map<String, int> _categoryAttendance = {};
  List<String> _specialties = [];
  int _yearsTeaching = 0;
  bool _isActiveInstructor = false;
  bool _allowClassCreation = false;
  bool _pushNotificationsEnabled = true;
  bool _standbyAlertsEnabled = true;
  bool _darkModeEnabled = false;
  int _noShowCount = 0;
  DateTime? _noShowPenaltyUntil;
  UserRole _role = UserRole.MEMBER;
  PermissionLevel _permissionLevel = PermissionLevel.PRODUCTION;
  int _accountCreationTime = 0;
  DateTime _dateLastPasswordChange = DateTime.now().add(
    const Duration(days: -365),
  );
  AccountCreationStep _accountCreationStep =
      AccountCreationStep.ACC_STEP_ONBOARDING_PROFILE_CONTACT_INFO;

  ////////////////////////////////////////////////////////////////////////
  // CONSTRUCTORS
  ////////////////////////////////////////////////////////////////////////
  // Positional Constructor
  UserProfile(
    this._uid,
    this._firstName,
    this._lastName,
    this._email,
    this._phoneNumber,
    this._bio,
    this._achievements,
    this._favoriteClassIds,
    this._categoryAttendance,
    this._specialties,
    this._yearsTeaching,
    this._isActiveInstructor,
    this._allowClassCreation,
    this._pushNotificationsEnabled,
    this._standbyAlertsEnabled,
    this._darkModeEnabled,
    this._role,
    this._permissionLevel,
    this._accountCreationTime,
    this._dateLastPasswordChange,
    this._accountCreationStep,
  );

  // Named Constructor
  UserProfile.empty() {
    _uid = "";
    _lastName = "";
    _firstName = "";
    _email = "";
    _phoneNumber = "";
    _bio = "";
    _achievements = [];
    _favoriteClassIds = [];
    _categoryAttendance = {};
    _specialties = [];
    _yearsTeaching = 0;
    _isActiveInstructor = false;
    _allowClassCreation = false;
    _pushNotificationsEnabled = true;
    _standbyAlertsEnabled = true;
    _darkModeEnabled = false;
    _noShowCount = 0;
    _noShowPenaltyUntil = null;
    _role = UserRole.MEMBER;
    _permissionLevel = PermissionLevel.PRODUCTION;
    _accountCreationTime = 0;
    _accountCreationStep =
        AccountCreationStep.ACC_STEP_ONBOARDING_PROFILE_CONTACT_INFO;
  }

  ////////////////////////////////////////////////////////////////////////
  // Creates a new User profile and populates using the JSON object passed
  // in as parameter
  ////////////////////////////////////////////////////////////////////////
  UserProfile.defFromJsonDbObject(
    Map<String, dynamic> jsonObject,
    String firebaseUid,
  ) {
    firstName = jsonObject["first_name"] ?? "";
    lastName = jsonObject["last_name"] ?? "";
    email = jsonObject["email"] ?? "";
    phoneNumber = jsonObject["phone_number"] ?? "";
    bio = jsonObject["bio"] ?? "";
    achievements = List<String>.from(jsonObject["achievements"] ?? const []);
    favoriteClassIds = List<String>.from(
      jsonObject["favorite_class_ids"] ?? const [],
    );
    categoryAttendance = _parseCategoryAttendance(
      jsonObject["category_attendance"] ?? jsonObject["categoryAttendance"],
    );
    specialties = List<String>.from(jsonObject["specialties"] ?? []);
    yearsTeaching = jsonObject["years_teaching"] ?? 0;
    isActiveInstructor = jsonObject["is_active_instructor"] ?? false;
    allowClassCreation = jsonObject["allow_class_creation"] ?? false;
    pushNotificationsEnabled = jsonObject["push_notifications_enabled"] ?? true;
    standbyAlertsEnabled = jsonObject["standby_alerts_enabled"] ?? true;
    darkModeEnabled = jsonObject["dark_mode_enabled"] ?? false;
    noShowCount = jsonObject["no_show_count"] ?? 0;
    noShowPenaltyUntil = _parseOptionalDateTime(
      jsonObject["no_show_penalty_until"],
    );
    uid = firebaseUid;
    role = _getRoleFromString(
      jsonObject["role"] ?? _getStringFromRole(UserRole.MEMBER),
    );
    permissionLevel = _getPermissionLevelFromString(
      jsonObject["permission_level"] ??
          _getStringFromPermissionLevel(PermissionLevel.PRODUCTION),
    );
    accountCreationTime = jsonObject["account_creation_time"] ?? 0;
    _dateLastPasswordChange =
        (jsonObject["date_last_password_change"] as Timestamp?)?.toDate() ??
        DateTime.now().add(const Duration(days: -365));
    accountCreationStep = getStepFromString(
      jsonObject["account_creation_step"] ??
          getStringFromStep(
            AccountCreationStep.ACC_STEP_ONBOARDING_PROFILE_CONTACT_INFO,
          ),
    );
  }

  ////////////////////////////////////////////////////////////////////////
  // SETTERS
  ////////////////////////////////////////////////////////////////////////
  set uid(String value) => _uid = value;
  set firstName(String value) => _firstName = value;
  set lastName(String value) => _lastName = value;
  set email(String value) => _email = value;
  set phoneNumber(String value) => _phoneNumber = value;
  set bio(String value) => _bio = value;
  set achievements(List<String> value) => _achievements = value;
  set favoriteClassIds(List<String> value) => _favoriteClassIds = value;
  set categoryAttendance(Map<String, int> value) => _categoryAttendance = value;
  set specialties(List<String> value) => _specialties = value;
  set yearsTeaching(int value) => _yearsTeaching = value;
  set isActiveInstructor(bool value) => _isActiveInstructor = value;
  set allowClassCreation(bool value) => _allowClassCreation = value;
  set pushNotificationsEnabled(bool value) => _pushNotificationsEnabled = value;
  set standbyAlertsEnabled(bool value) => _standbyAlertsEnabled = value;
  set darkModeEnabled(bool value) => _darkModeEnabled = value;
  set noShowCount(int value) => _noShowCount = value < 0 ? 0 : value;
  set noShowPenaltyUntil(DateTime? value) => _noShowPenaltyUntil = value;
  set role(UserRole value) => _role = value;

  set permissionLevel(PermissionLevel value) => _permissionLevel = value;
  set accountCreationTime(int value) => _accountCreationTime = value;
  set dateLastPasswordChange(DateTime value) => _dateLastPasswordChange = value;
  set accountCreationStep(AccountCreationStep value) =>
      _accountCreationStep = value;

  ////////////////////////////////////////////////////////////////////////
  // GETTERS
  ////////////////////////////////////////////////////////////////////////
  String get uid => _uid;
  String get firstName => _firstName;
  String get lastName => _lastName;
  String get email => _email;
  String get phoneNumber => _phoneNumber;
  String get bio => _bio;
  List<String> get achievements => _achievements;
  List<String> get favoriteClassIds => _favoriteClassIds;
  Map<String, int> get categoryAttendance => _categoryAttendance;
  List<String> get specialties => _specialties;
  int get yearsTeaching => _yearsTeaching;
  bool get isActiveInstructor => _isActiveInstructor;
  bool get allowClassCreation => _allowClassCreation;
  bool get pushNotificationsEnabled => _pushNotificationsEnabled;
  bool get standbyAlertsEnabled => _standbyAlertsEnabled;
  bool get darkModeEnabled => _darkModeEnabled;
  int get noShowCount => _noShowCount;
  DateTime? get noShowPenaltyUntil => _noShowPenaltyUntil;
  bool get hasActiveNoShowPenalty =>
      isNoShowPenaltyActive(_noShowPenaltyUntil);
  UserRole get role => _role;

  PermissionLevel get permissionLevel => _permissionLevel;
  int get accountCreationTime => _accountCreationTime;
  DateTime get dateLastPasswordChange => _dateLastPasswordChange;
  AccountCreationStep get accountCreationStep => _accountCreationStep;

  ////////////////////////////////////////////////////////////////////////
  ////////////////////////////////////////////////////////////////////////
  /// UTILITY METHODS
  ////////////////////////////////////////////////////////////////////////
  ////////////////////////////////////////////////////////////////////////
  ////////////////////////////////////////////////////////////////////////
  // Method checks to see if the user profile has been initialized
  // by checking if key data items exist
  ////////////////////////////////////////////////////////////////////////
  bool isMissingKeyData() {
    return (uid.isEmpty ||
        firstName.isEmpty ||
        lastName.isEmpty ||
        email.isEmpty);
  }

  ////////////////////////////////////////////////////////////////
  // Converts from enum status to string (for DB usage)
  ////////////////////////////////////////////////////////////////
  String getStringFromStep(AccountCreationStep step) {
    if (step == AccountCreationStep.ACC_STEP_ONBOARDING_PROFILE_CONTACT_INFO)
      return "Contact";
    if (step == AccountCreationStep.ACC_STEP_ONBOARDING_COMPLETE)
      return "Complete";
    return "Contact";
  }

  ////////////////////////////////////////////////////////////////
  // Converts from String to enum status (for DB usage)
  ////////////////////////////////////////////////////////////////
  AccountCreationStep getStepFromString(String stepStr) {
    if (stepStr == "Contact")
      return AccountCreationStep.ACC_STEP_ONBOARDING_PROFILE_CONTACT_INFO;
    if (stepStr == "Complete")
      return AccountCreationStep.ACC_STEP_ONBOARDING_COMPLETE;
    return AccountCreationStep.ACC_STEP_ONBOARDING_COMPLETE;
  }

  ////////////////////////////////////////////////////////////////////////
  // Converts from enum status to string (for DB usage) for
  // user role
  ////////////////////////////////////////////////////////////////////////
  String _getStringFromRole(UserRole role) {
    if (role == UserRole.MEMBER) return "Member";
    if (role == UserRole.STAFF) return "Staff";
    return "Member";
  }

  ////////////////////////////////////////////////////////////////////////
  // Converts from String to enum status for user role
  ////////////////////////////////////////////////////////////////////////
  UserRole _getRoleFromString(String roleStr) {
    if (roleStr == "Member") return UserRole.MEMBER;
    if (roleStr == "Staff") return UserRole.STAFF;
    return UserRole.MEMBER;
  }

  ////////////////////////////////////////////////////////////////////////
  // Converts from enum status to string (for DB usage) for
  // permission level
  ////////////////////////////////////////////////////////////////////////
  String _getStringFromPermissionLevel(PermissionLevel permissionLevel) {
    if (permissionLevel == PermissionLevel.PRODUCTION) return "Production";
    if (permissionLevel == PermissionLevel.BETA) return "Beta";
    if (permissionLevel == PermissionLevel.DEVELOPER) return "Developer";
    return "Production";
  }

  ////////////////////////////////////////////////////////////////////////
  // Converts from String to enum status for permission level
  ////////////////////////////////////////////////////////////////////////
  PermissionLevel _getPermissionLevelFromString(String permissionLevelStr) {
    if (permissionLevelStr == "Production") return PermissionLevel.PRODUCTION;
    if (permissionLevelStr == "Beta") return PermissionLevel.BETA;
    if (permissionLevelStr == "Developer") return PermissionLevel.DEVELOPER;
    return PermissionLevel.PRODUCTION;
  }

  Map<String, int> _parseCategoryAttendance(dynamic rawMap) {
    if (rawMap is! Map) {
      return <String, int>{};
    }

    final parsedMap = <String, int>{};
    rawMap.forEach((key, value) {
      final parsedValue = value is num ? value.toInt() : int.tryParse('$value');
      if (parsedValue != null) {
        parsedMap[key] = parsedValue;
      }
    });
    return parsedMap;
  }

  DateTime? _parseOptionalDateTime(dynamic rawValue) {
    if (rawValue is Timestamp) {
      return rawValue.toDate();
    }
    if (rawValue is DateTime) {
      return rawValue;
    }
    if (rawValue is String) {
      return DateTime.tryParse(rawValue);
    }
    return null;
  }

  ////////////////////////////////////////////////////////////////////////
  // Converts to JSON for saving to noSQL database
  ////////////////////////////////////////////////////////////////////////
  Map<String, dynamic> toJsonForDb() {
    // Create empty map
    Map<String, dynamic> jsonObject = {};

    // Add all fields to the json map
    //dbObject[""] = uid; // FYI: Not currently stored in DB
    jsonObject["first_name"] = firstName;
    jsonObject["last_name"] = lastName;
    jsonObject["email"] = email;
    jsonObject["email_lowercase"] = email
        .toLowerCase(); // Added for bf_manage_share_request GCF
    jsonObject["phone_number"] = phoneNumber;
    jsonObject["bio"] = bio;
    jsonObject["achievements"] = achievements;
    jsonObject["favorite_class_ids"] = favoriteClassIds;
    jsonObject["category_attendance"] = categoryAttendance;
    jsonObject["specialties"] = specialties;
    jsonObject["years_teaching"] = yearsTeaching;
    jsonObject["is_active_instructor"] = isActiveInstructor;
    jsonObject["allow_class_creation"] = allowClassCreation;
    jsonObject["push_notifications_enabled"] = pushNotificationsEnabled;
    jsonObject["standby_alerts_enabled"] = standbyAlertsEnabled;
    jsonObject["dark_mode_enabled"] = darkModeEnabled;
    jsonObject["no_show_count"] = noShowCount;
    if (noShowPenaltyUntil != null) {
      jsonObject["no_show_penalty_until"] = noShowPenaltyUntil;
    }
    jsonObject["role"] = _getStringFromRole(role);
    jsonObject["permission_level"] = _getStringFromPermissionLevel(
      permissionLevel,
    );
    jsonObject["account_creation_time"] = accountCreationTime;
    jsonObject["date_last_password_change"] = _dateLastPasswordChange;
    jsonObject["account_creation_step"] = getStringFromStep(
      accountCreationStep,
    );

    // Return the JSON object
    return jsonObject;
  }
}
