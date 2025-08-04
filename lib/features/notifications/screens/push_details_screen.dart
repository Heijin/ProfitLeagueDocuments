import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:profit_league_documents/api/api_client.dart';
import 'package:profit_league_documents/main_navigation.dart'; // добавь этот импорт, если у тебя TaskListScreen в другом файле

class PushDetailsScreen extends StatefulWidget {
  final ApiClient apiClient;
  final Map<String, dynamic> data;

  PushDetailsScreen({
    super.key,
    ApiClient? apiClient,
    required this.data,
  }) : apiClient = apiClient ?? ApiClient(); // 👈 дефолтный клиент

  @override
  State<PushDetailsScreen> createState() => _PushDetailsScreenState();
}

class _PushDetailsScreenState extends State<PushDetailsScreen> {
  bool _isTakingTask = false;
  bool _taskTaken = false;
  String? _errorMessage;

  Future<void> _takeOnTask(String id) async {
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

    setState(() {
      _isTakingTask = true;
      _errorMessage = null;
    });

    try {
      final response = await widget.apiClient.get('/takeOnTask?id=$id');
      final body = response.body;
      if (response.statusCode == 200) {
        setState(() {
          _taskTaken = true;
        });

        // Через 1 секунду переходим на TaskListScreen
        Future.delayed(const Duration(seconds: 1), () {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => MainNavigation(apiClient: widget.apiClient, initialTabIndex: 1), // индекс "Задания"
            ),
          );
        });
      } else {
        final decoded = json.decode(body);
        _errorMessage = 'Ошибка: ${decoded['message']}';
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isTakingTask = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final title = data['title'] ?? 'Без заголовка';
    final body = data['body'] ?? 'Без текста';
    final desc = data['desc'] ?? '—';
    final isNewTask = data['type'] == 'new_task';
    final taskId = data['id']?.toString();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Детали уведомления'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text('🔹 Заголовок:', style: Theme.of(context).textTheme.titleMedium),
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 20),
            Text('🔹 Сообщение:', style: Theme.of(context).textTheme.titleMedium),
            Text(body, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 20),
            Text('🔹 Описание:', style: Theme.of(context).textTheme.titleMedium),
            Text(desc, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 20),
            if (isNewTask && taskId != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ElevatedButton(
                    onPressed: (_taskTaken || _isTakingTask)
                        ? null
                        : () => _takeOnTask(taskId),
                    child: _isTakingTask
                        ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : const Text('Взять в работу'),
                  ),
                  const SizedBox(height: 10),
                  if (_taskTaken)
                    const Text(
                      'Задание взято в работу',
                      style: TextStyle(color: Colors.green),
                    ),
                  if (_errorMessage != null)
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
