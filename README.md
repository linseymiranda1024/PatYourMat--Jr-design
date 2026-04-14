# Pat Your Mat

Flutter app for browsing classes, reserving mats, and managing staff-side attendance and scheduling.

## Current Features
- Firebase Auth and profile onboarding
- Member class browsing and reservation flow
- Mat assignment and cancellation
- Social mat visibility with compact friend-avatar indicators on reserved mats
- Favorite classes with profile shortcuts
- Recurring class creation with per-occurrence booking
- Member social features including friends, profiles, and group notifications
- Staff portal for class creation, editing, deletion, and attendance
- Check-in flow that records attendance and updates achievement progress
- Automatic no-show behavior after class end for unchecked reservations

## Firebase Rules
- Firestore rules are stored in [firestore.rules](firestore.rules)
- Storage rules are stored in [storage.rules](storage.rules)
- Firebase config points to both rules files in [firebase.json](firebase.json)
- If attendance, reservation, social/friend-request writes, or profile-image access change, deploy updated rules with:

```bash
firebase deploy --only firestore:rules,storage --project jr-design-project
```

## Development
Run the app:

```bash
flutter run
```

Run tests:

```bash
flutter test
```

Run static analysis:

```bash
flutter analyze
```
