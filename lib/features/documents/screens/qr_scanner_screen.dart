import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../api/models/document.dart';

class QRScannerScreen extends StatefulWidget {
  final bool isParkingScanner;
  final Document? document;

  const QRScannerScreen({super.key, this.isParkingScanner = false, this.document});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  late MobileScannerController _controller;
  bool _isProcessing = false;
  bool _torchEnabled = false;
  bool _cameraInitialized = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      torchEnabled: _torchEnabled,
      formats: [BarcodeFormat.qrCode],
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeCamera();
    });
  }

  Future<void> _initializeCamera() async {
    try {
      setState(() {
        _cameraInitialized = true;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Не удалось запустить камеру. Проверьте разрешения: $e';
      });
      debugPrint('Camera initialization error: $e');
    }
  }

  void _handleBarcode(BarcodeCapture capture) {
    if (_isProcessing) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty || barcodes.first.rawValue == null) {
      debugPrint('No barcodes detected or rawValue is null');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final barcode = barcodes.first;
      final rawValue = barcode.rawValue!;
      debugPrint('Scanned QR code: $rawValue (isParkingScanner: ${widget.isParkingScanner})');

      if (widget.isParkingScanner) {
        Navigator.pop(context, {
          'data': rawValue,
          'document': widget.document,
        });
      } else {
        // Для сканирования документа просто возвращаем строку без декодирования JSON
        if (!rawValue.startsWith('e1cib/data/')) {
          throw Exception('QR-код не соответствует формату e1cib/data/');
        }
        Navigator.pop(context, {'data': rawValue});
      }
    } catch (e) {
      debugPrint('QR processing error: $e');
      debugPrint('Stack trace: ${StackTrace.current}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка обработки QR-кода: $e')),
        );
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _toggleTorch() async {
    try {
      setState(() => _torchEnabled = !_torchEnabled);
      await _controller.toggleTorch();
    } catch (e) {
      debugPrint('Torch toggle error: $e');
    }
  }

  Future<void> _restartCamera() async {
    setState(() {
      _cameraInitialized = false;
      _errorMessage = null;
    });
    await _controller.stop();
    await _initializeCamera();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildErrorWidget(BuildContext context, MobileScannerException error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.camera, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'Ошибка камеры: ${error.toString()}',
            style: const TextStyle(color: Colors.red, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _restartCamera,
            child: const Text('Попробовать снова'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isParkingScanner ? 'Сканер стеллажа' : 'Сканирование QR'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _buildScannerBody(),
    );
  }

  Widget _buildScannerBody() {
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.camera, size: 64, color: Colors.red),
            const SizedBox(height: 20),
            Text(
              _errorMessage!,
              style: const TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _restartCamera,
              child: const Text('Попробовать снова'),
            ),
          ],
        ),
      );
    }

    if (!_cameraInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        MobileScanner(
          controller: _controller,
          onDetect: _handleBarcode,
          errorBuilder: _buildErrorWidget,
        ),
        _buildTorchButton(),
        _buildScannerOverlay(),
        if (_isProcessing) _buildProcessingIndicator(),
      ],
    );
  }

  Widget _buildTorchButton() {
    return Positioned(
      top: 16,
      right: 16,
      child: IconButton(
        icon: Icon(
          _torchEnabled ? Icons.flash_on : Icons.flash_off,
          color: Colors.white,
          size: 32,
        ),
        onPressed: _toggleTorch,
      ),
    );
  }

  Widget _buildScannerOverlay() {
    return Positioned.fill(
      child: Align(
        alignment: Alignment.center,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.7,
          height: MediaQuery.of(context).size.width * 0.7,
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.white.withOpacity(0.5),
              width: 2,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildProcessingIndicator() {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
      ),
    );
  }
}