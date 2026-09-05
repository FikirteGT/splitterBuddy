import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:splitterbuddy/core/constants/app_constants.dart';
import 'package:splitterbuddy/core/errors/app_exceptions.dart';
import 'package:splitterbuddy/core/utils/currency_formatter.dart';
import 'package:splitterbuddy/features/history/domain/models/activity_log.dart';
import 'package:splitterbuddy/features/notifications/domain/models/app_notification.dart';
import 'package:splitterbuddy/features/settlement/domain/models/settlement.dart';
import 'package:splitterbuddy/features/workspace/domain/models/expense_period.dart';

class SettlementRepository {
  final FirebaseFirestore _firestore;

  SettlementRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference _settlementsRef(String workspaceId) =>
      _firestore.collection(AppConstants.workspacesCollection).doc(workspaceId).collection(AppConstants.settlementsCollection);

  CollectionReference _periodsRef(String workspaceId) =>
      _firestore.collection(AppConstants.workspacesCollection).doc(workspaceId).collection(AppConstants.periodsCollection);

  CollectionReference _activityLogsRef(String workspaceId) =>
      _firestore.collection(AppConstants.workspacesCollection).doc(workspaceId).collection(AppConstants.activityLogsCollection);

  CollectionReference _userNotificationsRef(String userId) =>
      _firestore.collection(AppConstants.usersCollection).doc(userId).collection(AppConstants.notificationsCollection);

  Stream<List<Settlement>> streamSettlements(String workspaceId) {
    if (workspaceId.isEmpty) return Stream.value([]);

    return _settlementsRef(workspaceId).snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => Settlement.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return list;
    });
  }

  Stream<List<ExpensePeriod>> streamPeriods(String workspaceId) {
    if (workspaceId.isEmpty) return Stream.value([]);

    return _periodsRef(workspaceId).snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => ExpensePeriod.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
      list.sort((a, b) => b.periodNumber.compareTo(a.periodNumber));
      return list;
    });
  }

  Future<void> settleBalance({
    required String workspaceId,
    required ExpensePeriod currentPeriod,
    required double amount,
    required String payerId,
    required String receiverId,
    required String payerName,
    required String receiverName,
    required String initiatedBy,
    required String initiatedByName,
    String? partnerId,
  }) async {
    final roundedAmount = CurrencyFormatter.roundMoney(amount);
    if (roundedAmount <= 0) {
      throw const SettlementException('Settlement amount must be greater than 0.');
    }

    try {
      final now = DateTime.now();
      final batch = _firestore.batch();

      final wsDocRef = _firestore.collection(AppConstants.workspacesCollection).doc(workspaceId);
      final currentPeriodDocRef = _periodsRef(workspaceId).doc(currentPeriod.id);
      final newPeriodDocRef = _periodsRef(workspaceId).doc();
      final settlementDocRef = _settlementsRef(workspaceId).doc();
      final actDocRef = _activityLogsRef(workspaceId).doc();

      // 1. Create settlement record
      final settlement = Settlement(
        id: settlementDocRef.id,
        workspaceId: workspaceId,
        periodId: currentPeriod.id,
        amount: roundedAmount,
        payerId: payerId,
        receiverId: receiverId,
        payerName: payerName,
        receiverName: receiverName,
        initiatedBy: initiatedBy,
        initiatedByName: initiatedByName,
        timestamp: now,
      );
      batch.set(settlementDocRef, settlement.toMap());

      // 2. Mark current period as settled
      batch.update(currentPeriodDocRef, {
        'isSettled': true,
        'settledAt': Timestamp.fromDate(now),
        'settledBy': initiatedBy,
        'settledAmount': roundedAmount,
      });

      // 3. Create new active expense period
      final nextPeriod = ExpensePeriod(
        id: newPeriodDocRef.id,
        workspaceId: workspaceId,
        periodNumber: currentPeriod.periodNumber + 1,
        isSettled: false,
        createdAt: now,
      );
      batch.set(newPeriodDocRef, nextPeriod.toMap());

      // 4. Update workspace's activePeriodId
      batch.update(wsDocRef, {
        'activePeriodId': newPeriodDocRef.id,
        'updatedAt': Timestamp.fromDate(now),
      });

      // 5. Add activity log
      final activityLog = ActivityLog(
        id: actDocRef.id,
        workspaceId: workspaceId,
        actorId: initiatedBy,
        actorName: initiatedByName,
        action: AppConstants.actionSettled,
        amount: roundedAmount,
        paidBy: payerId,
        paidByName: initiatedBy == payerId ? initiatedByName : 'Partner',
        timestamp: now,
      );
      batch.set(actDocRef, activityLog.toMap());

      // 6. Notify partner if present
      final targetPartner = partnerId ?? (initiatedBy == payerId ? receiverId : payerId);
      if (targetPartner.isNotEmpty && targetPartner != initiatedBy) {
        final notifDocRef = _userNotificationsRef(targetPartner).doc();
        final notif = AppNotification(
          id: notifDocRef.id,
          userId: targetPartner,
          workspaceId: workspaceId,
          type: AppConstants.notifSettlement,
          title: 'Balance Settled',
          message: '$initiatedByName marked ${CurrencyFormatter.format(roundedAmount)} as settled. A new expense period has begun.',
          createdAt: now,
        );
        batch.set(notifDocRef, notif.toMap());
      }

      await batch.commit();
    } catch (e) {
      throw SettlementException('Failed to settle balance: ${e.toString()}');
    }
  }
}
