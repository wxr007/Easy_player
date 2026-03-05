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

  const FullscreenPlayer({
    super.key,
    required this.chewieController,
    required this.videoAspectRatio,
    required this.showControls,
    required this.onTap,
    required this.onDoubleTap,
    required this.toolbarWidget,
    required this.onPopInvoked,
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
                ],
              )
            : const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
      ),
    );
  }
}
