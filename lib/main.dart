import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VideoItem {
  final String id;
  final String path;
  final String name;
  int position;
  int duration;
  String? thumbnailBase64;

  VideoItem({
    required this.id,
    required this.path,
    required this.name,
    this.position = 0,
    this.duration = 0,
    this.thumbnailBase64,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'path': path,
    'name': name,
    'position': position,
    'duration': duration,
    'thumbnailBase64': thumbnailBase64,
  };

  factory VideoItem.fromJson(Map<String, dynamic> json) => VideoItem(
    id: json['id'],
    path: json['path'],
    name: json['name'],
    position: json['position'] ?? 0,
    duration: json['duration'] ?? 0,
    thumbnailBase64: json['thumbnailBase64'],
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
      try {
        final List<dynamic> jsonList = json.decode(jsonString);
        List<VideoItem> loadedVideos = jsonList.map((e) => VideoItem.fromJson(e)).toList();
        _videos = loadedVideos.map((video) {
          if (video.name.isEmpty || video.name.contains(RegExp(r'^\d+$'))) {
            final pathParts = video.path.split(RegExp(r'[/\\]'));
            return VideoItem(
              id: video.id,
              path: video.path,
              name: pathParts.isNotEmpty ? pathParts.last : '未命名视频',
              position: video.position,
            );
          }
          return video;
        }).toList();
        notifyListeners();
      } catch (e) {
        await prefs.remove(_storageKey);
      }
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
      Permission.photos,
      Permission.videos,
    ].request();
  }

  Future<void> _addVideo() async {
    final List<AssetEntity>? result = await AssetPicker.pickAssets(
      context,
      pickerConfig: const AssetPickerConfig(
        maxAssets: 1,
        requestType: RequestType.video,
      ),
    );

    if (result != null && result.isNotEmpty) {
      final asset = result.first;
      final file = await asset.file;
      if (file != null) {
        final fileName = asset.title ?? '视频_${DateTime.now().millisecondsSinceEpoch}';
        
        // 获取缩略图（200x200）
        final thumbnailData = await asset.thumbnailDataWithSize(
          const ThumbnailSize(200, 200),
          quality: 80,
        );
        String? thumbnailBase64;
        if (thumbnailData != null) {
          thumbnailBase64 = base64Encode(thumbnailData);
        }
        
        // 获取视频时长（秒转换为毫秒）
        final duration = asset.duration * 1000;
        
        final video = VideoItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          path: file.path,
          name: fileName,
          position: 0,
          duration: duration,
          thumbnailBase64: thumbnailBase64,
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
        title: const Text('移除视频'),
        content: Text('确定要移除 "${video.name}" 吗？'),
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
            child: const Text('移除', style: TextStyle(color: Colors.red)),
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
              flex: 2,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    child: Container(
                      color: Colors.black,
                      child: video.thumbnailBase64 != null
                          ? Image.memory(
                              base64Decode(video.thumbnailBase64!),
                              fit: BoxFit.cover,
                            )
                          : const Center(
                              child: Icon(Icons.play_circle_fill, size: 50, color: Colors.white70),
                            ),
                    ),
                  ),
                  // 时间显示 已观看/总时长
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${_formatDuration(video.position)}/${_formatDuration(video.duration)}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  // 进度条
                  if (video.duration > 0)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 3,
                        decoration: BoxDecoration(
                          color: Colors.black38,
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(12),
                          ),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: video.position / video.duration,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.deepPurple,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  video.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(int milliseconds) {
    if (milliseconds <= 0) return '00:00';
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
  int _retryCount = 0;
  static const int _maxRetries = 2;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      // Wait a bit before retry to release resources
      if (_retryCount > 0) {
        await Future.delayed(Duration(milliseconds: 500 * _retryCount));
      }

      // Check if file exists first
      final videoFile = File(widget.video.path);
      if (!await videoFile.exists()) {
        setState(() {
          _errorMessage = '文件不存在或已被移除';
          _isLoading = false;
        });
        return;
      }

      // Dispose previous controllers first
      _chewieController?.dispose();
      _videoPlayerController?.dispose();
      _chewieController = null;
      _videoPlayerController = null;

      _videoPlayerController = VideoPlayerController.file(videoFile);
      
      await _videoPlayerController!.initialize();

      if (widget.video.position > 0 && _retryCount == 0) {
        await _videoPlayerController!.seekTo(Duration(milliseconds: widget.video.position));
      }

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: Colors.deepPurple,
          handleColor: Colors.white,
          backgroundColor: Colors.white38,
          bufferedColor: Colors.white54,
        ),
        placeholder: Container(
          color: Colors.black,
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, color: Colors.red, size: 40),
                const SizedBox(height: 10),
                Text(
                  errorMessage,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _retry,
                  child: const Text('重试'),
                ),
              ],
            ),
          );
        },
      );
      
      _videoPlayerController!.addListener(_onVideoPositionChanged);
      
      _retryCount = 0;
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      _retryCount++;
      if (_retryCount < _maxRetries) {
        // Retry
        _initializePlayer();
      } else {
        String errorMsg = '加载视频失败';
        if (e.toString().contains('VideoPlayer had error')) {
          errorMsg = '视频格式不支持\n请尝试其他视频文件';
        } else {
          errorMsg = '加载视频失败: $e';
        }
        setState(() {
          _errorMessage = errorMsg;
          _isLoading = false;
        });
      }
    }
  }

  void _retry() {
    _retryCount = 0;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    _initializePlayer();
  }

  void _onVideoPositionChanged() {
    if (_videoPlayerController != null && _videoPlayerController!.value.isPlaying) {
      final position = _videoPlayerController!.value.position.inMilliseconds;
      context.read<VideoStore>().updateVideoPosition(widget.video.id, position);
    }
  }

  @override
  void dispose() {
    try {
      if (_videoPlayerController != null) {
        _videoPlayerController!.removeListener(_onVideoPositionChanged);
        if (_videoPlayerController!.value.isPlaying) {
          _videoPlayerController!.pause();
        }
        final position = _videoPlayerController!.value.position.inMilliseconds;
        _videoPlayerController!.dispose();
        _videoPlayerController = null;
      }
      if (_chewieController != null) {
        _chewieController!.dispose();
        _chewieController = null;
      }
    } catch (e) {
      // Ignore errors during dispose
    }
    super.dispose();
  }

  void _togglePlayPause() {
    if (_videoPlayerController != null) {
      if (_videoPlayerController!.value.isPlaying) {
        _videoPlayerController!.pause();
      } else {
        _videoPlayerController!.play();
      }
    }
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
                  ? GestureDetector(
                      onDoubleTap: _togglePlayPause,
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: Chewie(controller: _chewieController!),
                        ),
                      ),
                    )
                  : const Center(
                      child: Text('无法加载播放器', style: TextStyle(color: Colors.white)),
                    ),
    );
  }
}
