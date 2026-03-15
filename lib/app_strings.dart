class AppStrings {
  final bool _ko;
  const AppStrings._(this._ko);
  static AppStrings of(String lang) => AppStrings._(lang == '한국어');

  // ── Login Screen ──
  String get appTitle => 'Word Bank';
  String get intro => _ko
      ? 'AI로 단어를 부담 없이 학습해보세요.'
      : 'Learn words with AI without the pressure.';
  String get startFree => _ko ? '무료로 시작하기' : 'Start for free';
  String get feature1 => _ko ? 'AI 단어 조회 월 50회' : '50 AI lookups per month';
  String get feature2 => _ko ? '단어 저장' : 'Save your words';
  String get feature3 => _ko ? '7개 언어 지원' : 'Supports 7 languages';
  String get premiumLabel => _ko
      ? 'Premium: 더 많은 단어 저장'
      : 'Premium: More word storage';
  String get continueGoogle => _ko ? 'Google로 계속하기' : 'Continue with Google';
  String get continueApple => _ko ? 'Apple로 계속하기' : 'Continue with Apple';
  String get loginSuccess => _ko ? '로그인에 성공했어요.' : 'Signed in successfully.';
  String get googleFail => _ko
      ? 'Google 로그인에 실패했습니다. 다시 시도해 주세요.'
      : 'Google sign-in failed. Please try again.';
  String get appleFail => _ko
      ? 'Apple 로그인에 실패했습니다. 다시 시도해 주세요.'
      : 'Apple sign-in failed. Please try again.';
  String get terms => _ko
      ? '로그인하면 이용약관 및 개인정보처리방침에 동의하게 됩니다.'
      : 'By signing in, you agree to the Terms and Privacy Policy.';

  // ── Library Screen ──
  String get searchHint => _ko ? '단어 검색..' : 'Search words...';
  String get randomWord => _ko ? '랜덤 단어' : 'Random word';
  String get settings => _ko ? '설정' : 'Settings';
  String get signIn => _ko ? '로그인' : 'Sign In';
  String get account => _ko ? '계정' : 'Account';
  String get addWord => _ko ? '단어 추가' : 'Add Word';
  String get emptyMessage => _ko
      ? '저장된 단어가 없어요.\n독서 중 모르는 단어가 나오면\n단어 추가 버튼으로 기록해보세요.'
      : 'No words saved yet.\nFind an unfamiliar word while reading?\nAdd it to your Word Bank.';
  String get all => _ko ? '전체' : 'All';
  String noResults(String q) =>
      _ko ? '"$q" 검색 결과가 없어요' : 'No results for "$q".';
  String get noWordsWithTag =>
      _ko ? '해당 태그의 단어가 없어요' : 'No words with this tag.';
  String get deleteTitle => _ko ? '단어 삭제' : 'Delete word?';
  String deleteContent(String w) => _ko
      ? '"$w"를 Word Bank에서 삭제할까요?\n삭제해도 이번 달 저장 가능 횟수는 복구되지 않습니다.'
      : 'Remove "$w" from your Word Bank?\nDeleting it will not restore your monthly save limit.';
  String get cancel => _ko ? '취소' : 'Cancel';
  String get delete => _ko ? '삭제' : 'Delete';

  // ── Settings Sheet ──
  String get settingsTitle => _ko ? '설정' : 'Settings';
  String get definitionLang => _ko ? '정의 표시 언어' : 'Definition language';
  String get examplesLang =>
      _ko ? '예문 및 유의어 언어' : 'Examples & synonyms language';
  String get sameAsWord => _ko ? '단어와 동일' : 'Same as word';
  String get appLanguage => _ko ? '앱 언어' : 'App language';

  // ── Account Sheet ──
  String get accountTitle => _ko ? '계정' : 'Account';
  String get signInDesc => _ko
      ? '로그인하면 구독 상태가 기기 간 동기화되고\nPremium 업그레이드가 가능합니다.'
      : 'Sign in to sync your subscription\nacross devices and unlock Premium.';
  String get signInButton => _ko ? '로그인 / 회원가입' : 'Sign In / Register';
  String get premiumPlan => _ko ? 'Premium 플랜' : 'Premium Plan';
  String get freePlan => _ko ? '무료 플랜' : 'Free Plan';
  String get upgrade => _ko ? '업그레이드' : 'Upgrade';
  String get signOut => _ko ? '로그아웃' : 'Sign Out';
  String get unlimitedLookup => _ko ? '더 많은 단어 저장' : 'More word storage';
  String monthlyUsage(int used, int limit) =>
      _ko ? '이번 달 단어 저장: $used / $limit' : 'This month: $used / $limit';

  // ── Usage Banner ──
  String usageBanner(int used, int limit) =>
      _ko ? '이번 달 단어 저장: $used/$limit' : 'Words saved this month: $used/$limit';
  String usageLimit(int used, int limit) => _ko
      ? '이번 달 무료 저장 한도 도달 ($used/$limit)'
      : 'Monthly save limit reached ($used/$limit)';
  String get upgradeButton => _ko ? 'Premium 업그레이드' : 'Upgrade to Premium';

  // ── Paywall Screen ──
  String get paywallTitle =>
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
  String get startFallback =>
      _ko ? '월 9,900원으로 시작하기' : 'Start for 9,900 KRW/month';
  String startWithPrice(String price) {
    if (_ko) {
      if (price.contains('/')) return '$price으로 시작하기';
      return '월 $price로 시작하기';
    }
    return price.contains('/') ? 'Start for $price' : 'Start for $price/month';
  }
  String cancelNote(String store) => _ko
      ? '구독은 $store에서 언제든 취소할 수 있습니다.'
      : 'You can cancel anytime in $store.';
  String storeName(bool isIos) {
    if (_ko) return isIos ? 'App Store' : 'Google Play 스토어';
    return isIos ? 'App Store' : 'Google Play';
  }

  // ── Purchase Errors ──
  String get purchaseErrorNetwork =>
      _ko ? '네트워크 오류가 발생했습니다. 연결을 확인해 주세요.' : 'A network error occurred. Please check your connection.';
  String get purchaseErrorAlreadyOwned =>
      _ko ? '이미 구독 중입니다. 구매 복원을 시도해 주세요.' : 'You already have an active subscription. Try restoring purchases.';
  String get purchaseErrorUnknown =>
      _ko ? '구독 처리 중 오류가 발생했습니다.\n다시 시도해 주세요.' : 'Something went wrong.\nPlease try again.';
  String get restoreErrorNetwork =>
      _ko ? '네트워크 오류로 복원에 실패했습니다.' : 'Restore failed due to a network error.';
  String get restoreErrorUnknown =>
      _ko ? '구매 복원에 실패했습니다.' : 'Failed to restore purchases.';
}
