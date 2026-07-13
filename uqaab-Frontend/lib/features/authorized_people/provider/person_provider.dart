// lib/features/authorized_people/provider/person_provider.dart
// import 'dart:io';
// import 'package:flutter/material.dart';

import 'package:uqaab/core/errors/api_exception.dart';
import 'package:uqaab/core/providers/base_provider.dart';
import 'package:uqaab/models/authorized_person_model.dart';
import 'package:uqaab/repositories/person_repository.dart';

class PersonProvider extends BaseProvider {
  final PersonRepository personRepository;

  List<AuthorizedPersonModel> _people = [];
  List<AuthorizedPersonModel> get people => _people;

  List<String> _relationships = [];
  List<String> get relationships => _relationships;

  String? _encodeMessage;
  String? get encodeMessage => _encodeMessage;

  PersonProvider({required this.personRepository});

  AuthorizedPersonModel? getPersonById(String id) {
    try {
      return _people.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> loadPeople(String propertyId) async {
    try {
      setLoading();
      _people = await personRepository.getPeople(propertyId);
      setSuccess();
    } on ApiException catch (e) {
      setError(e.message);
    } catch (e) {
      setError('Failed to load people');
    }
  }

  Future<void> loadRelationships() async {
    try {
      _relationships = await personRepository.getRoles();
      notifyListeners();
    } catch (_) {
      _relationships = ['Guard', 'Guest', 'Authorized Person'];
      notifyListeners();
    }
  }

  Future<bool> createPerson({
    required String propertyId,
    required String name,
    required String relationship,
    List<String> photoUrls = const [],
  }) async {
    try {
      setLoading();
      await personRepository.createPerson(
        propertyId: propertyId,
        name: name,
        role: relationship,
        photoUrls: photoUrls,
      );
      await loadPeople(propertyId);
      return true;
    } on ApiException catch (e) {
      // ---> SHOW REAL API ERROR <---
      setError('Server Error: ${e.message}');
      return false;
    } catch (e) {
      // ---> SHOW REAL APP ERROR <---
      setError('App Error: $e');
      return false;
    }
  }

  Future<bool> updatePerson({
    required String personId,
    required String propertyId,
    String? name,
    String? relationship,
    List<String>? photoUrls,
  }) async {
    try {
      setLoading();
      await personRepository.updatePerson(
        personId: personId,
        name: name,
        role: relationship,
        photoUrls: photoUrls,
      );
      await loadPeople(propertyId);
      return true;
    } on ApiException catch (e) {
      // ---> SHOW REAL API ERROR <---
      setError('Server Error: ${e.message}');
      return false;
    } catch (e) {
      setError('Failed to update person');
      return false;
    }
  }

  Future<bool> deletePerson({
    required String personId,
    required String propertyId,
  }) async {
    try {
      setLoading();
      await personRepository.deletePerson(personId);
      await loadPeople(propertyId);
      return true;
    } on ApiException catch (e) {
      setError(e.message);
      return false;
    } catch (e) {
      setError('Failed to delete person');
      return false;
    }
  }

  Future<bool> encodeFace(String personId) async {
    try {
      _encodeMessage = null;
      setLoading();
      final result = await personRepository.encodeFace(personId);
      final count = (result['encodings_count'] as num?)?.toInt() ?? 0;
      _encodeMessage = count > 0
          ? 'Face enrolled ($count encoding(s) saved)'
          : 'No face found — ensure photo shows a clear frontal face';
      setSuccess();
      return count > 0;
    } on ApiException catch (e) {
      setError(e.message);
      return false;
    } catch (e) {
      setError('Face enrollment failed');
      return false;
    }
  }

  void clearEncodeMessage() {
    _encodeMessage = null;
    notifyListeners();
  }
}
