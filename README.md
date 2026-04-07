# Pat Your Mat

Flutter app for browsing classes, reserving mats, and managing staff-side attendance and scheduling.

## Current Features
- Firebase Auth and profile onboarding
- Member class browsing and reservation flow
- Mat assignment and cancellation
- Staff portal for class creation, editing, deletion, and attendance
- Check-in flow that records attendance and updates achievement progress
- Automatic no-show behavior after class end for unchecked reservations

## Firestore
- Firestore rules are stored in [firestore.rules](firestore.rules)
- Firebase config points to that rules file in [firebase.json](firebase.json)
- If attendance or reservation writes change, deploy updated rules with:

```bash
firebase deploy --only firestore:rules --project jr-design-project
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
