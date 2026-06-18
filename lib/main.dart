// =================================================
// WA STATUS DOWNLOADER V10 PRO MAX
// Production Ready WhatsApp Status Saver
// Slice 1/20
// =================================================


// ====================
// Dart Imports
// ====================
import 'dart:ui';
import 'dart:async';
import 'dart:io';
import 'dart:collection';


// ====================
// Flutter Imports
// ====================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_video_thumbnail_plus/flutter_video_thumbnail_plus.dart';



// ====================
// Package Imports
// ====================

import 'package:saf/saf.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';


// =================================================
// APPLICATION ENTRY POINT
// =================================================

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Hide system UI for immersive experience
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.edgeToEdge,
  );

  runApp(
    const WAStatusDownloaderApp(),
  );
}





// =================================================
// ROOT APPLICATION
// =================================================

class WAStatusDownloaderApp extends StatelessWidget {


  const WAStatusDownloaderApp({
    super.key,
  });



  @override
  Widget build(
    BuildContext context,
  ) {


    return MaterialApp(

      debugShowCheckedModeBanner: false,


      title: "WA Status Downloader",


      theme: ThemeData(

        brightness: Brightness.dark,


        scaffoldBackgroundColor:
            const Color(0xFF000000),


        primaryColor:
            const Color(0xFF25D366),


        colorScheme:
            const ColorScheme.dark(

          primary: Color(0xFF25D366),

          secondary: Color(0xFF128C7E),

        ),


        appBarTheme:
            const AppBarTheme(

          backgroundColor:
              Colors.black,


          elevation: 0,


          centerTitle: true,


          titleTextStyle:
              TextStyle(

            color: Colors.white,

            fontSize: 22,

            fontWeight: FontWeight.bold,

          ),

        ),


        elevatedButtonTheme:

            ElevatedButtonThemeData(

          style:
              ElevatedButton.styleFrom(

            backgroundColor:
                const Color(0xFF25D366),

            foregroundColor:
                Colors.black,


            shape:

                RoundedRectangleBorder(

              borderRadius:

                  BorderRadius.circular(15),

            ),


            padding:
                const EdgeInsets.symmetric(

              horizontal: 22,

              vertical: 14,

            ),

          ),

        ),


        progressIndicatorTheme:

            const ProgressIndicatorThemeData(

          color:
              Color(0xFF25D366),

        ),

      ),


      home:
          const HomePage(),

    );

  }

}
// =================================================
// APPLICATION CONSTANTS
// Global configuration for V10
// =================================================

class AppConstants {

  // App information
  static const String appName =
      "WA Status Downloader";


  // SAF storage keys
  static const String whatsappKey =
      "whatsapp_saf_uri";

  static const String businessKey =
      "business_saf_uri";


  // WhatsApp folder names
  static const String whatsappFolder =
      "WhatsApp";

  static const String businessFolder =
      "WhatsApp Business";


  // UI configuration
  static const int gridColumns = 3;

  static const double gridSpacing = 2.0;

  static const double borderRadius = 8.0;


  // Performance
  static const int thumbnailCacheSize = 200;

  static const int imageCacheWidth = 400;

  static const Duration refreshInterval =
      Duration(seconds: 15);


  // Download folder
  static const String downloadFolder =
      "WA Status Downloader";

}



// =================================================
// STATUS FILE MODEL
// Represents image/video WhatsApp status
// =================================================

class StatusFile {


  final String path;

  final DateTime modifiedDate;

  final int size;


  const StatusFile({

    required this.path,

    required this.modifiedDate,

    required this.size,

  });



  /// File extension
  String get extension {

    final index =
        path.lastIndexOf(".");

    if (index == -1) {
      return "";
    }

    return path
        .substring(index)
        .toLowerCase();

  }



  /// Media checks
  bool get isVideo {

    return extension == ".mp4";

  }


  bool get isImage {

    return extension == ".jpg" ||
        extension == ".jpeg" ||
        extension == ".png";

  }



  /// File name
  String get name {

    return path
        .split("/")
        .last;

  }



  /// For duplicate comparison
  @override
  bool operator ==(Object other) {

    return other is StatusFile &&
        other.path == path;

  }


  @override
  int get hashCode {

    return path.hashCode;

  }

}
// =================================================
// FILE HELPER SERVICE
// Media validation and file utilities
// =================================================

class FileHelper {


  /// Supported status formats
  static const List<String> supportedExtensions = [

    ".jpg",
    ".jpeg",
    ".png",
    ".mp4",

  ];



  /// Check if file is supported
  static bool isSupported(
    String path,
  ) {


    final lower =
        path.toLowerCase();


    for (final ext in supportedExtensions) {

      if (lower.endsWith(ext)) {
        return true;
      }

    }


    return false;

  }



  /// Create StatusFile safely
  static Future<StatusFile?> createStatus(
    String path,
  ) async {


    try {


      final file =
          File(path);


      final exists =
          await file.exists();


      if (!exists) {

        return null;

      }


      final stat =
          await file.stat();


      return StatusFile(

        path: path,

        modifiedDate:
            stat.modified,

        size:
            stat.size,

      );


    } catch (e) {


      debugPrint(
        "Status creation failed: $e",
      );


      return null;

    }

  }



  /// Sort latest status first
  static void sortLatest(
    List<StatusFile> statuses,
  ) {


    statuses.sort(

      (
        a,
        b,
      ) {

        return b.modifiedDate.compareTo(
          a.modifiedDate,
        );

      },

    );

  }



  /// Human readable file size
  static String formatSize(
    int bytes,
  ) {


    if (bytes < 1024) {

      return "$bytes B";

    }


    if (bytes < 1024 * 1024) {

      return "${(bytes / 1024).toStringAsFixed(1)} KB";

    }


    if (bytes < 1024 * 1024 * 1024) {

      return "${(bytes / 1024 / 1024).toStringAsFixed(1)} MB";

    }


    return "${(bytes / 1024 / 1024 / 1024).toStringAsFixed(1)} GB";

  }



  /// Generate unique file name for downloads
  static String uniqueName(
    String originalName,
  ) {


    final timestamp =
        DateTime
            .now()
            .millisecondsSinceEpoch;


    final dot =
        originalName.lastIndexOf(".");


    if (dot == -1) {

      return "${originalName}_$timestamp";

    }


    final name =
        originalName.substring(
          0,
          dot,
        );


    final ext =
        originalName.substring(
          dot,
        );


    return "${name}_$timestamp$ext";

  }

}
// =================================================
// LRU MEMORY CACHE
// Keeps frequently used thumbnails in RAM
// =================================================

class LruCache<K, V> {

  final int maxSize;

  final LinkedHashMap<K, V> _cache =
      LinkedHashMap();


  LruCache(
    this.maxSize,
  );


  V? get(K key) {

    if (!_cache.containsKey(key)) {
      return null;
    }


    final value =
        _cache.remove(key);


    _cache[key] = value as V;


    return value;

  }



  void put(
    K key,
    V value,
  ) {


    if (_cache.length >= maxSize) {

      _cache.remove(
        _cache.keys.first,
      );

    }


    _cache[key] = value;

  }



  void clear() {

    _cache.clear();

  }

}




// =================================================
// THUMBNAIL CACHE SERVICE
// Generates and stores video thumbnails
// =================================================

class ThumbnailCacheService {


  static final LruCache<String, String>
      _memoryCache =
          LruCache(
    AppConstants.thumbnailCacheSize,
  );


  static final Set<String>
      _processing = {};



  /// Get thumbnail from RAM, disk or generate
  static Future<String?> getThumbnail(
    String videoPath,
  ) async {


    try {


      // 1. Check RAM cache
      final cached =
          _memoryCache.get(
        videoPath,
      );


      if (cached != null &&
          await File(cached).exists()) {

        return cached;

      }


      // Prevent duplicate generation
      if (_processing.contains(videoPath)) {

        return null;

      }


      _processing.add(videoPath);


      try {


        // 2. Check disk cache
        final cacheFile =
            File(
          "$videoPath.thumb.jpg",
        );


        if (await cacheFile.exists()) {


          _memoryCache.put(
            videoPath,
            cacheFile.path,
          );


          return cacheFile.path;

        }


        // 3. Generate thumbnail
               // 3. Generate thumbnail
        final generated =
            await FlutterVideoThumbnailPlus.thumbnailFile(
          video: videoPath,
          imageFormat: ImageFormat.jpeg, // Added the comma and changed to lowercase
          quality: 75,
          maxWidth: AppConstants.imageCacheWidth,
        );



        if (generated == null) {

          return null;

        }


        // Store persistent cache
        final copied =
            await File(generated).copy(
          cacheFile.path,
        );


        _memoryCache.put(
          videoPath,
          copied.path,
        );


        return copied.path;


      } finally {


        _processing.remove(
          videoPath,
        );

      }


    } catch (e) {


      debugPrint(
        "Thumbnail error: $e",
      );


      return null;

    }

  }



  /// Clear RAM cache
  static void clearMemory() {


    _memoryCache.clear();

  }

}
// =================================================
// SAF SERVICE
// WhatsApp / WhatsApp Business folder access
// =================================================

class SafService {


  /// Pick WhatsApp folder manually (first launch)
  static Future<bool> pickWhatsAppFolder() async {

    try {

      final saf = Saf(
        "content://com.android.externalstorage.documents/tree/primary%3AAndroid%2Fmedia",
      );


      final bool? granted = await saf.getDirectoryPermission(
  grantWritePermission: false,
);

if (granted != true) {
  return false;
}


      final prefs =
          await SharedPreferences.getInstance();


      await prefs.setString(
        AppConstants.whatsappKey,
        saf.toString(),
      );


      return true;


    } catch (e) {

      debugPrint(
        "WhatsApp SAF permission failed: $e",
      );

      return false;

    }

  }



  /// Pick WhatsApp Business folder
  static Future<bool> pickBusinessFolder() async {

    try {

      final saf = Saf(
        "content://com.android.externalstorage.documents/tree/primary%3AAndroid%2Fmedia",
      );


      final granted =
          await saf.getDirectoryPermission(
        grantWritePermission: false,
      );


      if (granted != true) {
        return false;
      }


      final prefs =
          await SharedPreferences.getInstance();


      await prefs.setString(
        AppConstants.businessKey,
        saf.toString(),	
      );


      return true;


    } catch (e) {

      debugPrint(
        "Business SAF permission failed: $e",
      );

      return false;

    }

  }



  // =================================================
  // Restore previously granted WhatsApp SAF
  // =================================================

  static Future<Saf?> getWhatsAppSaf() async {

    final prefs =
        await SharedPreferences.getInstance();


    final uri =
        prefs.getString(
      AppConstants.whatsappKey,
    );


    if (uri == null) {
      return null;
    }


    return Saf(uri);

  }



  // =================================================
  // Restore WhatsApp Business SAF
  // =================================================

  static Future<Saf?> getBusinessSaf() async {
  final prefs = await SharedPreferences.getInstance();

  final uri = prefs.getString(AppConstants.businessKey);

  if (uri == null || uri.isEmpty) {
    return null;
  }

  return Saf(uri);
}

  // =================================================
  // Check whether user already granted permission
  // =================================================

  static Future<bool> hasWhatsAppAccess() async {

    return (await getWhatsAppSaf()) != null;

  }



  static Future<bool> hasBusinessAccess() async {

    return (await getBusinessSaf()) != null;

  }



  // =================================================
  // Remove saved permissions (Reset)
  // =================================================

  static Future<void> clearPermissions() async {


    final prefs =
        await SharedPreferences.getInstance();


    await prefs.remove(
      AppConstants.whatsappKey,
    );


    await prefs.remove(
      AppConstants.businessKey,
    );

  }

}
// =================================================
// STATUS SCANNER SERVICE
// Reads WhatsApp statuses using SAF
// =================================================

class StatusScannerService {


  // ===============================================
  // Load normal WhatsApp statuses
  // ===============================================

  static Future<List<StatusFile>> loadWhatsApp() async {

    final saf =
        await SafService.getWhatsAppSaf();


    if (saf == null) {
      return [];
    }


    return _scanSaf(saf);

  }



  // ===============================================
  // Load WhatsApp Business statuses
  // ===============================================

  static Future<List<StatusFile>> loadBusiness() async {

    final saf =
        await SafService.getBusinessSaf();


    if (saf == null) {
      return [];
    }


    return _scanSaf(saf);

  }



  // ===============================================
  // Core SAF scanning engine
  // ===============================================

  static Future<List<StatusFile>> _scanSaf(
    Saf saf,
  ) async {


    final List<StatusFile> result = [];


    try {


      final files =
          await saf.getFilesPath();


      if (files == null ||
          files.isEmpty) {

        return [];
      }


      // Loop through all files
      for (final path in files) {


        // Skip unsupported files
        if (!FileHelper.isSupported(path)) {
          continue;
        }


        // Create safe status object
        final status =
            await FileHelper.createStatus(
          path,
        );


        if (status != null) {

          result.add(status);

        }

      }


      // Newest statuses first
      FileHelper.sortLatest(
        result,
      );


      return result;


    } catch (e) {


      debugPrint(
        "SAF scan failed: $e",
      );


      return [];

    }

  }



  // ===============================================
  // Refresh all sources together
  // Used for pull-to-refresh and background sync
  // ===============================================

  static Future<Map<String, List<StatusFile>>>
      refreshAll() async {


    final whatsappFuture =
        loadWhatsApp();


    final businessFuture =
        loadBusiness();


    final data =
        await Future.wait([
      whatsappFuture,
      businessFuture,
    ]);


    return {

      "whatsapp":
          data[0],

      "business":
          data[1],

    };

  }



  // ===============================================
  // Count helper
  // ===============================================

  static Future<int> totalCount() async {


    final data =
        await refreshAll();


    return data["whatsapp"]!.length +
        data["business"]!.length;

  }

}
// =================================================
// STATUS CONTROLLER
// Central app state management
// Handles loading, refresh, auto-sync
// =================================================

class StatusController extends ChangeNotifier {


  // ===============================================
  // Status collections
  // ===============================================

  List<StatusFile> whatsappStatuses = [];


  List<StatusFile> businessStatuses = [];


  // ===============================================
  // UI state
  // ===============================================

  bool loading = true;


  bool refreshing = false;


  String? error;


  DateTime? lastUpdated;


  Timer? _syncTimer;



  // ===============================================
  // Initialize controller
  // ===============================================

  Future<void> initialize() async {

    loading = true;
    error = null;

    notifyListeners();


    await refresh();


    _startAutoSync();

  }



  // ===============================================
  // Manual refresh
  // Pull-to-refresh support
  // ===============================================

  Future<void> refresh() async {


    try {


      refreshing = true;

      error = null;


      notifyListeners();


      final data =
          await StatusScannerService.refreshAll();


      whatsappStatuses =
          data["whatsapp"] ?? [];


      businessStatuses =
          data["business"] ?? [];


      lastUpdated =
          DateTime.now();


    } catch (e) {


      error =
          "Failed to load statuses";


      debugPrint(
        "Refresh error: $e",
      );


    } finally {


      loading = false;


      refreshing = false;


      notifyListeners();

    }

  }



  // ===============================================
  // Background refresh engine
  // ===============================================

  void _startAutoSync() {


    _syncTimer?.cancel();


    _syncTimer =
        Timer.periodic(

      AppConstants.refreshInterval,

      (timer) async {

        try {


          final data =
              await StatusScannerService
                  .refreshAll();


          whatsappStatuses =
              data["whatsapp"] ?? [];


          businessStatuses =
              data["business"] ?? [];


          lastUpdated =
              DateTime.now();


          notifyListeners();


        } catch (e) {


          debugPrint(
            "Auto sync failed: $e",
          );

        }

      },

    );

  }



  // ===============================================
  // Status statistics
  // ===============================================

  int get whatsappCount {


    return whatsappStatuses.length;

  }


  int get businessCount {


    return businessStatuses.length;

  }


  int get totalCount {


    return whatsappCount +
        businessCount;

  }


  bool get hasData {


    return totalCount > 0;

  }


  bool get hasError {


    return error != null;

  }


  bool get hasPermission {


    return whatsappStatuses.isNotEmpty ||
        businessStatuses.isNotEmpty;

  }



  // ===============================================
  // Clear all loaded statuses
  // ===============================================

  void clear() {


    whatsappStatuses.clear();


    businessStatuses.clear();


    error = null;


    notifyListeners();

  }



  // ===============================================
  // Clean resources
  // ===============================================

  @override
  void dispose() {


    _syncTimer?.cancel();


    super.dispose();

  }

}
// =================================================
// HOME PAGE
// Instagram style WhatsApp Status Downloader UI
// =================================================

class HomePage extends StatefulWidget {

  const HomePage({
    super.key,
  });


  @override
  State<HomePage> createState() =>
      _HomePageState();

}



class _HomePageState
    extends State<HomePage>
    with SingleTickerProviderStateMixin {


  late final TabController _tabController;


  final StatusController controller =
      StatusController();



  @override
  void initState() {

    super.initState();


    _tabController = TabController(
      length: 2,
      vsync: this,
    );


    controller.initialize();


    controller.addListener(
      _onControllerChanged,
    );

  }



  void _onControllerChanged() {

    if (mounted) {

      setState(() {});

    }

  }



  @override
  void dispose() {


    controller.removeListener(
      _onControllerChanged,
    );


    controller.dispose();


    _tabController.dispose();


    super.dispose();

  }



  // =================================================
  // UI
  // =================================================

  @override
  Widget build(
    BuildContext context,
  ) {


    return Scaffold(


      appBar: AppBar(

        title: const Text(
          "WA Status Downloader",
        ),


        actions: [


          IconButton(

            icon: const Icon(
              Icons.refresh,
            ),


            onPressed: () {

              controller.refresh();

            },

          ),


        ],


        bottom: TabBar(

          controller: _tabController,


          indicatorColor:
              const Color(0xFF25D366),


          tabs: [

            Tab(

              text:
                  "WhatsApp (${controller.whatsappCount})",

            ),


            Tab(

              text:
                  "Business (${controller.businessCount})",

            ),

          ],

        ),

      ),



      body: TabBarView(

        controller: _tabController,


        children: [


          // Normal WhatsApp
          StatusTabView(

            statuses:
                controller.whatsappStatuses,


            controller:
                controller,

          ),


          // WhatsApp Business
          StatusTabView(

            statuses:
                controller.businessStatuses,


            controller:
                controller,

          ),


        ],

      ),

    );

  }

}
// =================================================
// COMMON UI STATES
// Loading, Empty, Error, Permission Views
// =================================================


// =================================================
// Loading Widget
// =================================================

class LoadingView extends StatelessWidget {

  const LoadingView({
    super.key,
  });


  @override
  Widget build(BuildContext context) {

    return const Center(

      child: Column(

        mainAxisAlignment:
            MainAxisAlignment.center,

        children: [

          CircularProgressIndicator(),

          SizedBox(
            height: 20,
          ),

          Text(

            "Loading statuses...",

            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),

          ),

        ],

      ),

    );

  }

}



// =================================================
// Permission Required View
// =================================================

class PermissionRequiredView
    extends StatelessWidget {


  final Future<void> Function()
      onGrant;


  const PermissionRequiredView({

    super.key,

    required this.onGrant,

  });



  @override
  Widget build(BuildContext context) {


    return Center(

      child: Padding(

        padding:
            const EdgeInsets.all(24),

        child: Column(

          mainAxisAlignment:
              MainAxisAlignment.center,


          children: [


            const Icon(

              Icons.folder_open,

              size: 90,

              color: Color(0xFF25D366),

            ),


            const SizedBox(
              height: 25,
            ),


            const Text(

              "WhatsApp access required",

              textAlign:
                  TextAlign.center,


              style: TextStyle(

                fontSize: 22,

                fontWeight:
                    FontWeight.bold,

              ),

            ),


            const SizedBox(
              height: 12,
            ),


            const Text(

              "Allow access once to load your WhatsApp statuses automatically in future launches.",

              textAlign:
                  TextAlign.center,

              style: TextStyle(

                color: Colors.white70,

                fontSize: 15,

              ),

            ),


            const SizedBox(
              height: 30,
            ),


            ElevatedButton.icon(

              icon:
                  const Icon(Icons.lock_open),

              label:
                  const Text("Grant Access"),


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



// =================================================
// Empty Status View
// =================================================

class EmptyStatusView
    extends StatelessWidget {


  final String title;


  const EmptyStatusView({

    super.key,

    required this.title,

  });



  @override
  Widget build(BuildContext context) {


    return Center(

      child: Column(

        mainAxisAlignment:
            MainAxisAlignment.center,


        children: [


          const Icon(

            Icons.photo_library_outlined,

            size: 90,

            color: Colors.white30,

          ),


          const SizedBox(
            height: 20,
          ),


          Text(

            title,

            style: const TextStyle(

              fontSize: 20,

              fontWeight:
                  FontWeight.w600,

            ),

          ),


          const SizedBox(
            height: 8,
          ),


          const Text(

            "New WhatsApp statuses will appear here automatically.",

            textAlign:
                TextAlign.center,


            style: TextStyle(

              color: Colors.white54,

              fontSize: 14,

            ),

          ),

        ],

      ),

    );

  }

}



// =================================================
// Error View
// =================================================

class ErrorView
    extends StatelessWidget {


  final String message;


  final VoidCallback onRetry;


  const ErrorView({

    super.key,

    required this.message,

    required this.onRetry,

  });



  @override
  Widget build(BuildContext context) {


    return Center(

      child: Padding(

        padding:
            const EdgeInsets.all(20),

        child: Column(

          mainAxisAlignment:
              MainAxisAlignment.center,


          children: [


            const Icon(

              Icons.error_outline,

              color: Colors.redAccent,

              size: 80,

            ),


            const SizedBox(
              height: 16,
            ),


            Text(

              message,

              textAlign:
                  TextAlign.center,


              style: const TextStyle(

                fontSize: 16,

              ),

            ),


            const SizedBox(
              height: 25,
            ),


            ElevatedButton(

              onPressed: onRetry,

              child: const Text(
                "Try Again",
              ),

            ),

          ],

        ),

      ),

    );

  }

}
// =================================================
// STATUS TAB VIEW
// Handles loading, permission, empty and grid states
// =================================================

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


    // Loading state
    if (controller.loading) {

      return const LoadingView();

    }


    // Error state
    if (controller.hasError) {

      return ErrorView(

        message: controller.error!,

        onRetry: () {

          controller.refresh();

        },

      );

    }


    // Empty / Permission state
    if (statuses.isEmpty) {

      return PermissionRequiredView(

        onGrant: () async {


          final granted =
              await SafService
                  .pickWhatsAppFolder();


          if (granted) {

            await controller.refresh();

          }

        },

      );

    }


    // Real status grid
    return RefreshIndicator(

      onRefresh: () {

        return controller.refresh();

      },


      child: GridView.builder(

        padding: const EdgeInsets.all(
          AppConstants.gridSpacing,
        ),


        cacheExtent: 3000,


        physics:
            const AlwaysScrollableScrollPhysics(),


        gridDelegate:
            SliverGridDelegateWithFixedCrossAxisCount(

          crossAxisCount:
              AppConstants.gridColumns,


          crossAxisSpacing:
              AppConstants.gridSpacing,


          mainAxisSpacing:
              AppConstants.gridSpacing,

        ),


        itemCount: statuses.length,


        itemBuilder: (
          context,
          index,
        ) {


          final status =
              statuses[index];


          return StatusCard(

            status: status,


            index: index,


            allStatuses: statuses,

          );

        },

      ),

    );

  }

}
// =================================================
// STATUS CARD
// Instagram style image/video tile
// =================================================

class StatusCard extends StatelessWidget {

  final StatusFile status;

  final int index;

  final List<StatusFile> allStatuses;


  const StatusCard({

    super.key,

    required this.status,

    required this.index,

    required this.allStatuses,

  });


  @override
  Widget build(
    BuildContext context,
  ) {


    return GestureDetector(

      onTap: () {

        Navigator.push(

          context,

          MaterialPageRoute(

            builder: (_) => StatusViewerPage(

              statuses: allStatuses,

              initialIndex: index,

            ),

          ),

        );

      },


      child: Hero(

        tag: status.path,


        child: ClipRRect(

          borderRadius: BorderRadius.circular(
            AppConstants.borderRadius,
          ),


          child: Stack(

            fit: StackFit.expand,


            children: [


              // ===========================
              // IMAGE STATUS
              // ===========================

              if (status.isImage)

                Image.file(

                  File(status.path),

                  fit: BoxFit.cover,


                  cacheWidth:
                      AppConstants.imageCacheWidth,


                  errorBuilder:
                      (_, __, ___) {

                    return const Center(

                      child: Icon(

                        Icons.broken_image,

                        color: Colors.white,

                        size: 40,

                      ),

                    );

                  },

                )


              // ===========================
              // VIDEO STATUS
              // ===========================

              else

                VideoThumbnailView(

                  videoPath: status.path,

                ),


              // Dark overlay for premium look
              Container(

                decoration: BoxDecoration(

                  gradient: LinearGradient(

                    begin: Alignment.topCenter,

                    end: Alignment.bottomCenter,


                    colors: [

                      Colors.transparent,

                      Colors.black.withOpacity(0.25),

                    ],

                  ),

                ),

              ),


              // Video icon indicator
              if (status.isVideo)

                const Positioned(

                  top: 8,

                  right: 8,


                  child: Icon(

                    Icons.play_circle_fill,

                    color: Colors.white,

                    size: 30,

                  ),

                ),

            ],

          ),

        ),

      ),

    );

  }

}




// =================================================
// VIDEO THUMBNAIL VIEW
// Optimized thumbnail loader
// =================================================

class VideoThumbnailView extends StatefulWidget {


  final String videoPath;


  const VideoThumbnailView({

    super.key,

    required this.videoPath,

  });


  @override
  State<VideoThumbnailView> createState() =>
      _VideoThumbnailViewState();

}




class _VideoThumbnailViewState
    extends State<VideoThumbnailView> {


  String? thumbnail;


  @override
  void initState() {

    super.initState();

    loadThumbnail();

  }



  Future<void> loadThumbnail() async {


    final path =
        await ThumbnailCacheService
            .getThumbnail(
      widget.videoPath,
    );


    if (!mounted) {
      return;
    }


    setState(() {

      thumbnail = path;

    });

  }



  @override
  Widget build(
    BuildContext context,
  ) {


    // Loading placeholder
    if (thumbnail == null) {

      return Container(

        color: Colors.grey.shade900,


        child: const Center(

          child: CircularProgressIndicator(),

        ),

      );

    }


    return Image.file(

      File(thumbnail!),

      fit: BoxFit.cover,


      cacheWidth:
          AppConstants.imageCacheWidth,


      filterQuality:
          FilterQuality.low,


      errorBuilder:
          (_, __, ___) {


        return Container(

          color: Colors.black,


          child: const Icon(

            Icons.video_file,

            color: Colors.white,

            size: 45,

          ),

        );

      },

    );

  }

}
// =================================================
// STATUS VIEWER PAGE
// Instagram / Reels style full screen viewer
// =================================================

class StatusViewerPage extends StatefulWidget {

  final List<StatusFile> statuses;

  final int initialIndex;


  const StatusViewerPage({

    super.key,

    required this.statuses,

    required this.initialIndex,

  });


  @override
  State<StatusViewerPage> createState() =>
      _StatusViewerPageState();

}




class _StatusViewerPageState
    extends State<StatusViewerPage> {


  late final PageController _pageController;


  late int currentIndex;



  @override
  void initState() {

    super.initState();


    currentIndex =
        widget.initialIndex;


    _pageController = PageController(

      initialPage: currentIndex,

    );

  }



  @override
  void dispose() {


    _pageController.dispose();


    super.dispose();

  }



  @override
  Widget build(
    BuildContext context,
  ) {


    return Scaffold(

      backgroundColor: Colors.black,


      body: Stack(

        children: [


          // ===================================
          // Vertical swipe like Instagram reels
          // ===================================

          PageView.builder(

            controller: _pageController,


            scrollDirection:
                Axis.vertical,


            itemCount:
                widget.statuses.length,


            onPageChanged: (index) {

              setState(() {

                currentIndex = index;

              });

            },


            itemBuilder: (
              context,
              index,
            ) {


              final status =
                  widget.statuses[index];


              if (status.isVideo) {


                // Slice 13
                return StatusVideoPlayer(

                  status: status,

                );

              }


              return Hero(

                tag: status.path,


                child: InteractiveViewer(

                  minScale: 1,


                  maxScale: 5,


                  child: Center(

                    child: Image.file(

                      File(status.path),


                      fit: BoxFit.contain,


                      cacheWidth:
                          1200,


                      filterQuality:
                          FilterQuality.medium,


                      errorBuilder:
                          (
                        _,
                        __,
                        ___,
                      ) {


                        return const Icon(

                          Icons.broken_image,


                          color:
                              Colors.white,


                          size: 80,

                        );

                      },

                    ),

                  ),

                ),

              );

            },

          ),



          // ===============================
          // Top overlay
          // ===============================

          SafeArea(

            child: Row(

              children: [


                IconButton(

                  icon: const Icon(

                    Icons.arrow_back,

                    color: Colors.white,

                  ),


                  onPressed: () {

                    Navigator.pop(context);

                  },

                ),


                Expanded(

                  child: Text(

                    "${currentIndex + 1}/${widget.statuses.length}",


                    textAlign:
                        TextAlign.center,


                    style: const TextStyle(

                      color: Colors.white,


                      fontSize: 16,


                      fontWeight:
                          FontWeight.w600,

                    ),

                  ),

                ),


                const SizedBox(

                  width: 48,

                ),

              ],

            ),

          ),


          // ===============================
          // Bottom controls
          // Download / Share added later
          // Slice 14–16
          // ===============================

          ViewerControls(

            status:
                widget.statuses[currentIndex],

          ),

        ],

      ),

    );

  }

}
// =================================================
// STATUS VIDEO PLAYER
// Instagram / Reels style video player
// =================================================

class StatusVideoPlayer extends StatefulWidget {

  final StatusFile status;


  const StatusVideoPlayer({

    super.key,

    required this.status,

  });


  @override
  State<StatusVideoPlayer> createState() =>
      _StatusVideoPlayerState();

}



class _StatusVideoPlayerState
    extends State<StatusVideoPlayer>
    with WidgetsBindingObserver {


  VideoPlayerController? _controller;


  bool _loading = true;


  bool _showControls = false;


  @override
  void initState() {

    super.initState();


    WidgetsBinding.instance.addObserver(this);


    _initializeVideo();

  }



  Future<void> _initializeVideo() async {

    try {

      final controller =
          VideoPlayerController.file(
            File(widget.status.path),
          );


      await controller.initialize();


      await controller.setLooping(true);


      await controller.play();


      if (!mounted) {

        controller.dispose();

        return;

      }


      setState(() {

        _controller = controller;

        _loading = false;

      });

    } catch (e) {


      debugPrint(
        "Video player error: $e",
      );


      if (!mounted) {
        return;
      }


      setState(() {

        _loading = false;

      });

    }

  }



  // ============================================
  // Handle app background / foreground
  // ============================================

  @override
  void didChangeAppLifecycleState(
      AppLifecycleState state) {


    final controller = _controller;


    if (controller == null) {
      return;
    }


    if (state == AppLifecycleState.paused) {

      controller.pause();

    }


    if (state == AppLifecycleState.resumed) {

      controller.play();

    }

  }



  // ============================================
  // Play / Pause Toggle
  // ============================================

  void _togglePlayPause() {


    final controller = _controller;


    if (controller == null) {
      return;
    }


    if (controller.value.isPlaying) {

      controller.pause();

    } else {

      controller.play();

    }


    setState(() {

      _showControls = true;

    });


    Future.delayed(
      const Duration(seconds: 2),
      () {

        if (!mounted) {
          return;
        }


        setState(() {

          _showControls = false;

        });

      },
    );

  }



  @override
  void dispose() {


    WidgetsBinding.instance.removeObserver(this);


    _controller?.dispose();


    super.dispose();

  }



  @override
  Widget build(
    BuildContext context,
  ) {


    // Loading state
    if (_loading) {

      return const Center(

        child: CircularProgressIndicator(),

      );

    }


    // Failed state
    if (_controller == null) {


      return const Center(

        child: Icon(

          Icons.error_outline,

          color: Colors.white,

          size: 70,

        ),

      );

    }


    return GestureDetector(

      onTap: _togglePlayPause,


      child: Stack(

        alignment: Alignment.center,


        children: [


          Center(

            child: AspectRatio(

              aspectRatio:
                  _controller!
                      .value
                      .aspectRatio,


              child: VideoPlayer(
                _controller!,
              ),

            ),

          ),


          AnimatedOpacity(

            duration:
                const Duration(
                  milliseconds: 250,
                ),


            opacity:
                _showControls ? 1 : 0,


            child: Icon(

              _controller!
                      .value
                      .isPlaying
                  ? Icons.pause_circle_filled
                  : Icons.play_circle_fill,


              color: Colors.white,


              size: 80,

            ),

          ),

        ],

      ),

    );

  }

}

// =================================================
// DOWNLOAD SERVICE
// Save WhatsApp statuses to app storage
// =================================================

class DownloadService {

  static const String folderName =
      "WA_Status_Downloader";


  // =================================================
  // Copy status to app download folder
  // =================================================

  static Future<File?> saveStatus(
    StatusFile status,
  ) async {

    try {

      // App documents directory
      final directory =
          await getApplicationDocumentsDirectory();


      final saveFolder = Directory(
        "${directory.path}/$folderName",
      );


      // Create folder first time
      if (!await saveFolder.exists()) {

        await saveFolder.create(
          recursive: true,
        );

      }


      final source = File(
        status.path,
      );


      if (!await source.exists()) {

        debugPrint(
          "Source file missing",
        );

        return null;

      }


      // Unique filename
      final extension =
          status.isVideo
              ? ".mp4"
              : ".jpg";


      final filename =
          "WA_${DateTime
              .now()
              .millisecondsSinceEpoch}$extension";


      final destination = File(
        "${saveFolder.path}/$filename",
      );


      final result =
          await source.copy(
            destination.path,
          );


      debugPrint(
        "Saved: ${result.path}",
      );


      return result;


    } catch (e) {


      debugPrint(
        "Save error: $e",
      );


      return null;

    }

  }


}

// =================================================
// GALLERY & SHARE SERVICE
// Save to gallery and share downloaded statuses
// =================================================

class MediaService {


  // =============================================
  // Download status and show message
  // =============================================
  static Future<void> downloadStatus(
    BuildContext context,
    StatusFile status,
  ) async {

    final file = await DownloadService.saveStatus(
      status,
    );


    if (!context.mounted) {
      return;
    }


    if (file == null) {

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Download failed",
          ),
        ),
      );

      return;
    }


    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "Saved successfully:\n${file.path}",
        ),
      ),
    );

  }


  // =============================================
  // Share placeholder
  // Actual share plugin can be connected later
  // =============================================
  static Future<void> shareStatus(
    BuildContext context,
    StatusFile status,
  ) async {


    ScaffoldMessenger.of(context).showSnackBar(

      const SnackBar(

        content: Text(
          "Share feature will be enabled in next production update",
        ),

      ),

    );

  }

}
// =================================================
// VIEWER CONTROLS
// Instagram / Reels style bottom action overlay
// =================================================

class ViewerControls extends StatefulWidget {

  final StatusFile status;


  const ViewerControls({

    super.key,

    required this.status,

  });


  @override
  State<ViewerControls> createState() =>
      _ViewerControlsState();

}



class _ViewerControlsState
    extends State<ViewerControls>
    with SingleTickerProviderStateMixin {


  late final AnimationController _animationController;


  late final Animation<double> _scaleAnimation;



  @override
  void initState() {

    super.initState();


    _animationController = AnimationController(

      vsync: this,


      duration: const Duration(
        milliseconds: 250,
      ),

    );


    _scaleAnimation = Tween<double>(

      begin: 0.9,

      end: 1.0,

    ).animate(

      CurvedAnimation(

        parent: _animationController,


        curve: Curves.easeOut,

      ),

    );


    _animationController.forward();

  }



  @override
  void dispose() {


    _animationController.dispose();


    super.dispose();

  }



  @override
  Widget build(
    BuildContext context,
  ) {


    return Align(

      alignment: Alignment.bottomCenter,


      child: SafeArea(

        child: Padding(

          padding: const EdgeInsets.all(16),


          child: ScaleTransition(

            scale: _scaleAnimation,


            child: Container(

              padding: const EdgeInsets.symmetric(

                horizontal: 20,

                vertical: 12,

              ),


              decoration: BoxDecoration(

                color: Colors.black.withOpacity(0.55),


                borderRadius: BorderRadius.circular(35),


                border: Border.all(

                  color: Colors.white24,

                ),

              ),


              child: Row(

                mainAxisSize: MainAxisSize.min,


                children: [


                  // =========================
                  // Download Button
                  // =========================

                  _ActionButton(

                    icon: Icons.download_rounded,


                    label: "Save",


                    color: const Color(
                      0xFF25D366,
                    ),


                    onTap: () {

                      MediaService.downloadStatus(

                        context,

                        widget.status,

                      );

                    },

                  ),


                  const SizedBox(
                    width: 25,
                  ),



                  // =========================
                  // Share Button
                  // =========================

                  _ActionButton(

                    icon: Icons.share,


                    label: "Share",


                    color: Colors.blueAccent,


                    onTap: () {

                      MediaService.shareStatus(

                        context,

                        widget.status,

                      );

                    },

                  ),


                  const SizedBox(
                    width: 25,
                  ),



                  // =========================
                  // Information Button
                  // =========================

                  _ActionButton(

                    icon: Icons.info_outline,


                    label: "Info",


                    color: Colors.orangeAccent,


                    onTap: () {

                      _showInfoDialog();

                    },

                  ),

                ],

              ),

            ),

          ),

        ),

      ),

    );

  }



  // ==========================================
  // Status information popup
  // ==========================================

  void _showInfoDialog() {


    showDialog(

      context: context,


      builder: (context) {

        return AlertDialog(

          backgroundColor: Colors.grey.shade900,


          title: const Text(

            "Status Details",

            style: TextStyle(
              color: Colors.white,
            ),

          ),


          content: SelectableText(

            widget.status.path,


            style: const TextStyle(

              color: Colors.white70,

            ),

          ),


          actions: [

            TextButton(

              onPressed: () {

                Navigator.pop(context);

              },


              child: const Text(
                "Close",
              ),

            ),

          ],

        );

      },

    );

  }

}



// =================================================
// REUSABLE ACTION BUTTON
// =================================================

class _ActionButton extends StatelessWidget {


  final IconData icon;


  final String label;


  final Color color;


  final VoidCallback onTap;



  const _ActionButton({

    required this.icon,

    required this.label,

    required this.color,

    required this.onTap,

  });



  @override
  Widget build(
    BuildContext context,
  ) {


    return GestureDetector(

      onTap: onTap,


      child: Column(

        mainAxisSize: MainAxisSize.min,


        children: [

          CircleAvatar(

            radius: 22,


            backgroundColor: color,


            child: Icon(

              icon,

              color: Colors.white,

              size: 22,

            ),

          ),


          const SizedBox(
            height: 5,
          ),


          Text(

            label,


            style: const TextStyle(

              color: Colors.white,

              fontSize: 12,

            ),

          ),

        ],

      ),

    );

  }

}
// =================================================
// PREMIUM ANIMATIONS
// Fade, Scale, Slide and Ripple Effects
// =================================================


// =================================================
// Fade In Animation
// =================================================

class FadeInAnimation extends StatefulWidget {

  final Widget child;

  final Duration duration;


  const FadeInAnimation({

    super.key,

    required this.child,

    this.duration = const Duration(
      milliseconds: 350,
    ),

  });


  @override
  State<FadeInAnimation> createState() =>
      _FadeInAnimationState();

}



class _FadeInAnimationState
    extends State<FadeInAnimation>
    with SingleTickerProviderStateMixin {


  late final AnimationController _controller;


  late final Animation<double> _animation;


  @override
  void initState() {

    super.initState();


    _controller = AnimationController(

      vsync: this,

      duration: widget.duration,

    );


    _animation = CurvedAnimation(

      parent: _controller,

      curve: Curves.easeOut,

    );


    _controller.forward();

  }


  @override
  void dispose() {

    _controller.dispose();

    super.dispose();

  }


  @override
  Widget build(
    BuildContext context,
  ) {

    return FadeTransition(

      opacity: _animation,

      child: widget.child,

    );

  }

}



// =================================================
// Slide Up Animation
// =================================================

class SlideUpAnimation extends StatefulWidget {


  final Widget child;


  const SlideUpAnimation({

    super.key,

    required this.child,

  });


  @override
  State<SlideUpAnimation> createState() =>
      _SlideUpAnimationState();

}



class _SlideUpAnimationState
    extends State<SlideUpAnimation>
    with SingleTickerProviderStateMixin {


  late final AnimationController _controller;


  late final Animation<Offset> _offset;


  @override
  void initState() {

    super.initState();


    _controller = AnimationController(

      vsync: this,

      duration: const Duration(
        milliseconds: 300,
      ),

    );


    _offset = Tween<Offset>(

      begin: const Offset(0, 0.2),

      end: Offset.zero,

    ).animate(

      CurvedAnimation(

        parent: _controller,

        curve: Curves.easeOutCubic,

      ),

    );


    _controller.forward();

  }


  @override
  void dispose() {

    _controller.dispose();

    super.dispose();

  }


  @override
  Widget build(
    BuildContext context,
  ) {

    return SlideTransition(

      position: _offset,

      child: widget.child,

    );

  }

}



// =================================================
// Bounce Tap Animation
// For buttons and cards
// =================================================

class BounceButton extends StatefulWidget {


  final Widget child;

  final VoidCallback onTap;


  const BounceButton({

    super.key,

    required this.child,

    required this.onTap,

  });


  @override
  State<BounceButton> createState() =>
      _BounceButtonState();

}



class _BounceButtonState
    extends State<BounceButton>
    with SingleTickerProviderStateMixin {


  late final AnimationController _controller;


  late final Animation<double> _scale;


  @override
  void initState() {

    super.initState();


    _controller = AnimationController(

      vsync: this,

      duration: const Duration(
        milliseconds: 120,
      ),

      lowerBound: 0.92,

      upperBound: 1.0,

      value: 1.0,

    );


    _scale = _controller;

  }


  @override
  void dispose() {

    _controller.dispose();

    super.dispose();

  }


  Future<void> _handleTap() async {


    await _controller.reverse();


    await _controller.forward();


    widget.onTap();

  }


  @override
  Widget build(
    BuildContext context,
  ) {


    return GestureDetector(

      onTap: _handleTap,


      child: ScaleTransition(

        scale: _scale,

        child: widget.child,

      ),

    );

  }

}



// =================================================
// Shimmer Placeholder
// Lightweight loading effect
// =================================================

class PremiumPlaceholder extends StatefulWidget {


  const PremiumPlaceholder({
    super.key,
  });


  @override
  State<PremiumPlaceholder> createState() =>
      _PremiumPlaceholderState();

}



class _PremiumPlaceholderState
    extends State<PremiumPlaceholder>
    with SingleTickerProviderStateMixin {


  late final AnimationController _controller;


  @override
  void initState() {

    super.initState();


    _controller = AnimationController(

      vsync: this,

      duration: const Duration(
        milliseconds: 900,
      ),

    )..repeat(reverse: true);

  }


  @override
  void dispose() {

    _controller.dispose();

    super.dispose();

  }


  @override
  Widget build(
    BuildContext context,
  ) {


    return AnimatedBuilder(

      animation: _controller,


      builder: (_, __) {

        final value =
            0.15 + (_controller.value * 0.15);


        return Container(

          decoration: BoxDecoration(

            color: Colors.white.withOpacity(
              value,
            ),

            borderRadius: BorderRadius.circular(
              AppConstants.borderRadius,
            ),

          ),

        );

      },

    );

  }

}
// =================================================
// PERFORMANCE ENGINE
// Memory management and cache optimization
// =================================================

class PerformanceService {

  // Maximum cached video thumbnails
  static const int maxThumbnailCache = 200;


  // =================================================
  // Clean old thumbnail cache
  // =================================================

  static Future<void> cleanThumbnailCache() async {

    try {

      final cacheDir =
          await getTemporaryDirectory();


      if (!await cacheDir.exists()) {
        return;
      }


      final files =
          cacheDir.listSync();


      final thumbnails = files.whereType<File>()
          .where(
            (file) =>
                file.path.contains(
                  "wa_thumb",
                ),
          ).toList();


      if (thumbnails.length <=
          maxThumbnailCache) {

        return;

      }


      // Sort oldest first
      thumbnails.sort(
        (a, b) {

          return a
              .lastModifiedSync()
              .compareTo(
                b.lastModifiedSync(),
              );

        },
      );


      final removeCount =
          thumbnails.length -
          maxThumbnailCache;


      for (int i = 0;
          i < removeCount;
          i++) {

        try {

          await thumbnails[i].delete();

        } catch (_) {}

      }


      debugPrint(
        "Thumbnail cache cleaned",
      );

    } catch (e) {

      debugPrint(
        "Cache cleanup failed: $e",
      );

    }

  }



  // =================================================
  // Clear Flutter image cache
  // =================================================

  static void clearImageMemory() {

    PaintingBinding
        .instance
        .imageCache
        .clear();


    PaintingBinding
        .instance
        .imageCache
        .clearLiveImages();


    debugPrint(
      "Image memory cache cleared",
    );

  }



  // =================================================
  // App startup optimization
  // =================================================

  static Future<void> initialize() async {

    await cleanThumbnailCache();

  }



  // =================================================
  // Low memory callback
  // =================================================

  static void onLowMemory() {

    clearImageMemory();


    debugPrint(
      "Low memory optimization executed",
    );

  }

}



// =================================================
// LAZY IMAGE WIDGET
// Optimized image renderer
// =================================================

class OptimizedImage extends StatelessWidget {


  final String path;


  final BoxFit fit;


  const OptimizedImage({

    super.key,

    required this.path,

    this.fit = BoxFit.cover,

  });


  @override
  Widget build(
    BuildContext context,
  ) {

    return Image.file(

      File(path),

      fit: fit,


      cacheWidth:
          AppConstants.imageCacheWidth,


      filterQuality:
          FilterQuality.low,


      gaplessPlayback: true,


      errorBuilder:
          (_, __, ___) {

        return Container(

          color: Colors.black12,


          child: const Icon(

            Icons.broken_image,

            color: Colors.white,

          ),

        );

      },

    );

  }

}



// =================================================
// MEMORY OBSERVER
// Detects system memory pressure
// =================================================

class MemoryObserver
    with WidgetsBindingObserver {


  @override
  void didHaveMemoryPressure() {

    PerformanceService.onLowMemory();

  }

}
// =================================================
// PRODUCTION SAFETY ENGINE
// Crash protection and validation
// =================================================

class SafetyService {


  // =============================================
  // Verify a status file exists and is valid
  // =============================================
  static Future<bool> validateStatus(
    StatusFile status,
  ) async {

    try {

      final file = File(
        status.path,
      );


      if (!await file.exists()) {

        debugPrint(
          "Missing status file: ${status.path}",
        );

        return false;

      }


      final size =
          await file.length();


      // Ignore empty files
      if (size <= 0) {

        debugPrint(
          "Corrupted empty file: ${status.path}",
        );

        return false;

      }


      return true;


    } catch (e) {

      debugPrint(
        "Validation error: $e",
      );

      return false;

    }

  }



  // =============================================
  // Filter only safe status files
  // =============================================
  static Future<List<StatusFile>> filterValidStatuses(
    List<StatusFile> statuses,
  ) async {


    final valid =
        <StatusFile>[];


    for (final status in statuses) {


      final ok =
          await validateStatus(
            status,
          );


      if (ok) {

        valid.add(
          status,
        );

      }

    }


    return valid;

  }



  // =============================================
  // Safe async execution wrapper
  // =============================================
  static Future<T?> execute<T>(
    Future<T> Function() action,
  ) async {


    try {

      return await action();


    } catch (e, stack) {


      debugPrint(
        "App safety exception: $e",
      );


      debugPrint(
        stack.toString(),
      );


      return null;

    }

  }


}



// =================================================
// SAFE IMAGE VIEW
// Prevents crashes on broken images
// =================================================

class SafeImage extends StatelessWidget {


  final String path;


  final BoxFit fit;


  const SafeImage({

    super.key,

    required this.path,

    this.fit = BoxFit.cover,

  });


  @override
  Widget build(
    BuildContext context,
  ) {


    return Image.file(

      File(path),

      fit: fit,


      cacheWidth:
          AppConstants.imageCacheWidth,


      filterQuality:
          FilterQuality.low,


      errorBuilder:
          (
            context,
            error,
            stack,
          ) {


        debugPrint(
          "Image decode failed: $error",
        );


        return Container(

          color: Colors.black87,


          child: const Center(

            child: Icon(

              Icons.broken_image_outlined,

              color: Colors.white,

              size: 50,

            ),

          ),

        );

      },

    );

  }

}



// =================================================
// SAFE SNACKBAR HELPER
// Avoids context related crashes
// =================================================

class AppMessage {


  static void show(
    BuildContext context,
    String message,
  ) {


    if (!context.mounted) {
      return;
    }


    final messenger =
        ScaffoldMessenger.maybeOf(
          context,
        );


    if (messenger == null) {
      return;
    }


    messenger.hideCurrentSnackBar();


    messenger.showSnackBar(

      SnackBar(

        behavior:
            SnackBarBehavior.floating,


        content: Text(
          message,
        ),


        duration: const Duration(
          seconds: 2,
        ),

      ),

    );

  }

}
// =================================================
// FINAL PRODUCTION INITIALIZER
// Startup, crash handling, lifecycle
// =================================================

class AppInitializer {

  static bool _started = false;

  static Future<void> initialize() async {

    if (_started) {
      return;
    }

    _started = true;

    try {

      WidgetsFlutterBinding.ensureInitialized();


      // ---------------------------------------------
      // Performance startup
      // ---------------------------------------------
      await PerformanceService.initialize();


      // ---------------------------------------------
      // Monitor Android memory pressure
      // ---------------------------------------------
      WidgetsBinding.instance.addObserver(
        MemoryObserver(),
      );


      // ---------------------------------------------
      // Flutter framework errors
      // ---------------------------------------------
      FlutterError.onError =
          (FlutterErrorDetails details) {

        FlutterError.presentError(details);

        debugPrint(
          "Flutter Crash: ${details.exception}",
        );

      };


      // ---------------------------------------------
      // Unhandled Dart errors
      // ---------------------------------------------
      PlatformDispatcher.instance.onError =
          (
            Object error,
            StackTrace stack,
          ) {

        debugPrint(
          "Dart Crash: $error",
        );

        debugPrint(
          stack.toString(),
        );

        return true;
      };


      debugPrint(
        "V10 Production Engine Initialized",
      );

    } catch (e, stack) {

      debugPrint(
        "Initialization failed: $e",
      );

      debugPrint(
        stack.toString(),
      );

    }

  }

}



// =================================================
// APP LIFECYCLE OBSERVER
// Handles background and foreground states
// =================================================

class AppLifecycleHandler
    with WidgetsBindingObserver {


  @override
  void didChangeAppLifecycleState(
    AppLifecycleState state,
  ) {


    switch (state) {


      case AppLifecycleState.resumed:

        debugPrint(
          "Application resumed",
        );

        break;


      case AppLifecycleState.paused:

        debugPrint(
          "Application paused",
        );

        // Release unused memory
        PerformanceService.clearImageMemory();

        break;


      case AppLifecycleState.detached:

        debugPrint(
          "Application detached",
        );

        break;


      case AppLifecycleState.inactive:

        debugPrint(
          "Application inactive",
        );

        break;


      case AppLifecycleState.hidden:

        debugPrint(
          "Application hidden",
        );

        break;

    }

  }

}



// =================================================
// FINAL APPLICATION ENTRY POINT
// =================================================

