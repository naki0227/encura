import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// One way to support the developer: a consumable In-App Purchase that
/// unlocks nothing (App Store Review Guideline 3.1.1 allows tips this way).
class TipOption {
  final String productId;
  final int yen;
  final String title;

  const TipOption(this.productId, this.yen, this.title);

  /// "¥1,000" — shown until the App Store's own price string arrives.
  String get fallbackPrice {
    final digits = yen.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
    return '¥$digits';
  }
}

const tipOptions = [
  TipOption('com.enludus.encura.tip.100', 100, 'ちょっと応援'),
  TipOption('com.enludus.encura.tip.1000', 1000, 'しっかり応援'),
  TipOption('com.enludus.encura.tip.10000', 10000, 'たっぷり応援'),
];

enum TipStatus { idle, purchasing, thanks, failed }

/// Tips through the App Store. Started once at launch so a purchase that
/// finished while the app was closed is still completed (Apple asks apps to
/// finish every transaction).
class TipStore extends ChangeNotifier {
  TipStore._();

  static final instance = TipStore._();

  InAppPurchase get _iap => InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchases;

  bool available = false;
  bool loaded = false;
  Map<String, ProductDetails> products = {};
  TipStatus status = TipStatus.idle;
  String? pendingProduct;
  String? message;

  void start() {
    if (kIsWeb || _purchases != null) return;
    _purchases = _iap.purchaseStream.listen(_onPurchases, onError: (Object _) {});
  }

  Future<void> load() async {
    if (kIsWeb) {
      loaded = true;
      notifyListeners();
      return;
    }
    try {
      available = await _iap.isAvailable();
      if (available) {
        final found = await _iap.queryProductDetails({for (final o in tipOptions) o.productId});
        products = {for (final p in found.productDetails) p.id: p};
      }
    } catch (_) {
      available = false;
    }
    loaded = true;
    notifyListeners();
  }

  /// The App Store's price ("¥1,000"), or the yen amount before it loads.
  String priceOf(TipOption option) => products[option.productId]?.price ?? option.fallbackPrice;

  bool canBuy(TipOption option) => available && products.containsKey(option.productId) && status != TipStatus.purchasing;

  Future<void> buy(TipOption option) async {
    final product = products[option.productId];
    if (product == null) return;
    status = TipStatus.purchasing;
    pendingProduct = option.productId;
    message = null;
    notifyListeners();
    try {
      final started = await _iap.buyConsumable(purchaseParam: PurchaseParam(productDetails: product));
      if (!started) _fail('購入を始められませんでした。');
    } catch (_) {
      _fail('購入を始められませんでした。');
    }
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      switch (p.status) {
        case PurchaseStatus.pending:
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          status = TipStatus.thanks;
          pendingProduct = null;
        case PurchaseStatus.canceled:
          status = TipStatus.idle;
          pendingProduct = null;
        case PurchaseStatus.error:
          _fail('購入できませんでした。時間をおいてもう一度お試しください。');
      }
      if (p.pendingCompletePurchase) {
        await _iap.completePurchase(p);
      }
    }
    notifyListeners();
  }

  void _fail(String text) {
    status = TipStatus.failed;
    pendingProduct = null;
    message = text;
    notifyListeners();
  }

  /// Back to the list after a thank-you or an error.
  void reset() {
    status = TipStatus.idle;
    message = null;
    notifyListeners();
  }
}
