import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/models/live_room.dart';

void main() {
  group('LiveRoom.safeFromJsonList', () {
    test('parses valid rooms correctly', () {
      final rooms = [
        LiveRoom(roomId: '1', platform: 'bilibili', title: 'Room 1', liveStatus: LiveStatus.live),
        LiveRoom(roomId: '2', platform: 'huya', title: 'Room 2', liveStatus: LiveStatus.offline),
      ];
      final jsonStrings = rooms.map((r) => jsonEncode(r.toJson())).toList();

      final result = LiveRoom.safeFromJsonList(jsonStrings);

      expect(result.length, equals(2));
      expect(result[0].roomId, equals('1'));
      expect(result[0].title, equals('Room 1'));
      expect(result[0].liveStatus, equals(LiveStatus.live));
      expect(result[1].roomId, equals('2'));
      expect(result[1].platform, equals('huya'));
    });

    test('skips corrupted JSON entries', () {
      final validRoom = LiveRoom(roomId: '1', platform: 'bilibili', title: 'Valid');
      final jsonStrings = [
        jsonEncode(validRoom.toJson()),
        'this is not valid json{{{' + '}',
        '{"broken": "json"',
      ];

      final result = LiveRoom.safeFromJsonList(jsonStrings);

      expect(result.length, equals(1));
      expect(result[0].roomId, equals('1'));
      expect(result[0].title, equals('Valid'));
    });

    test('handles empty list', () {
      final result = LiveRoom.safeFromJsonList([]);
      expect(result, isEmpty);
    });

    test('handles all corrupted entries', () {
      final jsonStrings = [
        'not json at all',
        '{"incomplete": true',
        '',
      ];

      final result = LiveRoom.safeFromJsonList(jsonStrings);
      expect(result, isEmpty);
    });

    test('preserves liveStatus through round-trip', () {
      final room = LiveRoom(
        roomId: '42',
        platform: 'bilibili',
        title: 'Live Room',
        liveStatus: LiveStatus.live,
        nick: 'Streamer',
      );
      final jsonStr = jsonEncode(room.toJson());
      final result = LiveRoom.safeFromJsonList([jsonStr]);

      expect(result.length, equals(1));
      expect(result[0].liveStatus, equals(LiveStatus.live));
      expect(result[0].roomId, equals('42'));
      expect(result[0].nick, equals('Streamer'));
    });

    test('preserves link field through round-trip', () {
      final room = LiveRoom(
        roomId: '1',
        platform: 'bilibili',
        link: 'https://live.bilibili.com/123',
        title: 'Test',
      );
      final jsonStr = jsonEncode(room.toJson());
      final result = LiveRoom.safeFromJsonList([jsonStr]);

      expect(result[0].link, equals('https://live.bilibili.com/123'));
    });

    test('liveStatus offline survives round-trip', () {
      final room = LiveRoom(
        roomId: '1',
        platform: 'bilibili',
        liveStatus: LiveStatus.offline,
      );
      final jsonStr = jsonEncode(room.toJson());
      final result = LiveRoom.safeFromJsonList([jsonStr]);

      expect(result[0].liveStatus, equals(LiveStatus.offline));
    });

    test('multiple rooms with mixed validity', () {
      final valid1 = LiveRoom(roomId: '1', platform: 'bilibili', title: 'Valid 1');
      final valid2 = LiveRoom(roomId: '2', platform: 'huya', title: 'Valid 2');
      final jsonStrings = [
        jsonEncode(valid1.toJson()),
        'CORRUPTED',
        jsonEncode(valid2.toJson()),
        '{"also": "corrupted"',
      ];

      final result = LiveRoom.safeFromJsonList(jsonStrings);

      expect(result.length, equals(2));
      expect(result[0].roomId, equals('1'));
      expect(result[1].roomId, equals('2'));
    });
  });

  group('LiveRoom.toJson', () {
    test('includes link field', () {
      final room = LiveRoom(
        roomId: '1',
        platform: 'bilibili',
        link: 'https://example.com',
      );
      final json = room.toJson();

      expect(json['link'], equals('https://example.com'));
    });

    test('excludes runtime-only fields', () {
      final room = LiveRoom(
        roomId: '1',
        platform: 'bilibili',
        data: {'key': 'value'},
        danmakuData: 'some danmaku data',
      );
      final json = room.toJson();

      expect(json.containsKey('data'), isFalse);
      expect(json.containsKey('danmakuData'), isFalse);
    });

    test('liveStatus is saved as index', () {
      final room = LiveRoom(roomId: '1', liveStatus: LiveStatus.live);
      final json = room.toJson();

      expect(json['liveStatus'], equals(0)); // LiveStatus.live.index == 0
    });
  });

  group('LiveRoom.fromJson', () {
    test('defaults liveStatus to unknown for missing value', () {
      final json = {'roomId': '1', 'platform': 'test'};
      final room = LiveRoom.fromJson(json);

      // Missing liveStatus key => firstWhere returns orElse => LiveStatus.unknown
      expect(room.liveStatus, equals(LiveStatus.unknown));
    });

    test('parses liveStatus correctly', () {
      final json = {'roomId': '1', 'liveStatus': 0}; // 0 = LiveStatus.live
      final room = LiveRoom.fromJson(json);

      expect(room.liveStatus, equals(LiveStatus.live));
    });

    test('handles null fields gracefully', () {
      final json = <String, dynamic>{
        'roomId': '1',
        'title': null,
        'nick': null,
        'liveStatus': null,
      };
      final room = LiveRoom.fromJson(json);

      expect(room.roomId, equals('1'));
      expect(room.title, equals(''));
      expect(room.nick, equals(''));
      expect(room.liveStatus, equals(LiveStatus.unknown)); // null index => unknown
    });
  });
}
