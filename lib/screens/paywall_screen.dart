import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_strings.dart';
import '../services/subscription_service.dart';
import '../services/language_prefs.dart';

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
  late AppStrings _s;

  @override
  void initState() {
    super.initState();
    _s = AppStrings.of(_uiLanguage);
    _loadPrice();
    _loadUiLanguage();
  }

  Future<void> _loadUiLanguage() async {
    final lang = await LanguagePrefs.getUiLanguage();
    if (mounted) {
      setState(() {
        _uiLanguage = lang;
        _s = AppStrings.of(lang);
      });
    }
  }

  Future<void> _loadPrice() async {
    final price =
        await context.read<SubscriptionService>().getMonthlyPriceString();
    if (mounted) setState(() => _priceString = price);
  }

  String _storeName() {
    final isIos = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    return _s.storeName(isIos);
  }

  String _priceButtonText() {
    final price = _priceString;
    if (price == null || price.isEmpty) return _s.startFallback;
    return _s.startWithPrice(price);
  }

  String _purchaseErrorMessage(PurchaseErrorCode code) => switch (code) {
        PurchaseErrorCode.network => _s.purchaseErrorNetwork,
        PurchaseErrorCode.alreadyOwned => _s.purchaseErrorAlreadyOwned,
        PurchaseErrorCode.unknown => _s.purchaseErrorUnknown,
      };

  String _restoreErrorMessage(PurchaseErrorCode code) => switch (code) {
        PurchaseErrorCode.network => _s.restoreErrorNetwork,
        _ => _s.restoreErrorUnknown,
      };

  Future<void> _subscribe() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final errorCode = await context.read<SubscriptionService>().purchase();
      if (!mounted) return;
      if (errorCode == null) {
        Navigator.of(context).pop(true);
      } else {
        setState(() => _error = _purchaseErrorMessage(errorCode));
      }
    } catch (e) {
      if (mounted) setState(() => _error = _s.purchaseErrorUnknown);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _restore() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final service = context.read<SubscriptionService>();
      final errorCode = await service.restorePurchases();
      if (!mounted) return;
      if (errorCode != null) {
        setState(() => _error = _restoreErrorMessage(errorCode));
      } else if (service.isPremium) {
        Navigator.of(context).pop(true);
      } else {
        setState(() => _error = _s.restoreNotFound);
      }
    } catch (e) {
      if (mounted) setState(() => _error = _s.restoreErrorUnknown);
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
                _s.paywallTitle,
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
