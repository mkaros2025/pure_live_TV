import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/common/base/base_controller.dart';
import 'package:pure_live/common/services/settings_service.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';

class TestController extends BasePageController<String> {
  final List<List<String>> pages;
  int _callIndex = 0;

  TestController(this.pages);

  void resetCallIndex() => _callIndex = 0;

  @override
  Future<List<String>> getData(int page, int pageSize) async {
    if (_callIndex >= pages.length) return [];
    return pages[_callIndex++];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUp(() async {
    Get.reset();
    tempDir = await Directory.systemTemp.createTemp('base_ctrl_test_');
    Hive.init(tempDir.path);
    await HivePrefUtil.init();
  });

  tearDown(() async {
    Get.reset();
    await Future.delayed(const Duration(milliseconds: 50));
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('list loads data across multiple pages', () async {
    Get.put(SettingsService(), permanent: false);
    final pages = <List<String>>[
      List.generate(30, (i) => 'item_1_$i'),
      List.generate(30, (i) => 'item_2_$i'),
      List.generate(30, (i) => 'item_3_$i'),
    ];
    final controller = Get.put(TestController(pages));

    await controller.loadData();
    expect(controller.list.length, equals(30));

    await controller.loadData();
    expect(controller.list.length, equals(60));

    await controller.loadData();
    expect(controller.list.length, equals(90));
  });

  test('list can grow beyond 200 items (no artificial cap)', () async {
    Get.put(SettingsService(), permanent: false);
    final pages = List.generate(10, (p) =>
        List.generate(30, (i) => 'page${p}_item_$i'));
    final controller = Get.put(TestController(pages));

    for (int i = 0; i < 10; i++) {
      await controller.loadData();
    }
    // 10 pages × 30 items = 300, should all be present
    expect(controller.list.length, equals(300));
  });

  test('refreshData clears list and reloads from page 1', () async {
    Get.put(SettingsService(), permanent: false);
    final pages = <List<String>>[
      List.generate(30, (i) => 'first_$i'),
      List.generate(30, (i) => 'second_$i'),
    ];
    final controller = Get.put(TestController(pages));

    await controller.loadData();
    await controller.loadData();
    expect(controller.list.length, equals(60));

    // Reset _callIndex so refresh can reload from pages[0]
    controller.resetCallIndex();
    await controller.refreshData();
    expect(controller.list.length, equals(30));
    expect(controller.list.first, equals('first_0'));
  });
}
