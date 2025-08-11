import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:profit_league_documents/api/api_client.dart';
import 'package:profit_league_documents/api/models/task.dart';
import 'task_card.dart';

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
          : RefreshIndicator(
        onRefresh: _loadTasks,
        child: tasks.isEmpty
            ? ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 100),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.assignment_turned_in, size: 64, color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Заданий нет',
                  style: TextStyle(color: Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        )
            : ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: tasks.length,
          itemBuilder: (context, index) {
            final task = tasks[index];
            final isCompleted =
            completedTaskIds.contains(task.id);

            return TaskCard(
              task: task,
              isCompleted: isCompleted,
              onTake: () => _takeTask(task),
              onComplete: () => _completeTask(task),
            );
          },
        ),
      ),
    );
  }
}
