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

      // API trả về token trong trường "data"
      final String token = response.data['data'];

      // Lưu token
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token);
      // return object including token and name claim from token
      return {
        'token': token,
        'name': response.data['name'],
      };
    } on DioException catch (e) {
      print('Login error: ${e.response?.data ?? e.message}');
      return null;
    }
  }}