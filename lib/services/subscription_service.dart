import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';
import 'auth_service.dart';

class SubscriptionService extends ChangeNotifier {
  static const String _entitlementId = 'premium';
  static const String monthlyProductId = 'word_bank_premium_monthly';
  static const int freeLimit = 50;
  static const String _premiumCacheKey = 'cached_is_premium';

  // TODO: 배포 전 RevenueCat 대시보드에서 발급받은 실제 API 키로 교체
  static const String _iosApiKey = 'test_AAKutdApjufivhgOwuVxPTQjVsQ';
  static const String _androidApiKey = 'test_AAKutdApjufivhgOwuVxPTQjVsQ';

  bool _isPremium = false;
  int _monthlyCount = 0;

  bool get isPremium => _isPremium;
  int get monthlyCount => _monthlyCount;
  int get remaining =>
      _isPremium ? -1 : (freeLimit - _monthlyCount).clamp(0, freeLimit);

  Future<void> initialize() async {
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
  Future<void> refreshStatus() async {
    await Future.wait([
      _refreshPremiumStatus(),
      _refreshUsageCount(),
    ]);
    notifyListeners();
  }

  Future<void> _refreshPremiumStatus() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      _isPremium = customerInfo.entitlements.active.containsKey(_entitlementId);
      // 성공 시 오프라인 캐시 저장
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_premiumCacheKey, _isPremium);
    } catch (e) {
      debugPrint('RevenueCat getCustomerInfo failed: $e');
      // 오프라인 시 캐시된 값 사용
      final prefs = await SharedPreferences.getInstance();
      _isPremium = prefs.getBool(_premiumCacheKey) ?? false;
    }
  }

  Future<void> _refreshUsageCount() async {
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

  /// 구독을 시작합니다.
  /// 성공 시 null, 실패 시 사용자에게 보여줄 에러 메시지를 반환합니다.
  /// 사용자가 직접 취소한 경우도 null을 반환합니다.
  Future<String?> purchase() async {
    try {
      final offerings = await Purchases.getOfferings();
      final package = offerings.current?.monthly;
      if (package == null) {
        return '구매 가능한 상품을 찾을 수 없습니다.';
      }
      final customerInfo = await Purchases.purchasePackage(package);
      _isPremium = customerInfo.entitlements.active.containsKey(_entitlementId);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_premiumCacheKey, _isPremium);
      notifyListeners();
      return null;
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        return null; // 사용자 취소는 에러가 아님
      }
      return switch (errorCode) {
        PurchasesErrorCode.networkError =>
          '네트워크 오류가 발생했습니다. 연결을 확인해 주세요.',
        PurchasesErrorCode.productAlreadyPurchasedError =>
          '이미 구독 중입니다. 구매 복원을 시도해 주세요.',
        _ => '구독 처리 중 오류가 발생했습니다.\n다시 시도해 주세요.',
      };
    }
  }

  Future<void> restorePurchases() async {
    final customerInfo = await Purchases.restorePurchases();
    _isPremium = customerInfo.entitlements.active.containsKey(_entitlementId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_premiumCacheKey, _isPremium);
    notifyListeners();
  }
}
