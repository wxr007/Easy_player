import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ProgressBar extends StatelessWidget {
  final int duration;
  final int position;
  final bool isDragging;
  final Function(DragUpdateDetails) onDragUpdate;
  final Function(DragEndDetails) onDragEnd;

  const ProgressBar({
    super.key,
    required this.duration,
    required this.position,
    required this.isDragging,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.primaryColor,
      child: GestureDetector(
        onHorizontalDragUpdate: onDragUpdate,
        onHorizontalDragEnd: onDragEnd,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            height: 8,
            color: Colors.transparent,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final progress = duration > 0 ? (position / duration).clamp(0.0, 1.0) : 0.0;
                final progressWidth = progress * constraints.maxWidth;

                return Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    Container(
                      width: double.infinity,
                      height: 3,
                      color: AppTheme.primaryColor.withOpacity(0.3),
                    ),
                    Container(
                      width: progressWidth,
                      height: 3,
                      color: Colors.red,
                    ),
                    if (isDragging)
                      Positioned(
                        left: (progressWidth - 3).clamp(0.0, constraints.maxWidth - 6),
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
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

class FullscreenProgressBar extends StatelessWidget {
  final int duration;
  final int position;
  final bool isDragging;
  final Function(DragUpdateDetails) onDragUpdate;
  final Function(DragEndDetails) onDragEnd;

  const FullscreenProgressBar({
    super.key,
    required this.duration,
    required this.position,
    required this.isDragging,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: onDragUpdate,
      onHorizontalDragEnd: onDragEnd,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          height: 8,
          color: Colors.transparent,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final progress = duration > 0 ? (position / duration).clamp(0.0, 1.0) : 0.0;
              final progressWidth = progress * constraints.maxWidth;

              return Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Container(
                    width: double.infinity,
                    height: 3,
                    color: Colors.white30,
                  ),
                  Container(
                    width: progressWidth,
                    height: 3,
                    color: Colors.red,
                  ),
                  if (isDragging)
                    Positioned(
                      left: (progressWidth - 3).clamp(0.0, constraints.maxWidth - 6),
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
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
  final Function(DragUpdateDetails) onDragUpdate;
  final Function(DragEndDetails) onDragEnd;
  final VoidCallback onPlayPauseTap;
  final VoidCallback onExitFullscreenTap;
  final String Function(int) formatDuration;

  const FullscreenToolbar({
    super.key,
    required this.duration,
    required this.position,
    required this.isDragging,
    required this.isPlaying,
    required this.onDragUpdate,
    required this.onDragEnd,
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
            Colors.transparent,
            Colors.black.withOpacity(0.7),
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FullscreenProgressBar(
            duration: duration,
            position: position,
            isDragging: isDragging,
            onDragUpdate: onDragUpdate,
            onDragEnd: onDragEnd,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.settings, color: Colors.white),
                      onPressed: () {
                        debugPrint('Settings button pressed');
                      },
                    ),
                    Text(
                      formatDuration(position),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                  ),
                  onPressed: onPlayPauseTap,
                ),
                Row(
                  children: [
                    Text(
                      formatDuration(duration),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    IconButton(
                      icon: const Icon(Icons.fullscreen_exit, color: Colors.white),
                      onPressed: onExitFullscreenTap,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
