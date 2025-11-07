// lib/screens/preview_screen.dart
import 'dart:io';
import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import '../services/api_service.dart'; // Giả sử có ApiService

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
        _showError('Không phát hiện khuôn mặt. Vui lòng chụp lại!');
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) Navigator.pop(context);
        return;
      }

      final face = faces.first;
      final bytes = await File(widget.imagePath).readAsBytes();
      final original = img.decodeImage(bytes);
      if (original == null) throw Exception('Không đọc được ảnh');

      final rect = face.boundingBox;
      const padding = 0.45;
      final x = (rect.left * (1 - padding)).clamp(0, original.width - 1).toInt();
      final y = (rect.top * (1 - padding)).clamp(0, original.height - 1).toInt();
      final w = (rect.width * (1 + 2 * padding))
          .clamp(1, original.width - x)
          .toInt();
      final h = (rect.height * (1 + 2 * padding))
          .clamp(1, original.height - y)
          .toInt();

      final cropped = img.copyCrop(original, x: x, y: y, width: w, height: h);

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
        _showError('Lỗi xử lý ảnh. Vui lòng thử lại.');
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
      final success = true;//await ApiService.uploadFace(_croppedFace!.path);

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: 8),
                Text('Chấm công thành công!'),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.pop(context, true); // Trả về true
      } else {
        _showError('Chấm công thất bại. Vui lòng thử lại.');
      }
    } catch (e) {
      _showError('Lỗi mạng. Không thể gửi ảnh.');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    Flushbar(
      message: message,
      backgroundColor: Colors.red.shade600,
      duration: const Duration(seconds: 3),
      flushbarPosition: FlushbarPosition.TOP,
      margin: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(16),
      icon: const Icon(Icons.error_rounded, color: Colors.white),
  
      
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
    final double previewHeight = previewWidth * 4 / 3; // Tỷ lệ 3:4

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
                    CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
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

                  // Ảnh 3:4
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

                  // Badge phát hiện khuôn mặt
                  if (_croppedFace != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.green.shade700.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.face_retouching_natural,
                              color: Colors.white, size: 18),
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
                            label: Text(_isUploading ? 'Đang gửi...' : 'Xác nhận'),
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