// lib/api/models/task.dart
class Task {
  final String date;
  final String name;
  final String description;
  String getTime;
  final String author;
  final String whoTake;
  bool isNew;
  final String id;

  Task({
    required this.date,
    required this.name,
    required this.description,
    required this.getTime,
    required this.author,
    required this.whoTake,
    required this.isNew,
    required this.id,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      date: json['date'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      getTime: json['getTime'] ?? 'нет',
      author: json['author'] ?? '',
      whoTake: json['whoTake'] ?? 'никто',
      isNew: json['isNew'] is String
          ? json['isNew'].toLowerCase() == 'true'
          : json['isNew'] ?? false,
      id: json['id'].toString(),
    );
  }
}