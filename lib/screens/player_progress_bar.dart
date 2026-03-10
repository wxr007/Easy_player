import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ProgressBar extends StatelessWidget {
  final int duration;
  final int position;
  final bool isDragging;
  final Function(int)? onPositionChanged;  // 直接传递位置（毫秒）
  final VoidCallback? onDragStart;
  final VoidCallback? onDragEnd;

  const ProgressBar({
    super.key,
    required this.duration,
    required this.position,
    required this.isDragging,
    this.onPositionChanged,
    this.onDragStart,
    this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    final displayPosition = isDragging ? position : position;
    final progress = duration > 0 ? displayPosition / duration : 0.0;

    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: AppTheme.cardColor,
      child: Row(
        children: [
          Text(
            _formatDuration(position),
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.textColor,
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                activeTrackColor: AppTheme.textColor,
                inactiveTrackColor: AppTheme.textColor.withOpacity(0.3),
                thumbColor: AppTheme.textColor,
                overlayColor: AppTheme.textColor.withOpacity(0.2),
              ),
              child: Slider(
                value: progress.clamp(0.0, 1.0),
                onChangeStart: (value) {
                  onDragStart?.call();
                },
                onChanged: (value) {
                  final newPosition = (value * duration).toInt();
                  onPositionChanged?.call(newPosition);
                },
                onChangeEnd: (value) {
                  onDragEnd?.call();
                },
              ),
            ),
          ),
          Text(
            _formatDuration(duration),
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.textColor,
            ),
          ),
        ],
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

class PlayerToolbar extends StatelessWidget {
  final bool isTargetMode;
  final bool isPlaying;
  final bool hasSubtitle;
  final bool isEditingSubtitle;
  final VoidCallback onSettingsTap;
  final VoidCallback onTargetModeTap;
  final VoidCallback onPlayPauseTap;
  final VoidCallback onSubtitleTap;
  final VoidCallback onFullscreenTap;
  final VoidCallback onSubtitleEditTap;
  final VoidCallback? onExportSubtitleTap;

  const PlayerToolbar({
    super.key,
    required this.isTargetMode,
    required this.isPlaying,
    required this.hasSubtitle,
    required this.isEditingSubtitle,
    required this.onSettingsTap,
    required this.onTargetModeTap,
    required this.onPlayPauseTap,
    required this.onSubtitleTap,
    required this.onFullscreenTap,
    required this.onSubtitleEditTap,
    this.onExportSubtitleTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.primaryColor,
      child: Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: Icon(Icons.settings, color: AppTheme.textColor),
              onPressed: onSettingsTap,
            ),
            const Spacer(),
            IconButton(
              icon: Icon(
                Icons.gps_fixed,
                color: isTargetMode ? Colors.orange : AppTheme.textColor,
              ),
              onPressed: onTargetModeTap,
            ),
            const Spacer(),
            IconButton(
              icon: Icon(
                isPlaying ? Icons.pause : Icons.play_arrow,
                color: AppTheme.textColor,
              ),
              onPressed: onPlayPauseTap,
            ),
            const Spacer(),
            // 正常模式显示添加字幕按钮，编辑模式隐藏
            if (!isEditingSubtitle)
              IconButton(
                icon: Icon(
                  hasSubtitle ? Icons.subtitles : Icons.subtitles_off,
                  color: AppTheme.textColor,
                ),
                onPressed: onSubtitleTap,
              ),
            if (!isEditingSubtitle) const Spacer(),
            // 编辑模式显示导出字幕按钮，正常模式隐藏
            if (isEditingSubtitle && hasSubtitle && onExportSubtitleTap != null)
              IconButton(
                icon: Icon(Icons.upload_file, color: AppTheme.textColor),
                onPressed: onExportSubtitleTap,
                tooltip: '导出字幕',
              ),
            if (isEditingSubtitle && hasSubtitle && onExportSubtitleTap != null) const Spacer(),
            isEditingSubtitle
              ? IconButton(
                  icon: const Icon(Icons.edit, color: AppTheme.textColor),
                  onPressed: onSubtitleEditTap,
                )
              : IconButton(
                  icon: Icon(Icons.fullscreen, color: AppTheme.textColor),
                  onPressed: onFullscreenTap,
                ),
          ],
        ),
      ),
    );
  }
}

class FullscreenToolbar extends StatelessWidget {
  final int duration;
  final int position;
  final bool isDragging;
  final bool isPlaying;
  final Function(int)? onPositionChanged;
  final VoidCallback? onDragStart;
  final VoidCallback? onDragEnd;
  final VoidCallback onSettingsTap;
  final VoidCallback onPlayPauseTap;
  final VoidCallback onExitFullscreenTap;
  final VoidCallback? onCaptureTap;
  final String Function(int) formatDuration;

  const FullscreenToolbar({
    super.key,
    required this.duration,
    required this.position,
    required this.isDragging,
    required this.isPlaying,
    this.onPositionChanged,
    this.onDragStart,
    this.onDragEnd,
    required this.onSettingsTap,
    required this.onPlayPauseTap,
    required this.onExitFullscreenTap,
    this.onCaptureTap,
    required this.formatDuration,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Progress bar with time
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Text(
                  formatDuration(position),
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                      activeTrackColor: AppTheme.primaryColor,
                      inactiveTrackColor: Colors.white30,
                      thumbColor: AppTheme.primaryColor,
                      overlayColor: AppTheme.primaryColor.withOpacity(0.2),
                    ),
                    child: Slider(
                      value: duration > 0 ? (position / duration).clamp(0.0, 1.0) : 0.0,
                      onChangeStart: (value) {
                        onDragStart?.call();
                      },
                      onChanged: (value) {
                        final newPosition = (value * duration).toInt();
                        onPositionChanged?.call(newPosition);
                      },
                      onChangeEnd: (value) {
                        onDragEnd?.call();
                      },
                    ),
                  ),
                ),
                Text(
                  formatDuration(duration),
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ],
            ),
          ),
          // Control buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SizedBox(
                  width: 36,
                  height: 36,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.settings, color: Colors.white, size: 20),
                    onPressed: onSettingsTap,
                  ),
                ),
                // Removed: moved capture button to top-left overlay in fullscreen
                SizedBox(
                  width: 36,
                  height: 36,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                      color: Colors.white,
                      size: 32,
                    ),
                    onPressed: onPlayPauseTap,
                  ),
                ),
                SizedBox(
                  width: 36,
                  height: 36,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.fullscreen_exit, color: Colors.white, size: 20),
                    onPressed: onExitFullscreenTap,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
