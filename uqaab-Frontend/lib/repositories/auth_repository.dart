import '../core/constants/api_constants.dart';
import '../core/services/api_service.dart';
import '../models/user_model.dart';

class AuthRepository {
  final ApiService apiService;

  AuthRepository({required this.apiService});

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await apiService.post(
      ApiConstants.login,
      data: {'email': email, 'password': password},
    );
    return response;
  }

  Future<Map<String, dynamic>> signup({
    required String fullName,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    final response = await apiService.post(
      ApiConstants.signup,
      data: {
        'full_name': fullName,
        'email': email,
        'password': password,
        'confirm_password': confirmPassword,
      },
    );
    return response;
  }

  Future<UserModel> getMe() async {
    final response = await apiService.get(ApiConstants.me);
    return UserModel.fromJson(response['user']);
  }
}