import 'dart:convert';
import 'dart:io';
import 'package:universal_platform/universal_platform.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:profit_league_documents/api/api_client.dart';
import 'package:profit_league_documents/features/documents/screens/document_photos_screen.dart';
import 'package:profit_league_documents/features/documents/screens/qr_scanner_screen.dart';
import 'package:profit_league_documents/shared/auth_storage.dart';
import '../../../api/models/document.dart';
import '../../../api/models/photo.dart';
import 'package:profit_league_documents/shared/widgets/loading_overlay.dart';

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
    _clearPhotoCache();
    _loadDocuments();
  }

  Future<void> _clearPhotoCache() async {
    if (UniversalPlatform.isAndroid || UniversalPlatform.isIOS) {
      try {
        final directory = await getApplicationDocumentsDirectory();
        final photoDir = Directory('${directory.path}/photos');
        if (await photoDir.exists()) {
          await photoDir.delete(recursive: true);
          debugPrint('Photo cache cleared: ${photoDir.path}');
        } else {
          debugPrint('Photo cache directory does not exist: ${photoDir.path}');
        }
        await photoDir.create(recursive: true);
      } catch (e) {
        debugPrint('Error clearing photo cache: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка при очистке кэша фотографий: $e')),
        );
      }
    } else {
      // Web или другие платформы
    }
  }

  Future<void> _loadDocuments() async {
    try {
      final storedData = await _storage.getDocuments();
      if (storedData != null) {
        setState(() {
          documents = (jsonDecode(storedData) as List<dynamic>)
              .map((e) => Document.fromJson(e))
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading documents: $e');
      await _storage.clearDocuments();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Данные документов сброшены из-за несовместимости')),
      );
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

      final response = await widget.apiClient.get('/docPhoto?navLink=${doc.navLink}');
      if (!mounted) return;
      final List<dynamic> data = json.decode(response.body);
      final directory = await getApplicationDocumentsDirectory();

      doc.photos = await Future.wait(data.map((item) async {
        String base64 = item['base64'];
        if (base64.startsWith('data:image/')) {
          base64 = base64.split(',').last;
        }
        final fileName = '${item['name']}_${DateTime.now().millisecondsSinceEpoch}.${item['ext']}';
        final filePath = '${directory.path}/photos/$fileName';
        final file = File(filePath);
        await file.create(recursive: true);
        await file.writeAsBytes(base64Decode(base64));
        return Photo(
          name: item['name'],
          filePath: filePath,
          ext: item['ext'],
          uploaded: item['uploaded'],
        );
      }).toList());

      setState(() {
        doc.numberOfPhotos = doc.photos.where((p) => p.uploaded).length;
      });
      await _saveDocuments();

      Navigator.of(context).pop();

      if (doc.photos.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Нет фотографий для этого документа')),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: ${e.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
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
        Navigator.of(context).pop();
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
      await _clearPhotoCache();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Список документов и кэш фотографий очищены')),
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
      return Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 100), // насколько вверх поднять
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.qr_code, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              const Text(
                'Отсканируйте QR-код документа',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
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
            elevation: 0,
            child: ListTile(
              leading: IconButton(
                icon: const Icon(Icons.shelves, color: Colors.blue, size: 40),
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
                icon: const Icon(Icons.photo_library, color: Colors.green, size: 40),
                onPressed: () => _navigateToPhotoScreen(context, doc),
              ),
            ),
          ),
        );
      },
    );
  }
}
