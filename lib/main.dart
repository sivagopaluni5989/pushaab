// =================================================
// WA STATUS DOWNLOADER V10 PRO MAX
// =================================================

import 'dart:ui';
import 'dart:async';
import 'dart:io';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_video_thumbnail_plus/flutter_video_thumbnail_plus.dart';

import 'package:saf/saf.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const WAStatusDownloaderApp());
}

class WAStatusDownloaderApp extends StatelessWidget {
  const WAStatusDownloaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "WA Status Downloader",
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF000000),
        primaryColor: const Color(0xFF25D366),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF25D366),
          secondary: Color(0xFF128C7E),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF25D366),
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          ),
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: Color(0xFF25D366),
        ),
      ),
      home: const HomePage(),
    );
  }
}
class AppConstants {
  static const String appName = "WA Status Downloader";
  static const String whatsappKey = "whatsapp_saf_uri";
  static const String businessKey = "business_saf_uri";
  static const String whatsappFolder = "WhatsApp";
  static const String businessFolder = "WhatsApp Business";

  static const int gridColumns = 3;
  static const double gridSpacing = 2.0;
  static const double borderRadius = 8.0;

  static const int thumbnailCacheSize = 200;
  static const int imageCacheWidth = 400;
  static const Duration refreshInterval = Duration(seconds: 15);

  static const String downloadFolder = "WA Status Downloader";
}

class StatusFile {
  final String path;
  final DateTime modifiedDate;
  final int size;

  const StatusFile({
    required this.path,
    required this.modifiedDate,
    required this.size,
  });

  String get extension {
    final index = path.lastIndexOf(".");
    if (index == -1) return "";
    return path.substring(index).toLowerCase();
  }

  bool get isVideo => extension == ".mp4";
  bool get isImage =>
      extension == ".jpg" || extension == ".jpeg" || extension == ".png";

  String get name => path.split("/").last;

  @override
  bool operator ==(Object other) =>
      other is StatusFile && other.path == path;

  @override
  int get hashCode => path.hashCode;
}
class FileHelper {
  static const List<String> supportedExtensions = [
    ".jpg", ".jpeg", ".png", ".mp4",
  ];

  static bool isSupported(String path) {
    final lower = path.toLowerCase();
    for (final ext in supportedExtensions) {
      if (lower.endsWith(ext)) return true;
    }
    return false;
  }

  static Future<StatusFile?> createStatus(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return null;
      final stat = await file.stat();
      return StatusFile(
        path: path,
        modifiedDate: stat.modified,
        size: stat.size,
      );
    } catch (e) {
      debugPrint("Status creation failed: $e");
      return null;
    }
  }

  static void sortLatest(List<StatusFile> statuses) {
    statuses.sort((a, b) => b.modifiedDate.compareTo(a.modifiedDate));
  }

  static String formatSize(int bytes) {
    if (bytes < 1024) return "$bytes B";
    if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(1)} KB";
    if (bytes < 1024 * 1024 * 1024) {
      return "${(bytes / 1024 / 1024).toStringAsFixed(1)} MB";
    }
    return "${(bytes / 1024 / 1024 / 1024).toStringAsFixed(1)} GB";
  }

  static String uniqueName(String originalName) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final dot = originalName.lastIndexOf(".");
    if (dot == -1) return "${originalName}_$timestamp";
    final name = originalName.substring(0, dot);
    final ext = originalName.substring(dot);
    return "${name}_$timestamp$ext";
  }
}
class LruCache<K, V> {
  final int maxSize;
  final LinkedHashMap<K, V> _cache = LinkedHashMap();

  LruCache(this.maxSize);

  V? get(K key) {
    if (!_cache.containsKey(key)) return null;
    final value = _cache.remove(key);
    _cache[key] = value as V;
    return value;
  }

  void put(K key, V value) {
    if (_cache.length >= maxSize) {
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = value;
  }

  void clear() => _cache.clear();
}

class ThumbnailCacheService {
  static final LruCache<String, String> _memoryCache =
      LruCache(AppConstants.thumbnailCacheSize);
  static final Set<String> _processing = {};

  static Future<String?> getThumbnail(String videoPath) async {
    try {
      final cached = _memoryCache.get(videoPath);
      if (cached != null && await File(cached).exists()) return cached;

      if (_processing.contains(videoPath)) return null;
      _processing.add(videoPath);

      try {
        final tempDir = await getTemporaryDirectory();
        final cacheFile = File("${tempDir.path}/${videoPath.hashCode}.thumb.jpg");

        if (await cacheFile.exists()) {
          _memoryCache.put(videoPath, cacheFile.path);
          return cacheFile.path;
        }

        final generated = await FlutterVideoThumbnailPlus.thumbnailFile(
          video: videoPath,
          imageFormat: ImageFormat.jpeg,
          quality: 75,
          maxWidth: AppConstants.imageCacheWidth,
        );

        if (generated == null) return null;

        final copied = await File(generated).copy(cacheFile.path);
        _memoryCache.put(videoPath, copied.path);
        return copied.path;
      } finally {
        _processing.remove(videoPath);
      }
    } catch (e) {
      debugPrint("Thumbnail error: $e");
      return null;
    }
  }

  static void clearMemory() => _memoryCache.clear();
}
class SafService {
  static Future<bool> pickWhatsAppFolder() async {
    try {
      final saf = Saf(
        "content://com.android.externalstorage.documents/tree/primary%3AAndroid%2Fmedia",
      );
      final bool? granted = await saf.getDirectoryPermission(
        grantWritePermission: false,
      );
      if (granted == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(AppConstants.whatsappKey, saf.toString());
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("WhatsApp SAF permission failed: $e");
      return false;
    }
  }

  static Future<bool> pickBusinessFolder() async {
    try {
      final saf = Saf(
        "content://com.android.externalstorage.documents/tree/primary%3AAndroid%2Fmedia",
      );
      final bool? granted = await saf.getDirectoryPermission(
        grantWritePermission: false,
      );
      if (granted == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(AppConstants.businessKey, saf.toString());
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Business SAF permission failed: $e");
      return false;
    }
  }

  static Future<Saf?> getWhatsAppSaf() async {
    final prefs = await SharedPreferences.getInstance();
    final uri = prefs.getString(AppConstants.whatsappKey);
    if (uri == null || uri.isEmpty) return null;
    return Saf(uri);
  }

  static Future<Saf?> getBusinessSaf() async {
    final prefs = await SharedPreferences.getInstance();
    final uri = prefs.getString(AppConstants.businessKey);
    if (uri == null || uri.isEmpty) return null;
    return Saf(uri);
  }

  static Future<bool> hasWhatsAppAccess() async =>
      (await getWhatsAppSaf()) != null;

  static Future<bool> hasBusinessAccess() async =>
      (await getBusinessSaf()) != null;

  static Future<void> clearPermissions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.whatsappKey);
    await prefs.remove(AppConstants.businessKey);
  }
}



class StatusScannerService {
  static Future<List<StatusFile>> loadWhatsApp() async {
    final saf = await SafService.getWhatsAppSaf();
    if (saf == null) return [];
    return _scanSaf(saf);
  }

  static Future<List<StatusFile>> loadBusiness() async {
    final saf = await SafService.getBusinessSaf();
    if (saf == null) return [];
    return _scanSaf(saf);
  }

  static Future<List<StatusFile>> _scanSaf(Saf saf) async {
    final List<StatusFile> result = [];
    try {
      final files = await saf.getFilesPath();
      if (files == null || files.isEmpty) return [];
      for (final path in files) {
        if (!FileHelper.isSupported(path)) continue;
        final status = await FileHelper.createStatus(path);
        if (status != null) result.add(status);
      }
      FileHelper.sortLatest(result);
      return result;
    } catch (e) {
      debugPrint("SAF scan failed: $e");
      return [];
    }
  }

  static Future<Map<String, List<StatusFile>>> refreshAll() async {
    final whatsappFuture = loadWhatsApp();
    final businessFuture = loadBusiness();
    final data = await Future.wait([whatsappFuture, businessFuture]);
    return {"whatsapp": data[0], "business": data[1]};
  }

  static Future<int> totalCount() async {
    final data = await refreshAll();
    return data["whatsapp"]!.length + data["business"]!.length;
  }
}
class StatusController extends ChangeNotifier {
  List<StatusFile> whatsappStatuses = [];
  List<StatusFile> businessStatuses = [];

  bool loading = true;
  bool refreshing = false;
  String? error;
  DateTime? lastUpdated;
  Timer? _syncTimer;

  Future<void> initialize() async {
    loading = true;
    error = null;
    notifyListeners();
    await refresh();
    _startAutoSync();
  }

  Future<void> refresh() async {
    try {
      refreshing = true;
      error = null;
      notifyListeners();
      final data = await StatusScannerService.refreshAll();
      whatsappStatuses = data["whatsapp"] ?? [];
      businessStatuses = data["business"] ?? [];
      lastUpdated = DateTime.now();
    } catch (e) {
      error = "Failed to load statuses";
      debugPrint("Refresh error: $e");
    } finally {
      loading = false;
      refreshing = false;
      notifyListeners();
    }
  }

  void _startAutoSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(AppConstants.refreshInterval, (timer) async {
      try {
        final data = await StatusScannerService.refreshAll();
        whatsappStatuses = data["whatsapp"] ?? [];
        businessStatuses = data["business"] ?? [];
        lastUpdated = DateTime.now();
        notifyListeners();
      } catch (e) {
        debugPrint("Auto sync failed: $e");
      }
    });
  }

  int get whatsappCount => whatsappStatuses.length;
  int get businessCount => businessStatuses.length;
  int get totalCount => whatsappCount + businessCount;
  bool get hasData => totalCount > 0;
  bool get hasError => error != null;
  bool get hasPermission =>
      whatsappStatuses.isNotEmpty || businessStatuses.isNotEmpty;

  void clear() {
    whatsappStatuses.clear();
    businessStatuses.clear();
    error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }
}
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final StatusController controller = StatusController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    controller.initialize();
    controller.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    controller.removeListener(_onControllerChanged);
    controller.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("WA Status Downloader"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => controller.refresh(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF25D366),
          tabs: [
            Tab(text: "WhatsApp (${controller.whatsappCount})"),
            Tab(text: "Business (${controller.businessCount})"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          StatusTabView(statuses: controller.whatsappStatuses, controller: controller),
          StatusTabView(statuses: controller.businessStatuses, controller: controller),
        ],
      ),
    );
  }
}
class LoadingView extends StatelessWidget {
  const LoadingView({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 20),
          Text("Loading statuses...",
              style: TextStyle(color: Colors.white70, fontSize: 16)),
        ],
      ),
    );
  }
}

class PermissionRequiredView extends StatelessWidget {
  final Future<void> Function() onGrant;
  const PermissionRequiredView({super.key, required this.onGrant});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.folder_open, size: 90, color: Color(0xFF25D366)),
            const SizedBox(height: 25),
            const Text(
              "WhatsApp access required",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              "Allow access once to load your WhatsApp statuses automatically in future launches.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 15),
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              icon: const Icon(Icons.lock_open),
              label: const Text("Grant Access"),
              onPressed: () async {
                await onGrant();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class EmptyStatusView extends StatelessWidget {
  final String title;
  const EmptyStatusView({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.photo_library_outlined,
              size: 90, color: Colors.white30),
          const SizedBox(height: 20),
          Text(title,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text(
            "New WhatsApp statuses will appear here automatically.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const ErrorView({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline,
                color: Colors.redAccent, size: 80),
            const SizedBox(height: 16),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 25),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text("Try Again"),
            ),
          ],
        ),
      ),
    );
  }
}

class StatusTabView extends StatelessWidget {
  final List<StatusFile> statuses;
  final StatusController controller;

  const StatusTabView({
    super.key,
    required this.statuses,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    if (controller.loading) {
      return const LoadingView();
    }

    if (!controller.hasPermission) {
      return PermissionRequiredView(
        onGrant: () async {
          await SafService.pickWhatsAppFolder();
          await controller.refresh();
        },
      );
    }

    if (controller.hasError) {
      return ErrorView(
        message: controller.error!,
        onRetry: controller.refresh,
      );
    }

    if (statuses.isEmpty) {
      return const EmptyStatusView(title: "No statuses yet");
    }

    return GridView.builder(
      padding: const EdgeInsets.all(AppConstants.gridSpacing),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: AppConstants.gridColumns,
        crossAxisSpacing: AppConstants.gridSpacing,
        mainAxisSpacing: AppConstants.gridSpacing,
      ),
      itemCount: statuses.length,
      itemBuilder: (context, index) {
        final status = statuses[index];
        return ClipRRect(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          child: status.isImage
              ? Image.file(File(status.path), fit: BoxFit.cover)
              : FutureBuilder<String?>(
                  future: ThumbnailCacheService.getThumbnail(status.path),
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      return Image.file(File(snapshot.data!), fit: BoxFit.cover);
                    }
                    return const Center(child: CircularProgressIndicator());
                  },
                ),
        );
      },
    );
  }
}

