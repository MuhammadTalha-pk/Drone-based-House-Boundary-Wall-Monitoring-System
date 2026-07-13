// lib/repositories/person_repository.dart
import 'dart:io';

import 'package:uqaab/core/constants/api_constants.dart';
import 'package:uqaab/core/services/api_service.dart';
import 'package:uqaab/models/authorized_person_model.dart';

class PersonRepository {
  final ApiService apiService;

  PersonRepository({required this.apiService});

  Future<List<AuthorizedPersonModel>> getPeople(String propertyId) async {
    final response = await apiService.get(ApiConstants.people(propertyId));
    final List<dynamic> data = response['people'] ?? [];
    return data.map((json) => AuthorizedPersonModel.fromJson(json)).toList();
  }

  Future<List<String>> getRoles() async {
    final response = await apiService.get(ApiConstants.relationships);
    final list = response['roles'] ?? response['relationships'] ?? [];
    return List<String>.from(list);
  }

  Future<String> uploadPersonImage(File image) async {
    final response = await apiService.uploadFile(
      ApiConstants.uploadPersonImage,
      file: image,
    );
    return response['url'];
  }

  Future<void> createPerson({
    required String propertyId,
    required String name,
    required String role,
    List<String> photoUrls = const [],
  }) async {
    await apiService.post(
      ApiConstants.people(propertyId),
      data: {
        'name': name,
        'role': role,
        'photo_urls': photoUrls,
      },
    );
  }

  Future<void> updatePerson({
    required String personId,
    String? name,
    String? role,
    List<String>? photoUrls,
  }) async {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (role != null) data['role'] = role;
    if (photoUrls != null) data['photo_urls'] = photoUrls;
    await apiService.put(ApiConstants.person(personId), data: data);
  }

  Future<void> deletePerson(String personId) async {
    await apiService.delete(ApiConstants.person(personId));
  }

  /// Trigger backend to encode face from the person's stored photos.
  Future<Map<String, dynamic>> encodeFace(String personId) async {
    return await apiService.post(
      ApiConstants.encodePerson,
      data: {'person_id': int.parse(personId)},
    );
  }
}