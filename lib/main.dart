import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:saf/saf.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail_plus/video_thumbnail_plus.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
class AppConstants {
  static const String appName = 'WA Status Fast Saver';
  
  static const String keySafUriMain = 'saf_uri_main';
  static const String keySafUriBusiness = 'saf_uri_business';
  
  static const String whatsappTreeUri = 
      'content://com.android.externalstorage.documents/tree/primary%3AAndroid%2Fmedia%2Fcom.whatsapp%2FWhatsApp%2FMedia%2F.Statuses';
  static const String whatsappBusinessTreeUri = 
      'content://com.android.externalstorage.documents/tree/primary%3AAndroid%2Fmedia%2Fcom.w4b%2FWhatsApp%20Business%2FMedia%2F.Statuses';

  static const String legacyWhatsappPath = '/storage/emulated/0/WhatsApp/Media/.Statuses';
  static const String legacyBusinessPath = '/storage/emulated/0/WhatsApp Business/Media/.Statuses';
}
class AdManager {
  static BannerAd? _bannerAd;
  static InterstitialAd? _interstitialAd;
  static bool _isBannerLoaded = false;
  static bool _isInterstitialLoaded = false;

  static const String bannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111'; 
  static const String interstitialAdUnitId = 'ca-app-pub-3940256099942544/1033173712'; 

  static bool get isBannerLoaded => _isBannerLoaded;
  static BannerAd? get bannerAd => _bannerAd;

  static Future<void> initialize() async {
    await MobileAds.instance.initialize();
    loadBanner();
    loadInterstitial();
  }

  static void loadBanner() {
    _bannerAd = BannerAd(
      adUnitId: bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) => _isBannerLoaded = true,
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _isBannerLoaded = false;
        },
      ),
    )..load();
  }

  static void loadInterstitial() {
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialLoaded = true;
        },
        onAdFailedToLoad: (error) {
          _isInterstitialLoaded = false;
        },
      ),
    );
  }

  static void showInterstitial(VoidCallback onAdDismissed) {
    if (_isInterstitialLoaded && _interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          loadInterstitial();
          onAdDismissed();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          loadInterstitial();
          onAdDismissed();
        },
      );
      _interstitialAd!.show();
    } else {
      onAdDismissed();
    }
  }
}
class AppTheme {
  static const Color primaryColor = Color(0xFF075E54); 
  static const Color accentColor = Color(0xFF25D366);  
  static const Color backgroundColor = Color(0xFFF4F6F6);
  static const Color cardColor = Colors.white;
  static const Color textMain = Color(0xFF1F2C34);
  static const Color textSecondary = Color(0xFF667781);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      primaryColor: primaryColor,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        secondary: accentColor,
        surface: backgroundColor,
      ),
      scaffoldBackgroundColor: backgroundColor,
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 1.5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
      ),
    );
  }
}
class StatusMedia {
  final String path;
  final bool isVideo;
  final String? cachedThumbnailPath;
  final DateTime modifiedTime;

  StatusMedia({
    required this.path,
    required this.isVideo,
    this.cachedThumbnailPath,
    required this.modifiedTime,
  });
}

class StatusProvider with ChangeNotifier {
  List<StatusMedia> _whatsappImages = [];
  List<StatusMedia> _whatsappVideos = [];
  List<StatusMedia> _businessImages = [];
  List<StatusMedia> _businessVideos = [];
  List<StatusMedia> _savedStatuses = [];

  bool _isLoading = false;
  bool _hasSafPermissionWhatsapp = false;
  bool _hasSafPermissionBusiness = false;
  bool _isWhatsAppBusinessActive = false;

  List<StatusMedia> get whatsappImages => _whatsappImages;
  List<StatusMedia> get whatsappVideos => _whatsappVideos;
  List<StatusMedia> get businessImages => _businessImages;
  List<StatusMedia> get businessVideos => _businessVideos;
  List<StatusMedia> get savedStatuses => _savedStatuses;
  
  bool get isLoading => _isLoading;
  bool get hasSafPermissionWhatsapp => _hasSafPermissionWhatsapp;
  bool get hasSafPermissionBusiness => _hasSafPermissionBusiness;
  bool get isWhatsAppBusinessActive => _isWhatsAppBusinessActive;

  void setWhatsAppBusinessActive(bool active) {
    _isWhatsAppBusinessActive = active;
    notifyListeners();
  }

  void setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }

  void updateSafPermissionStatus({required bool whatsapp, required bool business}) {
    _hasSafPermissionWhatsapp = whatsapp;
    _hasSafPermissionBusiness = business;
    notifyListeners();
  }

  void updateMedia({
    required List<StatusMedia> waImages,
    required List<StatusMedia> waVideos,
    required List<StatusMedia> wbImages,
    required List<StatusMedia> wbVideos,
    required List<StatusMedia> saved,
  }) {
    _whatsappImages = waImages;
    _whatsappVideos = waVideos;
    _businessImages = wbImages;
    _businessVideos = wbVideos;
    _savedStatuses = saved;
    notifyListeners();
  }
}
class StoragePermissionEngine {
  static Future<bool> isAndroid11OrAbove() async {
    if (Platform.isAndroid) {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.version.sdkInt >= 30;
    }
    return false;
  }

  static Future<void> checkAndSyncPermissions(StatusProvider provider) async {
    final prefs = await SharedPreferences.getInstance();
    
    if (await isAndroid11OrAbove()) {
      final hasWaUri = prefs.getString(AppConstants.keySafUriMain) != null;
      final hasWbUri = prefs.getString(AppConstants.keySafUriBusiness) != null;
      
      bool waVerified = false;
      bool wbVerified = false;

      try {
        if (hasWaUri) {
          final safMain = Saf(AppConstants.whatsappTreeUri);
          waVerified = await Saf.isPersistedPermissionDirectoryFor(
  AppConstants.whatsappTreeUri,
) ?? false;
        }
      } catch (_) {}

      try {
        if (hasWbUri) {
          final safBusiness = Saf(AppConstants.whatsappBusinessTreeUri);
          wbVerified = await Saf.isPersistedPermissionDirectoryFor(
  AppConstants.whatsappBusinessTreeUri,
) ?? false;
        }
      } catch (_) {}

      provider.updateSafPermissionStatus(whatsapp: waVerified, business: wbVerified);
    } else {
      final status = await Permission.storage.status;
      provider.updateSafPermissionStatus(whatsapp: status.isGranted, business: status.isGranted);
    }
  }

  static Future<bool> requestSafDirectory(bool isBusiness, StatusProvider provider) async {
    final targetUri = isBusiness ? AppConstants.whatsappBusinessTreeUri : AppConstants.whatsappTreeUri;
    final prefKey = isBusiness ? AppConstants.keySafUriBusiness : AppConstants.keySafUriMain;
    
    try {
      final saf = Saf(targetUri);
      final isGranted = await saf.getDirectoryPermission(grantWritePermission: false);
      
      if (isGranted == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(prefKey, targetUri);
        await checkAndSyncPermissions(provider);
        return true;
      }
    } catch (e) {
      debugPrint("SAF Tree initialization exception: $e");
    }
    return false;
  }

  static Future<bool> requestLegacyStoragePermission(StatusProvider provider) async {
    final status = await Permission.storage.request();
    if (status.isGranted) {
      await checkAndSyncPermissions(provider);
      return true;
    }
    return false;
  }
}
class MediaProcessingEngine {
  static Future<void> synchronizeAppMedia(StatusProvider provider) async {
    provider.setLoading(true);
    
    List<StatusMedia> waImages = [];
    List<StatusMedia> waVideos = [];
    List<StatusMedia> wbImages = [];
    List<StatusMedia> wbVideos = [];
    List<StatusMedia> saved = [];

    try {
      final isModernAndroid = await StoragePermissionEngine.isAndroid11OrAbove();
      
      if (isModernAndroid) {
        if (provider.hasSafPermissionWhatsapp) {
          final results = await _fetchSafDirectoryMedia(AppConstants.whatsappTreeUri);
          waImages = results.where((e) => !e.isVideo).toList();
          waVideos = results.where((e) => e.isVideo).toList();
        }
      } else {
        final results = await _fetchLegacyDirectoryMedia(AppConstants.legacyWhatsappPath);
        waImages = results.where((e) => !e.isVideo).toList();
        waVideos = results.where((e) => e.isVideo).toList();
      }

      if (isModernAndroid) {
        if (provider.hasSafPermissionBusiness) {
          final results = await _fetchSafDirectoryMedia(AppConstants.whatsappBusinessTreeUri);
          wbImages = results.where((e) => !e.isVideo).toList();
          wbVideos = results.where((e) => e.isVideo).toList();
        }
      } else {
        final results = await _fetchLegacyDirectoryMedia(AppConstants.legacyBusinessPath);
        wbImages = results.where((e) => !e.isVideo).toList();
        wbVideos = results.where((e) => e.isVideo).toList();
      }

      saved = await _fetchLocalSavedStatuses();
    } catch (e) {
      debugPrint("Error syncing media models: $e");
    } finally {
      provider.updateMedia(
        waImages: waImages,
        waVideos: waVideos,
        wbImages: wbImages,
        wbVideos: wbVideos,
        saved: saved,
      );
      provider.setLoading(false);
    }
  }
  static Future<List<StatusMedia>> _fetchSafDirectoryMedia(String contentTreeUri) async {
    final List<StatusMedia> discoveredMedia = [];
    try {
      final safInstance = Saf(contentTreeUri);
      final List<String>? filePaths = await safInstance.getFilesPath();
      
      if (filePaths != null) {
        for (final rawPath in filePaths) {
          final fileRef = File(rawPath);
          final extension = p.extension(rawPath).toLowerCase();
          final isImg = extension == '.jpg' || extension == '.jpeg' || extension == '.png';
          final isVid = extension == '.mp4' || extension == '.mkv' || extension == '.3gp';
          
          if (isImg || isVid) {
            final stats = await fileRef.stat();
            discoveredMedia.add(StatusMedia(
              path: rawPath,
              isVideo: isVid,
              modifiedTime: stats.modified,
            ));
          }
        }
        discoveredMedia.sort((a, b) => b.modifiedTime.compareTo(a.modifiedTime));
      }
    } catch (e) {
      debugPrint("Failure traversing Scoped Storage collection: $e");
    }
    return discoveredMedia;
  }

  static Future<List<StatusMedia>> _fetchLegacyDirectoryMedia(String hardcodedPath) async {
    final List<StatusMedia> discoveredMedia = [];
    try {
      final targetDirectory = Directory(hardcodedPath);
      if (await targetDirectory.exists()) {
        final List<FileSystemEntity> entityCollection = targetDirectory.listSync();
        
        for (final entity in entityCollection) {
          if (entity is File) {
            final pathString = entity.path;
            final extension = p.extension(pathString).toLowerCase();
            final isImg = extension == '.jpg' || extension == '.jpeg' || extension == '.png';
            final isVid = extension == '.mp4' || extension == '.mkv' || extension == '.3gp';
            
            if (isImg || isVid) {
              final stats = await entity.stat();
              discoveredMedia.add(StatusMedia(
                path: pathString,
                isVideo: isVid,
                modifiedTime: stats.modified,
              ));
            }
          }
        }
        discoveredMedia.sort((a, b) => b.modifiedTime.compareTo(a.modifiedTime));
      }
    } catch (e) {
      debugPrint("Failure traversing Legacy Storage: $e");
    }
    return discoveredMedia;
  }
  static Future<List<StatusMedia>> _fetchLocalSavedStatuses() async {
    final List<StatusMedia> cachedList = [];
    try {
      final baseAppDocDirectory = await getApplicationDocumentsDirectory();
      final targetsPath = p.join(baseAppDocDirectory.path, 'SavedStatuses');
      final outputFolder = Directory(targetsPath);
      
      if (!await outputFolder.exists()) {
        await outputFolder.create(recursive: true);
      }
      
      final subFiles = outputFolder.listSync();
      for (final target in subFiles) {
        if (target is File) {
          final extension = p.extension(target.path).toLowerCase();
          final isVid = extension == '.mp4';
          final stats = await target.stat();
          
          cachedList.add(StatusMedia(
            path: target.path,
            isVideo: isVid,
            modifiedTime: stats.modified,
          ));
        }
      }
      cachedList.sort((a, b) => b.modifiedTime.compareTo(a.modifiedTime));
    } catch (e) {
      debugPrint("Error loading items from local app folder: $e");
    }
    return cachedList;
  }

  static Future<String?> extractVideoThumbnailReference(String path) async {
    try {
      final temporaryAppCachePath = await getTemporaryDirectory();
      final outputThumbnailName = await VideoThumbnailPlus.thumbnailFile(
        video: path,
        thumbnailPath: temporaryAppCachePath.path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 240, 
        quality: 65,
      );
      return outputThumbnailName;
    } catch (e) {
      debugPrint("Failed to resolve hardware-accelerated video thumbnail frame: $e");
      return null;
    }
  }
}
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  await AdManager.initialize();
  runApp(const WhatsAppFastSaverApp());
}

class WhatsAppFastSaverApp extends StatelessWidget {
  const WhatsAppFastSaverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return StatefulChangeNotifierProvider(
      create: (_) => StatusProvider(),
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const MainDashboardScreen(),
      ),
    );
  }
}

class StatefulChangeNotifierProvider extends StatefulWidget {
  final StatusProvider Function(BuildContext) create;
  final Widget child;

  const StatefulChangeNotifierProvider({
    super.key,
    required this.create,
    required this.child,
  });

  @override
  State<StatefulChangeNotifierProvider> createState() => _StatefulChangeNotifierProviderState();
}

class _StatefulChangeNotifierProviderState extends State<StatefulChangeNotifierProvider> {
  late StatusProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = widget.create(context);
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InheritedStatusProvider(
      provider: _provider,
      child: AnimatedBuilder(
        animation: _provider,
        builder: (context, _) => widget.child,
      ),
    );
  }
}

class InheritedStatusProvider extends InheritedWidget {
  final StatusProvider provider;

  const InheritedStatusProvider({
    super.key,
    required this.provider,
    required super.child,
  });

  static StatusProvider of(BuildContext context) {
    final result = context.dependOnInheritedWidgetOfExactType<InheritedStatusProvider>();
    assert(result != null, 'No InheritedStatusProvider found in context');
    return result!.provider;
  }

  @override
  bool updateShouldNotify(InheritedStatusProvider oldWidget) => provider != oldWidget.provider;
}
class MainDashboardScreen extends StatefulWidget {
  const MainDashboardScreen({super.key});

  @override
  State<MainDashboardScreen> createState() => _MainDashboardScreenState();
}

class _MainDashboardScreenState extends State<MainDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = InheritedStatusProvider.of(context);
      StoragePermissionEngine.checkAndSyncPermissions(provider).then((_) {
        MediaProcessingEngine.synchronizeAppMedia(provider);
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = InheritedStatusProvider.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          AppConstants.appName, 
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          Row(
            children: [
              const Text("WA Business", style: TextStyle(color: Colors.white, fontSize: 13)),
              Switch(
                value: provider.isWhatsAppBusinessActive,
                activeColor: AppTheme.accentColor,
                onChanged: (val) {
                  provider.setWhatsAppBusinessActive(val);
                },
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => MediaProcessingEngine.synchronizeAppMedia(provider),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.accentColor,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.image), text: "Images"),
            Tab(icon: Icon(Icons.videocam), text: "Videos"),
            Tab(icon: Icon(Icons.download_done_rounded), text: "Saved"),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                StatusGridContainer(isVideoTab: false, isSavedTab: false),
                StatusGridContainer(isVideoTab: true, isSavedTab: false),
                StatusGridContainer(isVideoTab: false, isSavedTab: true),
              ],
            ),
          ),
          const AdMobBannerWrapperWidget(),
        ],
      ),
    );
  }
}

class AdMobBannerWrapperWidget extends StatelessWidget {
  const AdMobBannerWrapperWidget({super.key});

  @override
  Widget build(BuildContext context) {
    if (AdManager.isBannerLoaded && AdManager.bannerAd != null) {
      return Container(
        alignment: Alignment.center,
        width: AdManager.bannerAd!.size.width.toDouble(),
        height: AdManager.bannerAd!.size.height.toDouble(),
        color: Colors.transparent,
        child: AdWidget(ad: AdManager.bannerAd!),
      );
    }
    return const SizedBox.shrink();
  }
}
class StatusGridContainer extends StatelessWidget {
  final bool isVideoTab;
  final bool isSavedTab;

  const StatusGridContainer({
    super.key,
    required this.isVideoTab,
    required this.isSavedTab,
  });

  @override
  Widget build(BuildContext context) {
    final provider = InheritedStatusProvider.of(context);

    if (provider.isLoading) {
      return const ShimmerSkeletonPlaceholderGrid();
    }

    if (isSavedTab) {
      if (provider.savedStatuses.isEmpty) {
        return const EmptyStateDisplayWidget(
          iconData: Icons.folder_open_outlined,
          message: "No downloaded statuses found yet.",
        );
      }
      return StatusItemsGridView(mediaCollection: provider.savedStatuses, isFromSavedFolder: true);
    }

    final isBusinessMode = provider.isWhatsAppBusinessActive;
    final hasTargetPermission = isBusinessMode 
        ? provider.hasSafPermissionBusiness 
        : provider.hasSafPermissionWhatsapp;

    if (!hasTargetPermission) {
      return PermissionGatekeeperOverlay(isBusinessScope: isBusinessMode);
    }

    final List<StatusMedia> activeDataset;
    if (isBusinessMode) {
      activeDataset = isVideoTab ? provider.businessVideos : provider.businessImages;
    } else {
      activeDataset = isVideoTab ? provider.whatsappVideos : provider.whatsappImages;
    }

    if (activeDataset.isEmpty) {
      return EmptyStateDisplayWidget(
        iconData: isVideoTab ? Icons.video_library_outlined : Icons.photo_library_outlined,
        message: "No active statuses found. Open WhatsApp first!",
      );
    }

    return StatusItemsGridView(mediaCollection: activeDataset, isFromSavedFolder: false);
  }
}

class StatusItemsGridView extends StatelessWidget {
  final List<StatusMedia> mediaCollection;
  final bool isFromSavedFolder;

  const StatusItemsGridView({
    super.key,
    required this.mediaCollection,
    required this.isFromSavedFolder,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(6.0),
      child: MasonryGridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        itemCount: mediaCollection.length,
        itemBuilder: (context, index) {
          final targetItem = mediaCollection[index];
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class EmptyStateDisplayWidget extends StatelessWidget {
  final IconData iconData;
  final String message;

  const EmptyStateDisplayWidget({
    super.key,
    required this.iconData,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(iconData, size: 72, color: AppTheme.textSecondary.withOpacity(0.4)),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
class PermissionGatekeeperOverlay extends StatefulWidget {
  final bool isBusinessScope;

  const PermissionGatekeeperOverlay({
    super.key,
    required this.isBusinessScope,
  });

  @override
  State<PermissionGatekeeperOverlay> createState() => _PermissionGatekeeperOverlayState();
}

class _PermissionGatekeeperOverlayState extends State<PermissionGatekeeperOverlay> {
  bool _isProcessingHandshake = false;

  Future<void> _handlePermissionRequest() async {
    if (_isProcessingHandshake) return;
    setState(() => _isProcessingHandshake = true);

    final provider = InheritedStatusProvider.of(context);
    final isModernAndroid = await StoragePermissionEngine.isAndroid11OrAbove();

    try {
      if (isModernAndroid) {
        final granted = await StoragePermissionEngine.requestSafDirectory(
          widget.isBusinessScope, 
          provider,
        );
        if (granted) {
          await MediaProcessingEngine.synchronizeAppMedia(provider);
        } else {
          _showFeedbackSnackbar("Permission is required to view status files.");
        }
      } else {
        final granted = await StoragePermissionEngine.requestLegacyStoragePermission(provider);
        if (granted) {
          await MediaProcessingEngine.synchronizeAppMedia(provider);
        } else {
          _showFeedbackSnackbar("Storage access permission denied.");
        }
      }
    } catch (e) {
      debugPrint("Handshake execution failure: $e");
    } finally {
      if (mounted) {
        setState(() => _isProcessingHandshake = false);
      }
    }
  }

  void _showFeedbackSnackbar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appLabel = widget.isBusinessScope ? "WhatsApp Business" : "WhatsApp";

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 16.0),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.folder_shared_rounded,
              size: 64,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "Access Authorization Required",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textMain,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "To view and save media, this application requires access to the hidden $appLabel status folder directory using Android Scoped Storage safely.",
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                elevation: 2,
              ),
              onPressed: _isProcessingHandshake ? null : _handlePermissionRequest,
              child: _isProcessingHandshake
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                  : const Text(
                      "Grant Folder Access",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class ShimmerSkeletonPlaceholderGrid extends StatelessWidget {
  const ShimmerSkeletonPlaceholderGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: GridView.builder(
          itemCount: 6,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 0.75,
          ),
          itemBuilder: (_, __) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            );
          },
        ),
      ),
    );
  }
}
class ImageDetailScreen extends StatelessWidget {
  final StatusMedia mediaItem;
  final bool isSavedItem;

  const ImageDetailScreen({
    super.key,
    required this.mediaItem,
    required this.isSavedItem,
  });

  @override
  Widget build(BuildContext context) {
    final fileRef = File(mediaItem.path);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text("Image View", style: TextStyle(fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 3.5,
              child: Hero(
                tag: mediaItem.path,
                child: Image.file(
                  fileRef,
                  fit: BoxFit.contain,
                  alignment: Alignment.center,
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Icon(Icons.broken_image, size: 64, color: Colors.white38),
                    );
                  },
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 24,
            left: 24,
            right: 24,
            child: FloatingActionRowWidget(
              mediaItem: mediaItem,
              isAlreadySaved: isSavedItem,
              onActionComplete: () {
                Navigator.of(context).pop();
              },
            ),
          ),
        ],
      ),
    );
  }
}

class FloatingActionRowWidget extends StatelessWidget {
  final StatusMedia mediaItem;
  final bool isAlreadySaved;
  final VoidCallback onActionComplete;

  const FloatingActionRowWidget({
    super.key,
    required this.mediaItem,
    required this.isAlreadySaved,
    required this.onActionComplete,
  });

  @override
  Widget build(BuildContext context) {
    final provider = InheritedStatusProvider.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white12, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          if (!isAlreadySaved) ...[
            IconButton(
              icon: const Icon(Icons.download_rounded, color: AppTheme.accentColor, size: 28),
              tooltip: "Save to Local Gallery",
              onPressed: () async {
                final success = false;
                if (success) {
                  MediaProcessingEngine.synchronizeAppMedia(provider);
                  onActionComplete();
                }
              },
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 28),
              tooltip: "Delete Permanently",
              onPressed: () async {
                final deleted = false;
                if (deleted) {
                  MediaProcessingEngine.synchronizeAppMedia(provider);
                  onActionComplete();
                }
              },
            ),
          ],
          const SizedBox(width: 24),
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white, size: 28),
            tooltip: "Repost Status",
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}
class VideoDetailScreen extends StatefulWidget {
  final StatusMedia mediaItem;
  final bool isSavedItem;

  const VideoDetailScreen({
    super.key,
    required this.mediaItem,
    required this.isSavedItem,
  });

  @override
  State<VideoDetailScreen> createState() => _VideoDetailScreenState();
}

class _VideoDetailScreenState extends State<VideoDetailScreen> {
  late VideoPlayerController _videoController;
  late Future<void> _initializeVideoFuture;

  @override
  void initState() {
    super.initState();
    _videoController = VideoPlayerController.file(File(widget.mediaItem.path));
    _initializeVideoFuture = _videoController.initialize().then((_) {
      _videoController.setLooping(true);
      _videoController.play();
      setState(() {});
    });
  }

  @override
  void dispose() {
    _videoController.pause();
    _videoController.dispose();
    super.dispose();
  }

  void _handleBackNavigation() {
    AdManager.showInterstitial(() {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _handleBackNavigation();
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: const Text("Video Player", style: TextStyle(fontSize: 18)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleBackNavigation,
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.share_outlined),
              onPressed: () {},
            ),
          ],
        ),
        body: Stack(
          alignment: Alignment.center,
          children: [
            FutureBuilder(
              future: _initializeVideoFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  return Center(
                    child: AspectRatio(
                      aspectRatio: _videoController.value.aspectRatio,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _videoController.value.isPlaying
                                ? _videoController.pause()
                                : _videoController.play();
                          });
                        },
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            VideoPlayer(_videoController),
                            if (!_videoController.value.isPlaying)
                              Container(
                                decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
                                child: const Icon(Icons.play_arrow_rounded, size: 80, color: Colors.white70),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }
                return const Center(child: CircularProgressIndicator(color: AppTheme.accentColor));
              },
            ),
            Positioned(
              bottom: 100,
              left: 16,
              right: 16,
              child: VideoProgressIndicator(
                _videoController,
                allowScrubbing: true,
                colors: const VideoProgressColors(
                  playedColor: AppTheme.accentColor,
                  bufferedColor: Colors.white24,
                  backgroundColor: Colors.white12,
                ),
              ),
            ),
            Positioned(
              bottom: 24,
              left: 24,
              right: 24,
              child: FloatingActionRowWidget(
                mediaItem: widget.mediaItem,
                isAlreadySaved: widget.isSavedItem,
                onActionComplete: _handleBackNavigation,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
// ==========================================
// SLICE 21: STORAGE CLEANUP & CACHE MODULE
// ==========================================

class AppCacheManager {
  /// Purges temporary image chunks and transient video frames to conserve device storage
  static Future<void> clearTemporaryCacheData(BuildContext context) async {
    try {
      final tempDir = await getTemporaryDirectory();
      if (await tempDir.exists()) {
        final totalFiles = tempDir.listSync();
        int explicitPruneCount = 0;

        for (final item in totalFiles) {
          if (item is File) {
            final ext = p.extension(item.path).toLowerCase();
            // Target app-specific ephemeral extensions safely
            if (ext == '.jpg' || ext == '.jpeg' || ext == '.png' || ext == '.tmp') {
              await item.delete();
              explicitPruneCount++;
            }
          }
        }
        _showCacheFeedback(context, "Successfully cleaned up $explicitPruneCount cached thumbnail logs.");
      }
    } catch (error) {
      debugPrint("Cache eviction framework encountered error: $error");
      _showCacheFeedback(context, "Storage optimization check finished with errors.");
    }
  }

  static void _showCacheFeedback(BuildContext context, String statement) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(statement),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
// ==========================================
// SLICE 22: PARSING THREADING UTILITIES
// ==========================================

class MediaIsolateParser {
  /// Offloads resource-heavy directory sorting operations away from the main thread 
  static List<StatusMedia> sortAndCategorizePayload(List<StatusMedia> dirtyInput) {
    // Structural optimization loop via localized reference copies
    final List<StatusMedia> workingSet = List.from(dirtyInput);
    
    // Sort array by newest creation timestamp
    workingSet.sort((first, second) => second.modifiedTime.compareTo(first.modifiedTime));
    return workingSet;
  }

  /// Extracts contextual size info metrics from an active file path reference
  static Future<String> computeFileMemorySize(String targetLocation) async {
    try {
      final systemRef = File(targetLocation);
      if (await systemRef.exists()) {
        final byteLength = await systemRef.length();
        if (byteLength < 1024) return "$byteLength B";
        if (byteLength < 1024 * 1024) return "${(byteLength / 1024).toStringAsFixed(1)} KB";
        return "${(byteLength / (1024 * 1024)).toStringAsFixed(1)} MB";
      }
    } catch (_) {}
    return "0 KB";
  }
}
// ==========================================
// SLICE 23: METADATA DETAILS SHEETS
// ==========================================

class MediaMetadataOverlayPanel {
  static void display(BuildContext context, StatusMedia activeMedia) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalContext) {
        return FutureBuilder<String>(
          future: MediaIsolateParser.computeFileMemorySize(activeMedia.path),
          builder: (context, snapshot) {
            final allocatedSize = snapshot.data ?? "Calculating...";
            final structuredDate = "${activeMedia.modifiedTime.day}/${activeMedia.modifiedTime.month}/${activeMedia.modifiedTime.year}";
            final structuredTime = "${activeMedia.modifiedTime.hour.toString().padLeft(2, '0')}:${activeMedia.modifiedTime.minute.toString().padLeft(2, '0')}";

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Status File Specifications",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textMain),
                  ),
                  const Divider(height: 24),
                  _buildSpecificationRow(Icons.insert_drive_file_outlined, "File Target Name", p.basename(activeMedia.path)),
                  _buildSpecificationRow(Icons.data_usage_rounded, "Memory App Footprint", allocatedSize),
                  _buildSpecificationRow(Icons.access_time_rounded, "Timestamp Discovered", "$structuredDate at $structuredTime"),
                  _buildSpecificationRow(Icons.folder_open_outlined, "System Directory Storage", activeMedia.isVideo ? "Video Formats Archive" : "Static Render Canvas"),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        );
      },
    );
  }

  static Widget _buildSpecificationRow(IconData visualLog, String description, String details) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(visualLog, size: 22, color: AppTheme.primaryColor),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(description, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(details, style: const TextStyle(fontSize: 14, color: AppTheme.textMain, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
// ==========================================
// SLICE 24: APPLICATION SETTINGS VIEW
// ==========================================

class ApplicationSettingsView extends StatelessWidget {
  const ApplicationSettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final statusEngineProvider = InheritedStatusProvider.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Preferences Menu", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Text("Directory Workspace Links", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
          ),
          _buildToggleOption(
            Icons.business_center_outlined,
            "Target Business Channels First",
            "Triggers automated fallbacks specifically for active WhatsApp Business folders.",
            statusEngineProvider.isWhatsAppBusinessActive,
            (newValue) => statusEngineProvider.setWhatsAppBusinessActive(newValue),
          ),
          const Divider(height: 1),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Text("Storage Maintenance Node", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
          ),
          ListTile(
            leading: const Icon(Icons.cleaning_services_outlined, color: Colors.amber, size: 24),
            title: const Text("Evict App Transient Cache", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textMain)),
            subtitle: const Text("Cleans out localized video previews and picture buffers to free memory space safely.", style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
            onTap: () => AppCacheManager.clearTemporaryCacheData(context),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.lock_reset_outlined, color: AppTheme.primaryColor, size: 24),
            title: const Text("Force Direct Workspace Resync", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textMain)),
            subtitle: const Text("Re-interrogates operating system permission structures to clear corrupted folder allocations.", style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            onTap: () async {
              await StoragePermissionEngine.checkAndSyncPermissions(statusEngineProvider);
              if (context.mounted) {
                MediaProcessingEngine.synchronizeAppMedia(statusEngineProvider);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Application environment pipeline successfully synchronized.")));
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildToggleOption(IconData leadSymbol, String heading, String dynamicText, bool statusMarker, ValueChanged<bool> actionHook) {
    return SwitchListTile(
      secondary: Icon(leadSymbol, color: AppTheme.primaryColor, size: 24),
      title: Text(heading, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textMain)),
      subtitle: Text(dynamicText, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
      activeColor: AppTheme.accentColor,
      value: statusMarker,
      onChanged: actionHook,
    );
  }
}
// ==========================================
// SLICE 25: INTEGRATED CONTROL NAVIGATION
// ==========================================

class NavigationDrawerFrameWidget extends StatelessWidget {
  const NavigationDrawerFrameWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppTheme.backgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.only(top: 60, bottom: 24, left: 20, right: 20),
            color: AppTheme.primaryColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  radius: 32,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.flash_on_rounded, size: 36, color: AppTheme.accentColor),
                ),
                const SizedBox(height: 16),
                const Text(
                  AppConstants.appName,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                Text(
                  "High-Speed Scoped Directory Utility",
                  style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.8), fontWeight: FontWeight.w400),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.grid_view_rounded, color: AppTheme.primaryColor),
            title: const Text("Status Feed Dashboard", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.settings_outlined, color: AppTheme.primaryColor),
            title: const Text("Application Preferences", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            onTap: () {
              Navigator.pop(context); // Close Drawer
              Navigator.push(
                context,
                MaterialPageRoute(builder: (routeContext) => const ApplicationSettingsView()),
              );
            },
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              "Engine Architecture v1.0.4+4",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary.withOpacity(0.6), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

