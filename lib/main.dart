import 'dart:io';
import 'package:flutter/material.dart';
import 'package:saf/saf.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const App());
}

/// =========================
/// APP ROOT
/// =========================
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const HomePage(),
    );
  }
}

/// =========================
/// SAF SERVICE
/// =========================
class SafService {
  static const keyMain = "wa_uri";

  /// Pick WhatsApp Status folder
  static Future<Saf?> pickFolder() async {
    final uri = Uri.parse(
      "content://com.android.externalstorage.documents/tree/primary%3AAndroid%2Fmedia%2Fcom.whatsapp%2FWhatsApp%2FMedia%2F.Statuses",
    );

    // IMPORTANT: saf ^1.0.4 expects String, NOT Uri
    final saf = Saf(uri.toString());

    final granted = await saf.getDirectoryPermission(
      grantWritePermission: false,
    );

    if (granted != true) return null;

    final prefs = await SharedPreferences.getInstance();

    // Store ORIGINAL URI string
    await prefs.setString(keyMain, uri.toString());

    return saf;
  }

  /// Restore saved SAF session
  static Future<Saf?> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final uriStr = prefs.getString(keyMain);

    if (uriStr == null) return null;

    final saf = Saf(uriStr);

    final granted = await saf.getDirectoryPermission(
      grantWritePermission: false,
    );

    if (granted != true) return null;

    return saf;
  }
}

/// =========================
/// STATUS LOADER
/// =========================
class StatusLoader {
  static Future<List<String>> load(Saf saf) async {
    final files = await saf.getFilesPath();

    if (files == null) return [];

    return files.where((f) {
      return f.endsWith(".jpg") ||
          f.endsWith(".png") ||
          f.endsWith(".mp4");
    }).toList();
  }
}

/// =========================
/// HOME PAGE
/// =========================
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<String> files = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    init();
  }

  Future<void> init() async {
    final saf = await SafService.restore();

    if (saf == null) {
      setState(() => loading = false);
      return;
    }

    final data = await StatusLoader.load(saf);

    setState(() {
      files = data;
      loading = false;
    });
  }

  Future<void> askPermission() async {
    final saf = await SafService.pickFolder();

    if (saf == null) return;

    final data = await StatusLoader.load(saf);

    setState(() {
      files = data;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("WA Status Downloader"),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open),
            onPressed: askPermission,
          )
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : files.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "No Status Found",
                        style: TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: askPermission,
                        child: const Text("Grant Access"),
                      )
                    ],
                  ),
                )
              : GridView.builder(
                  itemCount: files.length,
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 2,
                    mainAxisSpacing: 2,
                  ),
                  itemBuilder: (_, i) {
                    return StatusTile(path: files[i]);
                  },
                ),
    );
  }
}

/// =========================
/// STATUS TILE
/// =========================
class StatusTile extends StatefulWidget {
  final String path;

  const StatusTile({super.key, required this.path});

  @override
  State<StatusTile> createState() => _StatusTileState();
}

class _StatusTileState extends State<StatusTile> {
  String? thumb;

  @override
  void initState() {
    super.initState();
    generateThumb();
  }

  Future<void> generateThumb() async {
    final temp = await getTemporaryDirectory();
    final cachePath = "${temp.path}/${widget.path.hashCode}.jpg";

    final file = File(cachePath);

    if (await file.exists()) {
      setState(() => thumb = cachePath);
      return;
    }

    if (widget.path.endsWith(".mp4")) {
      final generated = await VideoThumbnail.thumbnailFile(
        video: widget.path,
        imageFormat: ImageFormat.JPEG,
        quality: 75,
      );

      if (generated != null) {
        await File(generated).copy(cachePath);
        setState(() => thumb = cachePath);
      }
    } else {
      setState(() => thumb = widget.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.path.endsWith(".mp4");

    return Stack(
      fit: StackFit.expand,
      children: [
        thumb == null
            ? Container(color: Colors.grey.shade900)
            : Image.file(File(thumb!), fit: BoxFit.cover),

        if (isVideo)
          const Center(
            child: Icon(Icons.play_circle, color: Colors.white, size: 40),
          ),

        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Colors.black87, Colors.transparent],
            ),
          ),
        ),

        const Center(
          child: Icon(Icons.download, color: Colors.white),
        )
      ],
    );
  }
}
