import 'package:flutter_test/flutter_test.dart';
import 'package:pat_your_mat/models/gym_class.dart';
import 'package:pat_your_mat/util/classes/class_visuals.dart';

void main() {
  test('gymClassVisualForKey returns the matching visual when key exists', () {
    final visual = gymClassVisualForKey('dance', classType: 'Dance');

    expect(visual.key, 'dance');
    expect(visual.label, 'Dance');
  });

  test('gymClassVisualForKey falls back to legacy class type defaults', () {
    final visual = gymClassVisualForKey('unknown-key', classType: 'Cardio');

    expect(visual.key, defaultGymClassIconKeyForType('Cardio'));
  });
}
