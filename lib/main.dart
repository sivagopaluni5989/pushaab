// lib/main.dart
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:saf/saf.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail_plus/video_thumbnail_plus.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:shimmer/shimmer.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
class SafHelper {
  static const String whatsappKey = "whatsapp_status_uri";
  static const String businessKey = "business_status_uri";

  static Future<String?> getPersistedUri(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  static Future<void> persistUri(String key, String uri) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, uri);
  }
}
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MobileAds.instance.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'WA Status Fast Saver',
      theme: ThemeData(
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
      ),
      home: const StatusScreen(),
    );
  }
}
class StatusScreen extends StatefulWidget {
  const StatusScreen({super.key});
  @override
  State<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen>
    with SingleTickerProviderStateMixin {
  // Platform channel name must match MainActivity.kt
  static const MethodChannel _contentReaderChannel =
      MethodChannel('com.bravesstudio.wastatusfastsaver/content_reader');

  late TabController _tabController;
  List<String> generalFiles = [];
  List<String> businessFiles = [];
  Map<String, String> videoThumbnails = {}; // uri -> temp thumbnail path
  Map<String, String> tempCache = {}; // uri -> temp file path
  bool isLoading = false;
  BannerAd? bannerAd;
  bool adLoaded = false;
  final String whatsappUri = "content://com.whatsapp.provider.statuses";
  final String businessUri = "content://com.whatsapp.w4b.provider.statuses";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    loadBanner();
    loadStatuses();
  }

  @override
  void dispose() {
    _tabController.dispose();
    bannerAd?.dispose();
    super.dispose();
  }
  void loadBanner() {
    bannerAd = BannerAd(
      size: AdSize.banner,
      adUnitId: Platform.isAndroid ? 'ca-app-pub-3940256099942544/6300978111' : '',
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() => adLoaded = true),
        onAdFailedToLoad: (ad, error) => ad.dispose(),
      ),
      request: const AdRequest(),
    )..load();
  }

  Future<String?> _readContentUriViaPlatform(String uri) async {
    try {
      final String? tempPath =
          await _contentReaderChannel.invokeMethod('readContentUriToFile', {'uri': uri});
      return tempPath;
    } catch (e) {
      debugPrint('Platform readContentUriToFile failed: $e');
      return null;
    }
  }
  // Copies a content URI to a temporary file and returns the temp file path.
  // This implementation uses the Android platform channel fallback exclusively
  // for reading content:// URIs to avoid compile-time SAF API mismatches.
  Future<String?> copyUriToTempFile(String uri) async {
    try {
      if (tempCache.containsKey(uri)) {
        final cached = tempCache[uri]!;
        if (await File(cached).exists()) return cached;
        tempCache.remove(uri);
      }

      // Use platform channel to read content URI into a temp file on Android
      final platformPath = await _readContentUriViaPlatform(uri);
      if (platformPath != null && platformPath.isNotEmpty) {
        tempCache[uri] = platformPath;
        return platformPath;
      }

      debugPrint('copyUriToTempFile: platform channel failed for $uri');
      return null;
    } catch (e, st) {
      debugPrint('copyUriToTempFile error: $e\n$st');
      return null;
    }
  }
  Future<void> generateAllThumbnails(List<String> files) async {
    try {
      final tempDir = await getTemporaryDirectory();
      const chunkSize = 6;
      for (var i = 0; i < files.length; i += chunkSize) {
        final chunk = files.skip(i).take(chunkSize).toList();
        await Future.wait(chunk.map((uri) async {
          if (uri.endsWith('.mp4') && !videoThumbnails.containsKey(uri)) {
            final tempPath = await copyUriToTempFile(uri);
            if (tempPath != null) {
              final thumb = await VideoThumbnailPlus.thumbnailFile(
                video: tempPath,
                thumbnailPath: tempDir.path,
                imageFormat: ImageFormat.JPEG,
                quality: 80,
                maxWidth: 600,
              );
              if (thumb != null) videoThumbnails[uri] = thumb;
            }
          } else if (!uri.endsWith('.mp4') && !videoThumbnails.containsKey(uri)) {
            final tempPath = await copyUriToTempFile(uri);
            if (tempPath != null) videoThumbnails[uri] = tempPath;
          }
        }));
      }
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('generateAllThumbnails error: $e');
    }
  }
  Future<void> loadStatuses() async {
    setState(() => isLoading = true);
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      if (info.version.sdkInt >= 30) {
        generalFiles = await loadSafFiles(whatsappUri, SafHelper.whatsappKey);
        businessFiles = await loadSafFiles(businessUri, SafHelper.businessKey);
      } else {
        final status = await Permission.storage.request();
        if (status.isGranted) {
          generalFiles = await loadSafFiles(whatsappUri, SafHelper.whatsappKey);
          businessFiles = await loadSafFiles(businessUri, SafHelper.businessKey);
        } else {
          generalFiles = [];
          businessFiles = [];
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Storage permission required on this device')),
            );
          }
        }
      }
      await generateAllThumbnails([...generalFiles, ...businessFiles]);
    } catch (e, st) {
      debugPrint('loadStatuses error: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load statuses: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }
  // loadSafFiles: use persisted tree URI or defaultUri and request directory permission.
  // Do not call SAF methods that are not present in the installed package.
  Future<List<String>> loadSafFiles(String defaultUri, String key) async {
    try {
      final prefsUri = await SafHelper.getPersistedUri(key);
      debugPrint('SAF: persistedUri from prefs = $prefsUri');

      String? treeUri = prefsUri ?? defaultUri;

      final saf = Saf(treeUri);
      final permission = await saf.getDirectoryPermission(isDynamic: true);
      debugPrint('SAF: getDirectoryPermission for $treeUri => $permission');

      if (permission == true) {
        final files = await saf.getFilesPath();
        debugPrint('SAF: files returned count = ${files?.length ?? 0}');
        debugPrint('SAF: sample files = ${files?.take(5).toList()}');
        if (files != null && files.isNotEmpty) {
          return files.where((file) =>
              file.endsWith('.jpg') ||
              file.endsWith('.jpeg') ||
              file.endsWith('.png') ||
              file.endsWith('.mp4')).toList();
        } else {
          debugPrint('SAF: no files found in treeUri');
          return [];
        }
      } else {
        debugPrint('SAF: permission denied for $treeUri');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Folder access required to read statuses. Please pick the folder.')),
          );
        }
        return [];
      }
    } catch (e, st) {
      debugPrint('SAF ERROR: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Storage access failed: $e')),
        );
      }
      return [];
    }
  }
  Future<void> saveStatus(String uri) async {
    try {
      final tempPath = await copyUriToTempFile(uri);
      if (tempPath == null) throw Exception('Unable to read status');

      final file = File(tempPath);
      final isVideo = file.path.endsWith('.mp4');

      final targetDir = Directory(
        isVideo ? '/storage/emulated/0/Movies/StatusSaver' : '/storage/emulated/0/Pictures/StatusSaver'
      );

      if (!await targetDir.exists()) await targetDir.create(recursive: true);

      final ext = p.extension(tempPath).isNotEmpty ? p.extension(tempPath) : (isVideo ? '.mp4' : '.jpg');
      final fileName = '${DateTime.now().millisecondsSinceEpoch}$ext';
      final savedPath = '${targetDir.path}/$fileName';
      final savedFile = await file.copy(savedPath);

      if (isVideo) await GallerySaver.saveVideo(savedFile.path);
      else await GallerySaver.saveImage(savedFile.path);

      try {
        await File(tempPath).delete();
        tempCache.remove(uri);
      } catch (e) {
        debugPrint('Failed to delete temp file: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved Successfully'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
  Widget buildGrid(List<String> files) {
    if (files.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'No statuses found.\n\nOpen WhatsApp and watch statuses first.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(10),
      child: MasonryGridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        itemCount: files.length,
        itemBuilder: (context, index) {
          final uri = files[index];
          final isVideo = uri.endsWith('.mp4');
          final thumbPath = videoThumbnails[uri];
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.95, end: 1.0),
            duration: const Duration(milliseconds: 420),
            builder: (context, scale, child) {
              return Transform.scale(
                scale: scale,
                child: child,
              );
            },
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.6),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12)],
              ),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                    child: Hero(
                      tag: uri,
                      child: GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => PreviewScreen(uri: uri, isVideo: isVideo)),
                        ),
                        child: thumbPath != null
                            ? Stack(
                                children: [
                                  Image.file(File(thumbPath), fit: BoxFit.cover, width: double.infinity),
                                  if (isVideo)
                                    Positioned(
                                      left: 8,
                                      top: 8,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.5),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Icon(Icons.play_arrow, color: Colors.white),
                                      ),
                                    ),
                                ],
                              )
                            : SizedBox(
                                height: 180,
                                child: Shimmer.fromColors(
                                  baseColor: Colors.grey.shade300,
                                  highlightColor: Colors.grey.shade100,
                                  child: Container(color: Colors.white),
                                ),
                              ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: ElevatedButton.icon(
                      onPressed: () => saveStatus(uri),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 4,
                      ),
                      icon: const Icon(Icons.download),
                      label: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green, Colors.teal],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Text(
          'WA Status Fast Saver',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          indicatorWeight: 4,
          tabs: const [
            Tab(icon: Icon(Icons.chat), text: 'WhatsApp'),
            Tab(icon: Icon(Icons.business), text: 'Business'),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          : TabBarView(
              controller: _tabController,
              children: [
                buildGrid(generalFiles),
                buildGrid(businessFiles),
              ],
            ),
      bottomNavigationBar: adLoaded
          ? SizedBox(
              height: bannerAd!.size.height.toDouble(),
              width: bannerAd!.size.width.toDouble(),
              child: AdWidget(ad: bannerAd!),
            )
          : null,
    );
  }
}

// PreviewScreen accepts a URI and copies to temp before playing/displaying
class PreviewScreen extends StatefulWidget {
  final String uri;
  final bool isVideo;

  const PreviewScreen({super.key, required this.uri, required this.isVideo});

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  VideoPlayerController? controller;
  String? tempPath;

  @override
  void initState() {
    super.initState();
    if (widget.isVideo) _prepareVideo();
    else _prepareImage();
  }

  Future<void> _prepareVideo() async {
    final parentState = context.findAncestorStateOfType<_StatusScreenState>();
    tempPath = await parentState?.copyUriToTempFile(widget.uri);
    if (tempPath != null) {
      controller = VideoPlayerController.file(File(tempPath!))
        ..initialize().then((_) {
          setState(() {});
          controller!.play();
        });
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to open video')));
    }
  }

  Future<void> _prepareImage() async {
    final parentState = context.findAncestorStateOfType<_StatusScreenState>();
    tempPath = await parentState?.copyUriToTempFile(widget.uri);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayPath = tempPath;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black),
      body: displayPath == null
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          : Stack(
              fit: StackFit.expand,
              children: [
                Image.file(File(displayPath), fit: BoxFit.cover),
                Container(color: Colors.black.withOpacity(0.6)),
                Center(
                  child: widget.isVideo
                      ? (controller != null && controller!.value.isInitialized)
                          ? AspectRatio(aspectRatio: controller!.value.aspectRatio, child: VideoPlayer(controller!))
                          : const CircularProgressIndicator(color: Colors.green)
                      : InteractiveViewer(child: Image.file(File(displayPath), fit: BoxFit.contain)),
                ),
              ],
            ),
      floatingActionButton: widget.isVideo
          ? FloatingActionButton(
              backgroundColor: Colors.green,
              onPressed: () {
                setState(() {
                  if (controller!.value.isPlaying) controller!.pause();
                  else controller!.play();
                });
              },
              child: Icon((controller != null && controller!.value.isPlaying) ? Icons.pause : Icons.play_arrow),
            )
          : null,
    );
  }
}
