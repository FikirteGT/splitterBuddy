import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:splitterbuddy/core/constants/app_colors.dart';
import 'package:splitterbuddy/features/authentication/presentation/controllers/auth_controller.dart';
import 'package:splitterbuddy/features/workspace/domain/models/workspace.dart';
import 'package:splitterbuddy/features/workspace/presentation/controllers/workspace_controller.dart';

class WorkspaceMembersScreen extends StatefulWidget {
  const WorkspaceMembersScreen({super.key});

  @override
  State<WorkspaceMembersScreen> createState() => _WorkspaceMembersScreenState();
}

class _WorkspaceMembersScreenState extends State<WorkspaceMembersScreen> {
  bool _isProcessing = false;

  void _copyInviteCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Invite code copied to clipboard!'),
        backgroundColor: AppColors.success,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handleRoleChange(Workspace ws, String targetUserId, String currentRole) async {
    final auth = context.read<AuthController>();
    final wsController = context.read<WorkspaceController>();
    final targetName = ws.getMemberName(targetUserId);

    final selectedRole = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Change Role for $targetName', style: const TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Member', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
              subtitle: const Text('Can add, edit, and settle expenses', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              trailing: currentRole == WorkspaceRole.member ? const Icon(Icons.check, color: AppColors.primaryLight) : null,
              onTap: () => Navigator.of(ctx).pop(WorkspaceRole.member),
            ),
            ListTile(
              title: const Text('Admin', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
              subtitle: const Text('Can manage members and budgets', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              trailing: currentRole == WorkspaceRole.admin ? const Icon(Icons.check, color: AppColors.primaryLight) : null,
              onTap: () => Navigator.of(ctx).pop(WorkspaceRole.admin),
            ),
            ListTile(
              title: const Text('Owner', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
              subtitle: const Text('Full control and workspace settings', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              trailing: currentRole == WorkspaceRole.owner ? const Icon(Icons.check, color: AppColors.primaryLight) : null,
              onTap: () => Navigator.of(ctx).pop(WorkspaceRole.owner),
            ),
          ],
        ),
      ),
    );

    if (selectedRole == null || selectedRole == currentRole) return;

    setState(() => _isProcessing = true);
    final success = await wsController.updateMemberRole(
      targetUserId: targetUserId,
      newRole: selectedRole,
      callerUserId: auth.uid,
      callerName: auth.displayName,
    );
    if (!mounted) return;
    setState(() => _isProcessing = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Updated $targetName to $selectedRole'),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      final err = wsController.errorMessage ?? 'Failed to update role';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _handleRemoveMember(Workspace ws, String targetUserId) async {
    final targetName = ws.getMemberName(targetUserId);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Remove $targetName?', style: const TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'Are you sure you want to remove $targetName from "${ws.name}"? They will lose access to shared expenses and budgets.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    final auth = context.read<AuthController>();
    final wsController = context.read<WorkspaceController>();

    setState(() => _isProcessing = true);
    final success = await wsController.removeMember(
      targetUserId: targetUserId,
      callerUserId: auth.uid,
      callerName: auth.displayName,
    );
    if (!mounted) return;
    setState(() => _isProcessing = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$targetName removed from workspace'),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      final err = wsController.errorMessage ?? 'Failed to remove member';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _handleLeaveWorkspace(Workspace ws) async {
    final auth = context.read<AuthController>();
    final wsController = context.read<WorkspaceController>();
    final isOwner = ws.isOwner(auth.uid);
    final otherMembers = ws.memberIds.where((id) => id != auth.uid).toList();

    String? transferOwnerId;

    if (isOwner && otherMembers.isNotEmpty) {
      // Must prompt to transfer ownership or auto-transfer
      transferOwnerId = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Transfer Ownership', style: TextStyle(color: AppColors.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'As the owner, you must choose a new owner before leaving:',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 12),
              ...otherMembers.map((mId) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(ws.getMemberName(mId), style: const TextStyle(color: AppColors.textPrimary)),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textMuted),
                    onTap: () => Navigator.of(ctx).pop(mId),
                  )),
            ],
          ),
        ),
      );

      if (transferOwnerId == null) return;
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Leave Workspace?', style: TextStyle(color: AppColors.textPrimary)),
          content: Text(
            'Are you sure you want to leave "${ws.name}"?',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Leave', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
    }

    setState(() => _isProcessing = true);
    final success = await wsController.leaveWorkspace(
      userId: auth.uid,
      userName: auth.displayName,
      transferOwnerId: transferOwnerId,
    );
    if (!mounted) return;
    setState(() => _isProcessing = false);

    if (success) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Left "${ws.name}"'),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      final err = wsController.errorMessage ?? 'Failed to leave workspace';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: AppColors.error),
      );
    }
  }

  Color _getRoleBadgeColor(String role) {
    switch (role) {
      case WorkspaceRole.owner:
        return AppColors.warning;
      case WorkspaceRole.admin:
        return AppColors.primaryLight;
      default:
        return AppColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final ws = context.watch<WorkspaceController>().currentWorkspace;

    if (ws == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Members')),
        body: const Center(child: Text('No active workspace selected', style: TextStyle(color: AppColors.textMuted))),
      );
    }

    final canManage = ws.canManageMembers(auth.uid);
    final isOwner = ws.isOwner(auth.uid);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Workspace Members', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Invite Banner
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primaryDark, AppColors.surfaceElevated],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        ws.name,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          '${ws.memberCount} / ${ws.maxMembers} Members',
                          style: const TextStyle(
                            color: AppColors.primaryLight,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Invite Code',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: Text(
                          ws.inviteCode,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2.0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton.filled(
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => _copyInviteCode(ws.inviteCode),
                        tooltip: 'Copy Invite Code',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Members Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Active Members',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${ws.memberCount} total',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Member Cards List
            ...ws.memberIds.map((memberId) {
              final name = ws.getMemberName(memberId);
              final role = ws.getRole(memberId);
              final isMe = memberId == auth.uid;
              final memberIsOwner = ws.isOwner(memberId);

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Row(
                  children: [
                    // Avatar Circle
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: isMe ? AppColors.primary : AppColors.surfaceElevated,
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: TextStyle(
                          color: isMe ? Colors.white : AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Name and info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  name,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isMe) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'YOU',
                                    style: TextStyle(
                                      color: AppColors.primaryLight,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getRoleBadgeColor(role).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              role,
                              style: TextStyle(
                                color: _getRoleBadgeColor(role),
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Management actions
                    if (canManage && !isMe) ...[
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert_rounded, color: AppColors.textMuted),
                        color: AppColors.surfaceElevated,
                        onSelected: (val) {
                          if (val == 'role') {
                            _handleRoleChange(ws, memberId, role);
                          } else if (val == 'remove') {
                            _handleRemoveMember(ws, memberId);
                          }
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(
                            value: 'role',
                            child: Row(
                              children: [
                                Icon(Icons.admin_panel_settings_rounded, size: 18, color: AppColors.primaryLight),
                                SizedBox(width: 10),
                                Text('Change Role', style: TextStyle(color: AppColors.textPrimary)),
                              ],
                            ),
                          ),
                          if (!memberIsOwner || isOwner)
                            const PopupMenuItem(
                              value: 'remove',
                              child: Row(
                                children: [
                                  Icon(Icons.person_remove_rounded, size: 18, color: AppColors.error),
                                  SizedBox(width: 10),
                                  Text('Remove Member', style: TextStyle(color: AppColors.error)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            }),

            const SizedBox(height: 24),

            // Leave Workspace Button
            OutlinedButton.icon(
              icon: const Icon(Icons.logout_rounded, color: AppColors.error),
              label: Text(
                isOwner && ws.memberCount == 1 ? 'Delete & Close Workspace' : 'Leave Workspace',
                style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.error),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isProcessing ? null : () => _handleLeaveWorkspace(ws),
            ),
          ],
        ),
      ),
    );
  }
}
