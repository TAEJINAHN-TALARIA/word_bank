import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum PurchaseErrorCode { network, alreadyOwned, unknown }

class SubscriptionService extends ChangeNotifier {
  static const String _entitlementId = 'premium';
  static const String monthlyProductId = 'word_bank_premium_monthly';
  static const int freeLimit = 30;
  static const String _premiumCacheKey = 'cached_is_premium';
  static const String _saveMonthKey = 'word_save_month';
  static const String _saveCountKey = 'word_save_count';

  // 빌드 시 --dart-define=REVENUECAT_IOS_KEY=<key> --dart-define=REVENUECAT_ANDROID_KEY=<key> 로 전달하세요.
  static const String _iosApiKey = String.fromEnvironment('REVENUECAT_IOS_KEY');
  static const String _androidApiKey = String.fromEnvironment('REVENUECAT_ANDROID_KEY');

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
      // Firebase 유저가 있으면 RevenueCat 고객과 연결
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await Purchases.logIn(uid);
      }
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
    _monthlyCount = await getMonthlySaveCount();
  }

  static String _monthKey(DateTime dt) {
    final utc = dt.toUtc();
    final mm = utc.month.toString().padLeft(2, '0');
    return '${utc.year}-$mm';
  }

  static DocumentReference<Map<String, dynamic>> _usageDoc(String uid, String monthKey) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('usage')
        .doc(monthKey);
  }

  static Future<int> getMonthlySaveCount() async {
    final nowKey = _monthKey(DateTime.now().toUtc());
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid != null) {
      try {
        final snap = await _usageDoc(uid, nowKey).get();
        return (snap.data()?['count'] as int?) ?? 0;
      } catch (e) {
        debugPrint('Firestore getMonthlySaveCount failed, falling back to local: $e');
      }
    }

    // 비로그인 또는 Firestore 실패 시 로컬 캐시 사용
    final prefs = await SharedPreferences.getInstance();
    final storedKey = prefs.getString(_saveMonthKey);
    if (storedKey != nowKey) {
      await prefs.setString(_saveMonthKey, nowKey);
      await prefs.setInt(_saveCountKey, 0);
      return 0;
    }
    return prefs.getInt(_saveCountKey) ?? 0;
  }

  static Future<void> incrementMonthlySaveCount() async {
    final nowKey = _monthKey(DateTime.now().toUtc());
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid != null) {
      try {
        await _usageDoc(uid, nowKey).set(
          {'count': FieldValue.increment(1)},
          SetOptions(merge: true),
        );
        return;
      } catch (e) {
        debugPrint('Firestore incrementMonthlySaveCount failed, falling back to local: $e');
      }
    }

    // 비로그인 또는 Firestore 실패 시 로컬에 저장
    final prefs = await SharedPreferences.getInstance();
    final storedKey = prefs.getString(_saveMonthKey);
    int count = prefs.getInt(_saveCountKey) ?? 0;
    if (storedKey != nowKey) {
      count = 0;
      await prefs.setString(_saveMonthKey, nowKey);
    }
    await prefs.setInt(_saveCountKey, count + 1);
  }

  /// 구독을 시작합니다.
  /// 성공/취소 시 null, 실패 시 [PurchaseErrorCode]를 반환합니다.
  Future<PurchaseErrorCode?> purchase() async {
    try {
      final offerings = await Purchases.getOfferings();
      final package = offerings.current?.monthly;
      if (package == null) return PurchaseErrorCode.unknown;

      final customerInfo = await Purchases.purchasePackage(package);
      _isPremium = customerInfo.entitlements.active.containsKey(_entitlementId);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_premiumCacheKey, _isPremium);
      await refreshStatus();
      return null;
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode == PurchasesErrorCode.purchaseCancelledError) return null;
      return switch (errorCode) {
        PurchasesErrorCode.networkError => PurchaseErrorCode.network,
        PurchasesErrorCode.productAlreadyPurchasedError => PurchaseErrorCode.alreadyOwned,
        _ => PurchaseErrorCode.unknown,
      };
    } catch (e) {
      debugPrint('Unexpected purchase error: $e');
      return PurchaseErrorCode.unknown;
    }
  }

  /// 구독을 복원합니다.
  /// 성공 시 null, 실패 시 [PurchaseErrorCode]를 반환합니다.
  Future<PurchaseErrorCode?> restorePurchases() async {
    try {
      final customerInfo = await Purchases.restorePurchases();
      _isPremium = customerInfo.entitlements.active.containsKey(_entitlementId);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_premiumCacheKey, _isPremium);
      await refreshStatus();
      return null;
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      return errorCode == PurchasesErrorCode.networkError
          ? PurchaseErrorCode.network
          : PurchaseErrorCode.unknown;
    } catch (e) {
      debugPrint('Unexpected restore error: $e');
      return PurchaseErrorCode.unknown;
    }
  }

  Future<String?> getMonthlyPriceString() async {
    try {
      final offerings = await Purchases.getOfferings();
      final package = offerings.current?.monthly;
      return package?.storeProduct.priceString;
    } catch (e) {
      debugPrint('RevenueCat getOfferings failed: $e');
      return null;
    }
  }
}
