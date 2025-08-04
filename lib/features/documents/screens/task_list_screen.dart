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
  bool isLoading = true;

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка загрузки: $e')),
      );
    }
  }

  Future<void> _takeTask(Task task) async {
    try {
      final response = await widget.apiClient.get('/task?id=${task.id}');
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Задание взято в работу')),
        );
        _loadTasks();
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

  Future<void> _completeTask(Task task) async {
    final List<String> comments =
    List.generate(15, (i) => 'Комментарий ${i + 1}');

    final selectedComment = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Выберите комментарий'),
        children: comments
            .map((comment) => SimpleDialogOption(
          child: Text(comment),
          onPressed: () => Navigator.pop(context, comment),
        ))
            .toList(),
      ),
    );

    if (selectedComment == null) return;

    try {
      final response = await widget.apiClient.post(
        '/task?id=${task.id}',
        body: {'comment': selectedComment},
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Задание успешно завершено')),
        );
        _loadTasks();
      } else {
        final decoded = json.decode(response.body);
        final message = decoded['message'] ?? 'Неизвестная ошибка';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка завершения: $message')),
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
      appBar: AppBar(
        title: const Text('Список заданий'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: tasks.length,
        itemBuilder: (context, index) {
          final task = tasks[index];
          final dateFormatted = DateFormat('dd.MM.yyyy HH:mm')
              .format(DateTime.tryParse(task.date) ?? DateTime.now());

          return Card(
            elevation: 2,
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Дата: $dateFormatted',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Название: ${task.name}'),
                  const SizedBox(height: 4),
                  Text('Описание: ${task.description}'),
                  const SizedBox(height: 4),
                  Text('Время: ${task.getTime}'),
                  const SizedBox(height: 4),
                  Text('Автор: ${task.author}'),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      onPressed: () {
                        if (task.isNew) {
                          _takeTask(task);
                        } else {
                          _completeTask(task);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                        task.isNew ? Colors.green : Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                      ),
                      child: Text(task.isNew
                          ? 'Взять в работу'
                          : 'Завершить задание'),
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
