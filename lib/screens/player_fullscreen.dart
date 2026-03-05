import 'package:flutter/material.dart';
import 'package:chewie/chewie.dart';

/// 全屏播放器进度条样式颜色
class FullscreenProgressColors {
  static const Color backgroundColor = Colors.white30;
  static const Color progressColor = Colors.red;
  static const Color thumbColor = Colors.white;
}

/// 全屏播放器组件
class FullscreenPlayer extends StatelessWidget {
  final ChewieController? chewieController;
  final double videoAspectRatio;
  final bool showControls;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final Widget toolbarWidget;
  final Function(bool, dynamic) onPopInvoked;
  final VoidCallback? onCaptureTap;

  const FullscreenPlayer({
    super.key,
    required this.chewieController,
    required this.videoAspectRatio,
    required this.showControls,
    required this.onTap,
    required this.onDoubleTap,
    required this.toolbarWidget,
    required this.onPopInvoked,
    this.onCaptureTap,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: onPopInvoked,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: chewieController != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Center(
                    child: AspectRatio(
                      aspectRatio: videoAspectRatio,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: onTap,
                        onDoubleTap: onDoubleTap,
                        child: Chewie(
                          controller: chewieController!,
                        ),
                      ),
                    ),
                  ),
                  if (showControls)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: toolbarWidget,
                    ),
                  // Top-left capture button overlay (optional)
                  if (onCaptureTap != null)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.camera_alt, color: Colors.white),
                          onPressed: onCaptureTap,
                          tooltip: '截取封面',
                        ),
                      ),
                    ),
                ],
              )
            : const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
      ),
    );
  }
}
