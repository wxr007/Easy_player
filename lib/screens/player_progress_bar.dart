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
  final VoidCallback onSettingsTap;
  final VoidCallback onTargetModeTap;
  final VoidCallback onPlayPauseTap;
  final VoidCallback onSubtitleTap;
  final VoidCallback onFullscreenTap;

  const PlayerToolbar({
    super.key,
    required this.isTargetMode,
    required this.isPlaying,
    required this.hasSubtitle,
    required this.onSettingsTap,
    required this.onTargetModeTap,
    required this.onPlayPauseTap,
    required this.onSubtitleTap,
    required this.onFullscreenTap,
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
            IconButton(
              icon: Icon(
                hasSubtitle ? Icons.subtitles : Icons.subtitles_off,
                color: AppTheme.textColor,
              ),
              onPressed: onSubtitleTap,
            ),
            const Spacer(),
            IconButton(
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
  final VoidCallback onPlayPauseTap;
  final VoidCallback onExitFullscreenTap;
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
    required this.onPlayPauseTap,
    required this.onExitFullscreenTap,
    required this.formatDuration,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black54,
            Colors.transparent,
            Colors.transparent,
            Colors.black54,
          ],
          stops: const [0.0, 0.3, 0.7, 1.0],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Progress bar with time
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  formatDuration(position),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
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
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
          // Control buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,//Icons.pause_circle_filled : Icons.play_circle_filled,
                    color: Colors.white,
                  ),
                  onPressed: onPlayPauseTap,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.fullscreen_exit, color: Colors.white),
                  onPressed: onExitFullscreenTap,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}