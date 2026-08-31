import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String uid;
  final String displayName;
  final String email;
  final List<String> workspaceIds;
  final bool isAnonymous;
  final DateTime createdAt;

  const UserProfile({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.workspaceIds,
    this.isAnonymous = false,
    required this.createdAt,
  });

  UserProfile copyWith({
    String? uid,
    String? displayName,
    String? email,
    List<String>? workspaceIds,
    bool? isAnonymous,
    DateTime? createdAt,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      workspaceIds: workspaceIds ?? this.workspaceIds,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'displayName': displayName,
      'email': email,
      'workspaceIds': workspaceIds,
      'isAnonymous': isAnonymous,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map, String documentId) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return UserProfile(
      uid: documentId.isNotEmpty ? documentId : (map['uid'] ?? ''),
      displayName: map['displayName'] ?? 'User',
      email: map['email'] ?? '',
      workspaceIds: List<String>.from(map['workspaceIds'] ?? []),
      isAnonymous: map['isAnonymous'] ?? false,
      createdAt: parseDate(map['createdAt']),
    );
  }
}
