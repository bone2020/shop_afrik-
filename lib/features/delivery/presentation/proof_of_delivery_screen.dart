import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/order.dart';
import '../../../core/theme/app_colors.dart';
import '../data/delivery_repository.dart';

/// Proof-of-delivery capture (v2 delivery flow). The delivery person scans the
/// package barcode and submits a photo, GPS location, and timestamp; submitting
/// marks the order delivered.
///
/// Hardware capture (camera scanner, auto-GPS, photo upload) is wired on-device
/// later — the same way product image upload is staged. The barcode, photo URL,
/// and coordinates are captured here and the timestamp is set server-side.
class ProofOfDeliveryScreen extends ConsumerStatefulWidget {
  const ProofOfDeliveryScreen({super.key, required this.order});

  final ShopOrder order;

  @override
  ConsumerState<ProofOfDeliveryScreen> createState() =>
      _ProofOfDeliveryScreenState();
}

class _ProofOfDeliveryScreenState extends ConsumerState<ProofOfDeliveryScreen> {
  final _barcode = TextEditingController();
  final _photoUrl = TextEditingController();
  final _lat = TextEditingController();
  final _lng = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _barcode.dispose();
    _photoUrl.dispose();
    _lat.dispose();
    _lng.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Confirm delivery')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Scan the package barcode, capture a photo and the drop-off '
            'location, then submit. This marks the order delivered.',
            style: TextStyle(color: AppColors.mutedText),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _barcode,
            decoration: InputDecoration(
              labelText: 'Package barcode',
              suffixIcon: IconButton(
                tooltip: 'Scan',
                icon: const Icon(Icons.qr_code_scanner),
                // On-device this opens the camera scanner; here it fills the
                // scanned value so the flow can be exercised end to end.
                onPressed: () => _barcode.text = widget.order.id,
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _photoUrl,
            decoration:
                const InputDecoration(labelText: 'Proof photo URL'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _lat,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true, signed: true),
                  decoration: const InputDecoration(labelText: 'Latitude'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _lng,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true, signed: true),
                  decoration: const InputDecoration(labelText: 'Longitude'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Submit proof & mark delivered'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final barcode = _barcode.text.trim();
    if (barcode.isEmpty) {
      _snack('Scan or enter the package barcode first.');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(deliveryRepositoryProvider).submitProof(
            orderId: widget.order.id,
            barcode: barcode,
            photoUrl: _photoUrl.text.trim().isEmpty ? null : _photoUrl.text.trim(),
            latitude: double.tryParse(_lat.text.trim()),
            longitude: double.tryParse(_lng.text.trim()),
          );
      if (!mounted) return;
      _snack('Delivery confirmed.');
      Navigator.of(context).pop();
    } catch (e) {
      _snack('Could not submit: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
