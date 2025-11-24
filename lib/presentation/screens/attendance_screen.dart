import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:another_flushbar/flushbar.dart';
import 'preview_screen.dart';

/// Màn hình chấm công bằng nhận diện khuôn mặt
class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen>
    with TickerProviderStateMixin {
  CameraController? _controller; // Controller cho camera
  bool _isCameraInitialized = false; // Kiểm tra camera đã sẵn sàng chưa
  bool _isCapturing = false; // Kiểm tra đang chụp ảnh hay không

  late AnimationController _pulseController; // Animation cho hiệu ứng pulse
  late Animation<double> _pulseAnimation; // Giá trị scale của pulse

  @override
  void initState() {
    super.initState();
    _initCamera();       // Khởi tạo camera
    _setupPulseAnimation(); // Khởi tạo hiệu ứng pulse cho khung khuôn mặt
  }

  /// Thiết lập animation pulse
  void _setupPulseAnimation() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true); // Lặp ngược lại để nhấp nháy
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  /// Khởi tạo camera
  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      // Lấy camera trước (front) nếu có, nếu không lấy camera đầu tiên
      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      _controller = CameraController(
        frontCamera,
        ResolutionPreset.medium,
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

  /// Chụp ảnh, phát hiện và crop khuôn mặt
  Future<void> _capturePhoto() async {
    if (_controller == null || !_controller!.value.isInitialized || _isCapturing) {
      return; // Nếu chưa sẵn sàng hoặc đang chụp thì return
    }
    setState(() => _isCapturing = true);
    HapticFeedback.mediumImpact(); // Rung phản hồi khi nhấn

    try {
      // Chụp ảnh từ camera
      final xFile = await _controller!.takePicture();

      // Phát hiện và crop khuôn mặt
      final croppedPath = await _detectAndCropFace(xFile.path);
      if (!mounted) return;

      if (croppedPath == null) {
        _showError('Không phát hiện khuôn mặt. Hãy đưa mặt vào giữa khung!');
        return;
      }

      // Mở màn hình preview để xác nhận
      final result = await Navigator.push<bool>(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => PreviewScreen(imagePath: croppedPath),
          transitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
        ),
      );

      if (result == true && mounted) {
        // Hiển thị thông báo thành công
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2),
          ),
        );

        // Quay lại màn hình trước sau 1 giây
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) Navigator.pop(context);
        });
      }
    } catch (e) {
      if (mounted) {
        _showError('Lỗi chụp ảnh. Vui lòng thử lại.');
      }
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  /// Phát hiện và crop khuôn mặt từ ảnh
  Future<String?> _detectAndCropFace(String imagePath) async {
    final faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableContours: true, // Lấy đường viền khuôn mặt
        enableLandmarks: true, // Lấy điểm landmark
        performanceMode: FaceDetectorMode.fast,
      ),
    );

    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final faces = await faceDetector.processImage(inputImage);
      if (faces.isEmpty) return null;

      final face = faces.first;
      final bytes = await File(imagePath).readAsBytes();
      final original = img.decodeImage(bytes)!;

      // Padding để bù cho khung nhỏ hơn
      const padding = 0.55;
      final rect = face.boundingBox;
      final x = (rect.left * (1 - padding)).clamp(0, original.width - 1).toInt();
      final y = (rect.top * (1 - padding)).clamp(0, original.height - 1).toInt();
      final w = (rect.width * (1 + 2 * padding)).clamp(1, original.width - x).toInt();
      final h = (rect.height * (1 + 2 * padding)).clamp(1, original.height - y).toInt();

      final cropped = img.copyCrop(original, x: x, y: y, width: w, height: h);

      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/face_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File(path).writeAsBytes(img.encodeJpg(cropped, quality: 94));

      return path;
    } catch (e) {
      debugPrint('Face detect error: $e');
      return null;
    } finally {
      await faceDetector.close();
    }
  }

  /// Hiển thị thông báo lỗi
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
    final cameraWidth = size.width * 0.75;
    final cameraHeight = cameraWidth * 4 / 3;

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
                const SizedBox(height: kToolbarHeight + 40),
                // Hướng dẫn sử dụng
                _buildInstruction(theme),
                const SizedBox(height: 32),
                // Camera + khung oval hướng dẫn
                _buildCameraPreview(cameraWidth, cameraHeight),
                const Spacer(),
                // Nút chụp ảnh
                _buildCaptureButton(),
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

  /// Hướng dẫn đưa mặt vào khung
  Widget _buildInstruction(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lightbulb, color: Colors.amber, size: 18),
          const SizedBox(width: 8),
          Text(
            'Đưa mặt vào giữa khung nhỏ',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Camera preview + khung oval
  Widget _buildCameraPreview(double cameraWidth, double cameraHeight) {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Container(
          width: cameraWidth,
          height: cameraHeight,
          color: Colors.black,
          child: Stack(
            children: [
              // Camera Preview
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
              // Khung oval + pulse
              Center(
                child: AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Container(
                        width: cameraWidth * 0.55,
                        height: cameraHeight * 0.65,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(cameraWidth),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.95),
                            width: 3.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.3),
                              blurRadius: 20,
                              spreadRadius: 6,
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
    );
  }

  /// Nút chụp ảnh
  Widget _buildCaptureButton() {
    return Padding(
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
                  color: Colors.black.withValues(alpha: 0.35),
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
                : const Icon(Icons.camera_alt_rounded, color: Colors.black87, size: 40),
          ),
        ),
      ),
    );
  }
}
