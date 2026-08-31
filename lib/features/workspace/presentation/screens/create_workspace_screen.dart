import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../../shared/widgets/custom_text_field.dart';
import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../controllers/workspace_controller.dart';
import 'invite_partner_screen.dart';

class CreateWorkspaceScreen extends StatefulWidget {
  const CreateWorkspaceScreen({super.key});

  @override
  State<CreateWorkspaceScreen> createState() => _CreateWorkspaceScreenState();
}

class _CreateWorkspaceScreenState extends State<CreateWorkspaceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleCreate() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final auth = context.read<AuthController>();
    final wsController = context.read<WorkspaceController>();

    final createdWs = await wsController.createWorkspace(
      name: _nameController.text,
      ownerId: auth.uid,
      ownerName: auth.displayName,
    );

    if (!mounted) return;
    if (createdWs != null) {
      // Navigate to Invite Partner Screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => InvitePartnerScreen(workspace: createdWs, isNewlyCreated: true),
        ),
      );
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
        title: const Text('Create Workspace'),
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
                          color: AppColors.badgeGreenBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.group_add_rounded, color: AppColors.primary, size: 28),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Two-Person Shared Space',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Perfect for roommates, couples, travel partners, or friends.',
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
                const SizedBox(height: 28),

                CustomTextField(
                  controller: _nameController,
                  label: 'Workspace Name',
                  hintText: 'e.g. Apartment, Vacation Trip, Home',
                  textCapitalization: TextCapitalization.words,
                  prefixIcon: const Icon(Icons.home_work_outlined, size: 20, color: AppColors.textMuted),
                  autofocus: true,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Workspace name is required';
                    if (val.trim().length < 2) return 'Name must be at least 2 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                CustomButton(
                  text: 'Create & Get Invite Code',
                  icon: Icons.check_circle_outline_rounded,
                  isLoading: wsController.isLoading,
                  onPressed: _handleCreate,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
