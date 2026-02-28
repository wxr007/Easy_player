import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => VideoPlayerProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Easy Player',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class VideoPlayerProvider extends ChangeNotifier {
  String? _videoPath;
  String? _subtitlePath;

  String? get videoPath => _videoPath;
  String? get subtitlePath => _subtitlePath;

  void setVideoPath(String? path) {
    _videoPath = path;
    notifyListeners();
  }

  void setSubtitlePath(String? path) {
    _subtitlePath = path;
    notifyListeners();
  }

  void clear() {
    _videoPath = null;
    _subtitlePath = null;
    notifyListeners();
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.storage,
      Permission.manageExternalStorage,
    ].request();
  }

  Future<void> _pickVideo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: false,
    );

    if (result != null && result.files.isNotEmpty) {
      if (mounted) {
        final provider = context.read<VideoPlayerProvider>();
        provider.setVideoPath(result.files.first.path);
        
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const PlayerScreen(),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Easy Player'),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.video_library,
              size: 100,
              color: Colors.deepPurple,
            ),
            const SizedBox(height: 30),
            const Text(
              '视频播放器',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              '支持本地视频和字幕',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 50),
            ElevatedButton.icon(
              onPressed: _pickVideo,
              icon: const Icon(Icons.add),
              label: const Text('选择视频文件'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    final provider = context.read<VideoPlayerProvider>();
    final videoPath = provider.videoPath;

    if (videoPath == null) {
      setState(() {
        _errorMessage = '未选择视频文件';
        _isLoading = false;
      });
      return;
    }

    try {
      final videoFile = File(videoPath);
      _videoPlayerController = VideoPlayerController.file(videoFile);
      
      await _videoPlayerController!.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
        placeholder: Container(
          color: Colors.black,
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Text(
              errorMessage,
              style: const TextStyle(color: Colors.red),
            ),
          );
        },
      );
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '加载视频失败: $e';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('正在播放'),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error,
                        color: Colors.red,
                        size: 50,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('返回'),
                      ),
                    ],
                  ),
                )
              : _chewieController != null
                  ? Center(
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Chewie(
                          controller: _chewieController!,
                        ),
                      ),
                    )
                  : const Center(
                      child: Text(
                        '无法加载播放器',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
    );
  }
}
