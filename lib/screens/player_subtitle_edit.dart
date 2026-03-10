import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../models/subtitle_item.dart';
import '../theme/app_theme.dart';

class SubtitleEditBottomSheet extends StatefulWidget {
  final SubtitleItem subtitle;
  final VideoPlayerController? videoController;

  const SubtitleEditBottomSheet({super.key, required this.subtitle, this.videoController});

  @override
  State<SubtitleEditBottomSheet> createState() => _SubtitleEditBottomSheetState();
}

class _SubtitleEditBottomSheetState extends State<SubtitleEditBottomSheet> {
  late TextEditingController _textController;
  late TextEditingController _startController;
  late TextEditingController _endController;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.subtitle.text);
    _startController = TextEditingController(text: _formatMs(widget.subtitle.startMs));
    _endController = TextEditingController(text: _formatMs(widget.subtitle.endMs));
    widget.videoController?.addListener(_onVideoStateChanged);
  }

  @override
  void dispose() {
    widget.videoController?.removeListener(_onVideoStateChanged);
    widget.videoController?.pause();
    _textController.dispose();
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  void _onVideoStateChanged() {
    if (mounted) {
      setState(() {
        _isPlaying = widget.videoController?.value.isPlaying ?? false;
      });
    }
  }

  Future<void> _playPreview() async {
    final controller = widget.videoController;
    if (controller == null) return;

    final startMs = _parseTime(_startController.text) ?? widget.subtitle.startMs;
    final endMs = _parseTime(_endController.text) ?? widget.subtitle.endMs;

    await controller.seekTo(Duration(milliseconds: startMs));
    await controller.play();

    controller.removeListener(_onVideoStateChanged);
    controller.addListener(() {
      if (mounted) {
        final position = controller.value.position.inMilliseconds;
        if (position >= endMs) {
          controller.pause();
          controller.removeListener(_onVideoStateChanged);
          setState(() => _isPlaying = false);
        } else {
          setState(() => _isPlaying = controller.value.isPlaying);
        }
      }
    });
  }

  String _formatMs(int ms) {
    final duration = Duration(milliseconds: ms);
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    final milliseconds = (ms % 1000).toString().padLeft(3, '0');
    return '$hours:$minutes:$seconds.$milliseconds';
  }

  int? _parseTime(String timeStr) {
    try {
      final parts = timeStr.split(':');
      if (parts.length != 3) return null;
      
      final hours = int.parse(parts[0]);
      final minutes = int.parse(parts[1]);
      final secParts = parts[2].split('.');
      if (secParts.length != 2) return null;
      
      final seconds = int.parse(secParts[0]);
      final milliseconds = int.parse(secParts[1].padRight(3, '0').substring(0, 3));
      
      return hours * 3600000 + minutes * 60000 + seconds * 1000 + milliseconds;
    } catch (e) {
      return null;
    }
  }

  void _adjustTime(TextEditingController controller, int deltaMs) {
    final currentMs = _parseTime(controller.text);
    if (currentMs != null) {
      final newMs = (currentMs + deltaMs).clamp(0, 359999999);
      controller.text = _formatMs(newMs);
    }
  }

  void _save() {
    final text = _textController.text.trim();
    final startMs = _parseTime(_startController.text);
    final endMs = _parseTime(_endController.text);

    if (text.isEmpty || startMs == null || endMs == null || startMs >= endMs) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写有效的开始/结束时间，且开始时间必须早于结束时间')),
      );
      return;
    }

    Navigator.of(context).pop(SubtitleItem(startMs: startMs, endMs: endMs, text: text));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            // 标题栏和按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.subtitles, color: AppTheme.primaryColor),
                    const SizedBox(width: 8),
                    Text(
                      '编辑字幕',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textColor,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        '取消',
                        style: TextStyle(color: AppTheme.textColor.withOpacity(0.7)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      ),
                      child: const Text('保存'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            // 字幕内容
            Text(
              '字幕内容',
              style: TextStyle(fontSize: 14, color: AppTheme.textColor.withOpacity(0.8)),
            ),
            const SizedBox(height: 6),
            Container(
              height: 80, // 固定高度为两行
              child: TextField(
                controller: _textController,
                maxLines: null, // 允许多行
                style: TextStyle(color: AppTheme.textColor),
                decoration: InputDecoration(
                  hintText: '请输入字幕内容',
                  hintStyle: TextStyle(fontSize: 13, color: AppTheme.textColor.withOpacity(0.5)),
                  filled: true,
                  fillColor: AppTheme.backgroundColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            // 时间设置
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '开始时间',
                        style: TextStyle(fontSize: 14, color: AppTheme.textColor.withOpacity(0.8)),
                      ),
                      const SizedBox(height: 6),
                      // 时间输入框带箭头按钮
                      Row(
                        children: [
                          // 左箭头按钮 (减少时间)
                          SizedBox(
                            width: 32,
                            height: 38,
                            child: GestureDetector(
                              onTap: () => _adjustTime(_startController, -50),
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: AppTheme.textColor.withOpacity(0.3),
                                    width: 1,
                                  ),
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(8),
                                    bottomLeft: Radius.circular(8),
                                  ),
                                ),
                                child: Center(
                                  child: Icon(Icons.arrow_left, size: 24, color: AppTheme.textColor),
                                ),
                              ),
                            ),
                          ),
                          // 时间输入框
                          Expanded(
                            child: TextField(
                              controller: _startController,
                              style: TextStyle(color: AppTheme.textColor, fontSize: 13),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'[\d:.]')),
                              ],
                              decoration: InputDecoration(
                                hintText: '00:00:00.000',
                                hintStyle: TextStyle(color: AppTheme.textColor.withOpacity(0.5), fontSize: 13),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                filled: true,
                                fillColor: AppTheme.backgroundColor,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.zero,
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                          // 右箭头按钮 (增加时间)
                          SizedBox(
                            width: 32,
                            height: 38,
                            child: GestureDetector(
                              onTap: () => _adjustTime(_startController, 50),
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: AppTheme.textColor.withOpacity(0.3),
                                    width: 1,
                                  ),
                                  borderRadius: BorderRadius.only(
                                    topRight: Radius.circular(8),
                                    bottomRight: Radius.circular(8),
                                  ),
                                ),
                                child: Center(
                                  child: Icon(Icons.arrow_right, size: 24, color: AppTheme.textColor),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '结束时间',
                        style: TextStyle(fontSize: 14, color: AppTheme.textColor.withOpacity(0.8)),
                      ),
                      const SizedBox(height: 6),
                      // 时间输入框带箭头按钮
                      Row(
                        children: [
                          // 左箭头按钮 (减少时间)
                          SizedBox(
                            width: 32,
                            height: 38,
                            child: GestureDetector(
                              onTap: () => _adjustTime(_endController, -50),
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: AppTheme.textColor.withOpacity(0.3),
                                    width: 1,
                                  ),
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(8),
                                    bottomLeft: Radius.circular(8),
                                  ),
                                ),
                                child: Center(
                                  child: Icon(Icons.arrow_left, size: 24, color: AppTheme.textColor),
                                ),
                              ),
                            ),
                          ),
                          // 时间输入框
                          Expanded(
                            child: TextField(
                              controller: _endController,
                              style: TextStyle(color: AppTheme.textColor, fontSize: 13),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'[\d:.]')),
                              ],
                              decoration: InputDecoration(
                                hintText: '00:00:00.000',
                                hintStyle: TextStyle(color: AppTheme.textColor.withOpacity(0.5), fontSize: 13),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                filled: true,
                                fillColor: AppTheme.backgroundColor,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.zero,
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                          // 右箭头按钮 (增加时间)
                          SizedBox(
                            width: 32,
                            height: 38,
                            child: GestureDetector(
                              onTap: () => _adjustTime(_endController, 50),
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: AppTheme.textColor.withOpacity(0.3),
                                    width: 1,
                                  ),
                                  borderRadius: BorderRadius.only(
                                    topRight: Radius.circular(8),
                                    bottomRight: Radius.circular(8),
                                  ),
                                ),
                                child: Center(
                                  child: Icon(Icons.arrow_right, size: 24, color: AppTheme.textColor),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // 预览按钮
            if (widget.videoController != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isPlaying ? null : _playPreview,
                  icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                  label: Text(_isPlaying ? '预览中...' : '预览播放'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
          ],
        ),
    );
  }
}
