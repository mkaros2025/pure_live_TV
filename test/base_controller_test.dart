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
    tempDir = await Directory.systemTemp.createTemp('hive_test_');
    Hive.init(tempDir.path);
    await HivePrefUtil.init();
  });

  tearDown(() async {
    Get.reset();
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('list never exceeds maxListSize', () async {
    Get.put(SettingsService());
    final pages = <List<String>>[
      List.generate(30, (i) => 'item_1_$i'),
      List.generate(30, (i) => 'item_2_$i'),
      List.generate(30, (i) => 'item_3_$i'),
      List.generate(30, (i) => 'item_4_$i'),
      List.generate(30, (i) => 'item_5_$i'),
      List.generate(30, (i) => 'item_6_$i'),
      List.generate(30, (i) => 'item_7_$i'),
      List.generate(30, (i) => 'item_8_$i'),
    ];
    final controller = Get.put(TestController(pages));
    controller.maxListSize = 50;

    for (int i = 0; i < pages.length; i++) {
      await controller.loadData();
    }

    expect(controller.list.length, lessThanOrEqualTo(50));
  });

  test('after trimming, newest items are preserved', () async {
    Get.put(SettingsService());
    final pages = <List<String>>[
      List.generate(30, (i) => 'old_$i'),
      List.generate(30, (i) => 'mid_$i'),
      List.generate(30, (i) => 'new_$i'),
    ];
    final controller = Get.put(TestController(pages));
    controller.maxListSize = 40;

    for (int i = 0; i < pages.length; i++) {
      await controller.loadData();
    }

    expect(controller.list.length, lessThanOrEqualTo(40));
    expect(controller.list.last, 'new_29');
    expect(controller.list.contains('new_0'), isTrue);
    expect(controller.list.contains('old_0'), isFalse);
  });

  test('list stays within bounds when under maxListSize', () async {
    Get.put(SettingsService());
    final pages = <List<String>>[
      List.generate(10, (i) => 'item_$i'),
    ];
    final controller = Get.put(TestController(pages));
    controller.maxListSize = 200;

    await controller.loadData();

    expect(controller.list.length, 10);
  });
}
