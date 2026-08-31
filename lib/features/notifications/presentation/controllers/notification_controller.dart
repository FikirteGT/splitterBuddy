import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:splitterbuddy/features/notifications/data/repositories/notification_repository.dart';
import 'package:splitterbuddy/features/notifications/domain/models/app_notification.dart';

class NotificationController extends ChangeNotifier {
  final NotificationRepository _notificationRepository;

  List<AppNotification> _notifications = [];
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription<List<AppNotification>>? _subscription;
  String? _currentUserId;

  NotificationController({NotificationRepository? notificationRepository})
      : _notificationRepository = notificationRepository ?? NotificationRepository();

  List<AppNotification> get notifications => _notifications;
  int get unreadCount => _notifications.where((n) => !n.isRead).length;
  bool get hasUnread => unreadCount > 0;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void updateUserId(String? userId) {
    if (_currentUserId == userId) return;
    _currentUserId = userId;

    _subscription?.cancel();
    _notifications = [];

    if (userId != null && userId.isNotEmpty) {
      _listenToNotifications(userId);
    } else {
      notifyListeners();
    }
  }

  void _listenToNotifications(String userId) {
    _isLoading = true;
    notifyListeners();

    _subscription = _notificationRepository.streamNotifications(userId).listen(
      (list) {
        _notifications = list;
        _isLoading = false;
        notifyListeners();
      },
      onError: (err) {
        _isLoading = false;
        _errorMessage = 'Failed to load notifications: $err';
        notifyListeners();
      },
    );
  }

  Future<void> markAsRead(String notificationId) async {
    if (_currentUserId == null) return;
    await _notificationRepository.markAsRead(_currentUserId!, notificationId);
  }

  Future<void> markAllAsRead() async {
    if (_currentUserId == null) return;
    await _notificationRepository.markAllAsRead(_currentUserId!);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
