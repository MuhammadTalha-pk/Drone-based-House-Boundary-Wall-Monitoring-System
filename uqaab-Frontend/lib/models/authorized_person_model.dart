// lib/models/authorized_person_model.dart
class AuthorizedPersonModel {
  final String id;
  final String name;
  final String role;           // Guard / Guest / Authorized Person
  final String relationship;   // kept for backward compat (same value as role)
  final List<String> photoUrls;
  final bool hasFaceEncoding;

  AuthorizedPersonModel({
    required this.id,
    required this.name,
    required this.role,
    String? relationship,
    required this.photoUrls,
    this.hasFaceEncoding = false,
  }) : relationship = relationship ?? role;

  factory AuthorizedPersonModel.fromJson(Map<String, dynamic> json) {
    final encodings = json['face_encodings'] as List? ?? [];
    final roleRaw   = json['role'] ?? json['relationship'] ?? 'Guest';
    return AuthorizedPersonModel(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      role: roleRaw,
      relationship: roleRaw,
      photoUrls: List<String>.from(json['photo_urls'] ?? []),
      hasFaceEncoding: encodings.isNotEmpty,
    );
  }
}