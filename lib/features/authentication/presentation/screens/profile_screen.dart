import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../../shared/widgets/custom_text_field.dart';
import '../controllers/auth_controller.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  bool _isEditingName = false;
  bool _isSavingName = false;

  @override
  void initState() {
    super.initState();
    final authController = context.read<AuthController>();
    _nameController.text = authController.displayName;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleSaveName() async {
    final trimmed = _nameController.text.trim();
    if (trimmed.isEmpty) return;

    setState(() => _isSavingName = true);
    await context.read<AuthController>().updateDisplayName(trimmed);
    if (!mounted) return;
    setState(() {
      _isSavingName = false;
      _isEditingName = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Display name updated successfully!'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  Future<void> _handleSignOut() async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Sign Out',
      message: 'Are you sure you want to sign out of SplitterBud?',
      confirmText: 'Sign Out',
      isDestructive: true,
    );

    if (confirmed == true && mounted) {
      await context.read<AuthController>().signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authController = context.watch<AuthController>();
    final profile = authController.userProfile;
    final isGuest = authController.isAnonymous;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile & Settings'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // User Avatar and Header Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: isGuest ? AppColors.secondary : AppColors.primary,
                      child: Text(
                        authController.displayName.isNotEmpty
                            ? authController.displayName.substring(0, 1).toUpperCase()
                            : 'U',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      authController.displayName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isGuest ? 'Guest User (Temporary Session)' : (profile?.email ?? authController.currentUser?.email ?? ''),
                      style: TextStyle(
                        fontSize: 14,
                        color: isGuest ? AppColors.warning : AppColors.textSecondary,
                        fontWeight: isGuest ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Edit Profile Info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Account Details',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_isEditingName) ...[
                      CustomTextField(
                        controller: _nameController,
                        label: 'Display Name',
                        textCapitalization: TextCapitalization.words,
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            setState(() {
                              _nameController.text = authController.displayName;
                              _isEditingName = false;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      CustomButton(
                        text: 'Save Changes',
                        isLoading: _isSavingName,
                        onPressed: _handleSaveName,
                        height: 44,
                      ),
                    ] else ...[
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.badge_outlined, color: AppColors.primaryLight),
                        title: const Text('Display Name', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
                        subtitle: Text(
                          authController.displayName,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20, color: AppColors.textSecondary),
                          onPressed: () {
                            _nameController.text = authController.displayName;
                            setState(() => _isEditingName = true);
                          },
                        ),
                      ),
                    ],
                    const Divider(),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.fingerprint_rounded, color: AppColors.secondaryLight),
                      title: const Text('User ID', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
                      subtitle: Text(
                        authController.uid,
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontFamily: 'monospace'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Sign Out Button
            CustomButton(
              text: 'Sign Out',
              isOutlined: true,
              icon: Icons.logout_rounded,
              textColor: AppColors.error,
              backgroundColor: AppColors.error,
              onPressed: _handleSignOut,
            ),
          ],
        ),
      ),
    );
  }
}
