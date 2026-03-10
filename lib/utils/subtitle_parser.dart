import 'package:flutter/material.dart';
import '../models/subtitle_item.dart';

List<SubtitleItem> parseSubtitles(String content) {
  final List<SubtitleItem> subtitles = [];
  final lines = content.split('\n');
  
  int i = 0;
  while (i < lines.length) {
    String line = lines[i].trim();
    
    if (line.isEmpty) {
      i++;
      continue;
    }
    
    if (line.contains('-->')) {
      try {
        final times = line.split('-->');
        if (times.length == 2) {
          final startMs = _parseTime(times[0].trim());
          final endMs = _parseTime(times[1].trim());
          
          final List<String> textLines = [];
          i++;
          while (i < lines.length && lines[i].trim().isNotEmpty) {
            textLines.add(lines[i].trim());
            i++;
          }
          
          if (textLines.isNotEmpty) {
            subtitles.add(SubtitleItem(
              startMs: startMs,
              endMs: endMs,
              text: textLines.join('\n'),
            ));
          }
          continue;
        }
      } catch (e) {
        debugPrint('Error parsing subtitle line: $line');
      }
    }
    i++;
  }
  
  return subtitles;
}

int _parseTime(String timeStr) {
  timeStr = timeStr.replaceAll(',', '.');
  
  final parts = timeStr.split(':');
  if (parts.length == 3) {
    final hours = int.parse(parts[0]);
    final minutes = int.parse(parts[1]);
    final secondsParts = parts[2].split('.');
    final seconds = int.parse(secondsParts[0]);
    final millis = secondsParts.length > 1 ? int.parse(secondsParts[1].padRight(3, '0').substring(0, 3)) : 0;
    return hours * 3600000 + minutes * 60000 + seconds * 1000 + millis;
  } else if (parts.length == 2) {
    final minutes = int.parse(parts[0]);
    final secondsParts = parts[1].split('.');
    final seconds = int.parse(secondsParts[0]);
    final millis = secondsParts.length > 1 ? int.parse(secondsParts[1].padRight(3, '0').substring(0, 3)) : 0;
    return minutes * 60000 + seconds * 1000 + millis;
  }
  return 0;
}

String formatDuration(int milliseconds) {
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

String formatMs(int ms) {
  final duration = Duration(milliseconds: ms);
  final hours = duration.inHours;
  final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
  final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
  final milliseconds = (ms % 1000).toString().padLeft(3, '0');
  if (hours > 0) {
    return '${hours.toString().padLeft(2, '0')}:$minutes:$seconds.$milliseconds';
  } else {
    return '$minutes:$seconds.$milliseconds';
  }
}

String exportSubtitles(List<SubtitleItem> subtitles) {
  final buffer = StringBuffer();
  
  for (int i = 0; i < subtitles.length; i++) {
    final subtitle = subtitles[i];
    buffer.writeln(i + 1);
    buffer.writeln('${_formatTimeForExport(subtitle.startMs)} --> ${_formatTimeForExport(subtitle.endMs)}');
    buffer.writeln(subtitle.text);
    buffer.writeln();
  }
  
  return buffer.toString();
}

String _formatTimeForExport(int ms) {
  final duration = Duration(milliseconds: ms);
  final hours = duration.inHours.toString().padLeft(2, '0');
  final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
  final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
  final milliseconds = (ms % 1000).toString().padLeft(3, '0');
  return '$hours:$minutes:$seconds,$milliseconds';
}