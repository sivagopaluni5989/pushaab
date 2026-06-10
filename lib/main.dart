import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';

import 'package:saf/saf.dart';

import 'package:video_player/video_player.dart';
import 'package:video_thumbnail_plus/video_thumbnail_plus.dart';

import 'package:gallery_saver_plus/gallery_saver.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';

import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:shimmer/shimmer.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await MobileAds.instance.initialize();

  runApp(const MyApp());
}

class AppConfig {
  static const String appName = 'WA Status Fast Saver';

  static const String bannerAdUnitId = 'ca-app-pub-8147663138065818/2224393560';

  static const String contentChannel =
      'com.bravesstudio.wastatusfastsaver/content_reader';

  static const String whatsappFolder =
      'Android/media/com.whatsapp/WhatsApp/Media/.Statuses';

  static const String businessFolder =
      'Android/media/com.whatsapp.w4b/WhatsApp Business/Media/.Statuses';

  static const String waPermission = 'wa_permission';

  static const String wbPermission = 'wb_permission';
}

class StatusItem {
  final String path;

  final bool isVideo;

  String? thumbnailPath;

  StatusItem({
    required this.path,
    required this.isVideo,
    this.thumbnailPath,
  });
}

class NativeContentReader {
  static const MethodChannel _channel = MethodChannel(
    AppConfig.contentChannel,
  );

  static Future<String?> copyToTemp(
    String uri,
  ) async {
    try {
      return await _channel.invokeMethod<String>(
        'readContentUriToFile',
        {
          'uri': uri,
        },
      );
    } catch (_) {
      return null;
    }
  }
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: AppConfig.appName,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.green,
      ),
      home: const StatusHomePage(),
    );
  }
}

class PermissionService {
  static Future<bool> requestMediaPermission() async {
    final info = await DeviceInfoPlugin().androidInfo;

    if (info.version.sdkInt >= 33) {
      final photos = await Permission.photos.request();

      final videos = await Permission.videos.request();

      return photos.isGranted || videos.isGranted;
    }

    final storage = await Permission.storage.request();

    return storage.isGranted;
  }
}

class SafService {
  static final Saf whatsapp = Saf(
    AppConfig.whatsappFolder,
  );

  static final Saf business = Saf(
    AppConfig.businessFolder,
  );
}

class PermissionStorage {
  static Future<bool> hasWhatsAppPermission() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getBool(
          AppConfig.waPermission,
        ) ??
        false;
  }

  static Future<bool> hasBusinessPermission() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getBool(
          AppConfig.wbPermission,
        ) ??
        false;
  }

  static Future<void> setWhatsAppPermission(
    bool value,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool(
      AppConfig.waPermission,
      value,
    );
  }

  static Future<void> setBusinessPermission(
    bool value,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool(
      AppConfig.wbPermission,
      value,
    );
  }
}

extension SafPermissionExtension on SafService {
  static Future<bool> requestWhatsAppPermission() async {
    try {
      final granted = await SafService.whatsapp.getDirectoryPermission(
        isDynamic: false,
        grantWritePermission: false,
      );

      if (granted == true) {
        await PermissionStorage.setWhatsAppPermission(
          true,
        );

        return true;
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> requestBusinessPermission() async {
    try {
      final granted = await SafService.business.getDirectoryPermission(
        isDynamic: false,
        grantWritePermission: false,
      );

      if (granted == true) {
        await PermissionStorage.setBusinessPermission(
          true,
        );

        return true;
      }

      return false;
    } catch (_) {
      return false;
    }
  }
}

class ThumbnailService {
  static Future<String?> createThumbnail(
    String path,
    bool isVideo,
  ) async {
    try {
      if (!isVideo) {
        return path;
      }

      final tempDir = await getTemporaryDirectory();

      return await VideoThumbnailPlus.thumbnailFile(
        video: path,
        thumbnailPath: tempDir.path,
        imageFormat: ImageFormat.JPEG,
        quality: 90,
      );
    } catch (e, s) {
      debugPrint('THUMBNAIL ERROR: $e');
      debugPrint('$s');
      return null;
    }
  }
}

class StatusLoader {
  static bool isImage(
    String file,
  ) {
    final lower = file.toLowerCase();

    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp');
  }

  static bool isVideo(
    String file,
  ) {
    final lower = file.toLowerCase();

    return lower.endsWith('.mp4') ||
        lower.endsWith('.3gp') ||
        lower.endsWith('.mkv');
  }

  static Future<List<StatusItem>> loadStatuses(
    Saf saf,
  ) async {
    try {
     final files = await saf.getFilesPath();

debugPrint('FILES FOUND: ${files?.length}');
debugPrint('FILES LIST: $files');

debugPrint(
  'FILES FOUND: ${files?.length}',
);

debugPrint(
  'FILES LIST: $files',
);

if (files == null || files.isEmpty) {
  debugPrint(
    'NO FILES RETURNED FROM SAF',
  );

  return [];
}

      final items = <StatusItem>[];

      for (final file in files) {
  debugPrint('FILE => $file');

  if (isImage(file)) {
    items.add(
      StatusItem(
        path: file,
        isVideo: false,
      ),
    );
  }

  if (isVideo(file)) {
    items.add(
      StatusItem(
        path: file,
        isVideo: true,
      ),
    );
  }
}

      for (final item in items) {
        item.thumbnailPath = await ThumbnailService.createThumbnail(
          item.path,
          item.isVideo,
        );
      }

      items.sort(
        (a, b) => b.path.compareTo(
          a.path,
        ),
      );

      return items;
    } catch (e, s) {
      debugPrint('LOAD STATUS ERROR: $e');
      debugPrint('$s');
      return [];
    }
  }
}

class StatusHomePage extends StatefulWidget {
  const StatusHomePage({
    super.key,
  });

  @override
  State<StatusHomePage> createState() => _StatusHomePageState();
}

class _StatusHomePageState extends State<StatusHomePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  BannerAd? _bannerAd;

  bool _bannerLoaded = false;

  bool _loading = true;

  List<StatusItem> whatsappStatuses = [];

  List<StatusItem> businessStatuses = [];

  @override
  void initState() {
    super.initState();

    _tabController = TabController(
      length: 2,
      vsync: this,
    );

    _loadBanner();

    _startup();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();

    _tabController.dispose();

    super.dispose();
  }

  void _loadBanner() {
    _bannerAd = BannerAd(
      size: AdSize.banner,
      adUnitId: AppConfig.bannerAdUnitId,
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (!mounted) {
            return;
          }

          setState(() {
            _bannerLoaded = true;
          });
        },
      ),
      request: const AdRequest(),
    );

    _bannerAd!.load();
  }

  Future<void> _startup() async {
    await PermissionService.requestMediaPermission();

    await _ensurePermissions();

    await _loadStatuses();
  }

  Future<void> _ensurePermissions() async {
    final waGranted = await PermissionStorage.hasWhatsAppPermission();

    final wbGranted = await PermissionStorage.hasBusinessPermission();

    if (!waGranted) {
      await SafPermissionExtension.requestWhatsAppPermission();
    }

    if (!wbGranted) {
      await SafPermissionExtension.requestBusinessPermission();
    }
  }

  Future<void> _loadStatuses() async {
    if (mounted) {
      setState(() {
        _loading = true;
      });
    }

    final wa = await StatusLoader.loadStatuses(
      SafService.whatsapp,
    );

    final wb = await StatusLoader.loadStatuses(
      SafService.business,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      whatsappStatuses = wa;

      businessStatuses = wb;

      _loading = false;
    });
  }

  Future<void> _refresh() async {
    await _loadStatuses();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'WA Status Fast Saver',
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(
              Icons.refresh,
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              icon: Icon(
                Icons.chat,
              ),
              text: 'WhatsApp',
            ),
            Tab(
              icon: Icon(
                Icons.business,
              ),
              text: 'Business',
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_bannerLoaded && _bannerAd != null)
            SizedBox(
              width: _bannerAd!.size.width.toDouble(),
              height: _bannerAd!.size.height.toDouble(),
              child: AdWidget(
                ad: _bannerAd!,
              ),
            ),
          Expanded(
            child: _loading
                ? _buildLoading()
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildStatusGrid(
                        whatsappStatuses,
                      ),
                      _buildStatusGrid(
                        businessStatuses,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return MasonryGridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      padding: const EdgeInsets.all(
        12,
      ),
      itemCount: 10,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey.shade300,
          highlightColor: Colors.grey.shade100,
          child: Container(
            height: 180,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(
                16,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusGrid(
    List<StatusItem> items,
  ) {
    if (items.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: MasonryGridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        padding: const EdgeInsets.all(
          12,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];

          return _buildCard(
            item,
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(
          24,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.hourglass_empty,
              size: 90,
              color: Colors.grey.shade400,
            ),
            const SizedBox(
              height: 20,
            ),
            const Text(
              'No statuses found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(
              height: 12,
            ),
            Text(
              'Open WhatsApp and view at least one status, then press Refresh.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(
              height: 24,
            ),
            ElevatedButton.icon(
              onPressed: _refresh,
              icon: const Icon(
                Icons.refresh,
              ),
              label: const Text(
                'Refresh',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(
    StatusItem item,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(
        16,
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PreviewScreen(
              item: item,
            ),
          ),
        );
      },
      child: Card(
        elevation: 3,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            16,
          ),
        ),
        child: Stack(
          children: [
            AspectRatio(
              aspectRatio: 0.70,
              child: item.thumbnailPath == null
                  ? Container(
                      color: Colors.grey.shade200,
                    )
                  : Image.file(
                      File(
                        item.thumbnailPath!,
                      ),
                      fit: BoxFit.cover,
                    ),
            ),
            if (item.isVideo)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(
                    6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(
                      50,
                    ),
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class PreviewScreen extends StatefulWidget {
  final StatusItem item;

  const PreviewScreen({
    super.key,
    required this.item,
  });

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  VideoPlayerController? _videoController;

  bool _loading = true;

  @override
  void initState() {
    super.initState();

    _initialize();
  }

  Future<void> _initialize() async {
    if (!widget.item.isVideo) {
      setState(() {
        _loading = false;
      });

      return;
    }

    _videoController = VideoPlayerController.file(
      File(widget.item.path),
    );

    await _videoController!.initialize();

    await _videoController!.setLooping(true);

    await _videoController!.play();

    if (!mounted) {
      return;
    }

    setState(() {
      _loading = false;
    });
  }

  @override
  void dispose() {
    _videoController?.dispose();

    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.item.isVideo ? 'Video Preview' : 'Image Preview',
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : Column(
              children: [
                Expanded(
                  child: Center(
                    child: widget.item.isVideo
                        ? AspectRatio(
                            aspectRatio: _videoController!.value.aspectRatio,
                            child: VideoPlayer(
                              _videoController!,
                            ),
                          )
                        : InteractiveViewer(
                            child: Image.file(
                              File(
                                widget.item.path,
                              ),
                              fit: BoxFit.contain,
                            ),
                          ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(
                    16,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton.icon(
                      onPressed: _saveStatus,
                      icon: const Icon(
                        Icons.download,
                      ),
                      label: const Text(
                        'Save Status',
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _saveStatus() async {
    try {
      bool? result;

      if (widget.item.isVideo) {
        result = await GallerySaver.saveVideo(
          widget.item.path,
          albumName: 'StatusSaver',
        );
      } else {
        result = await GallerySaver.saveImage(
          widget.item.path,
          albumName: 'StatusSaver',
        );
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result == true
                ? 'Status saved successfully'
                : 'Unable to save status',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Save failed: $e',
          ),
        ),
      );
    }
  }
}
