class VideoItem {
  final String id;
  final String path;
  final String name;
  int position;
  int duration;
  String? thumbnailBase64;
  String? subtitlePath;
  String? subtitleName;

  VideoItem({
    required this.id,
    required this.path,
    required this.name,
    this.position = 0,
    this.duration = 0,
    this.thumbnailBase64,
    this.subtitlePath,
    this.subtitleName,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'path': path,
    'name': name,
    'position': position,
    'duration': duration,
    'thumbnailBase64': thumbnailBase64,
    'subtitlePath': subtitlePath,
    'subtitleName': subtitleName,
  };

  factory VideoItem.fromJson(Map<String, dynamic> json) => VideoItem(
    id: json['id'],
    path: json['path'],
    name: json['name'],
    position: json['position'] ?? 0,
    duration: json['duration'] ?? 0,
    thumbnailBase64: json['thumbnailBase64'],
    subtitlePath: json['subtitlePath'],
    subtitleName: json['subtitleName'],
  );
}
