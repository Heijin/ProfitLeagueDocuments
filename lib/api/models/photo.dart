class Photo {
  String name;
  final String filePath;
  final String ext;
  bool uploaded;

  Photo({
    required this.name,
    required this.filePath,
    required this.ext,
    required this.uploaded,
  });

  factory Photo.fromJson(Map<String, dynamic> json) {
    return Photo(
      name: json['name'] as String? ?? 'Unnamed',
      filePath: json['filePath'] as String? ?? '',
      ext: json['ext'] as String? ?? 'jpg',
      uploaded: json['uploaded'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'filePath': filePath,
      'ext': ext,
      'uploaded': uploaded,
    };
  }
}