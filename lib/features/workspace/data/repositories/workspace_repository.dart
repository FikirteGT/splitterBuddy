import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:splitterbuddy/core/constants/app_constants.dart';
import 'package:splitterbuddy/core/errors/app_exceptions.dart';
import 'package:splitterbuddy/core/utils/invite_code_generator.dart';
import 'package:splitterbuddy/features/workspace/domain/models/expense_period.dart';
import 'package:splitterbuddy/features/workspace/domain/models/workspace.dart';

class WorkspaceRepository {
  final FirebaseFirestore _firestore;

  WorkspaceRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference get _workspacesRef =>
      _firestore.collection(AppConstants.workspacesCollection);

  CollectionReference get _usersRef =>
      _firestore.collection(AppConstants.usersCollection);

  Stream<List<Workspace>> streamUserWorkspaces(String userId) {
    return _workspacesRef
        .where('memberIds', arrayContains: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Workspace.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  Stream<Workspace?> streamWorkspace(String workspaceId) {
    return _workspacesRef.doc(workspaceId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return Workspace.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    });
  }

  Stream<ExpensePeriod?> streamActivePeriod(String workspaceId, String periodId) {
    if (workspaceId.isEmpty || periodId.isEmpty) {
      return Stream.value(null);
    }
    return _workspacesRef
        .doc(workspaceId)
        .collection(AppConstants.periodsCollection)
        .doc(periodId)
        .snapshots()
        .map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return ExpensePeriod.fromMap(doc.data()!, doc.id);
    });
  }

  Future<Workspace?> getWorkspace(String workspaceId) async {
    try {
      final doc = await _workspacesRef.doc(workspaceId).get();
      if (!doc.exists || doc.data() == null) return null;
      return Workspace.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    } catch (e) {
      throw WorkspaceException('Failed to fetch workspace: ${e.toString()}');
    }
  }

  Future<Workspace> createWorkspace({
    required String name,
    required String ownerId,
    required String ownerName,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw const WorkspaceException('Workspace name cannot be empty.');
    }

    try {
      final inviteCode = InviteCodeGenerator.generate();
      final wsDocRef = _workspacesRef.doc();
      final periodDocRef = wsDocRef.collection(AppConstants.periodsCollection).doc();

      final now = DateTime.now();

      final period = ExpensePeriod(
        id: periodDocRef.id,
        workspaceId: wsDocRef.id,
        periodNumber: 1,
        isSettled: false,
        createdAt: now,
      );

      final workspace = Workspace(
        id: wsDocRef.id,
        name: trimmedName,
        inviteCode: inviteCode,
        ownerId: ownerId,
        memberIds: [ownerId],
        memberNames: {ownerId: ownerName.trim().isEmpty ? 'Owner' : ownerName.trim()},
        activePeriodId: periodDocRef.id,
        createdAt: now,
        updatedAt: now,
      );

      final batch = _firestore.batch();
      batch.set(wsDocRef, workspace.toMap());
      batch.set(periodDocRef, period.toMap());
      batch.update(_usersRef.doc(ownerId), {
        'workspaceIds': FieldValue.arrayUnion([wsDocRef.id]),
      });

      await batch.commit();
      return workspace;
    } catch (e) {
      throw WorkspaceException('Failed to create workspace: ${e.toString()}');
    }
  }

  Future<Workspace> joinWorkspace({
    required String inviteCode,
    required String userId,
    required String userName,
  }) async {
    final normalizedCode = InviteCodeGenerator.normalize(inviteCode);
    if (!InviteCodeGenerator.isValidFormat(normalizedCode)) {
      throw const WorkspaceException('Invalid invitation code format. Please check and try again.');
    }

    try {
      // Find workspace by invite code
      final querySnapshot = await _workspacesRef
          .where('inviteCode', isEqualTo: normalizedCode)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        throw const WorkspaceException('No workspace found with this invitation code.');
      }

      final wsDoc = querySnapshot.docs.first;
      final wsId = wsDoc.id;

      // Run atomic transaction to verify and add user
      final joinedWorkspace = await _firestore.runTransaction<Workspace>((transaction) async {
        final freshSnapshot = await transaction.get(_workspacesRef.doc(wsId));
        if (!freshSnapshot.exists || freshSnapshot.data() == null) {
          throw const WorkspaceException('Workspace no longer exists.');
        }

        final currentData = freshSnapshot.data() as Map<String, dynamic>;
        final currentMembers = List<String>.from(currentData['memberIds'] ?? []);
        final currentNames = Map<String, dynamic>.from(currentData['memberNames'] ?? {});

        if (currentMembers.contains(userId)) {
          throw const WorkspaceException('You are already a member of this workspace.');
        }

        if (currentMembers.length >= AppConstants.maxWorkspaceMembers) {
          throw const WorkspaceException('This workspace is already full (maximum 2 members).');
        }

        final updatedMembers = [...currentMembers, userId];
        final updatedNames = {
          ...currentNames,
          userId: userName.trim().isEmpty ? 'Partner' : userName.trim(),
        };

        transaction.update(_workspacesRef.doc(wsId), {
          'memberIds': updatedMembers,
          'memberNames': updatedNames,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        transaction.update(_usersRef.doc(userId), {
          'workspaceIds': FieldValue.arrayUnion([wsId]),
        });

        return Workspace.fromMap({
          ...currentData,
          'memberIds': updatedMembers,
          'memberNames': updatedNames,
        }, wsId);
      });

      return joinedWorkspace;
    } on WorkspaceException {
      rethrow;
    } catch (e) {
      throw WorkspaceException('Failed to join workspace: ${e.toString()}');
    }
  }

  Future<void> deleteWorkspace(String workspaceId, String userId) async {
    try {
      final wsDoc = await _workspacesRef.doc(workspaceId).get();
      if (!wsDoc.exists || wsDoc.data() == null) return;

      final data = wsDoc.data() as Map<String, dynamic>;
      if (data['ownerId'] != userId) {
        throw const PermissionException('Only the workspace owner can delete this workspace.');
      }

      final memberIds = List<String>.from(data['memberIds'] ?? []);

      final batch = _firestore.batch();
      batch.delete(_workspacesRef.doc(workspaceId));

      for (final memberId in memberIds) {
        batch.update(_usersRef.doc(memberId), {
          'workspaceIds': FieldValue.arrayRemove([workspaceId]),
        });
      }

      await batch.commit();
    } on AppException {
      rethrow;
    } catch (e) {
      throw WorkspaceException('Failed to delete workspace: ${e.toString()}');
    }
  }
}
