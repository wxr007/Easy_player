import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

// 主题颜色配置 - 可在此处统一修改
class AppTheme {
  static const Color primaryColor = Color(0xFFFFD54F); // 浅橘黄色
  static const Color backgroundColor = Color(0xFFFFF8E1); // 浅橘黄背景色
  static const Color cardColor = Color(0xFFFFECB3); // 卡片颜色
  static const Color textColor = Color(0xFF5D4037); // 文字颜色
}

class VideoItem {
  final String id;
  final String path;
  final String name;
  int position;
  int duration;
  String? thumbnailBase64;
  String? subtitlePath;
  String? subtitleName;

  VideoItem({
    required this.id,
    required this.path,
    required this.name,
    this.position = 0,
    this.duration = 0,
    this.thumbnailBase64,
    this.subtitlePath,
    this.subtitleName,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'path': path,
    'name': name,
    'position': position,
    'duration': duration,
    'thumbnailBase64': thumbnailBase64,
    'subtitlePath': subtitlePath,
    'subtitleName': subtitleName,
  };

  factory VideoItem.fromJson(Map<String, dynamic> json) => VideoItem(
    id: json['id'],
    path: json['path'],
    name: json['name'],
    position: json['position'] ?? 0,
    duration: json['duration'] ?? 0,
    thumbnailBase64: json['thumbnailBase64'],
    subtitlePath: json['subtitlePath'],
    subtitleName: json['subtitleName'],
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

  Future<void> updateSubtitle(String id, String? subtitlePath, String? subtitleName) async {
    final index = _videos.indexWhere((v) => v.id == id);
    if (index != -1) {
      _videos[index].subtitlePath = subtitlePath;
      _videos[index].subtitleName = subtitleName;
      await _saveVideos();
      notifyListeners();
    }
  }

  Future<void> updateThumbnail(String id, String? thumbnailBase64) async {
    final index = _videos.indexWhere((v) => v.id == id);
    if (index != -1) {
      _videos[index].thumbnailBase64 = thumbnailBase64;
      await _saveVideos();
      notifyListeners();
    }
  }

  Future<void> updateDuration(String id, int duration) async {
    final index = _videos.indexWhere((v) => v.id == id);
    if (index != -1) {
      _videos[index].duration = duration;
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
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp4', 'mkv', 'avi', 'mov', 'wmv', 'flv', 'webm', '3gp', "pdf"],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.path != null) {
          final fileName = file.name;
          final videoPath = file.path!;
          
          int duration = 0;
          String? thumbnailBase64;
          
          try {
            final videoFile = File(videoPath);
            final tempController = VideoPlayerController.file(videoFile);
            await tempController.initialize();
            duration = tempController.value.duration.inMilliseconds;
            await tempController.dispose();
            
            final thumbnailData = await _generateThumbnail(videoPath, duration);
            if (thumbnailData != null) {
              thumbnailBase64 = base64Encode(thumbnailData);
            }
          } catch (e) {
            debugPrint('Error getting video info: $e');
          }
          
          final video = VideoItem(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            path: videoPath,
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
    } catch (e) {
      debugPrint('Error picking video: $e');
    }
  }

  Future<Uint8List?> _generateThumbnail(String videoPath, int videoDurationMs) async {
    try {
      debugPrint('Generating thumbnail for: $videoPath');
      
      int timeMs = 1000;
      if (videoDurationMs > 5000) {
        timeMs = (videoDurationMs * 0.1).toInt();
      }
      
      final uint8list = await VideoThumbnail.thumbnailData(
        video: videoPath,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 400,
        quality: 80,
        timeMs: timeMs,
      );
      
      if (uint8list != null) {
        debugPrint('Thumbnail generated successfully, size: ${uint8list.length}');
      } else {
        debugPrint('Thumbnail is null');
      }
      
      return uint8list;
    } catch (e) {
      debugPrint('Error generating thumbnail: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: AppTheme.textColor,
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
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.primaryColor, width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, size: 50, color: AppTheme.textColor),
            const SizedBox(height: 10),
            Text(
              '添加视频',
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.textColor,
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
          color: AppTheme.cardColor,
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
                              color: AppTheme.primaryColor,
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
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textColor,
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

List<SubtitleItem> parseSubtitles(String content) {
  final List<SubtitleItem> subtitles = [];
  final lines = content.split('\n');
  
  int i = 0;
  while (i < lines.length) {
    String line = lines[i].trim();
    
    if (line.isEmpty) {
      i++;
      continue;
    }
    
    if (line.contains('-->')) {
      try {
        final times = line.split('-->');
        if (times.length == 2) {
          final startMs = _parseTime(times[0].trim());
          final endMs = _parseTime(times[1].trim());
          
          final List<String> textLines = [];
          i++;
          while (i < lines.length && lines[i].trim().isNotEmpty) {
            textLines.add(lines[i].trim());
            i++;
          }
          
          if (textLines.isNotEmpty) {
            subtitles.add(SubtitleItem(
              startMs: startMs,
              endMs: endMs,
              text: textLines.join('\n'),
            ));
          }
          continue;
        }
      } catch (e) {
        debugPrint('Error parsing subtitle line: $line');
      }
    }
    i++;
  }
  
  return subtitles;
}

int _parseTime(String timeStr) {
  timeStr = timeStr.replaceAll(',', '.');
  
  final parts = timeStr.split(':');
  if (parts.length == 3) {
    final hours = int.parse(parts[0]);
    final minutes = int.parse(parts[1]);
    final secondsParts = parts[2].split('.');
    final seconds = int.parse(secondsParts[0]);
    final millis = secondsParts.length > 1 ? int.parse(secondsParts[1].padRight(3, '0').substring(0, 3)) : 0;
    return hours * 3600000 + minutes * 60000 + seconds * 1000 + millis;
  } else if (parts.length == 2) {
    final minutes = int.parse(parts[0]);
    final secondsParts = parts[1].split('.');
    final seconds = int.parse(secondsParts[0]);
    final millis = secondsParts.length > 1 ? int.parse(secondsParts[1].padRight(3, '0').substring(0, 3)) : 0;
    return minutes * 60000 + seconds * 1000 + millis;
  }
  return 0;
}

class PlayerScreen extends StatefulWidget {
  final VideoItem video;

  const PlayerScreen({super.key, required this.video});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class SubtitleItem {
  final int startMs;
  final int endMs;
  final String text;

  SubtitleItem({required this.startMs, required this.endMs, required this.text});
}

class _PlayerScreenState extends State<PlayerScreen> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isLoading = true;
  String? _errorMessage;
  int _retryCount = 0;
  static const int _maxRetries = 2;
  List<SubtitleItem> _subtitles = [];
  bool _isLoadingSubtitles = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
    _loadExistingSubtitles();
  }

  Future<void> _loadExistingSubtitles() async {
    if (widget.video.subtitlePath != null) {
      try {
        final subtitleFile = File(widget.video.subtitlePath!);
        if (await subtitleFile.exists()) {
          final subtitleContent = await subtitleFile.readAsString();
          final parsed = parseSubtitles(subtitleContent);
          setState(() {
            _subtitles = parsed;
          });
          debugPrint('Loaded ${parsed.length} existing subtitles');
        }
      } catch (e) {
        debugPrint('Failed to load existing subtitle: $e');
      }
    }
  }

  Future<void> _initializePlayer() async {
    try {
      if (_retryCount > 0) {
        await Future.delayed(Duration(milliseconds: 500 * _retryCount));
      }

      final videoFile = File(widget.video.path);
      if (!await videoFile.exists()) {
        setState(() {
          _errorMessage = '文件不存在或已被移除';
          _isLoading = false;
        });
        return;
      }

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
        looping: true,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
        showControlsOnInitialize: false,
        hideControlsTimer: const Duration(seconds: 2),
        overlay: Container(
          color: Colors.transparent,
        ),
        materialProgressColors: ChewieProgressColors(
          playedColor: AppTheme.primaryColor,
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

  Future<void> _pickSubtitle() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['srt', 'vtt'],
      );

      if (result != null && result.files.single.path != null) {
        final subtitlePath = result.files.single.path!;
        final subtitleName = result.files.single.name;
        
        await context.read<VideoStore>().updateSubtitle(widget.video.id, subtitlePath, subtitleName);
        
        setState(() {
          widget.video.subtitlePath = subtitlePath;
          widget.video.subtitleName = subtitleName;
          _isLoadingSubtitles = true;
        });
        
        try {
          final subtitleFile = File(subtitlePath);
          final subtitleContent = await subtitleFile.readAsString();
          final parsed = parseSubtitles(subtitleContent);
          
          setState(() {
            _subtitles = parsed;
            _isLoadingSubtitles = false;
          });
          debugPrint('Loaded ${parsed.length} subtitles');
        } catch (e) {
          debugPrint('Failed to parse subtitle: $e');
          setState(() {
            _subtitles = [];
            _isLoadingSubtitles = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Failed to pick subtitle: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: AppTheme.textColor,
        title: Text(
          widget.video.name,
          style: const TextStyle(fontSize: 14),
        ),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 250,
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error, color: Colors.red, size: 40),
                            const SizedBox(height: 10),
                            Text(_errorMessage!, style: TextStyle(color: AppTheme.textColor), textAlign: TextAlign.center),
                            const SizedBox(height: 10),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('返回'),
                            ),
                          ],
                        ),
                      )
                    : _chewieController != null
                        ? Container(
                            color: Colors.black,
                            child: Center(
                              child: AspectRatio(
                                aspectRatio: 16 / 9,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () {
                                    debugPrint('onTap triggered');
                                  },
                                  onDoubleTap: () {
                                    debugPrint('onDoubleTap triggered');
                                    _togglePlayPause();
                                  },
                                  child: Chewie(
                                    controller: _chewieController!,
                                  ),
                                ),
                              ),
                            ),
                          )
                        : Center(child: Text('无法加载播放器', style: TextStyle(color: AppTheme.textColor))),
          ),
          Expanded(
            child: Container(
              color: AppTheme.backgroundColor,
              child: _buildSubtitleSection(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubtitleSection() {
    if (widget.video.subtitlePath != null && widget.video.subtitleName != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSubtitleHeader(widget.video.subtitleName!, widget.video.subtitlePath!),
            const SizedBox(height: 8),
            if (_isLoadingSubtitles)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: CircularProgressIndicator(color: AppTheme.primaryColor),
                ),
              )
            else if (_subtitles.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '无法解析字幕文件',
                  style: TextStyle(color: AppTheme.textColor.withOpacity(0.6)),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _subtitles.length,
                  itemBuilder: (context, index) {
                    final subtitle = _subtitles[index];
                    return _buildSubtitleListItem(subtitle, index);
                  },
                ),
              ),
          ],
        ),
      );
    } else {
      return _buildAddSubtitleButton();
    }
  }

  Widget _buildSubtitleHeader(String name, String path) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(Icons.subtitles, color: AppTheme.textColor),
        title: Text(name, style: TextStyle(color: AppTheme.textColor)),
        subtitle: Text(
          path, 
          style: TextStyle(color: AppTheme.textColor.withOpacity(0.6), fontSize: 10), 
          maxLines: 1, 
          overflow: TextOverflow.ellipsis
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.delete, color: AppTheme.textColor.withOpacity(0.6)),
              onPressed: () async {
                await context.read<VideoStore>().updateSubtitle(widget.video.id, null, null);
                setState(() {
                  widget.video.subtitlePath = null;
                  widget.video.subtitleName = null;
                  _subtitles = [];
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubtitleListItem(SubtitleItem subtitle, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
      ),
      child: InkWell(
        onTap: () {
          if (_videoPlayerController != null) {
            _videoPlayerController!.seekTo(Duration(milliseconds: subtitle.startMs));
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_formatDuration(subtitle.startMs)} --> ${_formatDuration(subtitle.endMs)}',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textColor.withOpacity(0.6),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle.text,
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddSubtitleButton() {
    return InkWell(
      onTap: _pickSubtitle,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          border: Border.all(color: AppTheme.textColor.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.subtitles, color: AppTheme.textColor.withOpacity(0.6)),
            const SizedBox(width: 8),
            Text('添加字幕', style: TextStyle(color: AppTheme.textColor.withOpacity(0.6))),
          ],
        ),
      ),
    );
  }
}
