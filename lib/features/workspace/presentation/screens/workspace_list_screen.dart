import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:splitterbuddy/core/constants/app_colors.dart';
import 'package:splitterbuddy/features/authentication/presentation/controllers/auth_controller.dart';
import 'package:splitterbuddy/features/workspace/presentation/controllers/workspace_controller.dart';
import 'package:splitterbuddy/features/workspace/domain/models/workspace.dart';
import 'package:splitterbuddy/features/workspace/presentation/screens/create_workspace_screen.dart';
import 'package:splitterbuddy/features/workspace/presentation/screens/invite_partner_screen.dart';
import 'package:splitterbuddy/features/workspace/presentation/screens/join_workspace_screen.dart';
import 'package:splitterbuddy/features/workspace/presentation/screens/workspace_members_screen.dart';
import 'package:splitterbuddy/shared/widgets/confirm_dialog.dart';
import 'package:splitterbuddy/shared/widgets/custom_button.dart';
import 'package:splitterbuddy/shared/widgets/empty_state_view.dart';

class WorkspaceListScreen extends StatelessWidget {
  const WorkspaceListScreen({super.key});

  Future<void> _handleDelete(BuildContext context, Workspace ws, String userId) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Delete Workspace',
      message: 'Are you sure you want to delete "${ws.name}"? All shared expenses in this workspace will be deleted. This action cannot be undone.',
      confirmText: 'Delete',
      isDestructive: true,
    );

    if (confirmed == true && context.mounted) {
      final success = await context.read<WorkspaceController>().deleteWorkspace(ws.id, userId);
      if (context.mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Workspace "${ws.name}" deleted.'),
              backgroundColor: AppColors.error,
            ),
          );
        } else {
          final err = context.read<WorkspaceController>().errorMessage ?? 'Failed to delete workspace';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(err), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final wsController = context.watch<WorkspaceController>();
    final currentWs = wsController.currentWorkspace;
    final workspaces = wsController.workspaces;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workspaces'),
      ),
      body: workspaces.isEmpty
          ? EmptyStateView(
              icon: Icons.home_work_outlined,
              title: "You don't have a workspace yet",
              subtitle: 'Create a new workspace or enter an invitation code to start splitting expenses with your partner.',
              buttonText: 'Create Workspace',
              buttonIcon: Icons.add_rounded,
              onButtonPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CreateWorkspaceScreen()),
                );
              },
            )
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              children: [
                const Text(
                  'Active Workspaces',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                ...workspaces.map((ws) {
                  final isSelected = currentWs?.id == ws.id;
                  final isOwner = ws.ownerId == auth.uid;
                  final memberCount = ws.memberIds.length;
                  final hasPartner = memberCount == 2;

                  return Card(
                    color: isSelected ? AppColors.surfaceElevated : AppColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: isSelected ? AppColors.primary : AppColors.cardBorder,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    margin: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        wsController.selectWorkspace(ws);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Switched to "${ws.name}"'),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                        Navigator.of(context).pop(ws);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            ws.name,
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          if (isSelected) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppColors.badgeGreenBg,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: const Text(
                                                'ACTIVE',
                                                style: TextStyle(
                                                  color: AppColors.primary,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        memberCount > 1
                                            ? '$memberCount members: ${ws.memberNames.values.join(', ')}'
                                            : 'Waiting for members (1/${ws.maxMembers})',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: memberCount > 1 ? AppColors.textSecondary : AppColors.warning,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert_rounded, color: AppColors.textMuted),
                                  onSelected: (val) {
                                    if (val == 'members') {
                                      wsController.selectWorkspace(ws);
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => const WorkspaceMembersScreen(),
                                        ),
                                      );
                                    } else if (val == 'invite') {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => InvitePartnerScreen(workspace: ws),
                                        ),
                                      );
                                    } else if (val == 'delete') {
                                      _handleDelete(context, ws, auth.uid);
                                    }
                                  },
                                  itemBuilder: (ctx) => [
                                    const PopupMenuItem(
                                      value: 'members',
                                      child: Row(
                                        children: [
                                          Icon(Icons.groups_rounded, size: 18, color: AppColors.primaryLight),
                                          SizedBox(width: 8),
                                          Text('Members & Roles'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'invite',
                                      child: Row(
                                        children: [
                                          Icon(Icons.share_rounded, size: 18, color: AppColors.primaryLight),
                                          SizedBox(width: 8),
                                          Text('Invite Code'),
                                        ],
                                      ),
                                    ),
                                    if (isOwner)
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
                                            SizedBox(width: 8),
                                            Text('Delete Workspace', style: TextStyle(color: AppColors.error)),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                            if (!hasPartner) ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => InvitePartnerScreen(workspace: ws),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.person_add_outlined, size: 16, color: AppColors.primaryLight),
                                      label: const Text(
                                        'Invite Partner (Code: )',
                                        style: TextStyle(fontSize: 12, color: AppColors.primaryLight),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        side: const BorderSide(color: AppColors.primaryDark),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 24),
                CustomButton(
                  text: 'Create New Workspace',
                  icon: Icons.add_rounded,
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const CreateWorkspaceScreen()),
                    );
                  },
                ),
                const SizedBox(height: 12),
                CustomButton(
                  text: 'Join with Invitation Code',
                  icon: Icons.vpn_key_outlined,
                  isOutlined: true,
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const JoinWorkspaceScreen()),
                    );
                  },
                ),
              ],
            ),
    );
  }
}
