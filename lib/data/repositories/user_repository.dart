// ===================================
// 📁 lib/data/repositories/user_repository.dart
// ===================================
import '../../core/network/api_service.dart';
import '../../core/network/api_response.dart';
import '../../core/constants/api_constants.dart';
import '../models/user_model.dart';

class UserRepository {
  final ApiService _apiService = ApiService(
    baseUrl: ApiConstants.baseUrl,
  );

  Future<ApiResponse<List<User>>> getUsers({
    int? page,
    int? limit,
  }) async {
    return await _apiService.get<List<User>>(
      ApiConstants.users,
      queryParameters: {
        if (page != null) 'page': page,
        if (limit != null) 'limit': limit,
      },
      fromJson: (data) {
        return (data as List).map((json) => User.fromJson(json)).toList();
      },
    );
  }

  Future<ApiResponse<User>> getUserById(int id) async {
    return await _apiService.get<User>(
      '${ApiConstants.users}/$id',
      fromJson: (data) => User.fromJson(data),
    );
  }

  Future<ApiResponse<User>> createUser(Map<String, dynamic> userData) async {
    return await _apiService.post<User>(
      ApiConstants.users,
      data: userData,
      fromJson: (data) => User.fromJson(data),
    );
  }

  Future<ApiResponse<User>> updateUser(
    int id,
    Map<String, dynamic> userData,
  ) async {
    return await _apiService.put<User>(
      '${ApiConstants.users}/$id',
      data: userData,
      fromJson: (data) => User.fromJson(data),
    );
  }

  Future<ApiResponse<void>> deleteUser(int id) async {
    return await _apiService.delete<void>('${ApiConstants.users}/$id');
  }

  Future<ApiResponse<User>> uploadAvatar(int userId, String imagePath) async {
    return await _apiService.uploadFile<User>(
      '${ApiConstants.users}/$userId/avatar',
      imagePath,
      fieldName: 'avatar',
      fromJson: (data) => User.fromJson(data),
    );
  }
}