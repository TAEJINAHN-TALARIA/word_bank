import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:purchases_flutter/purchases_flutter.dart';
import 'api_client.dart';
import 'auth_service.dart';

class SubscriptionService {
  static const String _entitlementId = 'premium';
  static const String monthlyProductId = 'word_bank_premium_monthly';
  static const int freeLimit = 50;

  // TODO: 배포 전 RevenueCat 대시보드에서 발급받은 실제 API 키로 교체
  static const String _iosApiKey = 'test_AAKutdApjufivhgOwuVxPTQjVsQ';
  static const String _androidApiKey = 'test_AAKutdApjufivhgOwuVxPTQjVsQ';

  static bool _isPremium = false;
  static int _monthlyCount = 0;

  static bool get isPremium => _isPremium;
  static int get monthlyCount => _monthlyCount;
  static int get remaining =>
      _isPremium ? -1 : (freeLimit - _monthlyCount).clamp(0, freeLimit);

  static Future<void> initialize() async {
    if (kDebugMode) {
      await Purchases.setLogLevel(LogLevel.debug);
    }

    final apiKey = defaultTargetPlatform == TargetPlatform.iOS
        ? _iosApiKey
        : _androidApiKey;

    await Purchases.configure(PurchasesConfiguration(apiKey));

    // Firebase 사용자 ID를 RevenueCat에 연결 (구독 상태 동기화)
    final userId = AuthService.currentUser?.uid;
    if (userId != null) {
      await Purchases.logIn(userId);
    }

    await refreshStatus();
  }

  /// 구독 상태(RevenueCat)와 월별 사용량(백엔드)을 동시에 새로고침합니다.
  static Future<void> refreshStatus() async {
    await Future.wait([
      _refreshPremiumStatus(),
      _refreshUsageCount(),
    ]);
  }

  static Future<void> _refreshPremiumStatus() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      _isPremium = customerInfo.entitlements.active.containsKey(_entitlementId);
    } catch (e) {
      debugPrint('RevenueCat getCustomerInfo failed: $e');
    }
  }

  static Future<void> _refreshUsageCount() async {
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
        _monthlyCount = data['count'] as int? ?? 0;
      }
    } catch (e) {
      debugPrint('Failed to refresh usage count: $e');
    }
  }

  static Future<void> purchase() async {
    final offerings = await Purchases.getOfferings();
    final package = offerings.current?.monthly;
    if (package == null) {
      throw Exception('구매 가능한 상품을 찾을 수 없습니다.');
    }
    final customerInfo = await Purchases.purchasePackage(package);
    _isPremium = customerInfo.entitlements.active.containsKey(_entitlementId);
  }

  static Future<void> restorePurchases() async {
    final customerInfo = await Purchases.restorePurchases();
    _isPremium = customerInfo.entitlements.active.containsKey(_entitlementId);
  }
}
