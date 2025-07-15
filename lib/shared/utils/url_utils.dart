import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class UrlUtils {
  static Future<void> launchWebsite(BuildContext context, String url) async {
    try {
      final uri = Uri.parse(url.startsWith('http') ? url : 'https://$url');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Cannot launch URL';
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Не удалось открыть ссылку'),
          action: SnackBarAction(
            label: 'Ручной переход',
            onPressed: () => launchUrl(Uri.parse('https://pr-lg.ru')),
          ),
        ),
      );
    }
  }
}