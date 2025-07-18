import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';
import 'package:profit_league_documents/api/api_client.dart';
import 'package:profit_league_documents/features/auth/screens/authorization_screen.dart';
import 'package:profit_league_documents/shared/widgets/company_footer.dart';
import 'package:profit_league_documents/shared/auth_storage.dart';

class RegistrationScreen extends StatefulWidget {
  final ApiClient apiClient;

  const RegistrationScreen({super.key, required this.apiClient});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  void _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final name = _nameController.text.trim();
    final passwordHash = sha1.convert(utf8.encode(password)).toString();

    try {
      final response = await widget.apiClient.register(email, passwordHash, name);
      setState(() {
        _successMessage = response['message'];
      });

      AuthStorage().saveEmail(email);

      await Future.delayed(const Duration(seconds: 3));

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => AuthorizationScreen(apiClient: widget.apiClient),
          ),
        );
      }
    } on ApiException catch (e) {
      setState(() {
        _errorMessage = '${e.message}\n${e.details ?? ''}';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Неизвестная ошибка: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String? _validatePassword(String? value) {
    if (value == null || value.length < 6) {
      return 'Пароль должен быть не менее 6 символов';
    }
    if (!RegExp(r'[A-ZА-Яa-zа-я]').hasMatch(value)) {
      return 'Пароль должен содержать буквы';
    }
    if (!RegExp(r'\d').hasMatch(value)) {
      return 'Пароль должен содержать цифры';
    }
    if (!RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(value)) {
      return 'Пароль должен содержать спец. символ';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Регистрация'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    if (_errorMessage != null) ...[
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (_successMessage != null) ...[
                      Text(
                        _successMessage!,
                        style: const TextStyle(color: Colors.green),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Имя пользователя'),
                      validator: (value) =>
                      (value == null || value.trim().isEmpty) ? 'Введите имя' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(labelText: 'Почта'),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || !RegExp(r'^\S+@\S+\.\S+$').hasMatch(value)) {
                          return 'Введите корректный email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      decoration: const InputDecoration(labelText: 'Пароль'),
                      obscureText: true,
                      validator: _validatePassword,
                    ),
                    const SizedBox(height: 24),
                    _isLoading
                        ? const CircularProgressIndicator()
                        : ElevatedButton(
                      onPressed: _register,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: const Text('Регистрация'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const CompanyFooter(),
        ],
      ),
    );
  }
}