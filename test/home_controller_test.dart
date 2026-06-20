import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/common/services/settings_service.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/modules/home/home_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUp(() async {
    Get.reset();
    tempDir = await Directory.systemTemp.createTemp('home_ctrl_test_');
    Hive.init(tempDir.path);
    await HivePrefUtil.init();
    // Register SettingsService without triggering onInit
    Get.put<SettingsService>(SettingsService(), permanent: false);
  });

  tearDown(() async {
    Get.reset();
    await Future.delayed(const Duration(milliseconds: 50));
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('onClose does not throw', () {
    final controller = HomeController();
    // Just verify onClose doesn't crash
    controller.onClose();
    expect(true, isTrue);
  });

  test('controller can be created', () {
    final controller = HomeController();
    expect(controller, isNotNull);
  });
}
