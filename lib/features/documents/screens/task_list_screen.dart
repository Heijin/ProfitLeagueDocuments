import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchTasks();
  }

  Future<void> _fetchTasks() async {
    setState(() => isLoading = true);
    try {
      final response = await widget.apiClient.get('/taskList');
      final List<dynamic> data = jsonDecode(response.body);
      setState(() {
        tasks = data.map((e) => Task.fromJson(e)).toList();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка загрузки заданий: $e')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _takeOnTask(Task task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Подтверждение'),
        content: const Text('Вы точно берете в работу?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Нет'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Да',
              style: TextStyle(color: Colors.green),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final response = await widget.apiClient.get('/takeOnTask?id=${task.id}');
      if (response.statusCode == 200) {
        setState(() {
          task.isNew = false;
          task.getTime = DateFormat.Hm().format(DateTime.now());
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Задание взято в работу')),
        );
      } else {
        final decoded = json.decode(response.body);
        final message = decoded['message'] ?? 'Неизвестная ошибка';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $message')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Активные задания')),
      body: RefreshIndicator(
        onRefresh: _fetchTasks,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : tasks.isEmpty
            ? const Center(child: Text('Нет активных заданий'))
            : ListView.builder(
          itemCount: tasks.length,
            itemBuilder: (context, index) {
              final task = tasks[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.assignment, color: Colors.blue[700], size: 32),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              task.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        task.description,
                        style: const TextStyle(fontSize: 15, color: Colors.black87),
                      ),
                      const SizedBox(height: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.calendar_today,
                                  size: 16, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text(task.date, style: const TextStyle(color: Colors.grey)),
                              const SizedBox(width: 16),
                              Icon(Icons.access_time,
                                  size: 16, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text(task.getTime, style: const TextStyle(color: Colors.grey)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.person, size: 16, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  task.author,
                                  style: const TextStyle(color: Colors.grey),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (task.isNew) ...[
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton(
                            onPressed: () => _takeOnTask(task),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding:
                              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                            child: const Text('Взять в работу'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
        ),
      ),
    );
  }
}
