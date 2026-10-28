import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../config.dart';
import '../../core/locale.dart';
import '../../core/messages.dart';

final storeProvider = Provider<InAppPurchase>((ref) => InAppPurchase.instance);

/// Voluntary one-off purchases that unlock nothing. Consumable, so a supporter
/// may give again, and there is nothing to restore.
class SupportScreen extends ConsumerStatefulWidget {
  const SupportScreen({super.key});
  @override
  ConsumerState<SupportScreen> createState() => _SupportScreenState();
}

enum _State { loading, ready, unavailable, buying, thanks }

class _SupportScreenState extends ConsumerState<SupportScreen> {
  late final InAppPurchase _store = ref.read(storeProvider);
  StreamSubscription<List<PurchaseDetails>>? _purchases;
  List<ProductDetails> _products = [];
  var _state = _State.loading;
  var _failed = false;

  @override
  void initState() {
    super.initState();
    _purchases = _store.purchaseStream.listen(_onPurchases);
    _load();
  }

  @override
  void dispose() {
    _purchases?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    var products = <ProductDetails>[];
    try {
      if (await _store.isAvailable()) {
        products = (await _store.queryProductDetails(supportProducts.toSet()))
            .productDetails;
      }
    } catch (_) {}
    products.sort(
      (a, b) => supportProducts
          .indexOf(a.id)
          .compareTo(supportProducts.indexOf(b.id)),
    );
    if (!mounted) return;
    setState(() {
      _products = products;
      _state = products.isEmpty ? _State.unavailable : _State.ready;
    });
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.pending) continue;
      if (purchase.pendingCompletePurchase) {
        await _store.completePurchase(purchase);
      }
      if (!mounted) continue;
      setState(() {
        switch (purchase.status) {
          case PurchaseStatus.purchased || PurchaseStatus.restored:
            _state = _State.thanks;
          case PurchaseStatus.error:
            _failed = true;
            _state = _State.ready;
          case PurchaseStatus.canceled || PurchaseStatus.pending:
            _state = _State.ready;
        }
      });
    }
  }

  Future<void> _buy(ProductDetails product) async {
    setState(() {
      _failed = false;
      _state = _State.buying;
    });
    try {
      await _store.buyConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _failed = true;
          _state = _State.ready;
        });
      }
    }
  }

  String _name(Messages t, String id) => switch (supportProducts.indexOf(id)) {
    0 => t.supportSong,
    1 => t.supportSingle,
    _ => t.supportAlbum,
  };

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(messagesProvider);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.support)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(t.supportIntro(appName), style: theme.textTheme.bodyLarge),
            const SizedBox(height: 24),
            switch (_state) {
              _State.loading => const Center(
                child: CircularProgressIndicator(),
              ),
              _State.unavailable => Text(
                t.supportUnavailable,
                style: theme.textTheme.bodyMedium,
              ),
              _State.thanks => Text(
                t.supportThanks,
                style: theme.textTheme.titleMedium,
              ),
              _State.ready || _State.buying => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final product in _products)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: OutlinedButton(
                        onPressed: _state == _State.buying
                            ? null
                            : () => _buy(product),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            children: [
                              Expanded(child: Text(_name(t, product.id))),
                              Text(product.price),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (_failed)
                    Text(t.supportFailed, style: theme.textTheme.bodyMedium),
                ],
              ),
            },
          ],
        ),
      ),
    );
  }
}
