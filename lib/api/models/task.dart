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
  final String type;

  // новые поля
  final String doc;
  final List<String> goods;

  Task({
    required this.date,
    required this.name,
    required this.description,
    required this.getTime,
    required this.author,
    required this.whoTake,
    required this.isNew,
    required this.id,
    required this.type,
    required this.doc,
    required this.goods,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      date: json['date'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      getTime: (json['getTime'] as String?)?.isNotEmpty == true ? json['getTime'] : 'нет',
      author: json['author'] ?? '',
      whoTake: (json['whoTake'] as String?)?.isNotEmpty == true ? json['whoTake'] : 'никто',
      isNew: json['isNew'] ?? false,
      id: json['id'] ?? '',
      type: json['type'] ?? '',
      doc: json['doc'] ?? '',
      goods: (json['goods'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ??
          [],
    );
  }
}
