// services/face_recognition_service.dart
import 'package:dio/dio.dart';
import 'package:flutter_application_learn/ultils/pref_utils.dart';

class FaceRecognitionService {
  static Future<Map<String, dynamic>?> recognizeFace({
    required String imagePath,
    required double longitude,
    required double latitude,
  }) async {
    try {
      // LẤY CODE TỪ PREFS
      final code = await PrefUtils.getCode();

      if (code.isEmpty) {
        print("Lỗi: Chưa lưu mã nhân viên!");
        return null;
      }

      final dio = Dio();
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(imagePath, filename: 'face.jpg'),
        'code': code,
        'longitude': longitude.toStringAsFixed(8),
        'latitude': latitude.toStringAsFixed(8),
      });

      final response = await dio.post(
        'https://8877e915d6fa.ngrok-free.app/recognize',
        data: formData,
        options: Options(
          headers: {'Content-Type': 'multipart/form-data'},
          receiveTimeout: const Duration(seconds: 25),
          sendTimeout: const Duration(seconds: 15),
        ),
      );

      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      }
      return null;
    } on DioException catch (e) {
      print("API Error: ${e.response?.data ?? e.message}");
      return null;
    } catch (e) {
      print("Unexpected error: $e");
      return null;
    }
  }
}