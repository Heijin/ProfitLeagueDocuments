import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:profit_league_documents/shared/auth_storage.dart';
import '../../../api/models/document.dart';
import '../../../api/models/photo.dart';
import '../../../api/api_client.dart';

class DocumentPhotosScreen extends StatefulWidget {
  final Document document;

  const DocumentPhotosScreen({Key? key, required this.document}) : super(key: key);

  @override
  _DocumentPhotosScreenState createState() => _DocumentPhotosScreenState();
}

class _DocumentPhotosScreenState extends State<DocumentPhotosScreen> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _nameController = TextEditingController();
  final AuthStorage _storage = AuthStorage();
  final ApiClient _apiClient = ApiClient();
  bool _isSending = false;
  bool _isLoading = false;

  Future<void> _saveDocuments() async {
    final documents = await _storage.getDocuments();
    if (documents != null) {
      final List<Document> docs = (jsonDecode(documents) as List<dynamic>)
          .map((e) => Document.fromJson(e))
          .toList();
      final index = docs.indexWhere((d) => d.navLink == widget.document.navLink);
      if (index != -1) {
        docs[index] = widget.document;
        await _storage.saveDocuments(jsonEncode(docs.map((e) => e.toJson()).toList()));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Перехватываем любой возврат (стрелка, жест, кнопка "Назад")
        Navigator.pop(context, widget.document);
        return true; // Разрешаем возврат
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Фотографии документа'),
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          actions: [
            if (_hasUnuploadedPhotos())
              TextButton(
                child: _isSending
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text('Отправить фото', style: TextStyle(color: Colors.white)),
                onPressed: _isSending ? null : _sendPhotosToServer,
              ),
          ],
        ),
        body: _isLoading
            ? Center(child: CircularProgressIndicator())
            : widget.document.photos.isEmpty
            ? Center(child: Text('Нет фотографий'))
            : ListView.builder(
          itemCount: widget.document.photos.length,
          itemBuilder: (context, index) {
            final photo = widget.document.photos[index];
            return Card(
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: InkWell(
                onTap: () => _showFullScreenPhoto(photo),
                child: Column(
                  children: [
                    ListTile(
                      title: Text(photo.name),
                      subtitle: Text(
                          '${photo.ext} • ${photo.uploaded ? 'Загружено' : 'Не загружено'}'),
                    ),
                    Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: _buildPhotoPreview(photo),
                        ),
                        if (!photo.uploaded) _buildPhotoActions(photo, index),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: Colors.green,
          child: Icon(Icons.add_a_photo, color: Colors.white),
          onPressed: _showImageSourceDialog,
        ),
      ),
    );
  }

  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Добавить фото'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.camera_alt, color: Colors.blue),
              title: Text('Сделать фото'),
              onTap: () {
                Navigator.pop(context);
                _takePhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library, color: Colors.green),
              title: Text('Выбрать из галереи (множественный выбор)'),
              onTap: () {
                Navigator.pop(context);
                _pickMultipleImages();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickMultipleImages() async {
    final List<XFile>? images = await _picker.pickMultiImage(
      imageQuality: 100,
    );

    if (images != null && images.isNotEmpty) {
      for (final image in images) {
        final bytes = await image.readAsBytes();
        final base64Image = base64Encode(bytes);
        final timestamp = DateFormat('yyyy-MM-dd-HH-mm-ss').format(DateTime.now());

        setState(() {
          widget.document.photos.insert(0, Photo(
            name: '$timestamp-${images.indexOf(image)}',
            base64: base64Image,
            ext: 'jpg',
            uploaded: false,
          ));
        });
      }
      await _saveDocuments();
    }
  }

  Future<void> _takePhoto(ImageSource source) async {
    final XFile? image = await _picker.pickImage(
      source: source,
      imageQuality: 100,
    );

    if (image != null) {
      final bytes = await image.readAsBytes();
      final base64Image = base64Encode(bytes);
      final timestamp = DateFormat('yyyy-MM-dd-HH-mm-ss').format(DateTime.now());

      setState(() {
        widget.document.photos.insert(0, Photo(
          name: timestamp,
          base64: base64Image,
          ext: 'jpg',
          uploaded: false,
        ));
      });
      await _saveDocuments();
    }
  }

  bool _hasUnuploadedPhotos() {
    return widget.document.photos.any((photo) => !photo.uploaded);
  }

  Widget _buildPhotoPreview(Photo photo) {
    try {
      String base64String = photo.base64;
      if (base64String.contains(',')) {
        base64String = base64String.split(',').last;
      }

      final bytes = base64.decode(base64String);

      return Image.memory(
        bytes,
        fit: BoxFit.contain,
        height: 200,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            height: 200,
            color: Colors.grey[200],
            child: Center(
              child: Text('Ошибка отображения изображения'),
            ),
          );
        },
      );
    } catch (e) {
      return Container(
        height: 200,
        color: Colors.grey[200],
        child: Center(
          child: Text('Некорректные данные изображения'),
        ),
      );
    }
  }

  void _showFullScreenPhoto(Photo photo) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
          ),
          body: Center(
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 3.0,
              child: _buildFullScreenPhoto(photo),
            ),
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
          floatingActionButton: _buildUploadButtonIfNeeded(photo),
        ),
      ),
    );
  }

  Widget _buildFullScreenPhoto(Photo photo) {
    try {
      String base64String = photo.base64;
      if (base64String.contains(',')) {
        base64String = base64String.split(',').last;
      }

      final bytes = base64.decode(base64String);

      return Image.memory(
        bytes,
        fit: BoxFit.contain,
      );
    } catch (e) {
      return Center(
        child: Text('Ошибка отображения изображения'),
      );
    }
  }

  Widget _buildUploadButtonIfNeeded(Photo photo) {
    if (photo.uploaded) return SizedBox.shrink();

    return FloatingActionButton.extended(
      backgroundColor: Colors.green,
      icon: Icon(Icons.cloud_upload),
      label: Text('Отправить'),
      onPressed: () => _sendSinglePhotoToServer(photo),
    );
  }

  Widget _buildPhotoActions(Photo photo, int index) {
    return Positioned(
      top: 8,
      right: 8,
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.edit, color: Colors.blue),
            onPressed: () => _editPhotoName(index),
          ),
          IconButton(
            icon: Icon(Icons.brush, color: Colors.green),
            onPressed: () => _editPhotoWithEditor(index),
          ),
          IconButton(
            icon: Icon(Icons.delete, color: Colors.red),
            onPressed: () => _confirmDeletePhoto(index),
          ),
        ],
      ),
    );
  }

  Future<void> _editPhotoName(int index) async {
    final photo = widget.document.photos[index];
    _nameController.text = photo.name;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Редактировать название'),
        content: TextField(
          controller: _nameController,
          decoration: InputDecoration(hintText: 'Введите новое название'),
        ),
        actions: [
          TextButton(
            child: Text('Отмена'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: Text('Сохранить'),
            onPressed: () {
              setState(() {
                widget.document.photos[index].name = _nameController.text;
              });
              _saveDocuments();
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _editPhotoWithEditor(int index) async {
    final photo = widget.document.photos[index];
    String base64String = photo.base64;
    if (base64String.contains(',')) {
      base64String = base64String.split(',').last;
    }
    final bytes = base64.decode(base64String);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProImageEditor.memory(
          bytes,
          key: UniqueKey(),
          callbacks: ProImageEditorCallbacks(
            onImageEditingComplete: (Uint8List resultBytes) async {
              setState(() {
                widget.document.photos[index] = Photo(
                  name: photo.name,
                  base64: base64Encode(resultBytes),
                  ext: 'jpg',
                  uploaded: false,
                );
              });
              await _saveDocuments();
              Navigator.pop(context);
            },
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeletePhoto(int index) async {
    final confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Удалить фотографию?'),
        content: Text('Вы уверены, что хотите удалить эту фотографию?'),
        actions: [
          TextButton(
            child: Text('Отмена'),
            onPressed: () => Navigator.pop(context, false),
          ),
          TextButton(
            child: Text('Удалить', style: TextStyle(color: Colors.red)),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        widget.document.photos.removeAt(index);
        widget.document.numberOfPhotos = widget.document.photos.where((p) => p.uploaded).length;
      });
      await _saveDocuments();
    }
  }

  Future<void> _sendSinglePhotoToServer(Photo photo) async {
    try {
      setState(() => _isSending = true);
      await _apiClient.sendPhotoToBackend(photo, widget.document.navLink);
      setState(() {
        photo.uploaded = true;
        widget.document.numberOfPhotos = widget.document.photos.where((p) => p.uploaded).length;
      });
      await _saveDocuments();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Фото успешно отправлено')),
      );
    } on ApiException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка при отправке: ${e.message}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка при отправке: ${e.toString()}')),
      );
    } finally {
      setState(() => _isSending = false);
    }
  }

  Future<void> _sendPhotosToServer() async {
    if (_isSending) return;

    final unuploadedPhotos = widget.document.photos.where((p) => !p.uploaded).toList();
    if (unuploadedPhotos.isEmpty) return;

    setState(() => _isSending = true);

    int successCount = 0;
    int failCount = 0;
    String lastError = '';

    bool shouldContinue = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Text('Отправка фотографий'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Отправлено: $successCount из ${unuploadedPhotos.length}'),
              if (failCount > 0) Text('Ошибок: $failCount', style: TextStyle(color: Colors.red)),
            ],
          ),
          actions: [
            TextButton(
              child: Text('Отмена'),
              onPressed: () {
                shouldContinue = false;
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );

    try {
      for (final photo in unuploadedPhotos) {
        if (!shouldContinue) break;

        try {
          await _apiClient.sendPhotoToBackend(photo, widget.document.navLink);
          setState(() {
            photo.uploaded = true;
            successCount++;
            widget.document.numberOfPhotos = widget.document.photos.where((p) => p.uploaded).length;
          });
          await _saveDocuments();
        } on ApiException catch (e) {
          failCount++;
          lastError = e.message;
        } catch (e) {
          failCount++;
          lastError = e.toString();
        }
      }

      Navigator.pop(context); // Закрываем диалог прогресса

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            failCount == 0
                ? 'Все фото успешно отправлены ($successCount)'
                : 'Отправлено $successCount, ошибок: $failCount ($lastError)',
          ),
          duration: Duration(seconds: 5),
        ),
      );
    } finally {
      setState(() => _isSending = false);
    }
  }
}