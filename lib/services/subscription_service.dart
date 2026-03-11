import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_purchase/in_app_purchase.dart';
import 'api_client.dart';
import 'auth_service.dart';

enum _VerifyResult { success, transientFailure, permanentFailure }

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

  /// 구매 검증 실패 시 사용자에게 표시할 오류 메시지.
  /// null이면 오류 없음.
  static final ValueNotifier<String?> verificationError = ValueNotifier(null);

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
        final result = await _verifyAndActivate(purchase);
        if (result != _VerifyResult.transientFailure) {
          // 일시적 실패 시에는 completePurchase를 호출하지 않아
          // 스토어가 다음 앱 실행 시 트랜잭션을 재전달하도록 합니다.
          await InAppPurchase.instance.completePurchase(purchase);
        }
      } else if (purchase.status == PurchaseStatus.error) {
        debugPrint('Purchase error: ${purchase.error}');
        if (purchase.pendingCompletePurchase) {
          await InAppPurchase.instance.completePurchase(purchase);
        }
      }
    }
  }

  static Future<_VerifyResult> _verifyAndActivate(
    PurchaseDetails purchase,
  ) async {
    final token = await AuthService.getIdToken();
    if (token == null) {
      verificationError.value = '로그인이 필요합니다. 다시 로그인 후 구매를 복원해 주세요.';
      return _VerifyResult.transientFailure;
    }

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
        verificationError.value = null;
        return _VerifyResult.success;
      }

      // 400: 유효하지 않은 영수증 (영구 실패) → completePurchase로 트랜잭션 정리
      if (response.statusCode == 400) {
        verificationError.value = '유효하지 않은 구매입니다. 고객센터에 문의해 주세요.';
        return _VerifyResult.permanentFailure;
      }

      // 5xx 등 서버 일시 오류 → completePurchase 생략, 다음 실행 시 재시도
      verificationError.value = '구매 확인에 실패했습니다. 앱을 재시작하거나 구매 복원을 시도해 주세요.';
      return _VerifyResult.transientFailure;
    } on TimeoutException {
      verificationError.value = '서버 응답 시간 초과. 앱을 재시작하거나 구매 복원을 시도해 주세요.';
      return _VerifyResult.transientFailure;
    } catch (e) {
      debugPrint('Purchase verification failed: $e');
      verificationError.value = '구매 확인에 실패했습니다. 앱을 재시작하거나 구매 복원을 시도해 주세요.';
      return _VerifyResult.transientFailure;
    }
  }

  static void dispose() {
    _purchaseSubscription?.cancel();
  }
}
