import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/common/services/settings_service.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';

/// Creates a SettingsService without triggering onInit (which needs platform plugins).
/// We call onInit manually only for tests that need it.
SettingsService _createServiceWithoutInit() {
  // Use Get.create instead of Get.put to avoid calling onInit
  // But Get.create doesn't work for this. Instead, register without lifecycle.
  final svc = SettingsService();
  // Register in Get without calling onStart/onInit
  Get.put<SettingsService>(svc, permanent: false);
  return svc;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUp(() async {
    Get.reset();
    tempDir = await Directory.systemTemp.createTemp('settings_test_');
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

  group('cachedBackgroundFileImage', () {
    test('returns null when currentBoxImage is empty', () {
      final service = _createServiceWithoutInit();
      service.currentBoxImage.value = '';
      expect(service.cachedBackgroundFileImage, isNull);
    });

    test('returns null when path looks like base64 (not yet migrated)', () {
      final service = _createServiceWithoutInit();
      service.currentBoxImage.value = 'a' * 600;
      expect(service.cachedBackgroundFileImage, isNull);
    });

    test('returns null when file does not exist', () {
      final service = _createServiceWithoutInit();
      service.currentBoxImage.value = '/nonexistent/path/bg.jpg';
      expect(service.cachedBackgroundFileImage, isNull);
    });

    test('returns FileImage when file exists', () async {
      final service = _createServiceWithoutInit();
      final file = File('${tempDir.path}/bg.jpg');
      await file.writeAsBytes([0xFF, 0xD8, 0xFF, 0xE0]);

      service.currentBoxImage.value = file.path;
      final result = service.cachedBackgroundFileImage;
      expect(result, isNotNull);
      expect(result, isA<FileImage>());
    });

    test('caches FileImage for same path', () async {
      final service = _createServiceWithoutInit();
      final file = File('${tempDir.path}/bg.jpg');
      await file.writeAsBytes([0xFF, 0xD8, 0xFF, 0xE0]);

      service.currentBoxImage.value = file.path;
      final first = service.cachedBackgroundFileImage;
      final second = service.cachedBackgroundFileImage;
      expect(identical(first, second), isTrue);
    });

    test('returns new FileImage when path changes', () async {
      final service = _createServiceWithoutInit();
      final file1 = File('${tempDir.path}/bg1.jpg');
      final file2 = File('${tempDir.path}/bg2.jpg');
      await file1.writeAsBytes([0xFF, 0xD8]);
      await file2.writeAsBytes([0xFF, 0xD8]);

      service.currentBoxImage.value = file1.path;
      final first = service.cachedBackgroundFileImage;

      service.currentBoxImage.value = file2.path;
      final second = service.cachedBackgroundFileImage;
      expect(identical(first, second), isFalse);
    });
  });

  group('wallpaper migration', () {
    test('migrateBase64Wallpaper does not crash when path is empty', () async {
      await HivePrefUtil.setString('currentBoxImage', '');
      final service = _createServiceWithoutInit();
      expect(service.currentBoxImage.value, isEmpty);
    });

    test('migrateBase64Wallpaper skips short value (already a path)', () async {
      await HivePrefUtil.setString('currentBoxImage', '/some/path/bg.jpg');
      final service = _createServiceWithoutInit();
      expect(service.currentBoxImage.value, '/some/path/bg.jpg');
    });
  });

  group('configuration defaults', () {
    test('maxConcurrentRefresh defaults to 3', () {
      final service = _createServiceWithoutInit();
      expect(service.maxConcurrentRefresh.value, equals(3));
    });
  });

  group('favorite room management', () {
    test('addRoom adds a room to favorites', () {
      final service = _createServiceWithoutInit();
      final room = LiveRoom(roomId: '123', platform: 'bilibili', title: 'Test');
      final result = service.addRoom(room);
      expect(result, isTrue);
      expect(service.favoriteRooms.length, equals(1));
      expect(service.favoriteRooms.first.roomId, equals('123'));
    });

    test('addRoom returns false for duplicate', () {
      final service = _createServiceWithoutInit();
      final room = LiveRoom(roomId: '123', platform: 'bilibili', title: 'Test');
      service.addRoom(room);
      final result = service.addRoom(room);
      expect(result, isFalse);
      expect(service.favoriteRooms.length, equals(1));
    });

    test('removeRoom removes a room from favorites', () {
      final service = _createServiceWithoutInit();
      final room = LiveRoom(roomId: '123', platform: 'bilibili', title: 'Test');
      service.addRoom(room);
      final result = service.removeRoom(room);
      expect(result, isTrue);
      expect(service.favoriteRooms.length, equals(0));
    });

    test('updateRoom updates existing room in favorites', () {
      final service = _createServiceWithoutInit();
      final room = LiveRoom(roomId: '123', platform: 'bilibili', title: 'Old Title');
      service.addRoom(room);

      final updated = LiveRoom(roomId: '123', platform: 'bilibili', title: 'New Title');
      final result = service.updateRoom(updated);
      expect(result, isTrue);
      expect(service.favoriteRooms.first.title, equals('New Title'));
    });

    test('isFavorite correctly identifies favorited rooms', () {
      final service = _createServiceWithoutInit();
      final room = LiveRoom(roomId: '123', platform: 'bilibili', title: 'Test');
      expect(service.isFavorite(room), isFalse);
      service.addRoom(room);
      expect(service.isFavorite(room), isTrue);
    });
  });

  group('debounce behavior', () {
    test('rapid favoriteRooms changes persist after debounce', () async {
      final service = _createServiceWithoutInit();

      // Add multiple rooms rapidly
      for (int i = 0; i < 5; i++) {
        service.favoriteRooms.add(
          LiveRoom(roomId: '$i', platform: 'test', title: 'Room $i'),
        );
      }

      // Wait for debounce (500ms) to fire
      await Future.delayed(const Duration(milliseconds: 600));

      // Verify the data was persisted
      final saved = HivePrefUtil.getStringList('favoriteRooms');
      expect(saved, isNotNull);
      expect(saved!.length, equals(5));

      // Clean up
      service.favoriteRooms.clear();
      await Future.delayed(const Duration(milliseconds: 600));
    });
  });

  group('history management', () {
    test('addRoomToHistory caps at around 50 entries', () {
      final service = _createServiceWithoutInit();
      for (int i = 0; i < 55; i++) {
        service.addRoomToHistory(
          LiveRoom(roomId: '$i', platform: 'test', title: 'Room $i'),
        );
      }
      // addRoomToHistory trims to 50 then inserts, so max is 51
      expect(service.historyRooms.length, lessThanOrEqualTo(51));
      // Most recent should be first
      expect(service.historyRooms.first.roomId, equals('54'));
    });

    test('addRoomToHistory moves duplicate to front', () {
      final service = _createServiceWithoutInit();
      service.addRoomToHistory(LiveRoom(roomId: '1', platform: 'test', title: 'Room 1'));
      service.addRoomToHistory(LiveRoom(roomId: '2', platform: 'test', title: 'Room 2'));
      service.addRoomToHistory(LiveRoom(roomId: '1', platform: 'test', title: 'Room 1 Updated'));

      expect(service.historyRooms.length, equals(2));
      expect(service.historyRooms.first.roomId, equals('1'));
      expect(service.historyRooms.first.title, equals('Room 1 Updated'));
    });
  });
}
