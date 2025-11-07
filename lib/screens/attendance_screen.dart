// lib/screens/attendance_screen.dart
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:another_flushbar/flushbar.dart';
import 'preview_screen.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen>
    with TickerProviderStateMixin {
  CameraController? _controller;
  bool _isCameraInitialized = false;
  bool _isCapturing = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initCamera();
    _setupPulseAnimation();
  }

  void _setupPulseAnimation() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        frontCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _controller!.initialize();

      if (!mounted) return;
      setState(() => _isCameraInitialized = true);
    } catch (e) {
      if (mounted) {
        _showError('Không thể khởi động camera. Vui lòng kiểm tra quyền.');
      }
    }
  }

  Future<void> _capturePhoto() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _isCapturing) {
      return;
    }

    setState(() => _isCapturing = true);
    HapticFeedback.mediumImpact();

    try {
      final xFile = await _controller!.takePicture();
      final croppedPath = await _detectAndCropFace(xFile.path);

      if (!mounted) return;

      if (croppedPath == null) {
        _showError('Không phát hiện khuôn mặt. Hãy căn mặt vào khung!');
        return;
      }

      final result = await Navigator.push<bool>(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => PreviewScreen(imagePath: croppedPath),
          transitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (_, a, __, c) =>
              FadeTransition(opacity: a, child: c),
        ),
      );

      if (result == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Chấm công thành công!'),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 2),
          ),
        );

        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) Navigator.pop(context);
        });
      }
    } catch (e) {
      if (mounted) {
        _showError('Lỗi chụp ảnh. Vui lòng thử lại.');
      }
    } finally {
      if (mounted) {
        setState(() => _isCapturing = false);
      }
    }
  }

  Future<String?> _detectAndCropFace(String imagePath) async {
    final faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableContours: true,
        enableLandmarks: true,
        performanceMode: FaceDetectorMode.accurate,
      ),
    );

    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final faces = await faceDetector.processImage(inputImage);
      if (faces.isEmpty) return null;

      final face = faces.first;
      final bytes = await File(imagePath).readAsBytes();
      final original = img.decodeImage(bytes)!;

      const padding = 0.35;
      final rect = face.boundingBox;
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
          '${dir.path}/face_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File(path).writeAsBytes(img.encodeJpg(cropped, quality: 92));

      return path;
    } catch (e) {
      debugPrint('Face detect error: $e');
      return null;
    } finally {
      await faceDetector.close();
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
    _controller?.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final double cameraWidth = size.width * 0.75; // 75% chiều rộng màn hình
    final double cameraHeight = cameraWidth * 4 / 3; // Tỷ lệ 3:4

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Chấm công khuôn mặt',
          style: theme.textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isCameraInitialized && _controller != null
          ? Column(
              children: [
                const SizedBox(height: kToolbarHeight + 40), // Khoảng cách từ AppBar

                // Hướng dẫn
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lightbulb, color: Colors.amber, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Căn mặt vào khung oval',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Camera 3:4 vuông dọc
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: Container(
                      width: cameraWidth,
                      height: cameraHeight,
                      color: Colors.black,
                      child: Stack(
                        children: [
                          // Camera Preview (crop theo 3:4)
                          SizedBox(
                            width: cameraWidth,
                            height: cameraHeight,
                            child: FittedBox(
                              fit: BoxFit.cover,
                              child: SizedBox(
                                width: _controller!.value.previewSize!.height,
                                height: _controller!.value.previewSize!.width,
                                child: CameraPreview(_controller!),
                              ),
                            ),
                          ),

                          // Oval Guide + Pulse
                          Center(
                            child: AnimatedBuilder(
                              animation: _pulseAnimation,
                              builder: (context, child) {
                                return Transform.scale(
                                  scale: _pulseAnimation.value,
                                  child: Container(
                                    width: cameraWidth * 0.75,
                                    height: cameraHeight * 0.85,
                                    decoration: BoxDecoration(
                                      borderRadius:
                                          BorderRadius.circular(cameraWidth),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.95),
                                        width: 3.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.white.withOpacity(0.25),
                                          blurRadius: 25,
                                          spreadRadius: 8,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const Spacer(),

                // Nút chụp
                Padding(
                  padding: const EdgeInsets.only(bottom: 50),
                  child: GestureDetector(
                    onTap: _isCapturing ? null : _capturePhoto,
                    child: AnimatedScale(
                      scale: _isCapturing ? 0.88 : 1.0,
                      duration: const Duration(milliseconds: 180),
                      child: Container(
                        width: 86,
                        height: 86,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isCapturing ? Colors.grey : Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.35),
                              blurRadius: 15,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: _isCapturing
                            ? const SizedBox(
                                width: 34,
                                height: 34,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 3,
                                ),
                              )
                            : const Icon(
                                Icons.camera_alt_rounded,
                                color: Colors.black87,
                                size: 40,
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            )
          : const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
              ),
            ),
    );
  }
}