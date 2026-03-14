import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/subscription_service.dart';
import '../services/language_prefs.dart';

class _S {
  final bool _ko;
  const _S._(this._ko);
  static _S of(String lang) => _S._(lang == '한국어');

  String get title =>
      _ko ? 'Premium으로 업그레이드하세요.' : 'Upgrade to Premium.';
  String get unlimitedTitle => _ko ? '무제한 단어 저장' : 'Unlimited word storage';
  String get unlimitedSubtitle =>
      _ko ? '원하는 단어를 제한 없이 저장하세요' : 'Save as many words as you want';
  String get exportTitle => _ko ? 'PDF/Excel 내보내기' : 'Export to PDF/Excel';
  String get exportSubtitle => _ko
      ? '단어장을 깔끔하게 정리해 내보낼 수 있어요'
      : 'Export your word lists in a clean format';
  String get restore => _ko ? '이전 구매 복원' : 'Restore purchases';
  String get restoreNotFound =>
      _ko ? '복원된 구독을 찾을 수 없습니다.' : 'No restored subscription found.';
  String get restoreFailed =>
      _ko ? '구매 복원에 실패했습니다.' : 'Failed to restore purchases.';
  String get startFallback => _ko ? '월 9,900원으로 시작하기' : 'Start for 9,900 KRW/month';

  String startWithPrice(String price) {
    if (_ko) {
      if (price.contains('/')) return '$price으로 시작하기';
      return '월 $price로 시작하기';
    }
    return price.contains('/')
        ? 'Start for $price'
        : 'Start for $price/month';
  }

  String storeName(TargetPlatform platform) {
    if (_ko) {
      return switch (platform) {
        TargetPlatform.iOS => 'App Store',
        TargetPlatform.android => 'Google Play 스토어',
        _ => '앱 스토어',
      };
    }
    return switch (platform) {
      TargetPlatform.iOS => 'App Store',
      TargetPlatform.android => 'Google Play',
      _ => 'the app store',
    };
  }

  String cancelNote(String store) => _ko
      ? '구독은 $store에서 언제든 취소할 수 있습니다.'
      : 'You can cancel anytime in $store.';
}

class PaywallScreen extends StatefulWidget {
  final int? used;
  final int? limit;

  const PaywallScreen({super.key, this.used, this.limit});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  bool _isLoading = false;
  String? _error;
  String? _priceString;
  String _uiLanguage = 'English';
  late _S _s;

  @override
  void initState() {
    super.initState();
    _s = _S.of(_uiLanguage);
    _loadPrice();
    _loadUiLanguage();
  }

  Future<void> _loadUiLanguage() async {
    final lang = await LanguagePrefs.getUiLanguage();
    if (mounted) {
      setState(() {
        _uiLanguage = lang;
        _s = _S.of(lang);
      });
    }
  }

  Future<void> _loadPrice() async {
    final price =
        await context.read<SubscriptionService>().getMonthlyPriceString();
    if (mounted) setState(() => _priceString = price);
  }

  String _storeName() {
    if (kIsWeb) return _s.storeName(TargetPlatform.android);
    return _s.storeName(defaultTargetPlatform);
  }

  String _priceButtonText() {
    final price = _priceString;
    if (price == null || price.isEmpty) {
      return _s.startFallback;
    }
    return _s.startWithPrice(price);
  }

  Future<void> _subscribe() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final error = await context.read<SubscriptionService>().purchase();
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _error = error);
    }
    setState(() => _isLoading = false);
  }

  Future<void> _restore() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final service = context.read<SubscriptionService>();
      await service.restorePurchases();
      await service.refreshStatus();
      if (mounted && service.isPremium) {
        Navigator.of(context).pop(true);
      } else if (mounted) {
        setState(() => _error = _s.restoreNotFound);
      }
    } catch (e) {
      if (mounted) setState(() => _error = _s.restoreFailed);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            0,
            24,
            16 + MediaQuery.of(context).viewPadding.bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Icon(
                Icons.workspace_premium,
                size: 72,
                color: Color(0xFFFFB300),
              ),
              const SizedBox(height: 20),
              Text(
                _s.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  height: 1.4,
                  color: Color(0xFF2C3E50),
                ),
              ),
              const SizedBox(height: 28),
              _PremiumFeature(
                icon: Icons.all_inclusive,
                title: _s.unlimitedTitle,
                subtitle: _s.unlimitedSubtitle,
              ),
              const SizedBox(height: 16),
              _PremiumFeature(
                icon: Icons.picture_as_pdf,
                title: _s.exportTitle,
                subtitle: _s.exportSubtitle,
              ),
              const Spacer(),
              if (_error != null) ...[
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
                const SizedBox(height: 12),
              ],
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else ...[
                ElevatedButton(
                  onPressed: _subscribe,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2C3E50),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    _priceButtonText(),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _restore,
                  child: Text(
                    _s.restore,
                    style: const TextStyle(color: Colors.black54),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                _s.cancelNote(_storeName()),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: Colors.black38),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PremiumFeature extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _PremiumFeature({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF2C3E50).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xFF2C3E50), size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
