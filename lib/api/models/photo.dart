class Photo {
  String name;
  final String base64;
  final String ext;
  bool uploaded;

  Photo({
    required this.name,
    required this.base64,
    required this.ext,
    required this.uploaded,
  });

  factory Photo.fromJson(Map<String, dynamic> json) {
    return Photo(
      name: json['name'] as String? ?? 'Unnamed',
      base64: json['base64'] as String? ?? '',
      ext: json['ext'] as String? ?? 'jpg',
      uploaded: json['uploaded'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'base64': base64,
      'ext': ext,
      'uploaded': uploaded,
    };
  }
}