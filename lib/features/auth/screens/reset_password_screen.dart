import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';
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
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _codeController = TextEditingController();

  String? _emailError;
  String? _passwordError;
  String? _codeError;
  String? _infoMessage;
  bool _isErrorMessage = false;

  bool _isLoading = false;

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

  Future<void> _requestCode() async {
    setState(() {
      _emailError = null;
      _infoMessage = null;
      _isErrorMessage = false;
      _isLoading = true;
    });

    final email = _emailController.text.trim();
    if (!Validators.isValidEmail(email)) {
      setState(() {
        _emailError = 'Введите корректный email';
        _isLoading = false;
      });
      return;
    }

    try {
      final response = await widget.apiClient.get("/resetCode?email=$email", withAuth: false);

      if (response.statusCode == 200) {
        setState(() {
          _infoMessage = 'Код сброса отправлен на почту';
          _isErrorMessage = false;
        });
      } else {
        final data = jsonDecode(response.body);
        setState(() {
          _infoMessage = 'Ошибка: ${data['message'] ?? 'Неизвестная ошибка'}';
          _isErrorMessage = true;
        });
      }
    } catch (e) {
      setState(() {
        _infoMessage = 'Ошибка: $e';
        _isErrorMessage = true;
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _setNewPassword() async {
    setState(() {
      _emailError = null;
      _passwordError = null;
      _codeError = null;
      _infoMessage = null;
      _isErrorMessage = false;
      _isLoading = true;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final code = _codeController.text.trim();

    bool hasError = false;

    if (!Validators.isValidEmail(email)) {
      _emailError = 'Введите корректный email';
      hasError = true;
    }

    final passwordValidation = Validators.validatePassword(password);
    if (passwordValidation != null) {
      _passwordError = passwordValidation;
      hasError = true;
    }

    if (code.isEmpty) {
      _codeError = 'Введите код сброса';
      hasError = true;
    }

    if (hasError) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final passwordHash = sha1.convert(utf8.encode(password)).toString();
      final uri = '/resetPassword?email=$email&password=$passwordHash&code=$code';
      final response = await widget.apiClient.get(uri, withAuth: false);

      if (response.statusCode == 200) {
        setState(() {
          _infoMessage = 'Новый пароль успешно установлен';
          _isErrorMessage = false;
        });
      } else {
        final data = jsonDecode(response.body);
        setState(() {
          _infoMessage = 'Ошибка: ${data['message'] ?? 'Неизвестная ошибка'}';
          _isErrorMessage = true;
        });
      }
    } catch (e) {
      setState(() {
        _infoMessage = 'Ошибка: $e';
        _isErrorMessage = true;
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Сброс пароля'), backgroundColor: Colors.green),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Почта',
                  errorText: _emailError,
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Новый пароль',
                  errorText: _passwordError,
                ),
                obscureText: true,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _codeController,
                decoration: InputDecoration(
                  labelText: 'Код сброса',
                  errorText: _codeError,
                ),
              ),
              const SizedBox(height: 24),
              if (_infoMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _infoMessage!,
                    style: TextStyle(
                      color: _isErrorMessage ? Colors.red : Colors.green,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _requestCode,
                      child: const Text('Запросить код'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _setNewPassword,
                      child: const Text('Установить новый пароль'),
                    ),
                  ),
                ],
              ),
              if (_isLoading) const SizedBox(height: 12),
              if (_isLoading) const LinearProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}
