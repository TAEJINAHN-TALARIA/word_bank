import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../services/subscription_service.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  bool _isLoading = false;
  String? _error;

  Future<void> _subscribe() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await SubscriptionService.purchase();
      if (mounted) Navigator.of(context).pop(true);
    } on PurchasesException catch (e) {
      if (e.code == PurchasesErrorCode.purchaseCancelledError) {
        // 사용자가 직접 취소 — 오류 메시지 불필요
      } else if (mounted) {
        setState(() => _error = '구독 처리 중 오류가 발생했습니다.\n다시 시도해 주세요.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = '구독 처리 중 오류가 발생했습니다.\n다시 시도해 주세요.');
      }
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
      await SubscriptionService.restorePurchases();
      await SubscriptionService.refreshStatus();
      if (mounted && SubscriptionService.isPremium) {
        Navigator.of(context).pop(true);
      } else if (mounted) {
        setState(() => _error = '복원할 구독을 찾을 수 없습니다.');
      }
    } catch (e) {
      if (mounted) setState(() => _error = '구매 복원에 실패했습니다.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final used = SubscriptionService.monthlyCount;
    final limit = SubscriptionService.freeLimit;

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
      body: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
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
              '이번 달 무료 조회 한도에\n도달했습니다.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                height: 1.4,
                color: Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$used / $limit 회 사용',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.black45),
            ),
            const SizedBox(height: 32),
            // 프리미엄 혜택
            _PremiumFeature(
              icon: Icons.all_inclusive,
              title: '무제한 AI 조회',
              subtitle: '한도 없이 단어를 검색하세요',
            ),
            const SizedBox(height: 16),
            _PremiumFeature(
              icon: Icons.bolt,
              title: '고품질 AI 모델',
              subtitle: 'Claude Opus로 더 정확한 정의 제공',
            ),
            const SizedBox(height: 16),
            _PremiumFeature(
              icon: Icons.block,
              title: '광고 없음',
              subtitle: '광고 없이 깔끔하게 학습',
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
                child: const Text(
                  '월 ₩3,900으로 시작하기',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _restore,
                child: const Text(
                  '이전 구매 복원',
                  style: TextStyle(color: Colors.black54),
                ),
              ),
            ],
            const SizedBox(height: 8),
            const Text(
              '구독은 App Store에서 언제든지 취소할 수 있습니다.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Colors.black38),
            ),
          ],
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
            color: const Color(0xFF2C3E50).withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xFF2C3E50), size: 24),
        ),
        const SizedBox(width: 16),
        Column(
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
      ],
    );
  }
}
