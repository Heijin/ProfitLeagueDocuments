import '../../api/models/photo.dart';

class Document {
  final String navLink;
  String description;
  String parking;
  int numberOfPhotos;
  List<Photo> photos;

  Document({
    required this.navLink,
    this.description = '',
    this.parking = '',
    this.numberOfPhotos = 0,
    this.photos = const [],
  });

  factory Document.fromJson(Map<String, dynamic> json) {
    return Document(
      navLink: json['navLink'],
      description: json['description'] ?? '',
      parking: json['parking'] ?? '',
      numberOfPhotos: json['numberOfPhotos'] ?? 0,
      photos: (json['photos'] as List<dynamic>?)
          ?.map((e) => Photo.fromJson(e))
          .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'navLink': navLink,
      'description': description,
      'parking': parking,
      'numberOfPhotos': numberOfPhotos,
      'photos': photos.map((e) => e.toJson()).toList(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is Document && navLink == other.navLink;

  @override
  int get hashCode => navLink.hashCode;
}