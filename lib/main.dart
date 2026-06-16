import 'dart:io';
import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

void main() {
  runApp(const MyApp());
}

/// =========================
/// ROOT APP
/// =========================
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomePage(),
    );
  }
}

/// =========================
/// HOME PAGE (dummy files list placeholder)
/// =========================
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  // Replace this with SAF loaded files
  List<String> get files => [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Status Saver")),
      body: GridView.builder(
        itemCount: files.length,
        cacheExtent: 5000,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
        ),
        itemBuilder: (_, i) {
          return VideoThumbnailWidget(videoPath: files[i]);
        },
      ),
    );
  }
}

/// =========================
/// LRU CACHE
/// =========================
class LruCache<K, V> {
  final int maxSize;
  final _map = LinkedHashMap<K, V>();

  LruCache(this.maxSize);

  V? get(K key) {
    if (!_map.containsKey(key)) return null;
    final val = _map.remove(key);
    _map[key] = val as V;
    return val;
  }

  void put(K key, V value) {
    if (_map.length >= maxSize) {
      _map.remove(_map.keys.first);
    }
    _map[key] = value;
  }
}

final memoryCache = LruCache<String, String>(200);
final Set<String> _processing = {};

/// =========================
/// THUMBNAIL WIDGET
/// =========================
class VideoThumbnailWidget extends StatefulWidget {
  final String videoPath;

  const VideoThumbnailWidget({
    super.key,
    required this.videoPath,
  });

  @override
  State<VideoThumbnailWidget> createState() => _VideoThumbnailState();
}

class _VideoThumbnailState extends State<VideoThumbnailWidget> {
  String? thumb;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant VideoThumbnailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.videoPath != widget.videoPath) {
      thumb = null;
      loading = true;
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Container(color: Colors.grey.shade300);
    }

    if (thumb == null) {
      return const Icon(Icons.video_file);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.file(
          File(thumb!),
          fit: BoxFit.cover,
        ),
        Container(color: Colors.black26),
        const Center(
          child: Icon(Icons.play_circle_fill,
              color: Colors.white, size: 50),
        ),
      ],
    );
  }

  Future<void> _load() async {
    if (_processing.contains(widget.videoPath)) return;
    _processing.add(widget.videoPath);

    try {
      final cached = memoryCache.get(widget.videoPath);
      if (cached != null && await File(cached).exists()) {
        _set(cached);
        return;
      }

      await _generate();
    } finally {
      _processing.remove(widget.videoPath);
    }
  }

  Future<void> _generate() async {
    final file = File(widget.videoPath);

    if (!await file.exists()) {
      _finish(null);
      return;
    }

    final cachePath = "${widget.videoPath}.thumb.jpg";

    if (await File(cachePath).exists()) {
      _set(cachePath);
      return;
    }

    try {
      final path = await VideoThumbnail.thumbnailFile(
        video: widget.videoPath,
        imageFormat: ImageFormat.JPEG,
        quality: 75,
      );

      if (path == null) {
        _finish(null);
        return;
      }

      await File(path).copy(cachePath);
      memoryCache.put(widget.videoPath, cachePath);
      _set(cachePath);
    } catch (e) {
      debugPrint("Thumbnail error: $e");
      _finish(null);
    }
  }

  void _set(String path) {
    if (!mounted) return;

    setState(() {
      thumb = path;
      loading = false;
    });
  }

  void _finish(String? path) {
    if (!mounted) return;

    setState(() {
      thumb = path;
      loading = false;
    });
  }
}
