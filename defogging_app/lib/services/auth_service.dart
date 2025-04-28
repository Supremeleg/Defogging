import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 获取当前用户
  User? get currentUser => _auth.currentUser;

  // 用户状态流
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // 使用邮箱和密码注册
  Future<UserCredential> signUpWithEmailAndPassword(String email, String password) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      throw Exception('注册失败: $e');
    }
  }

  // 使用邮箱和密码登录
  Future<UserCredential> signInWithEmailAndPassword(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      throw Exception('登录失败: $e');
    }
  }

  // 退出登录
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw Exception('退出登录失败: $e');
    }
  }

  // 重置密码
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      throw Exception('重置密码失败: $e');
    }
  }
} 