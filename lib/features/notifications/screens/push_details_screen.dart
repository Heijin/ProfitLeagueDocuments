import 'dart:convert';
import 'package:flutter/material.dart';

class PushDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> data;

  const PushDetailsScreen({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
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
            const SizedBox(height: 20),
            Text('🔹 Полные данные:', style: Theme.of(context).textTheme.titleMedium),
            Text(const JsonEncoder.withIndent('  ').convert(data)),
          ],
        ),
      ),
    );
  }
}
