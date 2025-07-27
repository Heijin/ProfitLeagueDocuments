// lib/api/models/task.dart
class Task {
  final String date;
  final String name;
  final String description;
  final String getTime;
  final String author;

  Task({
    required this.date,
    required this.name,
    required this.description,
    required this.getTime,
    required this.author,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      date: json['date'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      getTime: json['getTime'] ?? '',
      author: json['author'] ?? '',
    );
  }
}