import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_purchase/in_app_purchase.dart';
import 'api_client.dart';
import 'auth_service.dart';

class SubscriptionService {
  static const String monthlyProductId = 'word_bank_premium_monthly';
  static const int freeLimit = 50;

  static StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  static bool _isPremium = false;
  static int _monthlyCount = 0;

  static bool get isPremium => _isPremium;
  static int get monthlyCount => _monthlyCount;
  static int get remaining =>
      _isPremium ? -1 : (freeLimit - _monthlyCount).clamp(0, freeLimit);

  static Future<void> initialize() async {
    final isAvailable = await InAppPurchase.instance.isAvailable();
    if (!isAvailable) {
      debugPrint('In-App Purchase not available on this device');
      return;
    }

    _purchaseSubscription = InAppPurchase.instance.purchaseStream.listen(
      _handlePurchaseUpdate,
      onDone: () => _purchaseSubscription?.cancel(),
      onError: (Object error) => debugPrint('IAP stream error: $error'),
    );

    await refreshStatus();
  }

  /// 서버에서 현재 사용량 및 구독 상태를 새로고침합니다.
  static Future<void> refreshStatus() async {
    final token = await AuthService.getIdToken();
    if (token == null) return;

    try {
      final uri = Uri.parse('$kBackendBaseUrl/api/usage');
      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _isPremium = data['isPremium'] as bool? ?? false;
        _monthlyCount = data['count'] as int? ?? 0;
      }
    } catch (e) {
      debugPrint('Failed to refresh subscription status: $e');
    }
  }

  static Future<void> purchase() async {
    final result = await InAppPurchase.instance
        .queryProductDetails({monthlyProductId});
    if (result.productDetails.isEmpty) {
      throw Exception('Product "$monthlyProductId" not found in store');
    }
    final purchaseParam = PurchaseParam(
      productDetails: result.productDetails.first,
    );
    await InAppPurchase.instance.buyNonConsumable(
      purchaseParam: purchaseParam,
    );
  }

  static Future<void> restorePurchases() async {
    await InAppPurchase.instance.restorePurchases();
  }

  static Future<void> _handlePurchaseUpdate(
    List<PurchaseDetails> purchases,
  ) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        await _verifyAndActivate(purchase);
        await InAppPurchase.instance.completePurchase(purchase);
      } else if (purchase.status == PurchaseStatus.error) {
        debugPrint('Purchase error: ${purchase.error}');
      }
    }
  }

  static Future<void> _verifyAndActivate(PurchaseDetails purchase) async {
    final token = await AuthService.getIdToken();
    if (token == null) return;

    try {
      final uri = Uri.parse('$kBackendBaseUrl/api/verify-purchase');
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'platform': Platform.isIOS ? 'ios' : 'android',
          'receiptData': purchase.verificationData.serverVerificationData,
          'productId': purchase.productID,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        _isPremium = true;
        _monthlyCount = 0;
      }
    } catch (e) {
      debugPrint('Purchase verification failed: $e');
    }
  }

  static void dispose() {
    _purchaseSubscription?.cancel();
  }
}
