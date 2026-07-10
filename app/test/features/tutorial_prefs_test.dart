import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/features/tutorial/tutorial_prefs.dart';

void main() {
  test('encodes and decodes completion', () {
    expect(TutorialProgress.decode('true'),
        const TutorialProgress(completed: true, stepIndex: 0));
    expect(const TutorialProgress(completed: true, stepIndex: 0).encode(),
        'true');
  });

  test('encodes and decodes a mid-tour step', () {
    expect(TutorialProgress.decode('step:3'),
        const TutorialProgress(completed: false, stepIndex: 3));
    expect(const TutorialProgress(completed: false, stepIndex: 3).encode(),
        'step:3');
  });

  test('legacy and garbage values decode sanely', () {
    // Legacy file contents: 'true' (seen) / 'false' (not seen).
    expect(TutorialProgress.decode('false'),
        const TutorialProgress(completed: false, stepIndex: 0));
    expect(TutorialProgress.decode('step:-2'),
        const TutorialProgress(completed: false, stepIndex: 0));
    expect(TutorialProgress.decode('garbage'),
        const TutorialProgress(completed: false, stepIndex: 0));
  });
}
