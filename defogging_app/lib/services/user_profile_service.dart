import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';

class UserProfileService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final SharedPreferences _prefs;

  UserProfileService(this._prefs);

  // Get current user profile
  Future<UserProfile?> getCurrentUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        return UserProfile.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      print('Failed to get user profile: $e');
      return null;
    }
  }

  // Create or update user profile
  Future<void> createOrUpdateUserProfile(UserProfile profile) async {
    try {
      await _firestore.collection('users').doc(profile.uid).set(profile.toMap());
    } catch (e) {
      print('Failed to update user profile: $e');
      throw Exception('Failed to update user profile: $e');
    }
  }

  // Update user display name
  Future<void> updateDisplayName(String displayName) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    try {
      await user.updateDisplayName(displayName);
      final profile = await getCurrentUserProfile();
      if (profile != null) {
        await createOrUpdateUserProfile(profile.copyWith(displayName: displayName));
      }
    } catch (e) {
      print('Failed to update display name: $e');
      throw Exception('Failed to update display name: $e');
    }
  }

  // Update user avatar
  Future<void> updatePhotoURL(String photoURL) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    try {
      await user.updatePhotoURL(photoURL);
      final profile = await getCurrentUserProfile();
      if (profile != null) {
        await createOrUpdateUserProfile(profile.copyWith(photoURL: photoURL));
      }
    } catch (e) {
      print('Failed to update avatar: $e');
      throw Exception('Failed to update avatar: $e');
    }
  }

  // Update user phone number
  Future<void> updatePhoneNumber(String phoneNumber) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    try {
      final profile = await getCurrentUserProfile();
      if (profile != null) {
        await createOrUpdateUserProfile(profile.copyWith(phoneNumber: phoneNumber));
      }
    } catch (e) {
      print('Failed to update phone number: $e');
      throw Exception('Failed to update phone number: $e');
    }
  }

  // Remember login state
  Future<void> rememberLoginState(bool remember) async {
    await _prefs.setBool('remember_login', remember);
  }

  // Get remember login state
  bool getRememberLoginState() {
    return _prefs.getBool('remember_login') ?? false;
  }

  // Save user email
  Future<void> saveUserEmail(String email) async {
    await _prefs.setString('user_email', email);
  }

  // Get saved user email
  String? getSavedUserEmail() {
    return _prefs.getString('user_email');
  }

  // Clear saved login information
  Future<void> clearSavedLoginInfo() async {
    await _prefs.remove('user_email');
    await _prefs.remove('remember_login');
  }
} 