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
import 'paywall_screen.dart';
import 'word_detail_sheet.dart';

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

  @override
  void initState() {
    super.initState();
    _loadWords();
    _refreshSubscription();
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
      builder: (_) => const _SettingsSheet(),
    );
  }

  void _showAccountSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AccountSheet(onRefresh: _refreshSubscription),
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
                decoration: const InputDecoration(
                  hintText: 'Search words...',
                  border: InputBorder.none,
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              )
            : const Text('Word Bank',
                style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: !_isSearching,
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
                    tooltip: 'Random word',
                    onPressed: _showRandomWord,
                  ),
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  tooltip: 'Settings',
                  onPressed: _showSettings,
                ),
                if (FirebaseAuth.instance.currentUser != null)
                  IconButton(
                    icon: const Icon(Icons.account_circle_outlined),
                    tooltip: 'Account',
                    onPressed: _showAccountSheet,
                  ),
              ],
      ),
      body: Column(
        children: [
          _UsageBanner(onUpgrade: () async {
            final upgraded = await Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder: (_) => const PaywallScreen(),
                fullscreenDialog: true,
              ),
            );
            if (upgraded == true) _refreshSubscription();
          }),
          Expanded(child: _buildBody()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddWordSheet,
        icon: const Icon(Icons.add),
        label: const Text('Add Word'),
      ),
    );
  }

  Widget _buildBody() {
    return _words.isEmpty
        ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                  'No words saved yet.\nFind an unfamiliar word while reading?\nAdd it to your Word Bank.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
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
                          label: const Text('All'),
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
                                ? 'No results for "$_searchQuery".'
                                : 'No words with this tag.',
                            style:
                                const TextStyle(color: Colors.black45),
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
                              onDeleted: _loadWords,
                            );
                          },
                        ),
                ),
              ],
            );
  }
}

class _WordCard extends StatelessWidget {
  final Word word;
  final VoidCallback onDeleted;

  const _WordCard({required this.word, required this.onDeleted});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: const Color(0xFFF1F3F5),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            shape: const RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (_) =>
                WordDetailSheet(word: word, onUpdated: onDeleted),
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
                          title: const Text('Delete word?'),
                          content: Text(
                              'Remove "${word.word}" from your Word Bank?'),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.pop(ctx, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () =>
                                  Navigator.pop(ctx, true),
                              style: TextButton.styleFrom(
                                  foregroundColor: Colors.red),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true && context.mounted) {
                        await DatabaseHelper.instance
                            .deleteWord(word.id!);
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

class _SettingsSheet extends StatefulWidget {
  const _SettingsSheet();

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  String _definitionLanguage = 'English';
  String? _exampleLanguage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final def = await LanguagePrefs.getDefinitionLanguage();
    final ex = await LanguagePrefs.getExampleLanguage();
    if (mounted) setState(() {
      _definitionLanguage = def;
      _exampleLanguage = ex;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Settings',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),

          const Text('Definition language',
              style: TextStyle(fontSize: 12, color: Colors.black45)),
          const SizedBox(height: 8),
          _LangDropdown(
            value: _definitionLanguage,
            options: LanguagePrefs.supported,
            onChanged: (lang) async {
              setState(() => _definitionLanguage = lang);
              await LanguagePrefs.setDefinitionLanguage(lang);
            },
          ),

          const SizedBox(height: 20),

          const Text('Examples & synonyms language',
              style: TextStyle(fontSize: 12, color: Colors.black45)),
          const SizedBox(height: 8),
          _LangDropdown(
            value: _exampleLanguage,
            options: LanguagePrefs.supported,
            noneLabel: 'Same as word',
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
      value: value,
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

// ─── 사용량 배너 ───
class _UsageBanner extends StatelessWidget {
  final VoidCallback onUpgrade;

  const _UsageBanner({required this.onUpgrade});

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
                  ? '이번 달 무료 조회 한도 도달 ($used/$limit)'
                  : '이번 달 AI 조회: $used/$limit',
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
                'Premium 업그레이드',
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

// ─── 계정 시트 ───
class _AccountSheet extends StatefulWidget {
  final VoidCallback onRefresh;

  const _AccountSheet({required this.onRefresh});

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

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isPremium = SubscriptionService.isPremium;
    final used = SubscriptionService.monthlyCount;
    final limit = SubscriptionService.freeLimit;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('계정',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFF2C3E50),
                child: Text(
                  (user?.displayName?.isNotEmpty == true
                          ? user!.displayName![0]
                          : user?.email?[0] ?? '?')
                      .toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (user?.displayName?.isNotEmpty == true)
                      Text(user!.displayName!,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (user?.email != null)
                      Text(user!.email!,
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
                      isPremium ? 'Premium 플랜' : '무료 플랜',
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
                          ? '무제한 AI 조회'
                          : '이번 달 조회: $used / $limit',
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
                    child: const Text('업그레이드'),
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
                  : const Text('로그아웃'),
            ),
          ),
        ],
      ),
    );
  }
}
