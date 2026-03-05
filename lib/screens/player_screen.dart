import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'dart:convert';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:file_picker/file_picker.dart';
import '../theme/app_theme.dart';
import '../models/video_item.dart';
import '../models/subtitle_item.dart';
import '../stores/video_store.dart';
import '../utils/subtitle_parser.dart';
import 'player_subtitle_search.dart';
import 'player_fullscreen.dart';
import 'player_subtitle_list.dart';
import 'player_progress_bar.dart';

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
  List<SubtitleItem> _subtitles = [];
  bool _isLoadingSubtitles = false;
  ScrollController? _subtitleScrollController;
  int _currentSubtitleIndex = -1;
  final List<GlobalKey> _subtitleKeys = [];
  int _currentPosition = 0;
  bool _targetMode = false;
  double _averageItemHeight = 90.0; // Will be updated after first calculation
  bool _isFullScreen = false;
  double _videoAspectRatio = 16.0 / 9.0; // Default aspect ratio
  bool _isDraggingProgress = false;
  int _draggedPosition = 0;
  bool _showFullScreenControls = true; // Show controls in fullscreen by default
  Timer? _fullScreenControlsTimer; // Auto-hide controls timer

  @override
  void initState() {
    super.initState();
    // Set system UI mode to edgeToEdge at the start
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _subtitleScrollController = ScrollController();
    _initializePlayer();
    _loadExistingSubtitles();
  }

  // Capture current frame as cover and update thumbnail in store
  Future<void> _captureCover() async {
    try {
      if (_videoPlayerController == null) return;
      final currentPositionMs = _videoPlayerController!.value.position.inMilliseconds;
      final videoPath = widget.video.path;
      if (videoPath.isEmpty) return;
      final data = await VideoThumbnail.thumbnailData(
        video: videoPath,
        imageFormat: ImageFormat.JPEG,
        timeMs: currentPositionMs,
        maxWidth: 600,
        quality: 80,
      );
      if (data != null) {
        final base64Image = base64Encode(data);
        await context.read<VideoStore>().updateThumbnail(widget.video.id, base64Image);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('封面已更新'), duration: Duration(seconds: 2)),
          );
        }
      }
    } catch (e) {
      debugPrint('Failed to capture cover: $e');
    }
  }

  Future<void> _loadExistingSubtitles() async {
    if (widget.video.subtitlePath != null) {
      try {
        final subtitleFile = File(widget.video.subtitlePath!);
        if (await subtitleFile.exists()) {
          final subtitleContent = await subtitleFile.readAsString();
          final parsed = parseSubtitles(subtitleContent);
          _subtitleKeys.clear();
          for (int i = 0; i < parsed.length; i++) {
            _subtitleKeys.add(GlobalKey());
          }
          setState(() {
            _subtitles = parsed;
          });
          
          // Scroll to current position after loading
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted) {
                _calculateAverageItemHeight(); // Calculate average height once after initial load
                _syncSubtitleToVideoPosition();
              }
            });
          });
          debugPrint('Loaded ${parsed.length} existing subtitles');
        }
      } catch (e) {
        debugPrint('Failed to load existing subtitle: $e');
      }
    }
  }

  void _syncSubtitleToVideoPosition({bool forceScroll = false}) {
    if (_subtitles.isEmpty || _videoPlayerController == null) return;
    
    final currentPosition = _videoPlayerController!.value.position.inMilliseconds;
    debugPrint('[DEBUG] _syncSubtitleToVideoPosition: currentPosition=$currentPosition, subtitles=${_subtitles.length}');
    _updateCurrentSubtitle(currentPosition, forceScroll: forceScroll);
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
        showControls: false,
        showControlsOnInitialize: false,
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
       
      // Record video aspect ratio
      if (_videoPlayerController!.value.isInitialized) {
        setState(() {
          _videoAspectRatio = _videoPlayerController!.value.aspectRatio;
          debugPrint('[DEBUG] Video aspect ratio: $_videoAspectRatio');
        });
      }
      
      _videoPlayerController!.addListener(_onVideoPositionChanged);
      
      _syncSubtitleToVideoPosition();
      
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
    if (_videoPlayerController != null) {
      final position = _videoPlayerController!.value.position.inMilliseconds;
      
      if (_videoPlayerController!.value.isPlaying) {
        context.read<VideoStore>().updateVideoPosition(widget.video.id, position);
        
        if (_targetMode && _currentSubtitleIndex >= 0 && _currentSubtitleIndex < _subtitles.length) {
          if(position >= _subtitles[_currentSubtitleIndex].endMs){
            debugPrint('[DEBUG] Target mode: reached end of subtitle at $position, pausing');
            _videoPlayerController!.pause();
          }          
        }
      }
      setState(() {
        _currentPosition = position;
      });
      _updateCurrentSubtitle(position);
    }
  }

  void _updateCurrentSubtitle(int positionMs, {bool forceScroll = false}) {
    if (_subtitles.isEmpty) return;
    
    // Binary search for faster subtitle lookup
    int newIndex = _searchSubtitle(positionMs);
    
    debugPrint('[DEBUG] _updateCurrentSubtitle: positionMs=$positionMs, newIndex=$newIndex, total=${_subtitles.length}, forceScroll=$forceScroll');
    
    if (newIndex != _currentSubtitleIndex || forceScroll) {
      if (newIndex != _currentSubtitleIndex) {
        debugPrint('[DEBUG] Subtitle changed from $_currentSubtitleIndex to $newIndex');
      }
      setState(() {
        _currentSubtitleIndex = newIndex;
      });
      
      if (newIndex >= 0 && _subtitleScrollController != null) {
        // Scroll to subtitle with retry logic
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            debugPrint('[DEBUG] Calling _scrollToSubtitle for index $newIndex');
            _scrollToSubtitle(newIndex);
          }
        });
      }
    }
  }

  int _binarySearchSubtitle(int positionMs) {
    return SubtitleSearch.binarySearch(_subtitles, positionMs);
  }

  int _linearSearchSubtitle(int positionMs) {
    return SubtitleSearch.linearSearch(_subtitles, positionMs);
  }

  // Switch between search algorithms - change to _linearSearchSubtitle() to test performance
  int _searchSubtitle(int positionMs) {
    return SubtitleSearch.search(_subtitles, positionMs);
  }

  void _scrollToSubtitle(int index) {
    if (index < 0 || index >= _subtitles.length || _subtitleScrollController == null) {
      debugPrint('[DEBUG] _scrollToSubtitle: index $index out of range or no controller');
      return;
    }
    
    if (!_subtitleScrollController!.hasClients) {
      debugPrint('[DEBUG] ScrollController has no clients, cannot scroll');
      return;
    }
    
    // First, try ensureVisible directly
    if (index < _subtitleKeys.length) {
      final key = _subtitleKeys[index];
      final ctx = key.currentContext;
      if (ctx != null) {
        debugPrint('[DEBUG] Item $index already rendered, using ensureVisible directly');
        try {
          Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut, alignment: 0.5);
          return; // Success, no need for jumpTo
        } catch (e) {
          debugPrint('[DEBUG] ensureVisible failed: $e, will try jumpTo');
        }
      }
    }
    
    // Item not visible, calculate offset and jumpTo
    final estimatedItemHeight = _averageItemHeight; // Use calculated average height
    final listViewPadding = 8.0;
    final targetOffset = listViewPadding + (index * estimatedItemHeight);
    final viewportHeight = _subtitleScrollController!.position.viewportDimension;
    final centerOffset = targetOffset - (viewportHeight / 2) + (estimatedItemHeight / 2);
    final maxScroll = _subtitleScrollController!.position.maxScrollExtent;
    final finalOffset = centerOffset.clamp(0.0, maxScroll);
    
    debugPrint('[DEBUG] Item $index not visible, jumpTo offset=$finalOffset');
    _subtitleScrollController!.jumpTo(finalOffset);
    
    // Then refine with ensureVisible after a delay
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted && index < _subtitleKeys.length) {
        final key = _subtitleKeys[index];
        final ctx = key.currentContext;
        if (ctx != null) {
          debugPrint('[DEBUG] Refining position of item $index with ensureVisible');
          try {
            Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 200), curve: Curves.easeInOut, alignment: 0.5);
          } catch (e) {
            debugPrint('[DEBUG] Final ensureVisible failed: $e');
          }
        }
      }
    });
  }

  @override
  void dispose() {
    try {
      // Cancel auto-hide timer
      _fullScreenControlsTimer?.cancel();
      
      // Restore portrait orientation
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      
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
      if (_subtitleScrollController != null) {
        _subtitleScrollController!.dispose();
        _subtitleScrollController = null;
      }
    } catch (e) {
      // Ignore errors during dispose
    }
    super.dispose();
  }

  void _calculateAverageItemHeight() {
    if (_subtitleKeys.isEmpty) return;
    
    double totalHeight = 0;
    int renderedCount = 0;
    
    for (int i = 0; i < _subtitleKeys.length && i < 10; i++) {
      final key = _subtitleKeys[i];
      final renderObject = key.currentContext?.findRenderObject() as RenderBox?;
      if (renderObject != null) {
        totalHeight += renderObject.size.height + 8; // +8 for margin
        renderedCount++;
      }
    }
    
    if (renderedCount > 0) {
      final calculated = totalHeight / renderedCount;
      debugPrint('[DEBUG] Calculated average item height: $calculated (from $renderedCount items)');
      _averageItemHeight = calculated;
    }
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

  void _toggleFullScreenControls() {
    // Cancel existing timer
    _fullScreenControlsTimer?.cancel();
    
    setState(() {
      _showFullScreenControls = !_showFullScreenControls;
    });
    
    // Auto-hide controls after 3 seconds if they're visible
    if (_showFullScreenControls) {
      _fullScreenControlsTimer = Timer(const Duration(seconds: 3), () {
        if (mounted && _isFullScreen) {
          setState(() {
            _showFullScreenControls = false;
          });
        }
      });
    }
  }

  void _showSettingsMenu(BuildContext context, {bool isFullScreen = false}) {
    if (isFullScreen) {
      // _showFullScreenSettingsMenu(context);
    } else {
      _showNormalSettingsMenu(context);
    }
  }

  void _showNormalSettingsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  '设置',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textColor,
                  ),
                ),
              ),
              ListTile(
                leading: Icon(Icons.volume_up, color: AppTheme.textColor),
                title: Text(
                  '选择音轨',
                  style: TextStyle(color: AppTheme.textColor),
                ),
                subtitle: Text(
                  '该功能需要系统支持',
                  style: TextStyle(
                    color: AppTheme.textColor.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
                enabled: false,
                onTap: null,
              ),
              ListTile(
                leading: Icon(Icons.closed_caption, color: AppTheme.textColor),
                title: Text(
                  '字幕设置',
                  style: TextStyle(color: AppTheme.textColor),
                ),
                onTap: () {
                  Navigator.pop(context);
                  debugPrint('Subtitle settings opened');
                },
              ),
              ListTile(
                leading: Icon(Icons.info_outline, color: AppTheme.textColor),
                title: Text(
                  '视频信息',
                  style: TextStyle(color: AppTheme.textColor),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showVideoInfo(context);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showVideoInfo(BuildContext context) async {
    // Prepare extra metadata
    String resolution = '-';
    String sizeMB = '-';
    String bitrateText = '-';
    int? fileSizeBytes;
    try {
      final file = File(widget.video.path);
      if (await file.exists()) {
        fileSizeBytes = await file.length();
      }
    } catch (_) {}
    // Resolution from video controller if available
    if (_videoPlayerController != null && _videoPlayerController!.value.isInitialized) {
      final sz = _videoPlayerController!.value.size;
      if (sz != null && sz.width > 0 && sz.height > 0) {
        resolution = '${sz.width.toInt()}x${sz.height.toInt()}';
      }
    }
    // File size in MB
    if (fileSizeBytes != null) {
      final mb = fileSizeBytes! / (1024 * 1024);
      sizeMB = mb.toStringAsFixed(2);
    }
    // Bitrate estimation (kbps)
    if (fileSizeBytes != null && widget.video.duration > 0) {
      final kbps = ((fileSizeBytes! * 8 * 1000) / widget.video.duration).round();
      bitrateText = '${kbps} kbps';
    }
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppTheme.cardColor,
          title: Text(
            '视频信息',
            style: TextStyle(color: AppTheme.textColor),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '视频名称: ${widget.video.name}',
                style: TextStyle(color: AppTheme.textColor),
              ),
              const SizedBox(height: 8),
              Text(
                '时长: ${_formatDuration(widget.video.duration)}',
                style: TextStyle(color: AppTheme.textColor),
              ),
              const SizedBox(height: 8),
              Text(
                '分辨率: ${resolution}',
                style: TextStyle(color: AppTheme.textColor),
              ),
              const SizedBox(height: 8),
              Text(
                '大小: ${sizeMB} MB',
                style: TextStyle(color: AppTheme.textColor),
              ),
              const SizedBox(height: 8),
              Text(
                '比特率: ${bitrateText}',
                style: TextStyle(color: AppTheme.textColor),
              ),
              const SizedBox(height: 8),
              Text(
                '宽高比: ${_videoAspectRatio.toStringAsFixed(2)}',
                style: TextStyle(color: AppTheme.textColor),
              ),
              if (widget.video.subtitleName != null) ...[
                const SizedBox(height: 8),
                Text(
                  '字幕: ${widget.video.subtitleName}',
                  style: TextStyle(color: AppTheme.textColor),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('关闭', style: TextStyle(color: AppTheme.primaryColor)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _enterFullScreen() async {
    // Hide system UI
    // await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    
    // Determine orientation based on aspect ratio
    // landscape if aspectRatio > 1.0 (width > height), portrait if < 1.0
    if (_videoAspectRatio > 1.2) {
      // Landscape video
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      // Portrait or square video
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }
    
    setState(() {
      _isFullScreen = true;
      _showFullScreenControls = false; // Hide controls when entering fullscreen
      _fullScreenControlsTimer?.cancel(); // Cancel any existing timer
    });
  }

  Future<void> _exitFullScreen() async {
    // Always restore to portrait when exiting
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    
    // Update the UI state
    setState(() {
      _isFullScreen = false;
    });
    
    // Resync subtitle position after exiting fullscreen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _syncSubtitleToVideoPosition(forceScroll: true);
      }
    });
  }

  Widget _buildFullScreenPlayer() {
    return FullscreenPlayer(
      chewieController: _chewieController,
      videoAspectRatio: _videoAspectRatio,
      showControls: _showFullScreenControls,
      onTap: _toggleFullScreenControls,
      onDoubleTap: () {
        debugPrint('onDoubleTap triggered in fullscreen');
        _togglePlayPause();
      },
      toolbarWidget: _buildFullScreenToolbar(),
      onCaptureTap: _captureCover,
      onPopInvoked: (didPop, result) {
        if (didPop) {
          _exitFullScreen();
        }
      },
    );
  }

  Widget _buildFullScreenToolbar() {
    final duration = widget.video.duration;
    final position = _isDraggingProgress ? _draggedPosition : _currentPosition;
    
    return FullscreenToolbar(
      duration: duration,
      position: position,
      isDragging: _isDraggingProgress,
      isPlaying: _videoPlayerController?.value.isPlaying ?? false,
      onDragStart: () {
        setState(() {
          _isDraggingProgress = true;
        });
      },
      onPositionChanged: (newPosition) {
        setState(() {
          _draggedPosition = newPosition;
        });
      },
      onDragEnd: () {
        if (_isDraggingProgress && _videoPlayerController != null) {
          _videoPlayerController!.seekTo(Duration(milliseconds: _draggedPosition));
        }
        
        setState(() {
          _isDraggingProgress = false;
        });
      },
      onCaptureTap: _captureCover,
      onSettingsTap: () {
        _showSettingsMenu(context, isFullScreen: true);
      },
      onPlayPauseTap: _togglePlayPause,
      onExitFullscreenTap: _exitFullScreen,
      formatDuration: _formatDuration,
    );
  }

  String _formatDuration(int milliseconds) {
    return formatDuration(milliseconds);
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
          
          _subtitleKeys.clear();
          for (int i = 0; i < parsed.length; i++) {
            _subtitleKeys.add(GlobalKey());
          }
          
          setState(() {
            _subtitles = parsed;
            _isLoadingSubtitles = false;
          });
          
          // Scroll to current position after loading
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted) {
                _calculateAverageItemHeight(); // Calculate average height once after loading
                _syncSubtitleToVideoPosition();
              }
            });
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
    if (_isFullScreen) {
      return _buildFullScreenPlayer();
    }
    
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: AppTheme.textColor,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.video.name,
              style: const TextStyle(fontSize: 14),
            ),
            Text(
              '${_formatDuration(_currentPosition)} / ${_formatDuration(widget.video.duration)}',
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.textColor.withOpacity(0.8),
              ),
            ),
          ],
        ),
        toolbarHeight: 60,
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
          _buildProgressBar(),
          Expanded(
            child: _buildSubtitleSection(),
          ),
          _buildToolbar(),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return PlayerToolbar(
      isTargetMode: _targetMode,
      isPlaying: _videoPlayerController?.value.isPlaying ?? false,
      hasSubtitle: widget.video.subtitlePath != null,
      onSettingsTap: () {
        _showSettingsMenu(context, isFullScreen: false);
      },
      onTargetModeTap: () {
        setState(() {
          _targetMode = !_targetMode;
        });
        if (_targetMode && _videoPlayerController?.value.isPlaying == true) {
          _videoPlayerController!.pause();
        }
      },
      onPlayPauseTap: _togglePlayPause,
      onSubtitleTap: _pickSubtitle,
      onFullscreenTap: () {
        if (_isFullScreen) {
          _exitFullScreen();
        } else {
          _enterFullScreen();
        }
      },
    );
  }

  Widget _buildProgressBar() {
    final duration = widget.video.duration;
    final position = _isDraggingProgress ? _draggedPosition : _currentPosition;
    
    return ProgressBar(
      duration: duration,
      position: position,
      isDragging: _isDraggingProgress,
      onDragStart: () {
        setState(() {
          _isDraggingProgress = true;
        });
      },
      onPositionChanged: (newPosition) {
        setState(() {
          _draggedPosition = newPosition;
        });
      },
      onDragEnd: () {
        if (_isDraggingProgress && _videoPlayerController != null) {
          _videoPlayerController!.seekTo(Duration(milliseconds: _draggedPosition));
        }
        
        setState(() {
          _isDraggingProgress = false;
        });
      },
    );
  }

  Widget _buildSubtitleSection() {
    if (widget.video.subtitlePath != null && widget.video.subtitleName != null) {
      return SubtitleListWidget(
        subtitles: _subtitles,
        isLoading: _isLoadingSubtitles,
        scrollController: _subtitleScrollController,
        subtitleKeys: _subtitleKeys,
        currentSubtitleIndex: _currentSubtitleIndex,
        isPlaying: _videoPlayerController?.value.isPlaying ?? false,
        onSubtitleTap: (subtitle) async {
          if (_videoPlayerController != null) {
            await _videoPlayerController!.seekTo(Duration(milliseconds: subtitle.startMs));
            if (_targetMode) {
              _videoPlayerController!.play();
            }
          }
        },
        onPlayPauseTap: () {
          _togglePlayPause();
        },
        onAddSubtitleTap: _pickSubtitle,
        formatDuration: _formatDuration,
      );
    } else {
      return Center(
        child: InkWell(
          onTap: () => _pickSubtitle().ignore(),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.subtitles_off, size: 48, color: AppTheme.textColor.withOpacity(0.4)),
              const SizedBox(height: 8),
              Text(
                '点击添加字幕',
                style: TextStyle(color: AppTheme.textColor.withOpacity(0.6)),
              ),
            ],
          ),
        ),
      );
    }
  }

}

