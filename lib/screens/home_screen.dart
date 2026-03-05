import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import '../theme/app_theme.dart';
import '../models/video_item.dart';
import '../stores/video_store.dart';
import 'player_screen.dart';

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
        allowedExtensions: ['mp4', 'mkv', 'avi', 'mov', 'wmv', 'flv', 'webm', '3gp', 'pdf'],
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
        maxWidth: 800,
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
              childAspectRatio: 1.2,
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
            const Icon(Icons.add, size: 50, color: AppTheme.textColor),
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
                padding: const EdgeInsets.all(6),
                child: Text(
                  video.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
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
