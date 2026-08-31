import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../../shared/widgets/custom_text_field.dart';
import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../controllers/workspace_controller.dart';

class JoinWorkspaceScreen extends StatefulWidget {
  const JoinWorkspaceScreen({super.key});

  @override
  State<JoinWorkspaceScreen> createState() => _JoinWorkspaceScreenState();
}

class _JoinWorkspaceScreenState extends State<JoinWorkspaceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _handleJoin() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final auth = context.read<AuthController>();
    final wsController = context.read<WorkspaceController>();

    final joinedWs = await wsController.joinWorkspace(
      inviteCode: _codeController.text.trim().toUpperCase(),
      userId: auth.uid,
      userName: auth.displayName,
    );

    if (!mounted) return;
    if (joinedWs != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Joined "${joinedWs.name}" successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.of(context).pop();
    } else if (wsController.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(wsController.errorMessage!),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final wsController = context.watch<WorkspaceController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Join Workspace'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.badgeBlueBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.vpn_key_outlined, color: AppColors.info, size: 28),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Have an Invitation Code?',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Enter the 6-character code shared by your partner.',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                CustomTextField(
                  controller: _codeController,
                  label: '6-Character Invitation Code',
                  hintText: 'e.g. K9X2MN',
                  textCapitalization: TextCapitalization.characters,
                  prefixIcon: const Icon(Icons.pin_outlined, size: 20, color: AppColors.textMuted),
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(6),
                    FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                  ],
                  autofocus: true,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Invitation code is required';
                    if (val.trim().length != 6) return 'Code must be exactly 6 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                CustomButton(
                  text: 'Join Workspace',
                  icon: Icons.login_rounded,
                  isLoading: wsController.isLoading,
                  onPressed: _handleJoin,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
