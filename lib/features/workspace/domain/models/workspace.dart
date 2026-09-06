import 'package:cloud_firestore/cloud_firestore.dart';

class Workspace {
  final String id;
  final String name;
  final String inviteCode;
  final String ownerId;
  final List<String> memberIds;
  final Map<String, String> memberNames; // uid -> displayName
  final String activePeriodId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Workspace({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.ownerId,
    required this.memberIds,
    required this.memberNames,
    required this.activePeriodId,
    required this.createdAt,
    required this.updatedAt,
  });

  List<String> get members => memberIds;
  bool get isFull => memberIds.length >= 2;
  bool get hasPartner => memberIds.length == 2;

  String? getPartnerId(String currentUserId) {
    for (final id in memberIds) {
      if (id != currentUserId) return id;
    }
    return null;
  }

  String getPartnerName(String currentUserId) {
    final partnerId = getPartnerId(currentUserId);
    if (partnerId == null) return 'Partner';
    return memberNames[partnerId] ?? 'Partner';
  }

  String getMemberName(String userId, {String fallback = 'User'}) {
    return memberNames[userId] ?? fallback;
  }

  Workspace copyWith({
    String? id,
    String? name,
    String? inviteCode,
    String? ownerId,
    List<String>? memberIds,
    Map<String, String>? memberNames,
    String? activePeriodId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Workspace(
      id: id ?? this.id,
      name: name ?? this.name,
      inviteCode: inviteCode ?? this.inviteCode,
      ownerId: ownerId ?? this.ownerId,
      memberIds: memberIds ?? this.memberIds,
      memberNames: memberNames ?? this.memberNames,
      activePeriodId: activePeriodId ?? this.activePeriodId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'inviteCode': inviteCode,
      'ownerId': ownerId,
      'memberIds': memberIds,
      'memberNames': memberNames,
      'activePeriodId': activePeriodId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory Workspace.fromMap(Map<String, dynamic> map, String documentId) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return Workspace(
      id: documentId.isNotEmpty ? documentId : (map['id'] ?? ''),
      name: map['name'] ?? 'Workspace',
      inviteCode: map['inviteCode'] ?? '',
      ownerId: map['ownerId'] ?? '',
      memberIds: List<String>.from(map['memberIds'] ?? []),
      memberNames: Map<String, String>.from(map['memberNames'] ?? {}),
      activePeriodId: map['activePeriodId'] ?? '',
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }
}
