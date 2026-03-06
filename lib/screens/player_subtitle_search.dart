import '../models/subtitle_item.dart';

/// 字幕搜索类 - 提供二分查找和线性查找算法
class SubtitleSearch {
  /// 二分查找 - O(log n) 复杂度
  static int binarySearch(List<SubtitleItem> subtitles, int positionMs) {
    int left = 0;
    int right = subtitles.length - 1;
    int result = -1;

    while (left <= right) {
      int mid = (left + right) ~/ 2;
      final subtitle = subtitles[mid];

      if (positionMs > subtitle.startMs && positionMs <= subtitle.endMs) {
        return mid; // Found exact match
      } else if (positionMs < subtitle.startMs) {
        right = mid - 1;
      } else {
        result = mid; // Keep track of last subtitle before position
        left = mid + 1;
      }
    }

    return result >= 0 ? result : -1;
  }

  /// 线性查找 - O(n) 复杂度
  static int linearSearch(List<SubtitleItem> subtitles, int positionMs) {
    int result = -1;

    for (int i = 0; i < subtitles.length; i++) {
      final subtitle = subtitles[i];

      if (positionMs > subtitle.startMs && positionMs <= subtitle.endMs) {
        return i; // Found exact match
      }

      if (positionMs >= subtitle.endMs) {
        result = i; // Keep track of last subtitle before position
      }
    }

    return result;
  }

  /// 搜索字幕 - 默认使用二分查找
  static int search(List<SubtitleItem> subtitles, int positionMs) {
    return binarySearch(subtitles, positionMs);
  }
}
