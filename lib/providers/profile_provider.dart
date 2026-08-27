import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/profile_model.dart';

class ProfileNotifier extends StateNotifier<Profile> {
  ProfileNotifier() : super(Profile()) {
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final profile = Profile(
      name: prefs.getString('profile_name') ?? state.name,
      email: prefs.getString('profile_email') ?? state.email,
      phone: prefs.getString('profile_phone') ?? state.phone,
      bio: prefs.getString('profile_bio') ?? state.bio,
      imagePath: prefs.getString('profile_image_path'),
    );
    state = profile;
  }

  Future<void> updateProfile(Profile profile) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      await prefs.setString('profile_name', profile.name);
      await prefs.setString('profile_email', profile.email);
      await prefs.setString('profile_phone', profile.phone);
      await prefs.setString('profile_bio', profile.bio);
      if (profile.imagePath != null) {
        await prefs.setString('profile_image_path', profile.imagePath!);
      } else {
        await prefs.remove('profile_image_path');
      }
      state = profile;
    } catch (e) {
      debugPrint('Error updating profile: $e');
    }
  }
}

final profileProvider =
    StateNotifierProvider<ProfileNotifier, Profile>((ref) => ProfileNotifier());
