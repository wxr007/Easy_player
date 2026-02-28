import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VideoItem {
  final String id;
  final String path;
  final String name;
  int position;

  VideoItem({
    required this.id,
    required this.path,
    required this.name,
    this.position = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'path': path,
    'name': name,
    'position': position,
  };

  factory VideoItem.fromJson(Map<String, dynamic> json) => VideoItem(
    id: json['id'],
    path: json['path'],
    name: json['name'],
    position: json['position'] ?? 0,
  );
}

class VideoStore extends ChangeNotifier {
  List<VideoItem> _videos = [];
  List<VideoItem> get videos => _videos;

  static const String _storageKey = 'video_list';

  Future<void> loadVideos() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_storageKey);
    if (jsonString != null) {
      final List<dynamic> jsonList = json.decode(jsonString);
      _videos = jsonList.map((e) => VideoItem.fromJson(e)).toList();
      notifyListeners();
    }
  }

  Future<void> addVideo(VideoItem video) async {
    _videos.add(video);
    await _saveVideos();
    notifyListeners();
  }

  Future<void> updateVideoPosition(String id, int position) async {
    final index = _videos.indexWhere((v) => v.id == id);
    if (index != -1) {
      _videos[index].position = position;
      await _saveVideos();
      notifyListeners();
    }
  }

  Future<void> removeVideo(String id) async {
    _videos.removeWhere((v) => v.id == id);
    await _saveVideos();
    notifyListeners();
  }

  Future<void> _saveVideos() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = json.encode(_videos.map((v) => v.toJson()).toList());
    await prefs.setString(_storageKey, jsonString);
  }
}

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => VideoStore()..loadVideos(),
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

  Future<void> _addVideo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: false,
    );

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      if (file.path != null) {
        final fileName = file.path!.split('/').last.split('\\').last;
        final video = VideoItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          path: file.path!,
          name: fileName,
          position: 0,
        );
        
        if (mounted) {
          await context.read<VideoStore>().addVideo(video);
        }
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
      body: Consumer<VideoStore>(
        builder: (context, store, child) {
          final videos = store.videos;
          
          return GridView.builder(
            padding: const EdgeInsets.all(10),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.8,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: videos.length + 1,
            itemBuilder: (context, index) {
              if (index == videos.length) {
                return _buildAddButton();
              }
              return _VideoGridItem(
                video: videos[index],
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PlayerScreen(video: videos[index]),
                    ),
                  );
                },
                onLongPress: () => _showDeleteDialog(context, videos[index]),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildAddButton() {
    return InkWell(
      onTap: _addVideo,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[400]!, width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, size: 50, color: Colors.grey[600]),
            const SizedBox(height: 10),
            Text(
              '添加视频',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, VideoItem video) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除视频'),
        content: Text('确定要删除 "${video.name}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              context.read<VideoStore>().removeVideo(video.id);
              Navigator.pop(context);
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _VideoGridItem extends StatelessWidget {
  final VideoItem video;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _VideoGridItem({
    required this.video,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: Container(
                  color: Colors.black,
                  child: const Center(
                    child: Icon(Icons.play_circle_fill, size: 50, color: Colors.white70),
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      video.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (video.position > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        _formatDuration(video.position),
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[400],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

class PlayerScreen extends StatefulWidget {
  final VideoItem video;

  const PlayerScreen({super.key, required this.video});

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
    try {
      final videoFile = File(widget.video.path);
      _videoPlayerController = VideoPlayerController.file(videoFile);
      
      await _videoPlayerController!.initialize();

      if (widget.video.position > 0) {
        await _videoPlayerController!.seekTo(Duration(milliseconds: widget.video.position));
      }

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
      
      _videoPlayerController!.addListener(_onVideoPositionChanged);
      
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

  void _onVideoPositionChanged() {
    if (_videoPlayerController != null && _videoPlayerController!.value.isPlaying) {
      final position = _videoPlayerController!.value.position.inMilliseconds;
      context.read<VideoStore>().updateVideoPosition(widget.video.id, position);
    }
  }

  @override
  void dispose() {
    if (_videoPlayerController != null) {
      _videoPlayerController!.pause();
      final position = _videoPlayerController!.value.position.inMilliseconds;
      _videoPlayerController!.removeListener(_onVideoPositionChanged);
      context.read<VideoStore>().updateVideoPosition(widget.video.id, position);
    }
    _chewieController?.dispose();
    _videoPlayerController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          widget.video.name,
          style: const TextStyle(fontSize: 14),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white),
            )
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, color: Colors.red, size: 50),
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
                        child: Chewie(controller: _chewieController!),
                      ),
                    )
                  : const Center(
                      child: Text('无法加载播放器', style: TextStyle(color: Colors.white)),
                    ),
    );
  }
}
