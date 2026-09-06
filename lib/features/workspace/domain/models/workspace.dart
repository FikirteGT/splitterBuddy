import 'package:cloud_firestore/cloud_firestore.dart';

class WorkspaceRole {
  static const String owner = 'OWNER';
  static const String admin = 'ADMIN';
  static const String member = 'MEMBER';
}

class Workspace {
  final String id;
  final String name;
  final String inviteCode;
  final String ownerId;
  final List<String> memberIds;
  final Map<String, String> memberNames; // uid -> displayName
  final Map<String, String> memberRoles; // uid -> OWNER | ADMIN | MEMBER
  final int maxMembers;
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
    this.memberRoles = const {},
    this.maxMembers = 10,
    required this.activePeriodId,
    required this.createdAt,
    required this.updatedAt,
  });

  List<String> get members => memberIds;
  int get memberCount => memberIds.length;
  bool get isFull => memberIds.length >= maxMembers;
  bool get hasPartner => memberIds.length >= 2;

  String getRole(String userId) {
    if (memberRoles.containsKey(userId)) {
      return memberRoles[userId]!;
    }
    if (userId == ownerId) {
      return WorkspaceRole.owner;
    }
    return WorkspaceRole.member;
  }

  bool isOwner(String userId) => getRole(userId) == WorkspaceRole.owner || userId == ownerId;
  bool isAdmin(String userId) => getRole(userId) == WorkspaceRole.admin || isOwner(userId);
  bool canManageMembers(String userId) => isAdmin(userId);
  bool canDeleteWorkspace(String userId) => isOwner(userId);

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
    Map<String, String>? memberRoles,
    int? maxMembers,
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
      memberRoles: memberRoles ?? this.memberRoles,
      maxMembers: maxMembers ?? this.maxMembers,
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
      'memberRoles': memberRoles.isNotEmpty
          ? memberRoles
          : {for (final m in memberIds) m: m == ownerId ? WorkspaceRole.owner : WorkspaceRole.member},
      'maxMembers': maxMembers,
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

    final mIds = List<String>.from(map['memberIds'] ?? []);
    final owner = map['ownerId'] ?? (mIds.isNotEmpty ? mIds.first : '');

    // Backward compatibility for memberRoles
    final rawRoles = map['memberRoles'] as Map<String, dynamic>?;
    final Map<String, String> roles = {};
    if (rawRoles != null) {
      rawRoles.forEach((k, v) => roles[k] = v.toString());
    } else {
      for (final m in mIds) {
        roles[m] = m == owner ? WorkspaceRole.owner : WorkspaceRole.member;
      }
    }

    return Workspace(
      id: documentId.isNotEmpty ? documentId : (map['id'] ?? ''),
      name: map['name'] ?? 'Workspace',
      inviteCode: map['inviteCode'] ?? '',
      ownerId: owner,
      memberIds: mIds,
      memberNames: Map<String, String>.from(map['memberNames'] ?? {}),
      memberRoles: roles,
      maxMembers: (map['maxMembers'] as num?)?.toInt() ?? 10,
      activePeriodId: map['activePeriodId'] ?? '',
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }
}
