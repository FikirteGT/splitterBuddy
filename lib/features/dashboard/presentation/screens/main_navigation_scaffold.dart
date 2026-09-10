import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:splitterbuddy/core/constants/app_colors.dart';
import 'package:splitterbuddy/features/analytics/presentation/screens/analytics_screen.dart';
import 'package:splitterbuddy/features/authentication/presentation/controllers/auth_controller.dart';
import 'package:splitterbuddy/features/authentication/presentation/screens/profile_screen.dart';
import 'package:splitterbuddy/features/budgets/presentation/controllers/budget_controller.dart';
import 'package:splitterbuddy/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:splitterbuddy/features/expenses/presentation/controllers/expense_controller.dart';
import 'package:splitterbuddy/features/history/presentation/controllers/history_controller.dart';
import 'package:splitterbuddy/features/history/presentation/screens/history_screen.dart';
import 'package:splitterbuddy/features/notifications/presentation/controllers/notification_controller.dart';
import 'package:splitterbuddy/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:splitterbuddy/features/recurring/presentation/controllers/recurring_expense_controller.dart';
import 'package:splitterbuddy/features/settlement/presentation/controllers/settlement_controller.dart';
import 'package:splitterbuddy/features/workspace/presentation/controllers/workspace_controller.dart';

class MainNavigationScaffold extends StatefulWidget {
  const MainNavigationScaffold({super.key});

  @override
  State<MainNavigationScaffold> createState() => _MainNavigationScaffoldState();
}

class _MainNavigationScaffoldState extends State<MainNavigationScaffold> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    DashboardScreen(),
    AnalyticsScreen(),
    HistoryScreen(),
    NotificationsScreen(),
    ProfileScreen(),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncControllerContexts();
    });
  }

  void _syncControllerContexts() {
    if (!mounted) return;
    final auth = context.read<AuthController>();
    final wsController = context.read<WorkspaceController>();
    final expController = context.read<ExpenseController>();
    final historyController = context.read<HistoryController>();
    final notifController = context.read<NotificationController>();
    final settlementController = context.read<SettlementController>();
    final recurringController = context.read<RecurringExpenseController>();
    final budgetController = context.read<BudgetController>();

    final user = auth.currentUser;
    if (user != null) {
      wsController.updateUserId(user.uid);
      notifController.updateUserId(user.uid);
    }

    final currentWs = wsController.currentWorkspace;
    final currentPeriod = wsController.currentPeriod;

    if (currentWs != null) {
      historyController.updateWorkspace(currentWs.id);
      settlementController.updateWorkspace(currentWs.id);
      recurringController.updateWorkspace(currentWs.id);
      budgetController.updateWorkspace(currentWs.id);

      final partnerId = currentWs.getPartnerId(auth.uid);
      final partnerName = currentWs.getPartnerName(auth.uid);

      expController.updateContext(
        workspaceId: currentWs.id,
        periodId: currentPeriod?.id ?? currentWs.activePeriodId,
        currentUserId: auth.uid,
        partnerId: partnerId,
        partnerName: partnerName,
      );

      // Check and process due recurring expenses
      recurringController.checkAndProcessDue(
        activePeriodId: currentPeriod?.id ?? currentWs.activePeriodId,
        currentUserId: auth.uid,
        currentUserName: auth.displayName,
        partnerId: partnerId,
      );

      // Evaluate budget alerts
      if (expController.activeExpenses.isNotEmpty) {
        budgetController.evaluateBudgetAlerts(
          expenses: expController.activeExpenses,
          currentUserId: auth.uid,
          memberIds: currentWs.members,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<WorkspaceController>();
    context.watch<AuthController>();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncControllerContexts();
    });

    final notifController = context.watch<NotificationController>();
    final unreadCount = notifController.unreadCount;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard_rounded),
            label: 'Home',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.insights_outlined),
            activeIcon: Icon(Icons.insights_rounded),
            label: 'Analytics',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.history_rounded),
            activeIcon: Icon(Icons.history_toggle_off_rounded),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Badge(
              isLabelVisible: unreadCount > 0,
              label: Text('$unreadCount'),
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.notifications_none_rounded),
            ),
            activeIcon: Badge(
              isLabelVisible: unreadCount > 0,
              label: Text('$unreadCount'),
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.notifications_rounded),
            ),
            label: 'Notifications',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            activeIcon: Icon(Icons.person_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
