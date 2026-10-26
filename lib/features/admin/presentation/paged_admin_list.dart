import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/util/callable_error.dart';
import '../data/admin_tools_repository.dart';

/// A list that loads [AdminPage]s on demand with a Load more button. Changing
/// [queryKey] starts again from the first page; a page that arrives for an
/// older query is dropped.
class PagedAdminList<T> extends StatefulWidget {
  const PagedAdminList({
    super.key,
    required this.queryKey,
    required this.load,
    required this.itemBuilder,
    required this.emptyText,
  });

  final Object queryKey;
  final Future<AdminPage<T>> Function(Object? cursor) load;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final String emptyText;

  @override
  State<PagedAdminList<T>> createState() => _PagedAdminListState<T>();
}

class _PagedAdminListState<T> extends State<PagedAdminList<T>> {
  final _items = <T>[];
  Object? _cursor;
  bool _hasMore = true;
  bool _loading = false;
  Object? _error;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _loadMore();
  }

  @override
  void didUpdateWidget(PagedAdminList<T> old) {
    super.didUpdateWidget(old);
    if (old.queryKey != widget.queryKey) {
      _generation++;
      _items.clear();
      _cursor = null;
      _hasMore = true;
      _loading = false;
      _error = null;
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    final generation = _generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await widget.load(_cursor);
      if (!mounted || generation != _generation) return;
      setState(() {
        _items.addAll(page.items);
        _cursor = page.cursor;
        _hasMore = page.hasMore;
      });
    } catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() => _error = e);
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty && _loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_items.isEmpty && _error != null) {
      return _Centered('Could not load.\n${callableErrorMessage(_error!)}');
    }
    if (_items.isEmpty) return _Centered(widget.emptyText);

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _items.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        if (i < _items.length) return widget.itemBuilder(context, _items[i]);
        if (_loading) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (_error != null) {
          return TextButton(
              onPressed: _loadMore, child: const Text('Retry'));
        }
        return _hasMore
            ? OutlinedButton(
                onPressed: _loadMore, child: const Text('Load more'))
            : const SizedBox.shrink();
      },
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered(this.text);
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
