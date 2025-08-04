// lib/main_navigation.dart
import 'package:flutter/material.dart';
import 'package:profit_league_documents/api/api_client.dart';
import 'package:profit_league_documents/features/documents/screens/document_screen.dart';
import 'package:profit_league_documents/features/documents/screens/task_list_screen.dart';
import 'package:profit_league_documents/features/settings/screens/settings_screen.dart';
import 'package:profit_league_documents/firebase/firebase_service.dart';
import 'features/notifications/screens/push_details_screen.dart';
import 'navigation_service.dart';

class MainNavigation extends StatefulWidget {
  final ApiClient apiClient;
  final int initialTabIndex;

  const MainNavigation({
    super.key,
    required this.apiClient,
    this.initialTabIndex = 0,
  });

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  late int _currentIndex;
  bool _initialPushHandled = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTabIndex;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_initialPushHandled) {
      _initialPushHandled = true;
      final data = FirebaseService.consumeInitialPushData();
      if (data != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (_) => PushDetailsScreen(apiClient:widget.apiClient, data: data),
            ),
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      DocumentScreen(apiClient: widget.apiClient),
      TaskListScreen(apiClient: widget.apiClient),
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
