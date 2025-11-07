// lib/utils/pref_utils.dart (hoặc trong class nào cần dùng)
import 'package:shared_preferences/shared_preferences.dart';

class PrefUtils {
  static Future<String> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('username') ?? 'Người dùng';
  }
  static Future<String> getCode() async{
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('code') ?? 'Mã nhân viên'; 
  }
}