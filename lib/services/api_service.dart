// lib/services/api_service.dart
import 'package:dio/dio.dart';
import 'dio_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static Future<Map<String, dynamic>?> login(String code) async {
    try {
      final response = await DioClient.instance.post(
        '/api/Auth/token',
        data: {'code': code},
      );

      // API trả về: { "data": { "token": "...", "username": "..." } }
      final data = response.data['data'];
      final String token = data['token'];
      final String username = data['username'];

      // Lưu vào SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token);
      await prefs.setString('username', username);
      await prefs.setString('code', code);

      return {'token': token, 'username': username};
    } on DioException catch (e) {
      print('Login error: ${e.response?.data ?? e.message}');
      return null;
    }
  }
}