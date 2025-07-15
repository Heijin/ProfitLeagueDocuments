import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../utils/url_utils.dart';

class CompanyFooter extends StatelessWidget {
  const CompanyFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 12, color: Colors.grey),
          children: [
            const TextSpan(text: 'Для сотрудников компании '),
            TextSpan(
              text: '"Профит-Лига"',
              style: const TextStyle(color: Colors.blue),
              recognizer: TapGestureRecognizer()
                ..onTap = () => UrlUtils.launchWebsite(context, 'https://pr-lg.ru'),
            ),
          ],
        ),
      ),
    );
  }
}