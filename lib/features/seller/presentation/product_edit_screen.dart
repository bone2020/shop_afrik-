import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/platform_settings_repository.dart';
import '../../../core/models/category.dart';
import '../../../core/models/money.dart';
import '../../../core/models/platform_settings.dart';
import '../../../core/models/product.dart';
import '../../../core/theme/app_colors.dart';
import '../../../services/session_controller.dart';
import '../../buyer/data/catalog_repository.dart';
import '../data/seller_products_repository.dart';
import '../data/seller_repository.dart';

/// Add or edit a product. New products always start pending admin approval.
/// The price is denominated in the seller's market currency (config-driven).
class ProductEditScreen extends ConsumerStatefulWidget {
  const ProductEditScreen({super.key, this.productId});

  final String? productId;

  bool get isEditing => productId != null;

  @override
  ConsumerState<ProductEditScreen> createState() => _ProductEditScreenState();
}

class _ProductEditScreenState extends ConsumerState<ProductEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _price = TextEditingController();
  final _stock = TextEditingController();
  final _imageUrl = TextEditingController();
  String? _categoryId;
  bool _initialized = false;
  bool _saving = false;
  Product? _existing;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _price.dispose();
    _stock.dispose();
    _imageUrl.dispose();
    super.dispose();
  }

  void _prefill(Product p) {
    _existing = p;
    _title.text = p.title;
    _description.text = p.description;
    _price.text = p.price.major.toString();
    _stock.text = p.stock.toString();
    _imageUrl.text = p.images.isNotEmpty ? p.images.first : '';
    _categoryId = p.categoryId;
    _initialized = true;
  }

  /// Currency the price is entered in: the existing product's, or the seller's
  /// market currency (from config).
  String? _resolveCurrency(PlatformSettings settings, String? sellerMarket) {
    if (_existing != null) return _existing!.price.currency;
    if (sellerMarket == null) return null;
    return settings.marketFor(sellerMarket)?.currency;
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);
    final settings = ref.watch(platformSettingsProvider).valueOrNull ??
        const PlatformSettings();
    final seller = ref.watch(currentSellerProvider).valueOrNull;
    final currency = _resolveCurrency(settings, seller?.market);

    // Prefill when editing and the product has loaded.
    if (widget.isEditing && !_initialized) {
      final product = ref.watch(productProvider(widget.productId!));
      return product.when(
        loading: () => _scaffold(const Center(child: CircularProgressIndicator())),
        error: (e, _) => _scaffold(Center(child: Text('$e'))),
        data: (p) {
          if (p == null) {
            return _scaffold(const Center(child: Text('Product not found.')));
          }
          _prefill(p);
          return _form(categories, currency);
        },
      );
    }

    return _form(categories, currency);
  }

  Widget _scaffold(Widget body) => Scaffold(
        appBar: AppBar(
            title: Text(widget.isEditing ? 'Edit product' : 'New product')),
        body: body,
      );

  Widget _form(AsyncValue<List<Category>> categories, String? currency) {
    return _scaffold(
      Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (currency == null)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'Your market currency is not configured yet, so pricing is '
                  'disabled. Contact an admin.',
                  style: TextStyle(color: AppColors.dangerCoral),
                ),
              ),
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Title'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _price,
              decoration: InputDecoration(
                labelText: 'Price',
                prefixText: currency == null ? null : '$currency ',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                final d = double.tryParse(v ?? '');
                if (d == null || d <= 0) return 'Enter a valid price';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _stock,
              decoration: const InputDecoration(labelText: 'Stock quantity'),
              keyboardType: TextInputType.number,
              validator: (v) {
                final n = int.tryParse(v ?? '');
                if (n == null || n < 0) return 'Enter a valid quantity';
                return null;
              },
            ),
            const SizedBox(height: 12),
            categories.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (cats) => DropdownButtonFormField<String>(
                // ignore: deprecated_member_use  // controlled by parent state
                value: _categoryId,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  for (final c in cats)
                    DropdownMenuItem(value: c.id, child: Text(c.name)),
                ],
                onChanged: (v) => setState(() => _categoryId = v),
                validator: (v) => v == null ? 'Choose a category' : null,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _imageUrl,
              decoration:
                  const InputDecoration(labelText: 'Image URL (optional)'),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: (currency == null || _saving)
                  ? null
                  : () => _save(currency),
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(widget.isEditing ? 'Save changes' : 'Create product'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save(String currency) async {
    if (!_formKey.currentState!.validate()) return;
    final uid = ref.read(sessionControllerProvider).uid;
    if (uid == null) return;

    final price = Money.fromMajor(double.parse(_price.text), currency);
    final stock = int.parse(_stock.text);
    final images = _imageUrl.text.trim().isEmpty ? <String>[] : [_imageUrl.text.trim()];
    final repo = ref.read(sellerProductsRepositoryProvider);

    setState(() => _saving = true);
    try {
      if (widget.isEditing && _existing != null) {
        final updated = Product(
          id: _existing!.id,
          sellerId: uid,
          title: _title.text.trim(),
          description: _description.text.trim(),
          price: price,
          categoryId: _categoryId!,
          images: images,
          stock: stock,
          initialStock: _existing!.initialStock,
          // Approval and ratings are not seller-editable (rules enforce this);
          // carry the existing values through unchanged.
          approvalStatus: _existing!.approvalStatus,
          isActive: _existing!.isActive,
          ratingAverage: _existing!.ratingAverage,
          ratingCount: _existing!.ratingCount,
        );
        await repo.update(updated);
      } else {
        final created = Product(
          id: '',
          sellerId: uid,
          title: _title.text.trim(),
          description: _description.text.trim(),
          price: price,
          categoryId: _categoryId!,
          images: images,
          stock: stock,
          initialStock: stock,
        );
        await repo.create(created);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
