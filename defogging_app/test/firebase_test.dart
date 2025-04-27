import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:defogging_app/firebase_options.dart';

Future<void> setupFirebaseTest() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
}

void main() {
  setUpAll(() async {
    await setupFirebaseTest();
  });

  group('Firebase 连接测试', () {
    test('检查 Firebase 配置是否正确', () {
      final options = DefaultFirebaseOptions.currentPlatform;
      expect(options.projectId, 'defogging-e4c51');
      expect(options.messagingSenderId, '815542967882');
      print('Firebase 配置验证成功！');
    });
  });
} 