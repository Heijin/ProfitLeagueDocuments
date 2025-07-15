import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:profit_league_documents/api/api_client.dart';
import 'package:profit_league_documents/features/documents/screens/document_photos_screen.dart';
import 'package:profit_league_documents/features/documents/screens/qr_scanner_screen.dart';
import 'package:profit_league_documents/shared/auth_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/gestures.dart';
import '../../../api/models/document.dart';
import '../../../api/models/photo.dart';

class DocumentScreen extends StatefulWidget {
  final ApiClient apiClient;

  const DocumentScreen({super.key, required this.apiClient});

  @override
  State<DocumentScreen> createState() => _DocumentScreenState();
}

class _DocumentScreenState extends State<DocumentScreen> {
  List<Document> documents = [];
  final AuthStorage _storage = AuthStorage();

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    final storedData = await _storage.getDocuments();
    if (storedData != null) {
      setState(() {
        documents = (jsonDecode(storedData) as List<dynamic>)
            .map((e) => Document.fromJson(e))
            .toList();
      });
    }
  }

  Future<void> _saveDocuments() async {
    await _storage.saveDocuments(jsonEncode(documents.map((e) => e.toJson()).toList()));
  }

  Future<void> _loadPhotosForDocument(Document doc) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black54,
        builder: (_) => const LoadingOverlay(),
      );

      final response = await widget.apiClient.get(
        '/docPhoto?navLink=${doc.navLink}',
      );
      if (!mounted) return;
      final List<dynamic> data = json.decode(response.body);
      setState(() {
        doc.photos = data.map((item) => Photo(
          name: item['name'],
          base64: item['base64'],
          ext: item['ext'],
          uploaded: item['uploaded'],
        )).toList();
        doc.numberOfPhotos = doc.photos.where((p) => p.uploaded).length;
      });
      await _saveDocuments();

      Navigator.of(context).pop(); // Закрываем лоадер

      if (doc.photos.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Нет фотографий для этого документа')),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Закрываем лоадер
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: ${e.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Закрываем лоадер
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка загрузки фотографий')),
        );
        debugPrint('Ошибка загрузки фотографий: $e');
      }
    }
  }

  void _navigateToPhotoScreen(BuildContext context, Document doc) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (_) => const LoadingOverlay(),
    );

    try {
      await _loadPhotosForDocument(doc);
      if (!mounted) return;
      Navigator.of(context).pop();
      final updatedDocument = await Navigator.push<Document>(
        context,
        MaterialPageRoute(
          builder: (_) => DocumentPhotosScreen(document: doc),
        ),
      );

      if (updatedDocument != null) {
        setState(() {
          final index = documents.indexWhere((d) => d.navLink == updatedDocument.navLink);
          if (index != -1) {
            documents[index] = updatedDocument;
            print('Updated document ${updatedDocument.navLink} with numberOfPhotos: ${updatedDocument.numberOfPhotos}');
          }
        });
        await _saveDocuments();
      }
    } catch (_) {
      if (mounted) Navigator.of(context).pop();
    }
  }

  void _openScanner({bool isParkingScanner = false, Document? document}) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => QRScannerScreen(isParkingScanner: isParkingScanner, document: document),
      ),
    );

    if (result != null) {
      if (isParkingScanner) {
        _handleParkingQR(result['data'], result['document']);
      } else {
        _handleDocumentQR(result['data']);
      }
    }
  }

  void _handleDocumentQR(String navLink) async {
    if (!navLink.startsWith('e1cib/data/')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ошибка чтения QR: некорректный формат')),
      );
      return;
    }

    final existingDocIndex = documents.indexWhere((d) => d.navLink == navLink);
    if (existingDocIndex != -1) {
      setState(() {
        final doc = documents.removeAt(existingDocIndex);
        documents.insert(0, doc);
      });
      await _saveDocuments();
      await _fetchDocumentInfoWithLoader(documents.first);
      return;
    }

    final newDoc = Document(navLink: navLink);
    setState(() {
      documents.insert(0, newDoc);
    });
    await _saveDocuments();
    await _fetchDocumentInfoWithLoader(newDoc);
  }

  void _handleParkingQR(String areaId, Document doc) async {
    try {
      final response = await widget.apiClient.parkDocument(doc.navLink, areaId);
      setState(() {
        doc.parking = response['parking'] ?? '';
      });
      await _saveDocuments();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Документ припаркован: ${response['parking']}')),
      );
    } on ApiException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: ${e.message}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ошибка при парковке документа')),
      );
    }
  }

  Future<void> _fetchDocumentInfoWithLoader(Document doc) async {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (_) => const LoadingOverlay(),
    );

    try {
      final response = await widget.apiClient.getDocumentInfo(doc.navLink);
      if (!mounted) return;
      setState(() {
        doc.description = response['description'] ?? '';
        doc.parking = response['parking'] ?? '';
        doc.numberOfPhotos = response['numberOfPhotos'] ?? 0;
      });
      await _saveDocuments();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: ${e.message} ${e.details ?? ''}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка получения информации о документе')),
        );
      }
    } finally {
      if (mounted) {
        Navigator.of(context).pop(); // Закрываем лоадер
      }
    }
  }

  Future<void> _clearDocuments() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Очистить список документов?'),
        content: const Text('Вы уверены, что хотите удалить все документы из списка?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Нет'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Да', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        documents.clear();
      });
      await _storage.clearDocuments();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Список документов очищен')),
      );
    }
  }

  Future<void> _deleteDocument(int index) async {
    setState(() {
      documents.removeAt(index);
    });
    await _saveDocuments();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Документ удалён')),
    );
  }

  Future<void> _launchWebsite(String url) async {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Документы'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever),
            onPressed: _clearDocuments,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildDocumentList()),
          Padding(
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
                      ..onTap = () => _launchWebsite('https://pr-lg.ru'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.green,
        child: const Icon(Icons.qr_code_scanner, color: Colors.white),
        onPressed: () => _openScanner(),
      ),
    );
  }

  Widget _buildDocumentList() {
    if (documents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.qr_code, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'Отсканируйте QR-код документа',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: documents.length,
      itemBuilder: (context, index) {
        final doc = documents[index];
        return Dismissible(
          key: Key(doc.navLink),
          direction: DismissDirection.endToStart,
          background: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 16),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          confirmDismiss: (direction) async {
            if (direction == DismissDirection.endToStart) {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Удалить документ?'),
                  content: const Text('Вы уверены, что хотите удалить этот документ?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Нет'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Да', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                await _deleteDocument(index);
                return true;
              }
            }
            return false;
          },
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading: IconButton(
                icon: const Icon(Icons.shelves, color: Colors.blue),
                onPressed: () => _openScanner(isParkingScanner: true, document: doc),
              ),
              title: Text(
                doc.description.isEmpty ? 'Документ' : doc.description,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Row(
                children: [
                  if (doc.parking.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue[100],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        doc.parking,
                        style: const TextStyle(color: Colors.blue, fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    'Фотографий: ${doc.numberOfPhotos}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
              trailing: IconButton(
                icon: const Icon(Icons.photo_library, color: Colors.green),
                onPressed: () => _navigateToPhotoScreen(context, doc),
              ),
              onTap: () => _navigateToPhotoScreen(context, doc),
            ),
          ),
        );
      },
    );
  }
}

class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 250,
          maxHeight: 200,
        ),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white, // Полностью непрозрачный белый фон
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Lottie.asset(
                'assets/animations/loader.json',
                width: 100,
                height: 100,
                fit: BoxFit.contain,
                backgroundLoading: true, // Загрузка в фоне для избежания артефактов
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Загрузка данных...',
              style: TextStyle(
                color: Colors.black,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}