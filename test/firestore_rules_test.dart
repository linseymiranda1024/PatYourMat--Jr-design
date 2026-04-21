import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'members can only update their class registration mirror for no-show sync',
    () {
      final rules = File('firestore.rules').readAsStringSync();

      expect(rules, contains('function ownerNoShowRegistrationUpdate(userId)'));
      expect(
        rules,
        contains(
          "request.resource.data.diff(resource.data).affectedKeys().hasOnly",
        ),
      );
      expect(rules, contains("'status'"));
      expect(rules, contains("'noShowAt'"));
      expect(rules, contains("request.resource.data.status == 'NO-SHOW'"));
      expect(rules, contains('allow create: if isOwner(userId) || isStaff();'));
      expect(
        rules,
        contains(
          'allow update: if isStaff() || ownerNoShowRegistrationUpdate(userId);',
        ),
      );
    },
  );
}
