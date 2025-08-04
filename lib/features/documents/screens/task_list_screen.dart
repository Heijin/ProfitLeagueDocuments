import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:profit_league_documents/api/api_client.dart';
import 'package:profit_league_documents/api/models/task.dart';

class TaskListScreen extends StatefulWidget {
  final ApiClient apiClient;

  const TaskListScreen({super.key, required this.apiClient});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  List<Task> tasks = [];
  bool isLoading = true;
  final Set<String> completedTaskIds = {};
  List<Map<String, dynamic>>? commentsCache;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    try {
      final response = await widget.apiClient.get('/taskList');
      final List<dynamic> data = json.decode(response.body);
      setState(() {
        tasks = data.map((e) => Task.fromJson(e)).toList();
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка загрузки: $e')));
    }
  }

  Future<void> _takeTask(Task task) async {
    try {
      final response = await widget.apiClient.get('/task?id=${task.id}');
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Задание взято в работу')));
        _loadTasks();
      } else {
        final decoded = json.decode(response.body);
        final message = decoded['message'] ?? 'Неизвестная ошибка';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка: $message')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  Future<void> _completeTask(Task task) async {
    try {
      // Загружаем только один раз
      if (commentsCache == null) {
        final commentsResp = await widget.apiClient.get('/comments');
        final List<dynamic> commentsJson = json.decode(commentsResp.body);
        commentsCache = commentsJson
            .map<Map<String, dynamic>>(
              (e) => {'id': e['id'], 'name': e['name']},
            )
            .toList();
      }

      final selected = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('Выберите комментарий'),
          children: commentsCache!
              .map(
                (comment) => SimpleDialogOption(
                  child: Text(comment['name']),
                  onPressed: () => Navigator.pop(context, comment),
                ),
              )
              .toList(),
        ),
      );

      if (selected == null) return;

      final response = await widget.apiClient.post(
        '/task?id=${task.id}',
        body: {'commentId': selected['id']},
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Задание успешно завершено')),
        );
        setState(() {
          completedTaskIds.add(task.id);
        });
      } else {
        final decoded = json.decode(response.body);
        final message = decoded['message'] ?? 'Неизвестная ошибка';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка завершения: $message')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Список заданий')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: tasks.length,
              itemBuilder: (context, index) {
                final task = tasks[index];

                final isCompleted = completedTaskIds.contains(task.id);

                return Card(
                  elevation: 4,
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: task.isNew
                          ? Colors.green.shade300
                          : Colors.red.shade300,
                      width: 1.5,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_today,
                              size: 20,
                              color: Colors.blueGrey,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Дата создания: ${task.date}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.title,
                              size: 20,
                              color: Colors.orange,
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text('Название: ${task.name}')),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.description,
                              size: 20,
                              color: Colors.teal,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text('Описание: ${task.description}'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.timer_outlined,
                              size: 20,
                              color: Colors.deepPurple,
                            ),
                            const SizedBox(width: 8),
                            Text('Время взятия: ${task.getTime}'),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.person,
                                  size: 20,
                                  color: Colors.indigo,
                                ),
                                const SizedBox(width: 8),
                                Text('Автор: ${task.author}'),
                              ],
                            ),
                            Row(
                              children: [
                                const Icon(
                                  Icons.assignment_ind,
                                  size: 20,
                                  color: Colors.teal,
                                ),
                                const SizedBox(width: 8),
                                Text('Кто взял: ${task.whoTake}'),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerRight,
                          child: isCompleted
                              ? const Text(
                                  'Задача завершена',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : ElevatedButton.icon(
                                  onPressed: () {
                                    if (task.isNew) {
                                      _takeTask(task);
                                    } else {
                                      _completeTask(task);
                                    }
                                  },
                                  icon: Icon(
                                    task.isNew ? Icons.play_arrow : Icons.check,
                                  ),
                                  label: Text(
                                    task.isNew
                                        ? 'Взять в работу'
                                        : 'Завершить задание',
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: task.isNew
                                        ? Colors.green
                                        : Colors.red,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
