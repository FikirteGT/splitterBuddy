import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:splitterbuddy/core/constants/app_constants.dart';
import 'package:splitterbuddy/features/history/domain/models/activity_log.dart';

class ActivityRepository {
  final FirebaseFirestore _firestore;

  ActivityRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Stream<List<ActivityLog>> streamActivityLogs(String workspaceId) {
    if (workspaceId.isEmpty) return Stream.value([]);

    return _firestore
        .collection(AppConstants.workspacesCollection)
        .doc(workspaceId)
        .collection(AppConstants.activityLogsCollection)
        .snapshots()
        .map((snapshot) {
      final logs = snapshot.docs
          .map((doc) => ActivityLog.fromMap(doc.data(), doc.id))
          .toList();
      logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return logs;
    });
  }
}
