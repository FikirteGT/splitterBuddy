import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:splitterbuddy/core/constants/app_constants.dart';
import 'package:splitterbuddy/core/errors/app_exceptions.dart';
import 'package:splitterbuddy/features/notifications/domain/models/app_notification.dart';

class NotificationRepository {
  final FirebaseFirestore _firestore;

  NotificationRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference _userNotifications(String userId) =>
      _firestore.collection(AppConstants.usersCollection).doc(userId).collection(AppConstants.notificationsCollection);

  Stream<List<AppNotification>> streamNotifications(String userId) {
    if (userId.isEmpty) return Stream.value([]);

    return _userNotifications(userId).snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => AppNotification.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Future<void> markAsRead(String userId, String notificationId) async {
    try {
      await _userNotifications(userId).doc(notificationId).update({'isRead': true});
    } catch (e) {
      // Non-fatal
    }
  }

  Future<void> markAllAsRead(String userId) async {
    try {
      final unreadDocs = await _userNotifications(userId).where('isRead', isEqualTo: false).get();
      final batch = _firestore.batch();
      for (final doc in unreadDocs.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      throw AppException('Failed to mark all as read: $e');
    }
  }
}
