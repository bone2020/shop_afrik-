import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/staff_member.dart';
import '../../../core/models/user_role.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/util/callable_error.dart';
import '../../../services/session_controller.dart';
import '../data/admin_tools_repository.dart';

/// The roles a supervisor can hand out here. Sellers come through the
/// application and approval flow instead.
enum StaffRoleChoice {
  buyer('No staff role', 'buyer', null),
  courier('Courier', 'delivery', null),
  admin('Admin', 'admin', 'admin'),
  supervisor('Supervisor', 'admin', 'supervisor');

  const StaffRoleChoice(this.label, this.role, this.adminTier);
  final String label;
  final String role;
  final String? adminTier;

  static StaffRoleChoice? of(String role, String? adminTier) {
    for (final c in values) {
      if (c.role == role && (c.adminTier == null || c.adminTier == adminTier)) {
        return c;
      }
    }
    return null;
  }
}

/// Find a user and grant or revoke courier, admin and supervisor roles
/// (SA-132). Any admin can look people up; only a supervisor can change roles,
/// and nobody can change their own. Every change is audited server-side.
class UsersRolesTab extends ConsumerStatefulWidget {
  const UsersRolesTab({super.key});

  @override
  ConsumerState<UsersRolesTab> createState() => _UsersRolesTabState();
}

class _UsersRolesTabState extends ConsumerState<UsersRolesTab> {
  final _query = TextEditingController();
  FoundUser? _user;
  String? _message;
  bool _searching = false;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _query.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _searching = true;
      _message = null;
    });
    try {
      final user = await ref.read(adminToolsRepositoryProvider).findUser(q);
      setState(() {
        _user = user;
        _message = user == null ? 'No account matches "$q".' : null;
      });
    } catch (e) {
      setState(() => _message = callableErrorMessage(e));
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _pick(StaffMember m) => setState(() {
        _message = null;
        _user = FoundUser(
          uid: m.uid,
          role: m.role,
          adminTier: m.adminTier,
          email: m.email,
          phone: m.phone,
          displayName: m.displayName,
        );
      });

  @override
  Widget build(BuildContext context) {
    final staff = ref.watch(staffProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _query,
                decoration: const InputDecoration(
                  labelText: 'Email, phone (+233...) or user id',
                ),
                onSubmitted: (_) => _search(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: 'Find',
              onPressed: _searching ? null : _search,
              icon: const Icon(Icons.search),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_searching) const LinearProgressIndicator(),
        if (_message != null)
          Text(_message!, style: const TextStyle(color: AppColors.mutedText)),
        if (_user != null)
          _UserCard(
            key: ValueKey('${_user!.uid}/${_user!.role}/${_user!.adminTier}'),
            user: _user!,
            onChanged: (u) => setState(() => _user = u),
          ),
        const SizedBox(height: 20),
        Text('Staff', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        staff.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Could not load staff.\n$e'),
          data: (list) {
            if (list.isEmpty) {
              return const Text('No staff yet.',
                  style: TextStyle(color: AppColors.mutedText));
            }
            final sorted = [...list]..sort((a, b) {
                final byRole = _rank(a).compareTo(_rank(b));
                return byRole != 0 ? byRole : a.label.compareTo(b.label);
              });
            return Column(
              children: [
                for (final m in sorted)
                  Card(
                    child: ListTile(
                      title: Text(m.label),
                      subtitle: Text(
                          StaffRoleChoice.of(m.role, m.adminTier)?.label ??
                              m.role),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _pick(m),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  static int _rank(StaffMember m) =>
      StaffRoleChoice.of(m.role, m.adminTier) == StaffRoleChoice.supervisor
          ? 0
          : m.role == 'admin'
              ? 1
              : 2;
}

class _UserCard extends ConsumerStatefulWidget {
  const _UserCard({super.key, required this.user, required this.onChanged});
  final FoundUser user;
  final ValueChanged<FoundUser> onChanged;

  @override
  ConsumerState<_UserCard> createState() => _UserCardState();
}

class _UserCardState extends ConsumerState<_UserCard> {
  late StaffRoleChoice? _choice =
      StaffRoleChoice.of(widget.user.role, widget.user.adminTier);
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    final session = ref.watch(sessionControllerProvider);
    final isSupervisor = session.adminTier == AdminTier.supervisor;
    final isSelf = session.uid == u.uid;
    final current = StaffRoleChoice.of(u.role, u.adminTier);
    final isSeller = u.role == 'seller';

    String? blocker;
    if (!isSupervisor) {
      blocker = 'Only a supervisor can change roles.';
    } else if (isSelf) {
      blocker = 'You cannot change your own role.';
    } else if (isSeller) {
      blocker = 'This account is a seller. Suspend the store from the '
          'Sellers tab instead.';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(u.label,
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 4),
            Text(
              [u.email, u.phone, u.uid].whereType<String>().join(' · '),
              style: const TextStyle(color: AppColors.mutedText, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
                'Current role: ${isSeller ? 'Seller' : current?.label ?? u.role}'
                '${u.disabled ? ' (account disabled)' : ''}'),
            const SizedBox(height: 12),
            if (blocker != null)
              Text(blocker, style: const TextStyle(color: AppColors.mutedText))
            else
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<StaffRoleChoice>(
                      initialValue: _choice,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Role'),
                      items: [
                        for (final c in StaffRoleChoice.values)
                          DropdownMenuItem(value: c, child: Text(c.label)),
                      ],
                      onChanged: (c) => setState(() => _choice = c),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // The theme makes buttons full-width; a Row needs a bound.
                  SizedBox(
                    width: 110,
                    child: ElevatedButton(
                      onPressed:
                          _saving || _choice == null || _choice == current
                              ? null
                              : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Save'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final c = _choice!;
    setState(() => _saving = true);
    try {
      await ref.read(adminToolsRepositoryProvider).setUserRole(
          uid: widget.user.uid, role: c.role, adminTier: c.adminTier);
      final u = widget.user;
      widget.onChanged(FoundUser(
        uid: u.uid,
        role: c.role,
        adminTier: c.adminTier,
        email: u.email,
        phone: u.phone,
        displayName: u.displayName,
        disabled: u.disabled,
      ));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('${u.label} is now: ${c.label}. It takes effect '
                'when they next sign in, or within an hour.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(callableErrorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
