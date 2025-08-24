import 'package:flutter/material.dart';
import 'package:profit_league_documents/api/api_client.dart';
import 'package:profit_league_documents/shared/auth_storage.dart';
import 'package:profit_league_documents/features/auth/screens/authorization_screen.dart';

class SettingsScreen extends StatefulWidget {
  final ApiClient apiClient;

  const SettingsScreen({super.key, required this.apiClient});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _email = '';
  final AuthStorage _storage = AuthStorage();

  @override
  void initState() {
    super.initState();
    _loadEmail();
  }

  Future<void> _loadEmail() async {
    final email = await _storage.getEmail();
    if (mounted) {
      setState(() {
        _email = email ?? '';
      });
    }
  }

  Future<void> _changeUser() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Сменить пользователя?'),
        content: const Text('Вы уверены, что хотите сменить пользователя?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.green),
            child: const Text('Да'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Нет'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // Очищаем сохранённый refresh_token и access_token
      await _storage.saveRefreshToken('');
      await _storage.saveAccessToken('');

      // Переходим на экран авторизации
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => AuthorizationScreen(apiClient: widget.apiClient),
          ),
              (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки'),
        backgroundColor: Colors.green,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 0,
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: ListTile(
              leading: const Icon(Icons.email, color: Colors.green),
              title: const Text('Электронная почта'),
              subtitle: Text(_email.isNotEmpty ? _email : 'Не указано'),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: ListTile(
              leading: const Icon(Icons.switch_account, color: Colors.green),
              title: const Text('Сменить пользователя'),
              onTap: _changeUser,
            ),
          ),
        ],
      ),
    );
  }
}
