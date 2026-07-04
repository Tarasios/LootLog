/// Device-local first-run setup: the household timezone, the two user profiles,
/// and which profile is "me" on this device.
///
/// This is deliberately not part of the event log. The household is exactly two
/// people; the profiles (id + display name) are shared configuration, but the
/// `me` pointer is device-specific and must never leave the device.
library;

/// One member of the two-person household.
class UserProfile {
  const UserProfile({required this.userId, required this.name});

  final String userId;
  final String name;

  @override
  bool operator ==(Object other) =>
      other is UserProfile && other.userId == userId && other.name == name;

  @override
  int get hashCode => Object.hash(userId, name);

  @override
  String toString() => 'UserProfile($userId, $name)';
}

/// The completed local setup for this device.
class LocalSetup {
  LocalSetup({
    required this.timezone,
    required this.user1,
    required this.user2,
    required this.meUserId,
  }) : assert(
          meUserId == user1.userId || meUserId == user2.userId,
          'meUserId must be one of the two profiles',
        );

  /// IANA-style household timezone. DuoBudget computes months in this zone
  /// (currently only America/Vancouver is supported by the reducer).
  final String timezone;

  final UserProfile user1;
  final UserProfile user2;

  /// Which of the two profiles this device is.
  final String meUserId;

  /// The two profiles in a stable order.
  List<UserProfile> get profiles => [user1, user2];

  /// The profile this device represents.
  UserProfile get me => user1.userId == meUserId ? user1 : user2;

  /// The other member of the household.
  UserProfile get partner => user1.userId == meUserId ? user2 : user1;

  LocalSetup copyWith({
    String? timezone,
    UserProfile? user1,
    UserProfile? user2,
    String? meUserId,
  }) =>
      LocalSetup(
        timezone: timezone ?? this.timezone,
        user1: user1 ?? this.user1,
        user2: user2 ?? this.user2,
        meUserId: meUserId ?? this.meUserId,
      );

  @override
  bool operator ==(Object other) =>
      other is LocalSetup &&
      other.timezone == timezone &&
      other.user1 == user1 &&
      other.user2 == user2 &&
      other.meUserId == meUserId;

  @override
  int get hashCode => Object.hash(timezone, user1, user2, meUserId);

  @override
  String toString() =>
      'LocalSetup($timezone, $user1, $user2, me=$meUserId)';
}
