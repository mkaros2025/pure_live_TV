import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pure_live/initialized.dart';
import 'package:pure_live/main.dart';
import 'package:pure_live/common/services/settings_service.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/get/get.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationDocumentsDirectory') return Directory.systemTemp.path;
        if (methodCall.method == 'getApplicationSupportDirectory') return Directory.systemTemp.path;
        if (methodCall.method == 'getTemporaryDirectory') return Directory.systemTemp.path;
        return null;
      },
    );
  });

  testWidgets('full app smoke test', (tester) async {
    // Initialize and skip agreement page
    await AppInitializer().initialize();
    HivePrefUtil.setBool('isFirstInApp', false);

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // 1. App launched on home page
    expect(find.text('纯粹直播'), findsOneWidget);
    expect(Get.isRegistered<SettingsService>(), isTrue);

    // 2. Image cache limit
    expect(PaintingBinding.instance.imageCache.maximumSizeBytes, equals(20 * 1024 * 1024));

    // 3. Home page elements
    expect(find.text('直播关注'), findsOneWidget);
    expect(find.text('热门直播'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);

    // 4. SettingsService lazy loading
    final settings = Get.find<SettingsService>();
    expect(settings.themeModeName.value, isNotNull);
    expect(settings.languageName.value, isNotNull);
    expect(settings.videoPlayerIndex.value, isNotNull);

    // 5. Navigate to settings
    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    expect(find.text('自动更新关注'), findsOneWidget);
    expect(find.text('首选清晰度'), findsOneWidget);
    expect(find.text('播放器设置'), findsOneWidget);

    // 6. Back to home
    await tester.tap(find.text('返回'));
    await tester.pumpAndSettle();
    expect(find.text('纯粹直播'), findsOneWidget);

    // 7. Navigate to favorites
    await tester.tap(find.text('直播关注'));
    await tester.pumpAndSettle();
    expect(find.text('已开播'), findsOneWidget);
    expect(find.text('未开播'), findsOneWidget);

    // 8. Back to home
    await tester.tap(find.text('返回'));
    await tester.pumpAndSettle();
    expect(find.text('纯粹直播'), findsOneWidget);

    // 9. Navigate to popular
    await tester.tap(find.text('热门直播'));
    await tester.pumpAndSettle();
    expect(find.text('返回'), findsOneWidget);

    // 10. Back to home
    await tester.tap(find.text('返回'));
    await tester.pumpAndSettle();
    expect(find.text('纯粹直播'), findsOneWidget);

    // 11. Settings changes work
    final original = settings.autoRefreshTime.value;
    settings.autoRefreshTime.value = original + 1;
    expect(settings.autoRefreshTime.value, equals(original + 1));
  });
}
