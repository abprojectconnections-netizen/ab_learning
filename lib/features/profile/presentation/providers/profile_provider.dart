import 'package:flutter_riverpod/flutter_riverpod.dart';

class UserProfile {
  final String displayName;
  final String email;
  final String avatarUrl;

  const UserProfile({
    required this.displayName,
    required this.email,
    required this.avatarUrl,
  });

  UserProfile copyWith({String? displayName, String? avatarUrl}) {
    return UserProfile(
      displayName: displayName ?? this.displayName,
      email: email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }
}

class ProfileNotifier extends StateNotifier<UserProfile> {
  ProfileNotifier() : super(const UserProfile(
    displayName: 'ผู้ใช้งานระบบ AB',
    email: 'learner@test.com',
    avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200',
  ));

  void updateProfile(String name, String avatar) {
    state = state.copyWith(displayName: name, avatarUrl: avatar);
  }
}

final profileProvider = StateNotifierProvider<ProfileNotifier, UserProfile>((ref) {
  return ProfileNotifier();
});