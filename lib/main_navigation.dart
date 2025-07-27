// lib/main_navigation.dart
import 'package:flutter/material.dart';
import 'package:profit_league_documents/api/api_client.dart';
import 'package:profit_league_documents/features/documents/screens/document_screen.dart';
import 'package:profit_league_documents/features/documents/screens/task_list_screen.dart';

class SettingsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(child: Text('Настройки'));
  }
}

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
      SettingsScreen(),
    ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.camera_alt),
            label: 'Фотографировать',
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