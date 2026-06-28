import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart'
    show FlutterTesseractOcr;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:permission_handler/permission_handler.dart';

import 'card_parser.dart';
import 'iraqData.dart';
import 'lockAuth.dart';
import 'result_screen.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({required this.cardType, super.key});

  final int cardType;

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  CameraController? _controller;
  bool _isReady = false;
  bool _isProcessing = false;
  String? _error;

  // Reused across every scan instead of creating a new recognizer each time
  // (cheaper, and avoids repeatedly loading the OCR model).
  final TextRecognizer _textRecognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  // Drives the background auto-capture loop.
  Timer? _autoCaptureTimer;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  Future<void> _setup() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      setState(() => _error = 'Camera permission is required to scan a card.');
      return;
    }

    try {
      final cameras = await availableCameras();
      final backCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();

      setState(() {
        _controller = controller;
        _isReady = true;
      });
      if (widget.cardType != 3) _autoCapture();
    } catch (e) {
      setState(() => _error = 'Could not start the camera: $e');
    }
  }

  Future<void> _flashOn(FlashMode mode) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    try {
      await controller.setFlashMode(mode);
    } catch (e) {
      _showSnack('Could not turn on flash: $e');
    }
  }

  Future<void> _captureAndScan() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        _isProcessing) {
      return;
    }

    _autoCaptureTimer
        ?.cancel(); // don't let auto-capture fire mid-manual-capture
    setState(() => _isProcessing = true);

    try {
      final XFile picture = await controller.takePicture();
      final RecognizedText result = await _textRecognizer
          .processImage(InputImage.fromFilePath(picture.path));

      final rawNumber = CardParser.extractCardNumber(result.text);
      final expiry = CardParser.extractExpiryDate(result.text);
      final name = CardParser.extractCardHolderName(result.text);

      if (!mounted) return;

      if (rawNumber == null) {
        setState(() => _isProcessing = false);
        _autoCapture(); // resume watching in the background
        _showSnack('No card number detected. Align the card and try again.');
        return;
      }

      await _goToResult(
        cardNumber: rawNumber,
        expiry: expiry,
        name: name,
        imagePath: picture.path,
      );
    } catch (e) {
      _showSnack('Something went wrong: $e');
      if (mounted) {
        setState(() => _isProcessing = false);
        _autoCapture();
      }
    }
  }

  Future<void> _captureAndScanNID() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        _isProcessing) {
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final XFile picture = await controller.takePicture();

      final String result = await extractArabicText(picture.path);

      final Map<String, String?> data = IraqiIdExtractor.extract(result);
      print('$data----');
      debugPrint('رقم الهوية: ${data['idNumber']}');
      debugPrint('الاسم: ${data['name']}');
      debugPrint('تاريخ الميلاد: ${data['dob']}');
      debugPrint('المحافظة: ${data['governorate']}');
      debugPrint('النص المنظف: ${data['cleaned']}');
      print('-----');
    } catch (e) {
      debugPrint('-----' + e.toString() + '----');
    }
  }

  Future<String> extractArabicText(String imagePath) async {
    // ١. قراءة الصورة
    final File imageFile = File(imagePath);
    final Uint8List bytes = await imageFile.readAsBytes();

    img.Image? image = img.decodeImage(bytes);
    if (image == null) return '';

    // ٢. تكبير الصورة (مهم جداً لـ Tesseract)
    image = img.copyResize(
      image,
      width: image.width * 2,
      height: image.height * 2,
      interpolation: img.Interpolation.cubic,
    );

    // ٣. تحويل لـ Grayscale
    image = img.grayscale(image);

    // ٤. زيادة التباين
    image = img.adjustColor(
      image,
      contrast: 1.5,
      brightness: 1.1,
    );

    // ٥. Sharpen لتوضيح الحروف
    image = img.convolution(image, filter: [
      0,
      -1,
      0,
      -1,
      5,
      -1,
      0,
      -1,
      0,
    ]);

    // ٦. حفظ الصورة المعالجة مؤقتاً
    final String processedPath = imagePath.replaceAll('.jpg', '_processed.jpg');
    await File(processedPath).writeAsBytes(img.encodeJpg(image, quality: 100));

    // ٧. OCR على الصورة المعالجة
    final String result = await FlutterTesseractOcr.extractText(
      processedPath,
      language: 'ara',
      args: {
        "preserve_interword_spaces": "1",
        "psm": "6", // نص منظم متعدد الأسطر
        "oem": "1", // LSTM engine (أدق)
      },
    );

    // حذف الملف المؤقت
    await File(processedPath).delete();

    return result.trim();
  }

  /// Starts watching for a card in the background: every 1.2 seconds it
  /// silently takes a photo and runs OCR on it. The instant a valid card
  /// number is found, it stops and opens the result screen automatically —
  /// the person doesn't need to tap anything.
  void _autoCapture() {
    _autoCaptureTimer?.cancel();
    _autoCaptureTimer = Timer.periodic(
      const Duration(milliseconds: 1000),
      (_) => _autoCaptureTick(),
    );
  }

  Future<void> _autoCaptureTick() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (_isProcessing) {
      return; // previous tick (or a manual capture) is still busy
    }

    setState(() => _isProcessing = true);

    try {
      final XFile picture = await controller.takePicture();

      final RecognizedText result = await _textRecognizer
          .processImage(InputImage.fromFilePath(picture.path));
      final account = CardParser.extractAccountNumber(result.text);
      final qiCard = CardParser.extractCardNumber(result.text);

      if (!mounted) return;
      if (widget.cardType == 0 ? qiCard == null : account == null) {
        // Nothing readable in this frame — discard it and keep watching.
        try {
          await File(picture.path).delete();
        } catch (_) {
          // Ignore — not worth surfacing a cleanup failure to the user.
        }
        if (mounted) setState(() => _isProcessing = false);
        return;
      }

      _autoCaptureTimer?.cancel(); // found it — stop background capturing
      final expiry = CardParser.extractExpiryDate(result.text);
      final name = CardParser.extractCardHolderName(result.text);

      await controller.setFlashMode(FlashMode.off);

      await _goToResult(
        cardNumber: widget.cardType == 0 ? qiCard! : account!,
        expiry: expiry,
        name: name,
        imagePath: picture.path,
      );
    } catch (e) {
      // Swallow per-frame errors (e.g. camera briefly busy) so background
      // scanning keeps trying instead of crashing the screen.
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  /// Shared navigation step used by both manual and automatic capture.
  /// Waits for the result screen to close, then resets state and resumes
  /// auto-capture so scanning is ready again if the person comes back.
  Future<void> _goToResult({
    required String cardNumber,
    required String? expiry,
    required String? name,
    required String imagePath,
  }) async {
    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => LockScreen(
                  child: ResultScreen(
                cardNumber: cardNumber.toString(),
                expiryDate: expiry,
                cardHolderName: name,
                imagePath: imagePath,
                cardType: widget.cardType,
              ))),
    );

    // await Navigator.push(
    //   context,
    //   MaterialPageRoute(
    //     builder: (_) => ResultScreen(
    //       cardNumber: cardNumber.toString(),
    //       expiryDate: expiry,
    //       cardHolderName: name,
    //       imagePath: imagePath,
    //       cardType: widget.cardType,
    //     ),
    //   ),
    // );

    if (mounted) {
      setState(() => _isProcessing = false);
      _autoCapture();
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _autoCaptureTimer?.cancel();
    _textRecognizer.close();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan your card'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _flashOn(FlashMode.torch),
          ),
          IconButton(
            icon: const Icon(Icons.flash_off),
            onPressed: () => _flashOn(FlashMode.off),
          ),
        ],
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : !_isReady
              ? const Center(child: CircularProgressIndicator())
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    CameraPreview(_controller!),
                    _buildOverlay(),
                    Positioned(
                      bottom: 32,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: _isProcessing
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : FloatingActionButton.large(
                                onPressed: _captureAndScanNID,
                                backgroundColor: Colors.white,
                                child: const Icon(Icons.camera_alt,
                                    color: Colors.black),
                              ),
                      ),
                    ),
                    const Positioned(
                      top: 16,
                      left: 0,
                      right: 0,
                      child: Text(
                        'Hold steady — it captures automatically once the\n'
                        'card number is detected (or tap the button anytime)',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildOverlay() {
    return Center(
      child: AspectRatio(
        aspectRatio: 1.586, // standard credit-card width:height ratio
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white, width: 2),
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
