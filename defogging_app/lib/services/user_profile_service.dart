import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';

class UserProfileService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final SharedPreferences _prefs;

  UserProfileService(this._prefs);

  // 获取当前用户的资料
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
      print('获取用户资料失败: $e');
      return null;
    }
  }

  // 创建或更新用户资料
  Future<void> createOrUpdateUserProfile(UserProfile profile) async {
    try {
      await _firestore.collection('users').doc(profile.uid).set(profile.toMap());
    } catch (e) {
      print('更新用户资料失败: $e');
      throw Exception('更新用户资料失败: $e');
    }
  }

  // 更新用户显示名称
  Future<void> updateDisplayName(String displayName) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('用户未登录');

    try {
      await user.updateDisplayName(displayName);
      final profile = await getCurrentUserProfile();
      if (profile != null) {
        await createOrUpdateUserProfile(profile.copyWith(displayName: displayName));
      }
    } catch (e) {
      print('更新显示名称失败: $e');
      throw Exception('更新显示名称失败: $e');
    }
  }

  // 更新用户头像
  Future<void> updatePhotoURL(String photoURL) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('用户未登录');

    try {
      await user.updatePhotoURL(photoURL);
      final profile = await getCurrentUserProfile();
      if (profile != null) {
        await createOrUpdateUserProfile(profile.copyWith(photoURL: photoURL));
      }
    } catch (e) {
      print('更新头像失败: $e');
      throw Exception('更新头像失败: $e');
    }
  }

  // 更新用户手机号
  Future<void> updatePhoneNumber(String phoneNumber) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('用户未登录');

    try {
      final profile = await getCurrentUserProfile();
      if (profile != null) {
        await createOrUpdateUserProfile(profile.copyWith(phoneNumber: phoneNumber));
      }
    } catch (e) {
      print('更新手机号失败: $e');
      throw Exception('更新手机号失败: $e');
    }
  }

  // 记住登录状态
  Future<void> rememberLoginState(bool remember) async {
    await _prefs.setBool('remember_login', remember);
  }

  // 获取记住登录状态
  bool getRememberLoginState() {
    return _prefs.getBool('remember_login') ?? false;
  }

  // 保存用户邮箱
  Future<void> saveUserEmail(String email) async {
    await _prefs.setString('user_email', email);
  }

  // 获取保存的用户邮箱
  String? getSavedUserEmail() {
    return _prefs.getString('user_email');
  }

  // 清除保存的登录信息
  Future<void> clearSavedLoginInfo() async {
    await _prefs.remove('user_email');
    await _prefs.remove('remember_login');
  }
} 