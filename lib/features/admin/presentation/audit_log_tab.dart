import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/admin_audit_entry.dart';
import '../../../core/theme/app_colors.dart';
import '../data/admin_tools_repository.dart';
import 'paged_admin_list.dart';

enum _AuditField {
  all('Everything'),
  actor('By who'),
  target('About (id)'),
  action('Action');

  const _AuditField(this.label);
  final String label;
}

/// Read-only audit log, newest first (SA-135). Filter by who acted, what
/// they acted on, or the action name, e.g. `settings.updated`.
class AuditLogTab extends ConsumerStatefulWidget {
  const AuditLogTab({super.key});

  @override
  ConsumerState<AuditLogTab> createState() => _AuditLogTabState();
}

class _AuditLogTabState extends ConsumerState<AuditLogTab> {
  final _value = TextEditingController();
  _AuditField _field = _AuditField.all;
  AuditFilter _filter = const AuditFilter();

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  void _apply() {
    final v = _value.text.trim();
    setState(() {
      _filter = v.isEmpty
          ? const AuditFilter()
          : switch (_field) {
              _AuditField.all => const AuditFilter(),
              _AuditField.actor => AuditFilter(actorId: v),
              _AuditField.target => AuditFilter(targetId: v),
              _AuditField.action => AuditFilter(action: v),
            };
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            children: [
              DropdownButton<_AuditField>(
                value: _field,
                items: [
                  for (final f in _AuditField.values)
                    DropdownMenuItem(value: f, child: Text(f.label)),
                ],
                onChanged: (f) {
                  setState(() => _field = f!);
                  _apply();
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _value,
                  enabled: _field != _AuditField.all,
                  decoration: InputDecoration(
                    labelText: switch (_field) {
                      _AuditField.all => 'Showing every entry',
                      _AuditField.actor => 'User id (or "system")',
                      _AuditField.target => 'Order, seller, user or refund id',
                      _AuditField.action => 'e.g. seller.suspended',
                    },
                  ),
                  onSubmitted: (_) => _apply(),
                ),
              ),
              IconButton(
                tooltip: 'Filter',
                onPressed: _apply,
                icon: const Icon(Icons.filter_alt),
              ),
            ],
          ),
        ),
        Expanded(
          child: PagedAdminList<AdminAuditEntry>(
            queryKey: _filter,
            load: (cursor) => ref
                .read(adminToolsRepositoryProvider)
                .fetchAudit(_filter, cursor: cursor),
            itemBuilder: (_, e) => _AuditCard(entry: e),
            emptyText: 'No audit entries match.',
          ),
        ),
      ],
    );
  }
}

class _AuditCard extends StatelessWidget {
  const _AuditCard({required this.entry});
  final AdminAuditEntry entry;

  @override
  Widget build(BuildContext context) {
    final e = entry;
    const muted = TextStyle(color: AppColors.mutedText, fontSize: 13);
    final when = e.createdAt?.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');

    return Card(
      child: ExpansionTile(
        title: Text(e.action,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          [
            'by ${e.actorId}',
            if (e.targetId != null) '${e.targetType ?? 'on'} ${e.targetId}',
            if (when != null)
              '${when.year}-${two(when.month)}-${two(when.day)} '
                  '${two(when.hour)}:${two(when.minute)}',
          ].join(' · '),
          style: muted,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (e.metadata.isEmpty)
            const Text('No details.', style: muted)
          else
            for (final m in e.metadata.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('${m.key}: ${m.value}', style: muted),
              ),
        ],
      ),
    );
  }
}
