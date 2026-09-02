import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'features/authentication/data/repositories/auth_repository.dart';
import 'features/authentication/presentation/controllers/auth_controller.dart';
import 'features/authentication/presentation/screens/auth_wrapper.dart';
import 'features/expenses/data/repositories/expense_repository.dart';
import 'features/expenses/presentation/controllers/expense_controller.dart';
import 'features/history/data/repositories/activity_repository.dart';
import 'features/history/presentation/controllers/history_controller.dart';
import 'features/notifications/data/repositories/notification_repository.dart';
import 'features/notifications/presentation/controllers/notification_controller.dart';
import 'features/settlement/data/repositories/settlement_repository.dart';
import 'features/settlement/presentation/controllers/settlement_controller.dart';
import 'features/workspace/data/repositories/workspace_repository.dart';
import 'features/workspace/presentation/controllers/workspace_controller.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    if (kIsWeb) {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
      );
    }
  } catch (e) {
    debugPrint('Firebase initialization note: $e');
  }

  runApp(const SplitterBudApp());
}

class SplitterBudApp extends StatelessWidget {
  const SplitterBudApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Repositories
        Provider<AuthRepository>(create: (_) => AuthRepository()),
        Provider<WorkspaceRepository>(create: (_) => WorkspaceRepository()),
        Provider<ExpenseRepository>(create: (_) => ExpenseRepository()),
        Provider<ActivityRepository>(create: (_) => ActivityRepository()),
        Provider<NotificationRepository>(create: (_) => NotificationRepository()),
        Provider<SettlementRepository>(create: (_) => SettlementRepository()),

        // Controllers
        ChangeNotifierProvider<AuthController>(
          create: (ctx) => AuthController(
            authRepository: ctx.read<AuthRepository>(),
          ),
        ),
        ChangeNotifierProvider<WorkspaceController>(
          create: (ctx) => WorkspaceController(
            workspaceRepository: ctx.read<WorkspaceRepository>(),
          ),
        ),
        ChangeNotifierProvider<ExpenseController>(
          create: (ctx) => ExpenseController(
            expenseRepository: ctx.read<ExpenseRepository>(),
          ),
        ),
        ChangeNotifierProvider<HistoryController>(
          create: (ctx) => HistoryController(
            activityRepository: ctx.read<ActivityRepository>(),
          ),
        ),
        ChangeNotifierProvider<NotificationController>(
          create: (ctx) => NotificationController(
            notificationRepository: ctx.read<NotificationRepository>(),
          ),
        ),
        ChangeNotifierProvider<SettlementController>(
          create: (ctx) => SettlementController(
            settlementRepository: ctx.read<SettlementRepository>(),
          ),
        ),
      ],
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const AuthWrapper(),
      ),
    );
  }
}
