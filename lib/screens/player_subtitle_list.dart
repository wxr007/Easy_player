import 'package:flutter/material.dart';
import '../models/subtitle_item.dart';
import '../theme/app_theme.dart';

class SubtitleListWidget extends StatelessWidget {
  final List<SubtitleItem> subtitles;
  final bool isLoading;
  final ScrollController? scrollController;
  final List<GlobalKey> subtitleKeys;
  final int currentSubtitleIndex;
  final bool isPlaying;
  final Future<void> Function(SubtitleItem subtitle) onSubtitleTap;
  final VoidCallback onPlayPauseTap;
  final Future<void> Function() onAddSubtitleTap;
  final String Function(int) formatDuration;

  const SubtitleListWidget({
    super.key,
    required this.subtitles,
    required this.isLoading,
    required this.scrollController,
    required this.subtitleKeys,
    required this.currentSubtitleIndex,
    required this.isPlaying,
    required this.onSubtitleTap,
    required this.onPlayPauseTap,
    required this.onAddSubtitleTap,
    required this.formatDuration,
  });

  @override
  Widget build(BuildContext context) {
    if (subtitles.isNotEmpty) {
      if (isLoading) {
        return Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
      }
      if (subtitles.isEmpty) {
        return Center(
          child: Text(
            '无法解析字幕文件',
            style: TextStyle(color: AppTheme.textColor.withOpacity(0.6)),
          ),
        );
      }
      return ListView.builder(
        controller: scrollController,
        padding: const EdgeInsets.all(8),
        cacheExtent: 8000,
        itemCount: subtitles.length,
        itemBuilder: (context, index) {
          return _buildSubtitleItem(context, index);
        },
      );
    } else {
      return Center(
        child: InkWell(
          onTap: () => onAddSubtitleTap().ignore(),
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

  Widget _buildSubtitleItem(BuildContext context, int index) {
    final subtitle = subtitles[index];
    final bool isActive = index == currentSubtitleIndex;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          key: subtitleKeys.length > index ? subtitleKeys[index] : null,
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: isActive ? AppTheme.primaryColor : AppTheme.cardColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive ? AppTheme.textColor : AppTheme.primaryColor.withOpacity(0.3),
              width: isActive ? 2 : 1,
            ),
          ),
          child: GestureDetector(
            onTap: () => onSubtitleTap(subtitle).ignore(),
            onDoubleTap: isActive ? onPlayPauseTap : null,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${formatDuration(subtitle.startMs)} --> ${formatDuration(subtitle.endMs)}',
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
                  if (isActive)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: GestureDetector(
                        onTap: onPlayPauseTap,
                        child: Icon(
                          isPlaying ? Icons.pause_circle_outline : Icons.play_circle_outline,
                          color: AppTheme.textColor,
                          size: 28,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
