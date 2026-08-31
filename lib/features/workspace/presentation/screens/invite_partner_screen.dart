import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:splitterbuddy/core/constants/app_colors.dart';
import 'package:splitterbuddy/features/workspace/domain/models/workspace.dart';
import 'package:splitterbuddy/shared/widgets/custom_button.dart';

class InvitePartnerScreen extends StatelessWidget {
  final Workspace workspace;
  final bool isNewlyCreated;

  const InvitePartnerScreen({
    super.key,
    required this.workspace,
    this.isNewlyCreated = false,
  });

  void _copyCode(BuildContext context) {
    Clipboard.setData(ClipboardData(text: workspace.inviteCode));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Invitation code "${workspace.inviteCode}" copied to clipboard!'),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invite Your Partner'),
        leading: isNewlyCreated
            ? IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 1),

              // Visual Icon Container
              Center(
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: AppColors.badgeGreenBg,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 2),
                  ),
                  child: const Icon(
                    Icons.share_rounded,
                    size: 44,
                    color: AppColors.primaryLight,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                'Invite Your Partner',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Share this 6-character code with your partner to join "${workspace.name}" and start splitting expenses automatically.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 36),

              // Code Display Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.cardBorder, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      'WORKSPACE INVITATION CODE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SelectableText(
                      workspace.inviteCode,
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primaryLight,
                        letterSpacing: 8,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Copy Button
              CustomButton(
                text: 'Copy Invitation Code',
                icon: Icons.copy_rounded,
                onPressed: () => _copyCode(context),
              ),
              const SizedBox(height: 12),

              if (isNewlyCreated)
                CustomButton(
                  text: 'Go to Dashboard',
                  isOutlined: true,
                  onPressed: () => Navigator.of(context).pop(),
                ),

              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}
