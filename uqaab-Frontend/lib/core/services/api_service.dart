import 'dart:convert';
import 'dart:io';
import 'package:uqaab/core/network/dio_client.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../errors/api_exception.dart';
import 'package:http_parser/http_parser.dart';

class ApiService {
  final DioClient dioClient;

  ApiService({required this.dioClient});

  // ==================== GET ====================
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final response = await dioClient.get(
      path,
      queryParameters: queryParameters,
    );
    return response.data as Map<String, dynamic>;
  }

  // ==================== POST ====================
  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? data,
  }) async {
    final response = await dioClient.post(path, data: data);
    return response.data as Map<String, dynamic>;
  }

  // ==================== PUT ====================
  Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? data,
  }) async {
    final response = await dioClient.put(path, data: data);
    return response.data as Map<String, dynamic>;
  }

  // ==================== DELETE ====================
  Future<Map<String, dynamic>> delete(String path) async {
    final response = await dioClient.delete(path);
    return response.data as Map<String, dynamic>;
  }

  // ==================== FILE UPLOAD (FIXED) ====================
  Future<Map<String, dynamic>> uploadFile(
    String endpoint, {
    required File file,
    String fieldName = 'file',
  }) async {
    try {
      final uri = Uri.parse('${AppConfig.baseUrl}$endpoint');

      final request = http.MultipartRequest('POST', uri);

      final token = await dioClient.secureStorage.getToken();
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      // ✅ DO NOT set Content-Type manually

      request.files.add(
        await http.MultipartFile.fromPath(
          fieldName,
          file.path,
          // This tells FastAPI: "Hey, this file is definitely a JPEG image!"
          contentType: MediaType('image', 'jpeg'),
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body);
      } else {
        // This holds the actual reason FastAPI rejected it!
        throw ApiException(
          message: 'Server rejected upload: ${response.body}',
          statusCode: response.statusCode,
        );
      }
    } on ApiException {
      // ✅ ADD THIS: Let our custom API exceptions pass through
      rethrow;
    } catch (e) {
      // Only catch genuine network crashes/timeouts here
      throw ApiException(
        message: 'Network/Upload error: $e',
        statusCode: 500,
      );
    }
  }
}
