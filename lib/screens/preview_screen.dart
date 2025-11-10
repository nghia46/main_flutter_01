import 'dart:io';
import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_learn/services/face_recognition_service.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class PreviewScreen extends StatefulWidget {
  final String imagePath;
  const PreviewScreen({super.key, required this.imagePath});

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen>
    with SingleTickerProviderStateMixin {
  bool _isProcessing = true;
  File? _croppedFace;
  bool _isUploading = false;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimation();
    _detectAndCropFace();
  }

  void _setupAnimation() {
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _fadeController.forward();
  }

  Future<void> _detectAndCropFace() async {
    final faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableContours: true,
        enableLandmarks: true,
        performanceMode: FaceDetectorMode.accurate,
      ),
    );

    try {
      final inputImage = InputImage.fromFilePath(widget.imagePath);
      final faces = await faceDetector.processImage(inputImage);

      if (!mounted) return;

      if (faces.isEmpty) {
        _showFlushbar(
          "Không phát hiện khuôn mặt. Vui lòng chụp lại!",
          Colors.orange,
        );
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) Navigator.pop(context);
        return;
      }

      final face = faces.first;
      final bytes = await File(widget.imagePath).readAsBytes();
      final original = img.decodeImage(bytes);
      if (original == null) throw Exception("Không đọc được ảnh");

      final rect = face.boundingBox;

      // CROP CĂN GIỮA HOÀN HẢO
      final centerX = rect.center.dx;
      final centerY = rect.center.dy;
      const padding = 0.6;

      final newWidth = (rect.width * (1 + padding)).toDouble();
      final newHeight = (rect.height * (1 + padding)).toDouble();

      final left = (centerX - newWidth / 2).clamp(
        0.0,
        original.width - newWidth,
      );
      final top = (centerY - newHeight / 2).clamp(
        0.0,
        original.height - newHeight,
      );

      final cropped = img.copyCrop(
        original,
        x: left.toInt(),
        y: top.toInt(),
        width: newWidth.toInt(),
        height: newHeight.toInt(),
      );

      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/cropped_face_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final file = File(path);
      await file.writeAsBytes(img.encodeJpg(cropped, quality: 94));

      if (mounted) {
        setState(() {
          _croppedFace = file;
          _isProcessing = false;
        });
      }
    } catch (e) {
      debugPrint('Lỗi crop face: $e');
      if (mounted) {
        _showFlushbar("Lỗi xử lý ảnh. Vui lòng thử lại.", Colors.red);
      }
    } finally {
      await faceDetector.close();
    }
  }

  Future<void> _confirmAndUpload() async {
    if (_croppedFace == null || _isUploading) return;
    setState(() => _isUploading = true);
    HapticFeedback.selectionClick();

    try {
      final result = await FaceRecognitionService.recognizeFace(
        _croppedFace!.path,
      );

      // === TRƯỜNG HỢP 404: Không có mặt (backend trả 404) ===
      if (result == null) {
        _showFlushbar("Khuôn mặt chưa rõ. Vui lòng chụp lại!", Colors.orange);
        return;
      }

      // === TRƯỜNG HỢP 200: Có kết quả ===
      final results = result['results'] as List;
      if (results.isEmpty) {
        _showFlushbar(
          "Không phát hiện khuôn mặt trong ảnh gửi đi.",
          Colors.orange,
        );
        return;
      }

      final info = results[0];
      final bool recognized = info['recognized'] as bool? ?? false;
      final String name = info['name'] as String? ?? 'Unknown';
      final double confidence = (info['confidence'] as num?)?.toDouble() ?? 0.0;

      if (!recognized) {
        _showFlushbar(
          "Không nhận diện được ($confidence%)",
          Colors.redAccent,
          icon: Icons.error_outline,
        );
        return;
      }

      // CHẤM CÔNG THÀNH CÔNG
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Chấm công thành công: $name (${confidence.toStringAsFixed(1)}%)',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 3),
        ),
      );

      Navigator.pop(context, true); // Trả về true
    } catch (e) {
      _showFlushbar("Lỗi mạng. Không thể gửi ảnh.", Colors.red);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showFlushbar(String message, Color color, {IconData? icon}) {
    if (!mounted) return;
    Flushbar(
      message: message,
      backgroundColor: color,
      duration: const Duration(seconds: 3),
      flushbarPosition: FlushbarPosition.TOP,
      margin: const EdgeInsets.all(12),
      borderRadius: BorderRadius.circular(8),
      icon: Icon(icon ?? Icons.info, color: Colors.white),
    ).show(context);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final double previewWidth = size.width * 0.75;
    final double previewHeight = previewWidth * 4 / 3;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Xem trước',
          style: theme.textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: _isProcessing
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Đang xử lý khuôn mặt...',
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  const SizedBox(height: kToolbarHeight + 40),
                  // Ảnh xem trước
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(32),
                      child: Container(
                        width: previewWidth,
                        height: previewHeight,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white24, width: 2),
                          borderRadius: BorderRadius.circular(32),
                        ),
                        child: _croppedFace != null
                            ? Image.file(
                                _croppedFace!,
                                fit: BoxFit.cover,
                                width: previewWidth,
                                height: previewHeight,
                              )
                            : Image.file(
                                File(widget.imagePath),
                                fit: BoxFit.cover,
                                width: previewWidth,
                                height: previewHeight,
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Badge phát hiện
                  if (_croppedFace != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade700.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.face_retouching_natural,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Khuôn mặt đã được phát hiện',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Spacer(),
                  // Nút hành động
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Row(
                      children: [
                        // Chụp lại
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Chụp lại'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white54),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Xác nhận
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _isUploading ? null : _confirmAndUpload,
                            icon: _isUploading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.check_circle_rounded),
                            label: Text(
                              _isUploading ? 'Đang gửi...' : 'Xác nhận',
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
      ),
    );
  }
}
