class AppConstants {
  AppConstants._();

  static const String appName = 'SplitterBud';
  static const String appTagline = 'Simple 2-Person Shared Expense Splitter';

  // Currency
  static const String defaultCurrency = 'ETB';

  // Constraints
  static const int maxWorkspaceMembers = 2;
  static const int inviteCodeLength = 6;

  // Collection Names
  static const String usersCollection = 'users';
  static const String workspacesCollection = 'workspaces';
  static const String expensesCollection = 'expenses';
  static const String periodsCollection = 'periods';
  static const String pendingChangesCollection = 'pendingChanges';
  static const String notificationsCollection = 'notifications';
  static const String activityLogsCollection = 'activityLogs';
  static const String settlementsCollection = 'settlements';

  // Expense Statuses
  static const String expenseActive = 'ACTIVE';
  static const String expenseDeleted = 'DELETED';

  // Pending Change Statuses
  static const String pendingChangePending = 'PENDING';
  static const String pendingChangeApproved = 'APPROVED';
  static const String pendingChangeRejected = 'REJECTED';

  // Notification Types
  static const String notifAddExpense = 'ADD_EXPENSE';
  static const String notifEditExpense = 'EDIT_EXPENSE';
  static const String notifDeleteExpense = 'DELETE_EXPENSE';
  static const String notifPendingEdit = 'PENDING_EDIT';
  static const String notifEditApproved = 'EDIT_APPROVED';
  static const String notifEditRejected = 'EDIT_REJECTED';
  static const String notifSettlement = 'SETTLEMENT';

  // Activity Actions
  static const String actionAdded = 'ADDED';
  static const String actionEdited = 'EDITED';
  static const String actionProposedEdit = 'PROPOSED_EDIT';
  static const String actionApprovedEdit = 'APPROVED_EDIT';
  static const String actionRejectedEdit = 'REJECTED_EDIT';
  static const String actionDeleted = 'DELETED';
  static const String actionSettled = 'SETTLED';
}
