import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/domain/state.dart';
import 'package:lootlog/domain/value_types.dart';
import 'package:lootlog/features/settings/member_edit_diff.dart';

void main() {
  final existing = MemberState(
    memberId: 'm1',
    name: 'Riley',
    role: MemberRole.adult,
    active: true,
    customSpriteSha256: null,
    descriptionText: 'A brave accountant.',
  );

  test('identical values are a no-op', () {
    expect(
      memberEditChanged(
        existing,
        name: 'Riley',
        role: MemberRole.adult,
        active: true,
        customSpriteSha256: null,
        descriptionText: 'A brave accountant.',
      ),
      isFalse,
    );
  });

  test('an empty description equals a null one (the sheet round-trips it)',
      () {
    final noDesc = MemberState(
      memberId: 'm1',
      name: 'Riley',
      role: MemberRole.adult,
      active: true,
      customSpriteSha256: null,
      descriptionText: null,
    );
    expect(
      memberEditChanged(
        noDesc,
        name: 'Riley',
        role: MemberRole.adult,
        active: true,
        customSpriteSha256: null,
        descriptionText: null,
      ),
      isFalse,
    );
  });

  test('each changed field is detected', () {
    expect(
      memberEditChanged(existing,
          name: 'Riley R.',
          role: MemberRole.adult,
          active: true,
          customSpriteSha256: null,
          descriptionText: 'A brave accountant.'),
      isTrue,
    );
    expect(
      memberEditChanged(existing,
          name: 'Riley',
          role: MemberRole.dependent,
          active: true,
          customSpriteSha256: null,
          descriptionText: 'A brave accountant.'),
      isTrue,
    );
    expect(
      memberEditChanged(existing,
          name: 'Riley',
          role: MemberRole.adult,
          active: false,
          customSpriteSha256: null,
          descriptionText: 'A brave accountant.'),
      isTrue,
    );
    expect(
      memberEditChanged(existing,
          name: 'Riley',
          role: MemberRole.adult,
          active: true,
          customSpriteSha256: 'f' * 64,
          descriptionText: 'A brave accountant.'),
      isTrue,
    );
    expect(
      memberEditChanged(existing,
          name: 'Riley',
          role: MemberRole.adult,
          active: true,
          customSpriteSha256: null,
          descriptionText: 'Now a bard.'),
      isTrue,
    );
  });
}
