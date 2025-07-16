import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:profit_league_documents/shared/auth_storage.dart';
import '../../../api/models/document.dart';
import '../../../api/models/photo.dart';
import '../../../api/api_client.dart';
import 'package:photo_view/photo_view.dart';

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

  @override
  void dispose() {
    PaintingBinding.instance.imageCache.clear();
    _nameController.dispose();
    super.dispose();
  }

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
        Navigator.pop(context, widget.document);
        return true;
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
          cacheExtent: 500,
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
      final directory = await getApplicationDocumentsDirectory();
      for (final image in images) {
        final bytes = await image.readAsBytes();
        final timestamp = DateFormat('yyyy-MM-dd-HH-mm-ss').format(DateTime.now());
        final fileName = '$timestamp-${images.indexOf(image)}.jpg';
        final filePath = '${directory.path}/photos/$fileName';
        final file = File(filePath);
        await file.create(recursive: true);
        await file.writeAsBytes(bytes);

        setState(() {
          widget.document.photos.insert(0, Photo(
            name: '$timestamp-${images.indexOf(image)}',
            filePath: filePath,
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
      final timestamp = DateFormat('yyyy-MM-dd-HH-mm-ss').format(DateTime.now());
      final directory = await getApplicationDocumentsDirectory();
      final fileName = '$timestamp.jpg';
      final filePath = '${directory.path}/photos/$fileName';
      final file = File(filePath);
      await file.create(recursive: true);
      await file.writeAsBytes(bytes);

      setState(() {
        widget.document.photos.insert(0, Photo(
          name: timestamp,
          filePath: filePath,
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
    return FutureBuilder<Size>(
      future: _getImageSize(photo.filePath),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            height: 200,
            color: Colors.grey[200],
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        final aspectRatio = snapshot.data!.width / snapshot.data!.height;
        return AspectRatio(
          aspectRatio: aspectRatio,
          child: Image.file(
            File(photo.filePath),
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.grey[200],
                child: const Center(child: Text('Ошибка отображения изображения')),
              );
            },
          ),
        );
      },
    );
  }

  Future<Size> _getImageSize(String path) async {
    final bytes = await File(path).readAsBytes();
    final image = await decodeImageFromList(bytes);
    return Size(image.width.toDouble(), image.height.toDouble());
  }

  void _showFullScreenPhoto(Photo photo) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
          ),
          body: PhotoView(
            imageProvider: FileImage(File(photo.filePath)),
            backgroundDecoration: BoxDecoration(color: Colors.black),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 3,
            errorBuilder: (context, error, stackTrace) =>
                Center(child: Text('Ошибка отображения изображения')),
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
          floatingActionButton: _buildUploadButtonIfNeeded(photo),
        ),
      ),
    );
  }

  Widget _buildFullScreenPhoto(Photo photo) {
    try {
      return Image.file(
        File(photo.filePath),
        fit: BoxFit.contain,
        cacheHeight: 800,
        cacheWidth: 800,
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
    final bytes = await File(photo.filePath).readAsBytes();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProImageEditor.memory(
          bytes,
          key: UniqueKey(),
          callbacks: ProImageEditorCallbacks(
            onImageEditingComplete: (Uint8List resultBytes) async {
              final directory = await getApplicationDocumentsDirectory();
              final fileName = '${photo.name}_${DateTime.now().millisecondsSinceEpoch}.jpg';
              final filePath = '${directory.path}/photos/$fileName';
              final file = File(filePath);
              await file.create(recursive: true);
              await file.writeAsBytes(resultBytes);

              setState(() {
                widget.document.photos[index] = Photo(
                  name: photo.name,
                  filePath: filePath,
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
        final photo = widget.document.photos.removeAt(index);
        File(photo.filePath).deleteSync();
        widget.document.numberOfPhotos = widget.document.photos.where((p) => p.uploaded).length;
      });
      await _saveDocuments();
    }
  }

  String _getMimeType(String ext) {
    switch (ext.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      default:
        return 'image/jpeg'; // По умолчанию для неизвестных расширений
    }
  }

  Future<void> _sendSinglePhotoToServer(Photo photo) async {
    try {
      setState(() => _isSending = true);
      final bytes = await File(photo.filePath).readAsBytes();
      final base64Image = base64Encode(bytes);
      final mimeType = _getMimeType(photo.ext);
      final dataUrl = 'data:$mimeType;base64,$base64Image';

      print('Sending photo ${photo.name} with data URL: ${dataUrl.substring(0, 100)}...'); // Отладочный вывод

      await _apiClient.sendPhotoToBackend(
        Photo(
          name: photo.name,
          filePath: dataUrl, // Передаём Data URL вместо filePath
          ext: photo.ext,
          uploaded: photo.uploaded,
        ),
        widget.document.navLink,
      );
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
          final bytes = await File(photo.filePath).readAsBytes();
          final base64Image = base64Encode(bytes);
          final mimeType = _getMimeType(photo.ext);
          final dataUrl = 'data:$mimeType;base64,$base64Image';

          print('Sending photo ${photo.name} with data URL: ${dataUrl.substring(0, 100)}...'); // Отладочный вывод

          await _apiClient.sendPhotoToBackend(
            Photo(
              name: photo.name,
              filePath: dataUrl, // Передаём Data URL вместо filePath
              ext: photo.ext,
              uploaded: photo.uploaded,
            ),
            widget.document.navLink,
          );
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

      Navigator.pop(context);

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