// lib/api/models/task.dart
class Task {
  final String date;
  final String name;
  final String description;
  String getTime;
  final String author;
  bool isNew;
  final String id;

  Task({
    required this.date,
    required this.name,
    required this.description,
    required this.getTime,
    required this.author,
    required this.isNew,
    required this.id,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      date: json['date'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      getTime: json['getTime'] ?? '',
      author: json['author'] ?? '',
      isNew: json['isNew'] ?? false,
      id: json['id'].toString(),
    );
  }
}