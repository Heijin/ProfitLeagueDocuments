// lib/main_navigation.dart
import 'package:flutter/material.dart';
import 'package:profit_league_documents/api/api_client.dart';
import 'package:profit_league_documents/features/documents/screens/document_screen.dart';
import 'package:profit_league_documents/features/documents/screens/task_list_screen.dart';
import 'package:profit_league_documents/features/settings/screens/settings_screen.dart';


class MainNavigation extends StatefulWidget {
  final ApiClient apiClient;
  const MainNavigation({super.key, required this.apiClient});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      DocumentScreen(apiClient: widget.apiClient),
      TaskListScreen(apiClient: widget.apiClient), // Новый экран
      SettingsScreen(apiClient: widget.apiClient),
    ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.camera_alt),
            label: 'Сделать фото',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt),
            label: 'Активные',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Настройки',
          ),
        ],
      ),
    );
  }
}