// import 'package:flutter/material.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/providers/base_provider.dart';
import '../../../core/services/secure_storage_service.dart';
import '../../../models/user_model.dart';
import '../../../repositories/auth_repository.dart';

class AuthProvider extends BaseProvider {
  final AuthRepository authRepository;
  final SecureStorageService secureStorage;

  UserModel? _user;
  UserModel? get user => _user;

  AuthProvider({
    required this.authRepository,
    required this.secureStorage,
  });

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    try {
      setLoading();
      final response = await authRepository.login(
        email: email,
        password: password,
      );

      final token = response['token'] as String;
      _user = UserModel.fromJson(response['user']);

      await secureStorage.saveToken(token);
      await secureStorage.saveUserInfo(
        userId: _user!.id.toString(),
        name: _user!.fullName,
        email: _user!.email,
      );

      setSuccess();
      return true;
    } on ApiException catch (e) {
      setError(e.message);
      return false;
    } catch (e) {
      setError('Something went wrong');
      return false;
    }
  }

  Future<bool> signup({
    required String fullName,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    try {
      setLoading();
      final response = await authRepository.signup(
        fullName: fullName,
        email: email,
        password: password,
        confirmPassword: confirmPassword,
      );

      final token = response['token'] as String;
      _user = UserModel.fromJson(response['user']);

      await secureStorage.saveToken(token);
      await secureStorage.saveUserInfo(
        userId: _user!.id.toString(),
        name: _user!.fullName,
        email: _user!.email,
      );

      setSuccess();
      return true;
    } on ApiException catch (e) {
      setError(e.message);
      return false;
    } catch (e) {
      setError('Something went wrong');
      return false;
    }
  }

  Future<bool> checkAuth() async {
    try {
      final isLoggedIn = await secureStorage.isLoggedIn();
      if (!isLoggedIn) return false;

      _user = await authRepository.getMe();
      return true;
    } catch (e) {
      await secureStorage.clearAll();
      return false;
    }
  }

  Future<void> logout() async {
    await secureStorage.clearAll();
    _user = null;
    setIdle();
  }

  Future<String?> getUserName() async {
    return await secureStorage.getUserName();
  }
}