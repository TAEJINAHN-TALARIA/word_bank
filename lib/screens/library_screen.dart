import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/word.dart';
import '../services/auth_service.dart';
import '../services/language_prefs.dart';
import '../services/subscription_service.dart';
import '../widgets/meaning_display.dart';
import 'add_word_sheet.dart';
import 'login_screen.dart';
import 'paywall_screen.dart';
import 'word_detail_sheet.dart';

// ─── UI Strings ───
class _S {
  final bool _ko;
  const _S._(this._ko);
  static _S of(String lang) => _S._(lang == '한국어');

  String get searchHint => _ko ? '단어 검색...' : 'Search words...';
  String get randomWord => _ko ? '랜덤 단어' : 'Random word';
  String get settings => _ko ? '설정' : 'Settings';
  String get signIn => _ko ? '로그인' : 'Sign In';
  String get account => _ko ? '계정' : 'Account';
  String get addWord => _ko ? '단어 추가' : 'Add Word';
  String get emptyMessage => _ko
      ? '저장된 단어가 없어요.\n읽다가 모르는 단어가 생기면\n단어 추가 버튼으로 기록해 보세요.'
      : 'No words saved yet.\nFind an unfamiliar word while reading?\nAdd it to your Word Bank.';
  String get all => _ko ? '전체' : 'All';
  String noResults(String q) =>
      _ko ? '"$q" 검색 결과가 없어요.' : 'No results for "$q".';
  String get noWordsWithTag =>
      _ko ? '이 태그에 저장된 단어가 없어요.' : 'No words with this tag.';
  String get deleteTitle => _ko ? '단어 삭제' : 'Delete word?';
  String deleteContent(String w) =>
      _ko ? '"$w"를 Word Bank에서 삭제할까요?' : 'Remove "$w" from your Word Bank?';
  String get cancel => _ko ? '취소' : 'Cancel';
  String get delete => _ko ? '삭제' : 'Delete';

  // Settings sheet
  String get settingsTitle => _ko ? '설정' : 'Settings';
  String get definitionLang => _ko ? '뜻 표시 언어' : 'Definition language';
  String get examplesLang =>
      _ko ? '예문 및 유의어 언어' : 'Examples & synonyms language';
  String get sameAsWord => _ko ? '단어와 동일' : 'Same as word';
  String get appLanguage => _ko ? '앱 언어' : 'App language';

  // Account sheet
  String get accountTitle => _ko ? '계정' : 'Account';
  String get signInDesc => _ko
      ? '로그인하면 구독 상태가 기기 간 동기화되고\nPremium 업그레이드가 가능합니다.'
      : 'Sign in to sync your subscription\nacross devices and unlock Premium.';
  String get signInButton => _ko ? '로그인 / 회원가입' : 'Sign In / Register';
  String get premiumPlan => _ko ? 'Premium 플랜' : 'Premium Plan';
  String get freePlan => _ko ? '무료 플랜' : 'Free Plan';
  String get upgrade => _ko ? '업그레이드' : 'Upgrade';
  String get signOut => _ko ? '로그아웃' : 'Sign Out';
  String get unlimitedLookup => _ko ? '무제한 AI 조회' : 'Unlimited AI lookups';
  String monthlyUsage(int used, int limit) =>
      _ko ? '이번 달 조회: $used / $limit' : 'This month: $used / $limit';

  // Usage banner
  String usageBanner(int used, int limit) =>
      _ko ? '이번 달 AI 조회: $used/$limit' : 'AI lookups this month: $used/$limit';
  String usageLimit(int used, int limit) => _ko
      ? '이번 달 무료 조회 한도 도달 ($used/$limit)'
      : 'Monthly free limit reached ($used/$limit)';
  String get upgradeButton => _ko ? 'Premium 업그레이드' : 'Upgrade to Premium';
}

// ─── Library Screen ───
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  List<Word> _words = [];
  String? _selectedTag;
  bool _isSearching = false;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  String _uiLanguage = 'English';

  _S get _s => _S.of(_uiLanguage);

  @override
  void initState() {
    super.initState();
    _loadWords();
    _refreshSubscription();
    _loadUiLanguage();
  }

  Future<void> _loadUiLanguage() async {
    final lang = await LanguagePrefs.getUiLanguage();
    if (mounted) setState(() => _uiLanguage = lang);
  }

  Future<void> _refreshSubscription() async {
    await SubscriptionService.refreshStatus();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadWords() async {
    final words = await DatabaseHelper.instance.getAllWords();
    if (!mounted) return;
    setState(() => _words = words);
  }

  List<String> get _allTags {
    return _words.expand((w) => w.tags).toSet().toList()..sort();
  }

  List<Word> get _filteredWords {
    var words = _selectedTag == null
        ? _words
        : _words.where((w) => w.tags.contains(_selectedTag)).toList();
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      words = words.where((w) => w.word.toLowerCase().contains(q)).toList();
    }
    return words;
  }

  void _showAddWordSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const AddWordSheet(),
    );
    _loadWords();
  }

  void _showRandomWord() {
    if (_words.isEmpty) return;
    final word = _words[Random().nextInt(_words.length)];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => WordDetailSheet(word: word, onUpdated: _loadWords),
    );
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SettingsSheet(
        s: _s,
        uiLanguage: _uiLanguage,
        onUiLanguageChanged: (lang) {
          setState(() => _uiLanguage = lang);
        },
      ),
    );
  }

  void _showAccountSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AccountSheet(s: _s, onRefresh: _refreshSubscription),
    );
  }

  void _stopSearching() {
    setState(() {
      _isSearching = false;
      _searchQuery = '';
      _searchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: _isSearching
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _stopSearching,
              )
            : null,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: _s.searchHint,
                  border: InputBorder.none,
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              )
            : null,
        centerTitle: false,
        actions: _isSearching
            ? []
            : [
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => setState(() => _isSearching = true),
                ),
                if (_words.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.shuffle),
                    tooltip: _s.randomWord,
                    onPressed: _showRandomWord,
                  ),
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  tooltip: _s.settings,
                  onPressed: _showSettings,
                ),
                IconButton(
                  icon: const Icon(Icons.account_circle_outlined),
                  tooltip: FirebaseAuth.instance.currentUser != null
                      ? _s.account
                      : _s.signIn,
                  onPressed: _showAccountSheet,
                ),
              ],
      ),
      body: Column(
        children: [
          _UsageBanner(
            s: _s,
            onUpgrade: () async {
              final upgraded = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => const PaywallScreen(),
                  fullscreenDialog: true,
                ),
              );
              if (upgraded == true) _refreshSubscription();
            },
          ),
          Expanded(child: _buildBody()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddWordSheet,
        icon: const Icon(Icons.add),
        label: Text(_s.addWord),
      ),
    );
  }

  Widget _buildBody() {
    return _words.isEmpty
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                _s.emptyMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 16, color: Colors.black54, height: 1.6),
              ),
            ),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_allTags.isNotEmpty && !_isSearching)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      FilterChip(
                        label: Text(_s.all),
                        selected: _selectedTag == null,
                        onSelected: (_) =>
                            setState(() => _selectedTag = null),
                        selectedColor: const Color(0xFF2C3E50),
                        labelStyle: TextStyle(
                          color: _selectedTag == null
                              ? Colors.white
                              : Colors.black87,
                        ),
                        checkmarkColor: Colors.white,
                      ),
                      ..._allTags.map((tag) => Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: FilterChip(
                              label: Text(tag),
                              selected: _selectedTag == tag,
                              onSelected: (_) =>
                                  setState(() => _selectedTag = tag),
                              selectedColor: const Color(0xFF2C3E50),
                              labelStyle: TextStyle(
                                color: _selectedTag == tag
                                    ? Colors.white
                                    : Colors.black87,
                              ),
                              checkmarkColor: Colors.white,
                            ),
                          )),
                    ],
                  ),
                ),
              Expanded(
                child: _filteredWords.isEmpty
                    ? Center(
                        child: Text(
                          _searchQuery.isNotEmpty
                              ? _s.noResults(_searchQuery)
                              : _s.noWordsWithTag,
                          style: const TextStyle(color: Colors.black45),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredWords.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          return _WordCard(
                            word: _filteredWords[index],
                            s: _s,
                            onDeleted: _loadWords,
                          );
                        },
                      ),
              ),
            ],
          );
  }
}

// ─── Word Card ───
class _WordCard extends StatelessWidget {
  final Word word;
  final _S s;
  final VoidCallback onDeleted;

  const _WordCard({required this.word, required this.s, required this.onDeleted});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: const Color(0xFFF1F3F5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (_) => WordDetailSheet(word: word, onUpdated: onDeleted),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          word.word,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2C3E50),
                          ),
                        ),
                        if (word.phonetic != null)
                          Text(
                            word.phonetic!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black45,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        size: 20, color: Colors.black38),
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text(s.deleteTitle),
                          content: Text(s.deleteContent(word.word)),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text(s.cancel),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: TextButton.styleFrom(
                                  foregroundColor: Colors.red),
                              child: Text(s.delete),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true && context.mounted) {
                        await DatabaseHelper.instance.deleteWord(word.id!);
                        onDeleted();
                      }
                    },
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              MeaningCardDisplay(meaning: word.meaning),
              if (word.tags.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  children: word.tags
                      .map((tag) => Chip(
                            label: Text(tag,
                                style: const TextStyle(fontSize: 12)),
                            backgroundColor: const Color(0xFFDDE3EA),
                            padding: EdgeInsets.zero,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ))
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Settings Sheet ───
class _SettingsSheet extends StatefulWidget {
  final _S s;
  final String uiLanguage;
  final void Function(String) onUiLanguageChanged;

  const _SettingsSheet({
    required this.s,
    required this.uiLanguage,
    required this.onUiLanguageChanged,
  });

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  String _definitionLanguage = 'English';
  String? _exampleLanguage;
  late String _uiLanguage;
  late _S _s;

  @override
  void initState() {
    super.initState();
    _uiLanguage = widget.uiLanguage;
    _s = widget.s;
    _load();
  }

  Future<void> _load() async {
    final def = await LanguagePrefs.getDefinitionLanguage();
    final ex = await LanguagePrefs.getExampleLanguage();
    if (mounted) {
      setState(() {
        _definitionLanguage = def;
        _exampleLanguage = ex;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_s.settingsTitle,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),

          Text(_s.appLanguage,
              style: const TextStyle(fontSize: 12, color: Colors.black45)),
          const SizedBox(height: 8),
          _LangDropdown(
            value: _uiLanguage,
            options: LanguagePrefs.supportedUiLanguages,
            onChanged: (lang) async {
              if (lang == null) return;
              await LanguagePrefs.setUiLanguage(lang);
              setState(() {
                _uiLanguage = lang;
                _s = _S.of(lang);
              });
              widget.onUiLanguageChanged(lang);
            },
          ),

          const SizedBox(height: 20),

          Text(_s.definitionLang,
              style: const TextStyle(fontSize: 12, color: Colors.black45)),
          const SizedBox(height: 8),
          _LangDropdown(
            value: _definitionLanguage,
            options: LanguagePrefs.supported,
            onChanged: (lang) async {
              if (lang == null) return;
              setState(() => _definitionLanguage = lang);
              await LanguagePrefs.setDefinitionLanguage(lang);
            },
          ),

          const SizedBox(height: 20),

          Text(_s.examplesLang,
              style: const TextStyle(fontSize: 12, color: Colors.black45)),
          const SizedBox(height: 8),
          _LangDropdown(
            value: _exampleLanguage,
            options: LanguagePrefs.supported,
            noneLabel: _s.sameAsWord,
            onChanged: (lang) async {
              setState(() => _exampleLanguage = lang);
              await LanguagePrefs.setExampleLanguage(lang);
            },
          ),
        ],
      ),
    );
  }
}

// ─── Lang Dropdown ───
class _LangDropdown extends StatelessWidget {
  final String? value;
  final List<String> options;
  final String? noneLabel;
  final void Function(String?) onChanged;

  const _LangDropdown({
    required this.value,
    required this.options,
    this.noneLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final items = <DropdownMenuItem<String?>>[];
    if (noneLabel != null) {
      items.add(DropdownMenuItem<String?>(
        value: null,
        child: Text(noneLabel!),
      ));
    }
    for (final opt in options) {
      items.add(DropdownMenuItem<String?>(
        value: opt,
        child: Text(opt),
      ));
    }

    return DropdownButtonFormField<String?>(
      initialValue: value,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      items: items,
      onChanged: (v) => onChanged(v),
    );
  }
}

// ─── Usage Banner ───
class _UsageBanner extends StatelessWidget {
  final _S s;
  final VoidCallback onUpgrade;

  const _UsageBanner({required this.s, required this.onUpgrade});

  @override
  Widget build(BuildContext context) {
    if (SubscriptionService.isPremium) return const SizedBox.shrink();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    final used = SubscriptionService.monthlyCount;
    final limit = SubscriptionService.freeLimit;
    final remaining = SubscriptionService.remaining;
    final isNearLimit = remaining <= 10;
    final isAtLimit = remaining == 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: isAtLimit
          ? Colors.red.shade50
          : isNearLimit
              ? Colors.orange.shade50
              : Colors.transparent,
      child: Row(
        children: [
          Icon(
            isAtLimit ? Icons.block : Icons.bar_chart,
            size: 16,
            color: isAtLimit
                ? Colors.red
                : isNearLimit
                    ? Colors.orange
                    : Colors.black45,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isAtLimit
                  ? s.usageLimit(used, limit)
                  : s.usageBanner(used, limit),
              style: TextStyle(
                fontSize: 12,
                color: isAtLimit
                    ? Colors.red
                    : isNearLimit
                        ? Colors.orange.shade800
                        : Colors.black54,
              ),
            ),
          ),
          if (isNearLimit || isAtLimit)
            GestureDetector(
              onTap: onUpgrade,
              child: Text(
                s.upgradeButton,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isAtLimit ? Colors.red : Colors.orange.shade800,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Account Sheet ───
class _AccountSheet extends StatefulWidget {
  final _S s;
  final VoidCallback onRefresh;

  const _AccountSheet({required this.s, required this.onRefresh});

  @override
  State<_AccountSheet> createState() => _AccountSheetState();
}

class _AccountSheetState extends State<_AccountSheet> {
  bool _isLoading = false;

  Future<void> _signOut() async {
    setState(() => _isLoading = true);
    await AuthService.signOut();
    if (mounted) Navigator.of(context).pop();
    widget.onRefresh();
  }

  void _goToLogin() {
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(s.accountTitle,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Text(
              s.signInDesc,
              style: const TextStyle(
                  fontSize: 14, color: Colors.black54, height: 1.5),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _goToLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2C3E50),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: Text(s.signInButton),
            ),
          ],
        ),
      );
    }

    final isPremium = SubscriptionService.isPremium;
    final used = SubscriptionService.monthlyCount;
    final limit = SubscriptionService.freeLimit;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.accountTitle,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFF2C3E50),
                child: Text(
                  (user.displayName?.isNotEmpty == true
                          ? user.displayName![0]
                          : user.email?[0] ?? '?')
                      .toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (user.displayName?.isNotEmpty == true)
                      Text(user.displayName!,
                          style:
                              const TextStyle(fontWeight: FontWeight.w600)),
                    if (user.email != null)
                      Text(user.email!,
                          style: const TextStyle(
                              fontSize: 13, color: Colors.black54)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F3F5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPremium ? s.premiumPlan : s.freePlan,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isPremium
                            ? const Color(0xFFFFB300)
                            : const Color(0xFF2C3E50),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isPremium
                          ? s.unlimitedLookup
                          : s.monthlyUsage(used, limit),
                      style: const TextStyle(
                          fontSize: 13, color: Colors.black54),
                    ),
                  ],
                ),
                if (!isPremium)
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const PaywallScreen(),
                        fullscreenDialog: true,
                      ));
                    },
                    child: Text(s.upgrade),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _isLoading ? null : _signOut,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(s.signOut),
            ),
          ),
        ],
      ),
    );
  }
}
