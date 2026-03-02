import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/video_item.dart';

class VideoStore extends ChangeNotifier {
  List<VideoItem> _videos = [];
  List<VideoItem> get videos => _videos;

  static const String _storageKey = 'video_list';

  Future<void> loadVideos() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_storageKey);
    if (jsonString != null) {
      try {
        final List<dynamic> jsonList = json.decode(jsonString);
        List<VideoItem> loadedVideos = jsonList.map((e) => VideoItem.fromJson(e)).toList();
        _videos = loadedVideos.map((video) {
          if (video.name.isEmpty || video.name.contains(RegExp(r'^\d+$'))) {
            final pathParts = video.path.split(RegExp(r'[/\\]'));
            return VideoItem(
              id: video.id,
              path: video.path,
              name: pathParts.isNotEmpty ? pathParts.last : '未命名视频',
              position: video.position,
            );
          }
          return video;
        }).toList();
        notifyListeners();
      } catch (e) {
        await prefs.remove(_storageKey);
      }
    }
  }

  Future<void> addVideo(VideoItem video) async {
    _videos.add(video);
    await _saveVideos();
    notifyListeners();
  }

  Future<void> updateVideoPosition(String id, int position) async {
    final index = _videos.indexWhere((v) => v.id == id);
    if (index != -1) {
      _videos[index].position = position;
      await _saveVideos();
      notifyListeners();
    }
  }

  Future<void> updateSubtitle(String id, String? subtitlePath, String? subtitleName) async {
    final index = _videos.indexWhere((v) => v.id == id);
    if (index != -1) {
      _videos[index].subtitlePath = subtitlePath;
      _videos[index].subtitleName = subtitleName;
      await _saveVideos();
      notifyListeners();
    }
  }

  Future<void> updateThumbnail(String id, String? thumbnailBase64) async {
    final index = _videos.indexWhere((v) => v.id == id);
    if (index != -1) {
      _videos[index].thumbnailBase64 = thumbnailBase64;
      await _saveVideos();
      notifyListeners();
    }
  }

  Future<void> updateDuration(String id, int duration) async {
    final index = _videos.indexWhere((v) => v.id == id);
    if (index != -1) {
      _videos[index].duration = duration;
      await _saveVideos();
      notifyListeners();
    }
  }

  Future<void> removeVideo(String id) async {
    _videos.removeWhere((v) => v.id == id);
    await _saveVideos();
    notifyListeners();
  }

  Future<void> _saveVideos() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = json.encode(_videos.map((v) => v.toJson()).toList());
    await prefs.setString(_storageKey, jsonString);
  }
}
