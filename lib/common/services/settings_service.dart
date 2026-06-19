import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/app/app_focus_node.dart';
import 'package:stop_watch_timer/stop_watch_timer.dart';
import 'package:pure_live/common/consts/app_consts.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:pure_live/player/utils/player_consts.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/common/utils/app_path_manager.dart';
import 'package:pure_live/core/iptv/services/auto_sync_scheduler.dart';
import 'package:pure_live/common/services/bilibili_account_service.dart';

class SettingsService extends GetxController {
  // ========== 懒加载基础设施 ==========
  final Map<String, dynamic> _lazyRxCache = {};

  /// 创建懒加载 Rx 变量：首次访问时从 Hive 读取，并自动注册写入监听
  Rx<T> _lazy<T>(String key, T defaultValue, T? Function(String) readFn, {void Function(T)? onWrite}) {
    return _lazyRxCache.putIfAbsent(key, () {
      final T val = readFn(key) ?? defaultValue;
      final rx = Rx<T>(val);
      if (onWrite != null) {
        rx.listen(onWrite);
      }
      return rx;
    }) as Rx<T>;
  }

  // 懒加载 getter：首次访问 .value 时才读 Hive + 注册写入监听
  Rx<String> get themeModeName => _lazy<String>('themeMode', "System", HivePrefUtil.getString,
      onWrite: (v) => HivePrefUtil.setString('themeMode', v));
  Rx<String> get themeColorSwitch => _lazy<String>('themeColorSwitch', Colors.red.hex, HivePrefUtil.getString,
      onWrite: (v) => HivePrefUtil.setString('themeColorSwitch', v));
  Rx<bool> get enableDynamicTheme => _lazy<bool>('enableDynamicTheme', false, HivePrefUtil.getBool,
      onWrite: (v) { HivePrefUtil.setBool('enableDynamicTheme', v); update(['myapp']); });
  Rx<String> get languageName => _lazy<String>('language', "简体中文", HivePrefUtil.getString,
      onWrite: (v) => HivePrefUtil.setString('language', v));
  Rx<int> get autoRefreshTime => _lazy<int>('autoRefreshTime', 3, HivePrefUtil.getInt,
      onWrite: (v) => HivePrefUtil.setInt('autoRefreshTime', v));
  Rx<int> get autoShutDownTime => _lazy<int>('autoShutDownTime', 120, HivePrefUtil.getInt,
      onWrite: (v) => HivePrefUtil.setInt('autoShutDownTime', v));
  Rx<bool> get enableAutoShutDownTime => _lazy<bool>('enableAutoShutDownTime', false, HivePrefUtil.getBool,
      onWrite: (v) => HivePrefUtil.setBool('enableAutoShutDownTime', v));
  Rx<int> get lastRefreshTime => _lazy<int>('lastRefreshTime', 0, HivePrefUtil.getInt,
      onWrite: (v) => HivePrefUtil.setInt('lastRefreshTime', v));
  Rx<bool> get enableDenseFavorites => _lazy<bool>('enableDenseFavorites', false, HivePrefUtil.getBool,
      onWrite: (v) => HivePrefUtil.setBool('enableDenseFavorites', v));
  Rx<bool> get enableBackgroundPlay => _lazy<bool>('enableBackgroundPlay', false, HivePrefUtil.getBool,
      onWrite: (v) => HivePrefUtil.setBool('enableBackgroundPlay', v));
  Rx<bool> get enableScreenKeepOn => _lazy<bool>('enableScreenKeepOn', true, HivePrefUtil.getBool,
      onWrite: (v) => HivePrefUtil.setBool('enableScreenKeepOn', v));
  Rx<bool> get enableAutoCheckUpdate => _lazy<bool>('enableAutoCheckUpdate', true, HivePrefUtil.getBool,
      onWrite: (v) => HivePrefUtil.setBool('enableAutoCheckUpdate', v));
  Rx<bool> get enableFullScreenDefault => _lazy<bool>('enableFullScreenDefault', false, HivePrefUtil.getBool,
      onWrite: (v) => HivePrefUtil.setBool('enableFullScreenDefault', v));
  Rx<int> get maxConcurrentRefresh => _lazy<int>('maxConcurrentRefresh', 3, HivePrefUtil.getInt,
      onWrite: (v) => HivePrefUtil.setInt('maxConcurrentRefresh', v));
  Rx<bool> get autoRefreshFavorite => _lazy<bool>('autoRefreshFavorite', true, HivePrefUtil.getBool,
      onWrite: (v) => HivePrefUtil.setBool('autoRefreshFavorite', v));
  Rx<int> get autoRefreshInterval => _lazy<int>('autoRefreshInterval', 10, HivePrefUtil.getInt,
      onWrite: (v) => HivePrefUtil.setInt('autoRefreshInterval', v));
  Rx<bool> get isFirstInApp => _lazy<bool>('isFirstInApp', true, HivePrefUtil.getBool,
      onWrite: (v) => HivePrefUtil.setBool('isFirstInApp', false));
  Rx<int> get videoFitIndex => _lazy<int>('videoFitIndex', 0, HivePrefUtil.getInt,
      onWrite: (v) => HivePrefUtil.setInt('videoFitIndex', v));
  Rx<int> get videoPlayerIndex => _lazy<int>('videoPlayerIndex', 0, HivePrefUtil.getInt,
      onWrite: (v) => HivePrefUtil.setInt('videoPlayerIndex', v));
  Rx<bool> get useHardStopOnExit => _lazy<bool>('useHardStopOnExit', true, HivePrefUtil.getBool,
      onWrite: (v) => HivePrefUtil.setBool('useHardStopOnExit', v));
  Rx<bool> get enableCodec => _lazy<bool>('enableCodec', true, HivePrefUtil.getBool,
      onWrite: (v) => HivePrefUtil.setBool('enableCodec', v));
  Rx<double> get audioDelay => _lazy<double>('audioDelay', 0.0, HivePrefUtil.getDouble,
      onWrite: (v) => HivePrefUtil.setDouble('audioDelay', v));
  Rx<bool> get playerCompatMode => _lazy<bool>('playerCompatMode', false, HivePrefUtil.getBool,
      onWrite: (v) => HivePrefUtil.setBool('playerCompatMode', v));
  Rx<String> get preferResolution => _lazy<String>('preferResolution', PlayerConsts.resolutions[0], HivePrefUtil.getString,
      onWrite: (v) => HivePrefUtil.setString('preferResolution', v));
  Rx<String> get preferPlatform => _lazy<String>('preferPlatform', AppConsts.platforms[0], HivePrefUtil.getString,
      onWrite: (v) => HivePrefUtil.setString('preferPlatform', v));
  Rx<double> get volume => _lazy<double>('volume', 0.5, HivePrefUtil.getDouble,
      onWrite: (v) => HivePrefUtil.setDouble('volume', v));
  Rx<bool> get customPlayerOutput => _lazy<bool>('customPlayerOutput', false, HivePrefUtil.getBool,
      onWrite: (v) => HivePrefUtil.setBool('customPlayerOutput', v));
  Rx<String> get videoOutputDriver => _lazy<String>('videoOutputDriver', "gpu", HivePrefUtil.getString,
      onWrite: (v) => HivePrefUtil.setString('videoOutputDriver', v));
  Rx<String> get audioOutputDriver => _lazy<String>('audioOutputDriver', "auto", HivePrefUtil.getString,
      onWrite: (v) => HivePrefUtil.setString('audioOutputDriver', v));
  Rx<String> get videoHardwareDecoder => _lazy<String>('videoHardwareDecoder', "auto", HivePrefUtil.getString,
      onWrite: (v) => HivePrefUtil.setString('videoHardwareDecoder', v));
  Rx<bool> get hideDanmaku => _lazy<bool>('hideDanmaku', false, HivePrefUtil.getBool,
      onWrite: (v) => HivePrefUtil.setBool('hideDanmaku', v));
  Rx<double> get danmakuArea => _lazy<double>('danmakuArea', 1.0, HivePrefUtil.getDouble,
      onWrite: (v) => HivePrefUtil.setDouble('danmakuArea', v));
  Rx<double> get danmakuTopArea => _lazy<double>('danmakuTopArea', 0.0, HivePrefUtil.getDouble,
      onWrite: (v) => HivePrefUtil.setDouble('danmakuTopArea', v));
  Rx<double> get danmakuBottomArea => _lazy<double>('danmakuBottomArea', 0.5, HivePrefUtil.getDouble,
      onWrite: (v) => HivePrefUtil.setDouble('danmakuBottomArea', v));
  Rx<double> get danmakuSpeed => _lazy<double>('danmakuSpeed', 8.0, HivePrefUtil.getDouble,
      onWrite: (v) => HivePrefUtil.setDouble('danmakuSpeed', v));
  Rx<double> get danmakuFontSize => _lazy<double>('danmakuFontSize', 16.0, HivePrefUtil.getDouble,
      onWrite: (v) => HivePrefUtil.setDouble('danmakuFontSize', v));
  Rx<double> get danmakuFontBorder => _lazy<double>('danmakuFontBorder', 4.0, HivePrefUtil.getDouble,
      onWrite: (v) => HivePrefUtil.setDouble('danmakuFontBorder', v));
  Rx<double> get danmakuOpacity => _lazy<double>('danmakuOpacity', 1.0, HivePrefUtil.getDouble,
      onWrite: (v) => HivePrefUtil.setDouble('danmakuOpacity', v));
  Rx<String> get bilibiliCookie => _lazy<String>('bilibiliCookie', '', HivePrefUtil.getString,
      onWrite: (v) => HivePrefUtil.setString('bilibiliCookie', v));
  Rx<String> get huyaCookie => _lazy<String>('huyaCookie', '', HivePrefUtil.getString,
      onWrite: (v) => HivePrefUtil.setString('huyaCookie', v));
  Rx<String> get douyinCookie => _lazy<String>('douyinCookie', '', HivePrefUtil.getString,
      onWrite: (v) => HivePrefUtil.setString('douyinCookie', v));
  Rx<String> get kuaishouCookie => _lazy<String>('kuaishouCookie', '', HivePrefUtil.getString,
      onWrite: (v) => HivePrefUtil.setString('kuaishouCookie', v));
  Rx<bool> get dontAskExit => _lazy<bool>('dontAskExit', false, HivePrefUtil.getBool,
      onWrite: (v) => HivePrefUtil.setBool('dontAskExit', v));
  Rx<String> get exitChoose => _lazy<String>('exitChoose', '', HivePrefUtil.getString,
      onWrite: (v) => HivePrefUtil.setString('exitChoose', v));
  Rx<String> get webPort => _lazy<String>('webPort', "9527", HivePrefUtil.getString,
      onWrite: (v) => HivePrefUtil.setString('webPort', v));
  Rx<String> get backupDirectory => _lazy<String>('backupDirectory', '', HivePrefUtil.getString,
      onWrite: (v) => HivePrefUtil.setString('backupDirectory', v));
  Rx<String> get m3uDirectory => _lazy<String>('m3uDirectory', 'm3uDirectory', HivePrefUtil.getString,
      onWrite: (v) => HivePrefUtil.setString('m3uDirectory', v));
  Rx<String> get selectedSourceName => _lazy<String>('selectedSourceName', '', HivePrefUtil.getString,
      onWrite: (v) => HivePrefUtil.setString('selectedSourceName', v));
  Rx<String> get selectedSourceId => _lazy<String>('selectedSourceId', '', HivePrefUtil.getString,
      onWrite: (v) => HivePrefUtil.setString('selectedSourceId', v));
  Rx<bool> get isAutoSyncEnabled => _lazy<bool>('isAutoSyncEnabled', false, HivePrefUtil.getBool,
      onWrite: (v) => HivePrefUtil.setBool('isAutoSyncEnabled', v));
  Rx<int> get autoSyncHoursInterval => _lazy<int>('autoSyncHoursInterval', 24, HivePrefUtil.getInt,
      onWrite: (v) => HivePrefUtil.setInt('autoSyncHoursInterval', v));
  Rx<String> get customIptvUserAgent => _lazy<String>('customIptvUserAgent', '', HivePrefUtil.getString,
      onWrite: (v) => HivePrefUtil.setString('customIptvUserAgent', v));

  // ========== 以下变量保持直接初始化（需要变异方法或非 Hive 来源） ==========
  final Map<ColorSwatch<Object>, String> colorsNameMap = AppConsts.themeColors.map(
    (key, value) => MapEntry(ColorTools.createPrimarySwatch(value), key),
  );
  final StopWatchTimer _stopWatchTimer = StopWatchTimer(mode: StopWatchMode.countDown);

  // 列表类型（需要 .add() / []= 等变异方法）
  final shieldList = ((HivePrefUtil.getStringList('shieldList') ?? [])).obs;
  final hotAreasList = ((HivePrefUtil.getStringList('hotAreasList') ?? AppConsts.supportSites)).obs;
  final favoriteRooms =
      ((HivePrefUtil.getStringList('favoriteRooms') ?? []).map((e) => LiveRoom.fromJson(jsonDecode(e))).toList()).obs;
  final historyRooms =
      ((HivePrefUtil.getStringList('historyRooms') ?? []).map((e) => LiveRoom.fromJson(jsonDecode(e))).toList()).obs;
  final favoriteAreas =
      ((HivePrefUtil.getStringList('favoriteAreas') ?? []).map((e) => LiveArea.fromJson(jsonDecode(e))).toList()).obs;

  // 非 Hive 来源或需要立即响应的变量
  final currentPlayList = [].obs;
  final currentPlayListNodeIndex = 0.obs;
  final currentBoxImage = (HivePrefUtil.getString('currentBoxImage') ?? "").obs;
  final currentBoxImageIndex = (HivePrefUtil.getInt('currentBoxImageIndex') ?? 0).obs;
  final backgroundImageFitIndex = (HivePrefUtil.getInt('backgroundImageFitIndex') ?? 2).obs;
  final webPortEnable = false.obs;
  final httpErrorMsg = ''.obs;
  final ScrollController scrollController = ScrollController();
  final routeChangeType = RouteChangeType.push.obs;
  final currentRouteName = ''.obs;

  // 焦点节点
  final AppFocusNode maxConcurrentRefreshNode = AppFocusNode();
  final AppFocusNode autoRefreshTimeNode = AppFocusNode();
  final AppFocusNode backFocusNode = AppFocusNode();
  final AppFocusNode autoRefreshIntervalNode = AppFocusNode();
  final AppFocusNode preferResolutionNode = AppFocusNode();
  final AppFocusNode videoPlayerNode = AppFocusNode();
  final AppFocusNode enableCodecNode = AppFocusNode();
  final AppFocusNode audioDelayNode = AppFocusNode();
  final AppFocusNode playerCompatModeNode = AppFocusNode();
  final AppFocusNode preferPlatformNode = AppFocusNode();
  final AppFocusNode dataSyncNode = AppFocusNode();
  final AppFocusNode accountNode = AppFocusNode();
  final AppFocusNode platformNode = AppFocusNode();
  final AppFocusNode currentImageNode = AppFocusNode();
  final AppFocusNode currentImageIndexNode = AppFocusNode();
  final AppFocusNode useHardStopOnExitNode = AppFocusNode();

  String? _cachedImagePath;
  FileImage? _cachedFileImage;

  // ========== Debounce 辅助 ==========
  final Map<String, Timer> _debounceTimers = {};
  final Map<String, Future<void> Function()> _pendingWrites = {};

  void _debounceWrite(String key, Future<void> Function() writeOp,
      {Duration delay = const Duration(milliseconds: 500)}) {
    _debounceTimers[key]?.cancel();
    _pendingWrites[key] = writeOp;
    _debounceTimers[key] = Timer(delay, () async {
      await writeOp();
      _debounceTimers.remove(key);
      _pendingWrites.remove(key);
    });
  }

  /// 立即执行所有待写入操作（退出前调用，防止数据丢失）
  Future<void> _flushPendingWrites() async {
    for (final timer in _debounceTimers.values) {
      timer.cancel();
    }
    _debounceTimers.clear();
    for (final writeOp in _pendingWrites.values) {
      await writeOp();
    }
    _pendingWrites.clear();
  }

  // ========== Getter 方法 ==========
  ThemeMode get themeMode => AppConsts.themeModes[themeModeName.value]!;
  Locale get language => AppConsts.languages[languageName.value]!;
  StopWatchTimer get stopWatchTimer => _stopWatchTimer;
  List<String> get resolutionsList => PlayerConsts.resolutions;
  List<BoxFit> get videofitArrary => PlayerConsts.videofitList;
  List<String> get playerlist => PlayerConsts.players;
  FileImage? get cachedBackgroundFileImage {
    if (currentBoxImage.isEmpty) return null;
    final path = currentBoxImage.value;
    // If it looks like base64 (not yet migrated)
    if (path.length > 500) return null;
    // Cache hit: same path, already verified
    if (_cachedImagePath == path) return _cachedFileImage;
    // New path: verify file exists (only once per path change)
    final file = File(path);
    if (!file.existsSync()) return null;
    _cachedImagePath = path;
    _cachedFileImage = FileImage(file);
    return _cachedFileImage;
  }

  // ========== 数据迁移方法 ==========
  Future<void> migrateOldPrefsData() async {
    if (HivePrefUtil.getBool('_migrated_from_sp') == true) {
      return;
    }
    try {
      final allKeys = PrefUtil.prefs.getKeys();
      for (final key in allKeys) {
        final value = PrefUtil.prefs.get(key);
        if (value == null) continue;
        if (value is String) {
          await HivePrefUtil.setString(key, value);
        } else if (value is int) {
          await HivePrefUtil.setInt(key, value);
        } else if (value is bool) {
          await HivePrefUtil.setBool(key, value);
        } else if (value is double) {
          await HivePrefUtil.setDouble(key, value);
        } else if (value is List<String>) {
          await HivePrefUtil.setStringList(key, value);
        }
      }

      await HivePrefUtil.setBool('_migrated_from_sp', true);
      log('旧 SharedPreferences 数据迁移到 Hive 完成！', name: 'SettingsService');
    } catch (e) {
      log('数据迁移失败: $e', name: 'SettingsService');
    }
  }

  // ========== 初始化生命周期方法 ==========
  @override
  void onInit() {
    super.onInit();
    Future.delayed(const Duration(seconds: 3), () {
      AutoSyncScheduler.instance.checkAndExecuteAutoSync();
      AutoSyncScheduler.instance.loadHotResources();
      AutoSyncScheduler.instance.loadDefaultEpgResources();
    });
    // 执行旧数据迁移
    migrateOldPrefsData().then((_) {
      update(['migrate_complete']);
    });

    // 注册列表类型和特殊变量的写入监听（这些不是懒加载的）
    _registerDirectFieldListeners();
    _migrateBase64Wallpaper();
  }

  /// 注册直接字段（列表、特殊变量）的 Hive 写入监听
  void _registerDirectFieldListeners() {
    shieldList.listen((value) {
      _debounceWrite('shieldList', () => HivePrefUtil.setStringList('shieldList', value));
    });
    hotAreasList.listen((value) {
      _debounceWrite('hotAreasList', () => HivePrefUtil.setStringList('hotAreasList', value));
    });
    favoriteRooms.listen((rooms) {
      _debounceWrite('favoriteRooms', () => HivePrefUtil.setStringList(
        'favoriteRooms',
        favoriteRooms.map<String>((e) => jsonEncode(e.toJson())).toList(),
      ));
    });
    favoriteAreas.listen((rooms) {
      _debounceWrite('favoriteAreas', () => HivePrefUtil.setStringList(
        'favoriteAreas',
        favoriteAreas.map<String>((e) => jsonEncode(e.toJson())).toList(),
      ));
    });
    historyRooms.listen((rooms) {
      _debounceWrite('historyRooms', () => HivePrefUtil.setStringList(
        'historyRooms',
        historyRooms.map<String>((e) => jsonEncode(e.toJson())).toList(),
      ));
    });
    currentBoxImage.listen((value) {
      HivePrefUtil.setString('currentBoxImage', value);
    });
    currentBoxImageIndex.listen((value) {
      HivePrefUtil.setInt('currentBoxImageIndex', value);
    });
    backgroundImageFitIndex.listen((value) {
      HivePrefUtil.setInt('backgroundImageFitIndex', value);
    });
  }

  void _migrateBase64Wallpaper() async {
    final value = currentBoxImage.value;
    if (value.isEmpty || value.length < 500) return;
    try {
      final bytes = base64Decode(value);
      final imageDir = await AppPathManager().getDir('WALLPAPER');
      final file = File('${imageDir.path}${Platform.pathSeparator}bg.jpg');
      await file.writeAsBytes(bytes);
      currentBoxImage.value = file.path;
    } catch (_) {}
  }

  // ========== 配置修改方法 ==========
  void changeThemeMode(String mode) async {
    themeModeName.value = mode;
    await HivePrefUtil.setString('themeMode', mode);
    Get.changeThemeMode(themeMode);
  }

  void changeLanguage(String value) async {
    languageName.value = value;
    await HivePrefUtil.setString('language', value);
    Get.updateLocale(language);
  }

  void changePlayer(int value) async {
    videoPlayerIndex.value = value;
    await HivePrefUtil.setInt('videoPlayerIndex', value);
  }

  void changePreferResolution(String name) async {
    if (PlayerConsts.resolutions.indexWhere((e) => e == name) != -1) {
      preferResolution.value = name;
      await HivePrefUtil.setString('preferResolution', name);
    }
  }

  void changeAutoRefreshConfig(int minutes) async {
    autoRefreshTime.value = minutes;
    await HivePrefUtil.setInt('autoRefreshTime', minutes);
  }

  void changePreferPlatform(String name) async {
    if (AppConsts.platforms.indexWhere((e) => e == name) != -1) {
      preferPlatform.value = name;
      update(['myapp']);
      await HivePrefUtil.setString('preferPlatform', name);
    }
  }

  BoxFit get currentBoxFit => BoxFit.values[backgroundImageFitIndex.value];

  void setBoxFitIndex(int index) {
    backgroundImageFitIndex.value = index;
  }

  // ========== 图片相关方法 ==========
  Future<void> getImage() async {
    // 1. Get the current source name and base URL
    var selectedSource = AppConsts.currentBoxImageSources[currentBoxImageIndex.value];
    String name = selectedSource.keys.first;
    String url = selectedSource.values.first;

    if (url == "default") {
      currentBoxImage.value = "";
      return;
    }

    Dio dio = Dio();
    String? finalImageUrl;

    try {
      // 2. Handle Wuming API (JSON response)
      if (url.contains('://jkapi.com')) {
        // Find the corresponding apiKey
        var keyMap = AppConsts.wumingApiKeys.firstWhere((element) => element.containsKey(name), orElse: () => {});

        if (keyMap.isNotEmpty) {
          String apiKey = keyMap[name]!;
          // Construct URL with type=json and apiKey
          String requestUrl = "$url${url.contains('?') ? '&' : '?'}type=json&apiKey=$apiKey";

          // First request to get the JSON
          var jsonRes = await dio.get(requestUrl);
          if (jsonRes.statusCode == 200 && jsonRes.data != null) {
            // Extract the URL from the "image_url" key
            finalImageUrl = jsonRes.data['image_url'] ?? jsonRes.data['content'];
          }
        }
      }
      // 3. Handle Alcy (Path-based category)
      else if (url == "https://alcy.cc") {
        var category = ['ycy', 'moez', 'ai', 'ysz', 'ys', 'mp', 'moemp', 'ysmp', 'aimp', 'tx', 'lai', 'xhl', 'bd'];
        finalImageUrl = url + category[math.Random().nextInt(category.length)];
      }
      // 4. Handle other direct image APIs
      else {
        finalImageUrl = url;
      }

      // 5. Download image and save to file
      if (finalImageUrl != null && finalImageUrl.isNotEmpty) {
        var response = await dio.get(
          finalImageUrl,
          options: Options(
            responseType: ResponseType.bytes,
            headers: {
              'User-Agent':
                  "Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.5845.97 Safari/537.36 Core/1.116.567.400 QQBrowser/19.7.6764.400",
            },
          ),
        );

        if (response.data != null && response.data.length > 30) {
          final imageDir = await AppPathManager().getDir('WALLPAPER');
          final file = File('${imageDir.path}${Platform.pathSeparator}bg.jpg');
          await file.writeAsBytes(response.data);

          _cachedFileImage = null;
          _cachedImagePath = null;

          currentBoxImage.value = file.path;
        } else {
          ToastUtil.show("The image content is invalid.");
        }
      } else {
        ToastUtil.show("Failed to retrieve a valid image URL.");
      }
    } catch (e) {
      ToastUtil.show("Error: $e");
    }
  }

  Map<dynamic, String> getBoxImageItems() {
    var keys = AppConsts.currentBoxImageSources.map((e) => e.keys.first).toList();
    Map<dynamic, String> map = {};
    for (var i = 0; i < keys.length; i++) {
      map[keys[i]] = keys[i];
    }
    return map;
  }

  // ========== 收藏与历史相关业务方法 ==========
  bool isFavorite(LiveRoom room) {
    return favoriteRooms.any((element) => element.roomId == room.roomId);
  }

  LiveRoom getLiveRoomByRoomId(String roomId, String platform) {
    if (!favoriteRooms.any((element) => element.roomId == roomId && element.platform == platform) &&
        !historyRooms.any((element) => element.roomId == roomId && element.platform == platform)) {
      return LiveRoom(roomId: roomId, platform: platform, liveStatus: LiveStatus.unknown);
    }
    return favoriteRooms.firstWhere(
      (element) => element.roomId == roomId && element.platform == platform,
      orElse: () => historyRooms.firstWhere((element) => element.roomId == roomId && element.platform == platform),
    );
  }

  bool addRoom(LiveRoom room) {
    if (favoriteRooms.any((element) => element.roomId == room.roomId)) {
      return false;
    }
    favoriteRooms.add(room);
    return true;
  }

  void addShieldList(String value) {
    shieldList.add(value);
  }

  void removeShieldList(int value) {
    shieldList.removeAt(value);
  }

  bool removeRoom(LiveRoom room) {
    if (!favoriteRooms.any((element) => element.roomId == room.roomId)) {
      return false;
    }
    favoriteRooms.remove(room);
    return true;
  }

  bool removeHistoryRoom(LiveRoom room) {
    if (!historyRooms.any((element) => element.roomId == room.roomId)) {
      return false;
    }
    historyRooms.remove(room);
    return true;
  }

  bool updateRoom(LiveRoom room) {
    int idx = favoriteRooms.indexWhere((element) => element.roomId == room.roomId);
    updateRoomInHistory(room);
    if (idx == -1) return false;
    favoriteRooms[idx] = room;
    favoriteRooms.refresh();
    return true;
  }

  void updateRooms(List<LiveRoom> rooms) {
    favoriteRooms.value = rooms;
  }

  bool updateRoomInHistory(LiveRoom room) {
    int idx = historyRooms.indexWhere((element) => element.roomId == room.roomId);
    if (idx == -1) return false;
    historyRooms[idx] = room;
    return true;
  }

  void addRoomToHistory(LiveRoom room) {
    if (historyRooms.any((element) => element.roomId == room.roomId)) {
      historyRooms.remove(room);
    }
    updateRoom(room);
    if (historyRooms.length > 50) {
      historyRooms.removeRange(0, historyRooms.length - 50);
    }
    historyRooms.insert(0, room);
  }

  // ========== 分区收藏相关业务方法 ==========
  bool isFavoriteArea(LiveArea area) {
    return favoriteAreas.any(
      (element) =>
          element.areaId == area.areaId && element.platform == area.platform && element.areaType == area.areaType,
    );
  }

  bool addArea(LiveArea area) {
    if (favoriteAreas.any(
      (element) =>
          element.areaId == area.areaId && element.platform == area.platform && element.areaType == area.areaType,
    )) {
      return false;
    }
    favoriteAreas.add(area);
    return true;
  }

  bool removeArea(LiveArea area) {
    if (!favoriteAreas.any(
      (element) =>
          element.areaId == area.areaId && element.platform == area.platform && element.areaType == area.areaType,
    )) {
      return false;
    }
    favoriteAreas.remove(area);
    return true;
  }

  // ========== 备份与恢复相关方法 ==========
  bool backup(File file) {
    try {
      final json = toJson();
      file.writeAsStringSync(jsonEncode(json));
    } catch (e) {
      return false;
    }
    return true;
  }

  bool recover(File file) {
    try {
      final json = file.readAsStringSync();
      fromJson(jsonDecode(json));
    } catch (e) {
      log(e.toString(), name: 'recover');
      return false;
    }
    return true;
  }

  // ========== Bilibili账号相关方法 ==========
  void setBilibiliCookit(String cookie) {
    final BiliBiliAccountService biliAccountService = Get.find<BiliBiliAccountService>();
    if (biliAccountService.cookie.isEmpty || biliAccountService.uid == 0) {
      biliAccountService.resetCookie(cookie);
      biliAccountService.loadUserInfo();
    }
  }

  // ========== JSON序列化/反序列化 ==========
  void fromJson(Map<String, dynamic> json) async {
    // 1. 定義內部輔助解析函數，處理兼容性邏輯
    List<T> safeParseList<T>(dynamic data, T Function(Map<String, dynamic>) fromJsonFactory) {
      if (data == null || data is! List) return [];
      return data.map<T>((e) {
        if (e is Map<String, dynamic>) {
          return fromJsonFactory(e);
        } else if (e is String) {
          try {
            return fromJsonFactory(jsonDecode(e));
          } catch (err) {
            debugPrint("解析單項數據失敗: $err");
          }
        }
        return fromJsonFactory({}); // 備選方案
      }).toList();
    }

    // 2. 解析列表數據 (自動處理 String/Map 兼容)
    favoriteRooms.value = safeParseList<LiveRoom>(json['favoriteRooms'], (m) => LiveRoom.fromJson(m));
    favoriteAreas.value = safeParseList<LiveArea>(json['favoriteAreas'], (m) => LiveArea.fromJson(m));
    // 3. 解析普通列表與基本類型
    shieldList.value = (json['shieldList'] as List?)?.map((e) => e.toString()).toList() ?? [];
    hotAreasList.value = (json['hotAreasList'] as List?)?.map((e) => e.toString()).toList() ?? [];
    themeModeName.value = AppConsts.themeModes.keys.firstWhere((e) => e == json['themeMode'], orElse: () => "System");
    enableDynamicTheme.value = json['enableDynamicTheme'] ?? false;
    enableDenseFavorites.value = json['enableDenseFavorites'] ?? false;
    languageName.value = AppConsts.languages.keys.firstWhere((e) => e == json['languageName'], orElse: () => "简体中文");
    preferResolution.value = PlayerConsts.resolutions.firstWhere(
      (e) => e == json['preferResolution'],
      orElse: () => PlayerConsts.resolutions[0],
    );
    preferPlatform.value = AppConsts.platforms.firstWhere(
      (e) => e == json['preferPlatform'],
      orElse: () => AppConsts.platforms[0],
    );
    bilibiliCookie.value = json['bilibiliCookie'] ?? '';
    huyaCookie.value = json['huyaCookie'] ?? '';
    douyinCookie.value = json['douyinCookie'] ?? '';
    themeColorSwitch.value = json['themeColorSwitch'] ?? Colors.blue.hex;
    webPort.value = json['webPort'] ?? '9527';
    customIptvUserAgent.value = json['customIptvUserAgent'] ?? '';

    // 4. 恢復備份時同步到 Hive
    // 使用 Future.wait 並行執行所有異步操作，效率更高
    await Future.wait([
      HivePrefUtil.setString('themeMode', themeModeName.value),
      HivePrefUtil.setBool('enableDynamicTheme', enableDynamicTheme.value),
      HivePrefUtil.setBool('enableDenseFavorites', enableDenseFavorites.value),
      HivePrefUtil.setString('language', languageName.value),
      HivePrefUtil.setString('preferResolution', preferResolution.value),
      HivePrefUtil.setString('preferPlatform', preferPlatform.value),
      HivePrefUtil.setString('bilibiliCookie', bilibiliCookie.value),
      HivePrefUtil.setString('huyaCookie', huyaCookie.value),
      HivePrefUtil.setString('douyinCookie', douyinCookie.value),
      HivePrefUtil.setString('kuaishouCookie', kuaishouCookie.value),
      HivePrefUtil.setString('themeColorSwitch', themeColorSwitch.value),
      HivePrefUtil.setString('webPort', webPort.value),
      HivePrefUtil.setString('customIptvUserAgent', customIptvUserAgent.value),

      // 注意：確保傳入的是 List<String> 類型
      HivePrefUtil.setStringList('shieldList', shieldList.value),
      HivePrefUtil.setStringList('hotAreasList', hotAreasList.value),
      // 保存至 Hive 時，維持 StringList 格式以確保底層兼容性
      HivePrefUtil.setStringList('favoriteRooms', favoriteRooms.value.map((e) => jsonEncode(e.toJson())).toList()),
      HivePrefUtil.setStringList('favoriteAreas', favoriteAreas.value.map((e) => jsonEncode(e.toJson())).toList()),
    ]);
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['favoriteRooms'] = favoriteRooms.map<String>((e) => jsonEncode(e.toJson())).toList();
    json['favoriteAreas'] = favoriteAreas.map<String>((e) => jsonEncode(e.toJson())).toList();
    json['themeMode'] = themeModeName.value;
    json['autoRefreshTime'] = autoRefreshTime.value;
    json['autoShutDownTime'] = autoShutDownTime.value;
    json['enableAutoShutDownTime'] = enableAutoShutDownTime.value;
    json['enableDynamicTheme'] = enableDynamicTheme.value;
    json['enableDenseFavorites'] = enableDenseFavorites.value;
    json['enableBackgroundPlay'] = enableBackgroundPlay.value;
    json['enableScreenKeepOn'] = enableScreenKeepOn.value;
    json['enableAutoCheckUpdate'] = enableAutoCheckUpdate.value;
    json['enableFullScreenDefault'] = enableFullScreenDefault.value;
    json['maxConcurrentRefresh'] = maxConcurrentRefresh.value;
    json['autoRefreshFavorite'] = autoRefreshFavorite.value;
    json['autoRefreshInterval'] = autoRefreshInterval.value;
    json['preferResolution'] = preferResolution.value;
    json['preferPlatform'] = preferPlatform.value;
    json['languageName'] = languageName.value;
    json['videoFitIndex'] = videoFitIndex.value;
    json['hideDanmaku'] = hideDanmaku.value;
    json['danmakuArea'] = 1.0;
    json['danmakuTopArea'] = danmakuTopArea.value;
    json['danmakuBottomArea'] = danmakuBottomArea.value;
    json['danmakuSpeed'] = danmakuSpeed.value;
    json['danmakuFontSize'] = danmakuFontSize.value;
    json['danmakuFontBorder'] = danmakuFontBorder.value;
    json['danmakuOpacity'] = danmakuOpacity.value;
    json['videoPlayerIndex'] = videoPlayerIndex.value;
    json['useHardStopOnExit'] = useHardStopOnExit.value;
    json['enableCodec'] = enableCodec.value;
    json['audioDelay'] = audioDelay.value;
    json['bilibiliCookie'] = bilibiliCookie.value;
    json['huyaCookie'] = huyaCookie.value;
    json['douyinCookie'] = douyinCookie.value;
    json['kuaishouCookie'] = kuaishouCookie.value;
    json['shieldList'] = shieldList.map<String>((e) => e.toString()).toList();
    json['hotAreasList'] = hotAreasList.map<String>((e) => e.toString()).toList();
    json['themeColorSwitch'] = themeColorSwitch.value;
    json['webPort'] = webPort.value;
    json['webPortEnable'] = false;
    json['customIptvUserAgent'] = customIptvUserAgent.value;
    return json;
  }

  // ========== 生命周期结束方法 ==========
  @override
  void onClose() {
    _stopWatchTimer.dispose();
    _flushPendingWrites();
    super.onClose();
  }
}
