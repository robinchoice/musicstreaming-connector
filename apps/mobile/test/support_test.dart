import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:musiclink/config.dart';
import 'package:musiclink/core/locale.dart';
import 'package:musiclink/core/messages.dart';
import 'package:musiclink/features/support/support_screen.dart';

class FakeStore implements InAppPurchase {
  FakeStore({this.available = true});
  final bool available;
  final purchases = StreamController<List<PurchaseDetails>>.broadcast();
  final bought = <String>[];
  final completed = <String>[];

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => purchases.stream;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<ProductDetailsResponse> queryProductDetails(
    Set<String> identifiers,
  ) async => ProductDetailsResponse(
    productDetails: [
      // Out of order, the screen sorts them
      for (final (id, price) in [
        (supportProducts[2], '9,99 €'),
        (supportProducts[0], '0,99 €'),
        (supportProducts[1], '4,19 €'),
      ])
        ProductDetails(
          id: id,
          title: id,
          description: '',
          price: price,
          rawPrice: 0,
          currencyCode: 'EUR',
        ),
    ],
    notFoundIDs: [],
  );

  @override
  Future<bool> buyConsumable({
    required PurchaseParam purchaseParam,
    bool autoConsume = true,
  }) async {
    bought.add(purchaseParam.productDetails.id);
    return true;
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    completed.add(purchase.productID);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Future<void> mount(WidgetTester tester, FakeStore store) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storeProvider.overrideWithValue(store),
          messagesProvider.overrideWithValue(const De()),
        ],
        child: const MaterialApp(home: SupportScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lists the three tiers and thanks after a purchase', (
    tester,
  ) async {
    final store = FakeStore();
    await mount(tester, store);
    final names = tester
        .widgetList<Text>(find.textContaining('Ein'))
        .map((t) => t.data)
        .where((d) => d!.length < 15)
        .toList();
    expect(names, ['Ein Song', 'Eine Single', 'Ein Album']);
    expect(find.text('4,19 €'), findsOneWidget);

    await tester.tap(find.text('Eine Single'));
    await tester.pump();
    expect(store.bought, [supportProducts[1]]);

    store.purchases.add([
      PurchaseDetails(
        productID: supportProducts[1],
        verificationData: PurchaseVerificationData(
          localVerificationData: '',
          serverVerificationData: '',
          source: 'test',
        ),
        transactionDate: null,
        status: PurchaseStatus.purchased,
      )..pendingCompletePurchase = true,
    ]);
    await tester.pumpAndSettle();
    expect(store.completed, [supportProducts[1]]);
    expect(find.text('Danke für deine Unterstützung!'), findsOneWidget);
  });

  testWidgets('says so quietly when the store is unavailable', (tester) async {
    await mount(tester, FakeStore(available: false));
    expect(find.textContaining('Store ist gerade nicht erreichbar'), findsOne);
    expect(find.byType(OutlinedButton), findsNothing);
  });
}
