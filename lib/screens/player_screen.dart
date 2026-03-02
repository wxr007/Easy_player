import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:file_picker/file_picker.dart';
import '../theme/app_theme.dart';
import '../models/video_item.dart';
import '../models/subtitle_item.dart';
import '../stores/video_store.dart';
import '../utils/subtitle_parser.dart';

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

  @override
  void initState() {
    super.initState();
    _subtitleScrollController = ScrollController();
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
          _subtitleKeys.clear();
          for (int i = 0; i < parsed.length; i++) {
            _subtitleKeys.add(GlobalKey());
          }
          setState(() {
            _subtitles = parsed;
          });
          
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _syncSubtitleToVideoPosition();
          });
          
          debugPrint('Loaded ${parsed.length} existing subtitles');
        }
      } catch (e) {
        debugPrint('Failed to load existing subtitle: $e');
      }
    }
  }

  void _syncSubtitleToVideoPosition() {
    if (_subtitles.isEmpty || _videoPlayerController == null) return;
    
    final currentPosition = _videoPlayerController!.value.position.inMilliseconds;
    _updateCurrentSubtitle(currentPosition);
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
      }
      setState(() {
        _currentPosition = position;
      });
      _updateCurrentSubtitle(position);
    }
  }

  void _updateCurrentSubtitle(int positionMs) {
    if (_subtitles.isEmpty) return;
    
    int newIndex = -1;
    for (int i = 0; i < _subtitles.length; i++) {
      if (positionMs >= _subtitles[i].startMs && positionMs < _subtitles[i].endMs) {
        newIndex = i;
        break;
      }
      if (positionMs >= _subtitles[i].endMs) {
        if (i + 1 < _subtitles.length && positionMs < _subtitles[i + 1].startMs) {
          newIndex = i;
          break;
        }
      }
    }
    
    if (newIndex == -1 && positionMs >= _subtitles.last.endMs) {
      newIndex = _subtitles.length - 1;
    }
    
    if (newIndex != _currentSubtitleIndex) {
      setState(() {
        _currentSubtitleIndex = newIndex;
      });
      
      if (newIndex >= 0 && _subtitleScrollController != null && _subtitleScrollController!.hasClients) {
        _scrollToSubtitle(newIndex);
      }
    }
  }

  void _scrollToSubtitle(int index) {
    if (index < 0 || index >= _subtitleKeys.length) return;
    
    final key = _subtitleKeys[index];
    final context = key.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: 0.5,
      );
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
      if (_subtitleScrollController != null) {
        _subtitleScrollController!.dispose();
        _subtitleScrollController = null;
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
            child: _buildSubtitleSection(),
          ),
          _buildToolbar(),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        border: Border(
          top: BorderSide(color: AppTheme.primaryColor.withOpacity(0.3)),
        ),
      ),
      child: Row(
        children: [
          Text(
            '${_formatDuration(_currentPosition)} / ${_formatDuration(widget.video.duration)}',
            style: TextStyle(
              color: AppTheme.textColor,
              fontSize: 12,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(
              _videoPlayerController?.value.isPlaying == true ? Icons.pause : Icons.play_arrow,
              color: AppTheme.textColor,
            ),
            onPressed: _togglePlayPause,
          ),
          const Spacer(),
          IconButton(
            icon: Icon(
              widget.video.subtitlePath != null ? Icons.subtitles : Icons.subtitles_off,
              color: AppTheme.textColor,
            ),
            onPressed: _pickSubtitle,
          ),
        ],
      ),
    );
  }

  Widget _buildSubtitleSection() {
    if (widget.video.subtitlePath != null && widget.video.subtitleName != null) {
      if (_isLoadingSubtitles) {
        return Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
      }
      if (_subtitles.isEmpty) {
        return Center(
          child: Text(
            '无法解析字幕文件',
            style: TextStyle(color: AppTheme.textColor.withOpacity(0.6)),
          ),
        );
      }
      return ListView.builder(
        controller: _subtitleScrollController,
        padding: const EdgeInsets.all(8),
        itemCount: _subtitles.length,
        itemBuilder: (context, index) {
          final subtitle = _subtitles[index];
          return _buildSubtitleListItem(subtitle, index);
        },
      );
    } else {
      return Center(
        child: InkWell(
          onTap: _pickSubtitle,
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

  Widget _buildSubtitleListItem(SubtitleItem subtitle, int index) {
    final bool isActive = index == _currentSubtitleIndex;
    
    return Container(
      key: _subtitleKeys.length > index ? _subtitleKeys[index] : null,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isActive ? AppTheme.primaryColor : AppTheme.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive ? AppTheme.textColor : AppTheme.primaryColor.withOpacity(0.3),
          width: isActive ? 2 : 1,
        ),
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
                  color: isActive ? AppTheme.textColor : AppTheme.textColor.withOpacity(0.6),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle.text,
                style: TextStyle(
                  fontSize: 14,
                  color: isActive ? Colors.black87 : AppTheme.textColor,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
