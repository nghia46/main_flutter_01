import '../../core/network/api_service.dart';
import '../../core/network/api_response.dart';
import '../../core/constants/api_constants.dart';
import '../../core/storage/token_storage.dart';
import '../../core/storage/userdata_storage.dart';


class AuthRepository {
  final ApiService _apiService = ApiService(baseUrl: ApiConstants.baseUrl);
  final TokenStorage _tokenStorage = TokenStorage();
  final UserDataStorage _userDataStorage = UserDataStorage();


  Future<ApiResponse<Map<String, dynamic>>> login({
    required String code,
  }) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiConstants.login,
      data: {'code': code},
      fromJson: (data) => data as Map<String, dynamic>,
    );

    if (response.success && response.data != null) {
      await _userDataStorage.saveCode(response.data!['data']['code']);
      await _userDataStorage.saveName(response.data!['data']['username']);
      await _tokenStorage.saveToken(response.data!['data']['token']);
    }
    return response;
  }
  Future<ApiResponse<Map<String, dynamic>>> register({
    required String name,
    required String email,
    required String password,
  }) async {
    return await _apiService.post<Map<String, dynamic>>(
      ApiConstants.register,
      data: {'name': name, 'email': email, 'password': password},
      fromJson: (data) => data as Map<String, dynamic>,
    );
  }

  Future<ApiResponse<void>> logout() async {
    final response = await _apiService.post<void>(ApiConstants.logout);
    if (response.success) {
      await _tokenStorage.deleteTokens();
    }
    return response;
  }
}
