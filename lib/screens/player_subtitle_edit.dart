import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/subtitle_item.dart';
import '../theme/app_theme.dart';

class SubtitleEditDialog extends StatefulWidget {
  final SubtitleItem subtitle;

  const SubtitleEditDialog({super.key, required this.subtitle});

  @override
  State<SubtitleEditDialog> createState() => _SubtitleEditDialogState();
}

class _SubtitleEditDialogState extends State<SubtitleEditDialog> {
  late TextEditingController _textController;
  late TextEditingController _startController;
  late TextEditingController _endController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.subtitle.text);
    _startController = TextEditingController(text: _formatMs(widget.subtitle.startMs));
    _endController = TextEditingController(text: _formatMs(widget.subtitle.endMs));
  }

  @override
  void dispose() {
    _textController.dispose();
    _startController.dispose();
    _endController.dispose();
    super.dispose();
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
    return Dialog(
      backgroundColor: AppTheme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.subtitles, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  '编辑字幕',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              '字幕内容',
              style: TextStyle(fontSize: 14, color: AppTheme.textColor.withOpacity(0.8)),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _textController,
              maxLines: 3,
              style: TextStyle(color: AppTheme.textColor),
              decoration: InputDecoration(
                hintText: '请输入字幕内容',
                hintStyle: TextStyle(color: AppTheme.textColor.withOpacity(0.5)),
                filled: true,
                fillColor: AppTheme.backgroundColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
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
                      const SizedBox(height: 8),
                      TextField(
                        controller: _startController,
                        style: TextStyle(color: AppTheme.textColor),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[\d:.]')),
                        ],
                        decoration: InputDecoration(
                          hintText: '00:00:00.000',
                          hintStyle: TextStyle(color: AppTheme.textColor.withOpacity(0.5)),
                          filled: true,
                          fillColor: AppTheme.backgroundColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _adjustTime(_startController, -50),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.textColor,
                                side: BorderSide(color: AppTheme.textColor.withOpacity(0.3)),
                                padding: const EdgeInsets.symmetric(vertical: 4),
                              ),
                              child: const Text('-50ms', style: TextStyle(fontSize: 12)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _adjustTime(_startController, 50),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.textColor,
                                side: BorderSide(color: AppTheme.textColor.withOpacity(0.3)),
                                padding: const EdgeInsets.symmetric(vertical: 4),
                              ),
                              child: const Text('+50ms', style: TextStyle(fontSize: 12)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '结束时间',
                        style: TextStyle(fontSize: 14, color: AppTheme.textColor.withOpacity(0.8)),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _endController,
                        style: TextStyle(color: AppTheme.textColor),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[\d:.]')),
                        ],
                        decoration: InputDecoration(
                          hintText: '00:00:00.000',
                          hintStyle: TextStyle(color: AppTheme.textColor.withOpacity(0.5)),
                          filled: true,
                          fillColor: AppTheme.backgroundColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _adjustTime(_endController, -50),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.textColor,
                                side: BorderSide(color: AppTheme.textColor.withOpacity(0.3)),
                                padding: const EdgeInsets.symmetric(vertical: 4),
                              ),
                              child: const Text('-50ms', style: TextStyle(fontSize: 12)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _adjustTime(_endController, 50),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.textColor,
                                side: BorderSide(color: AppTheme.textColor.withOpacity(0.3)),
                                padding: const EdgeInsets.symmetric(vertical: 4),
                              ),
                              child: const Text('+50ms', style: TextStyle(fontSize: 12)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    '取消',
                    style: TextStyle(color: AppTheme.textColor.withOpacity(0.7)),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('保存'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
