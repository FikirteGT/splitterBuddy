import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:splitterbuddy/features/authentication/presentation/controllers/auth_controller.dart';
import 'package:splitterbuddy/features/authentication/presentation/screens/sign_in_screen.dart';
import 'package:splitterbuddy/features/dashboard/presentation/screens/main_navigation_scaffold.dart';
import 'package:splitterbuddy/shared/widgets/error_view.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    if (auth.isLoading && auth.currentUser == null) {
      return const Scaffold(
        body: LoadingView(message: 'Initializing SplitterBud...'),
      );
    }

    if (auth.isAuthenticated) {
      return const MainNavigationScaffold();
    }

    return const SignInScreen();
  }
}
