import 'package:flutter/material.dart';
import 'package:profit_league_documents/api/api_client.dart';
import 'package:profit_league_documents/shared/auth_storage.dart';
import 'package:profit_league_documents/features/auth/screens/validators.dart';

class ResetPasswordScreen extends StatefulWidget {
  final ApiClient apiClient;

  const ResetPasswordScreen({super.key, required this.apiClient});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailFormKey = GlobalKey<FormState>(); // отдельный ключ для email
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _codeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSavedEmail();
  }

  Future<void> _loadSavedEmail() async {
    final savedEmail = await AuthStorage().getEmail();
    if (savedEmail != null && mounted) {
      setState(() {
        _emailController.text = savedEmail;
      });
    }
  }

  void _requestCode() {
    if (_emailFormKey.currentState!.validate()) {
      // заглушка
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Запрос кода отправлен (заглушка)')),
      );
    }
  }

  void _setNewPassword() {
    if (!_formKey.currentState!.validate()) return;

    // заглушка
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Пароль обновлён (заглушка)')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Сброс пароля'), backgroundColor: Colors.green),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Form(
              key: _emailFormKey,
              child: TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Почта'),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (!Validators.isValidEmail(value)) {
                    return 'Введите корректный email';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 12),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(labelText: 'Новый пароль'),
                    obscureText: true,
                    validator: Validators.validatePassword,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _codeController,
                    decoration: const InputDecoration(labelText: 'Код сброса'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Введите код сброса';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _requestCode,
                    child: const Text('Запросить код'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _setNewPassword,
                    child: const Text('Установить новый пароль'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
