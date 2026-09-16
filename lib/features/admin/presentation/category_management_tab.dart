import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/category.dart';
import '../../../core/theme/app_colors.dart';
import '../data/category_repository.dart';

/// Admin category management: list categories and add/edit them.
class CategoryManagementTab extends ConsumerWidget {
  const CategoryManagementTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(allCategoriesProvider);

    return Scaffold(
      body: categories.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Message('Could not load categories.\n$e'),
        data: (items) => items.isEmpty
            ? const _Message('No categories yet. Tap + to add one.')
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: AppColors.divider),
                itemBuilder: (_, i) {
                  final c = items[i];
                  return ListTile(
                    title: Text(c.name),
                    subtitle: Text(c.isActive ? 'Active' : 'Hidden'),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _edit(context, ref, c),
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _edit(context, ref, null),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _edit(
      BuildContext context, WidgetRef ref, Category? existing) async {
    final result = await showDialog<({String name, int sortOrder, bool active})>(
      context: context,
      builder: (_) => _CategoryDialog(existing: existing),
    );
    if (result == null) return;

    final repo = ref.read(categoryRepositoryProvider);
    if (existing == null) {
      await repo.create(Category(
        id: '',
        name: result.name,
        sortOrder: result.sortOrder,
        isActive: result.active,
      ));
    } else {
      await repo.update(Category(
        id: existing.id,
        name: result.name,
        parentId: existing.parentId,
        iconName: existing.iconName,
        sortOrder: result.sortOrder,
        isActive: result.active,
      ));
    }
  }
}

class _CategoryDialog extends StatefulWidget {
  const _CategoryDialog({this.existing});
  final Category? existing;

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  late final TextEditingController _name =
      TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController _sort = TextEditingController(
      text: (widget.existing?.sortOrder ?? 0).toString());
  late bool _active = widget.existing?.isActive ?? true;

  @override
  void dispose() {
    _name.dispose();
    _sort.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'New category' : 'Edit category'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          TextField(
            controller: _sort,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Sort order'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Active'),
            value: _active,
            onChanged: (v) => setState(() => _active = v),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_name.text.trim().isEmpty) return;
            Navigator.of(context).pop((
              name: _name.text.trim(),
              sortOrder: int.tryParse(_sort.text.trim()) ?? 0,
              active: _active,
            ));
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.mutedText)),
        ),
      );
}
