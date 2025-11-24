import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class UserDataStorage {
  static const _storage = FlutterSecureStorage();
  static const _userCode = 'user_code';
  static const _userName = 'user_name';

  Future<String?> getCode() async {
    return await _storage.read(key: _userCode);
  }

  Future<void> saveCode(String token) async {
    await _storage.write(key: _userCode, value: token);
  }

  Future<void> deleteCode() async {
    await _storage.delete(key: _userCode);
  }
  // For username
  Future<String?> getName() async {
    return await _storage.read(key: _userName);
  }

  Future<void> saveName(String token) async {
    await _storage.write(key: _userName, value: token);
  }

  Future<void> deleteName() async {
    await _storage.delete(key: _userName);
  }
}
