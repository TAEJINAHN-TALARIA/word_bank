import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:purchases_flutter/purchases_flutter.dart';
import 'api_client.dart';
import 'auth_service.dart';

class SubscriptionService {
  /// RevenueCat에서 생성한 Entitlement 식별자 (대시보드와 동일해야 함)
  static const String _entitlementId = 'premium';
  static const int freeLimit = 50;

  static bool _isPremium = false;
  static int _monthlyCount = 0;

  static bool get isPremium => _isPremium;
  static int get monthlyCount => _monthlyCount;

  /// RevenueCat 초기화. Firebase 초기화 이후 호출.
  static Future<void> initialize() async {
    final apiKey = Platform.isIOS ? kRevenueCatIosKey : kRevenueCatAndroidKey;
    if (apiKey.startsWith('YOUR_')) {
      debugPrint('RevenueCat API key not configured — skipping IAP setup');
      return;
    }

    await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.error);
    await Purchases.configure(PurchasesConfiguration(apiKey));

    // Firebase UID로 RevenueCat 사용자를 식별
    final uid = AuthService.currentUser?.uid;
    if (uid != null) {
      await Purchases.logIn(uid);
    }

    await refreshStatus();
  }

  /// 서버(Firestore)에서 구독 상태와 사용량을 새로고침.
  ///
  /// RevenueCat 웹훅이 Firestore를 업데이트하므로,
  /// 서버가 항상 최신·정확한 상태를 가짐.
  static Future<void> refreshStatus() async {
    // 로그인 상태가 바뀐 경우 RC 사용자 동기화
    final uid = AuthService.currentUser?.uid;
    if (uid != null) {
      try {
        final info = await Purchases.getCustomerInfo();
        if (info.originalAppUserId != uid) {
          await Purchases.logIn(uid);
        }
      } catch (_) {}
    }

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

  /// 월간 구독 구매.
  ///
  /// RevenueCat SDK가 영수증 검증, 스토어 통신을 모두 처리.
  /// 사용자 취소 시: [PurchasesException] (code: purchaseCancelledError) 발생.
  /// 네트워크/스토어 오류 시: [PurchasesException] 발생.
  static Future<void> purchase() async {
    final offerings = await Purchases.getOfferings();
    final monthly = offerings.current?.monthly;
    if (monthly == null) throw Exception('No monthly package available');

    final customerInfo = await Purchases.purchasePackage(monthly);

    // RevenueCat이 검증까지 완료한 시점이므로 즉시 반영
    if (customerInfo.entitlements.active.containsKey(_entitlementId)) {
      _isPremium = true;
      _monthlyCount = 0;
    }
  }

  /// 이전 구매 복원.
  static Future<void> restorePurchases() async {
    final customerInfo = await Purchases.restorePurchases();
    if (customerInfo.entitlements.active.containsKey(_entitlementId)) {
      _isPremium = true;
      _monthlyCount = 0;
    }
  }

  /// 로그아웃 시 RevenueCat 사용자 세션 종료.
  static Future<void> logOut() async {
    try {
      await Purchases.logOut();
    } catch (e) {
      debugPrint('RevenueCat logout failed: $e');
    }
    _isPremium = false;
    _monthlyCount = 0;
  }
}
