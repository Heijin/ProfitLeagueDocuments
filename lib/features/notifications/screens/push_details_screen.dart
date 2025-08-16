import 'package:profit_league_documents/api/api_client.dart';
import 'package:flutter/material.dart';
import 'package:profit_league_documents/main_navigation.dart';

class PushDetailsScreen extends StatelessWidget {
  final ApiClient apiClient;
  final Map<String, dynamic> data;

  PushDetailsScreen({
    super.key,
    required this.data,
    ApiClient? apiClient,
  }) : apiClient = apiClient ?? ApiClient();

  @override
  Widget build(BuildContext context) {
    final taskId = data['id'];

    // Если в пуше есть id задачи — сразу открываем MainNavigation с вкладкой заданий
    if (taskId != null) {
      Future.microtask(() {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => MainNavigation(
              apiClient: apiClient,
              initialTabIndex: 1,
            ),
          ),
        );
      });

      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Если id нет — просто показываем содержимое пуша
    final title = data['title'] ?? 'Без заголовка';
    final body = data['body'] ?? 'Без текста';

    return Scaffold(
      appBar: AppBar(title: const Text('Детали уведомления')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text('🔹 Заголовок:', style: Theme.of(context).textTheme.titleMedium),
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 20),
            Text('🔹 Сообщение:', style: Theme.of(context).textTheme.titleMedium),
            Text(body, style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}
