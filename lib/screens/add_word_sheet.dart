import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../db/database_helper.dart';
import '../models/word.dart';
import '../services/api_client.dart';
import '../services/language_prefs.dart';
import 'paywall_screen.dart';

class AddWordSheet extends StatefulWidget {
  const AddWordSheet({super.key});

  @override
  State<AddWordSheet> createState() => _AddWordSheetState();
}

class _AddWordSheetState extends State<AddWordSheet> {
  bool _showContextField = false;
  bool _isLoading = false;
  bool _notFound = false;
  bool _isManualEntry = false;
  bool _networkError = false;
  String? _networkErrorDetail;
  String? _searchResult;
  String? _phonetic;
  List<String> _existingTags = [];
  List<String> _wordSuggestions = [];
  Timer? _debounce;

  String _definitionLanguage = 'English';
  String? _exampleLanguage; // null = same as input word

  // Manual entry
  String _manualPos = 'noun';
  final _manualMeaningController = TextEditingController();
  final _manualExampleController = TextEditingController();

  final _wordController = TextEditingController();
  final _contextController = TextEditingController();
  final _tagController = TextEditingController();
  final List<String> _tags = [];

  static const _posList = ['noun', 'verb', 'adjective', 'adverb', 'other'];

  @override
  void initState() {
    super.initState();
    _loadExistingTags();
    _loadLanguagePrefs();
    _manualMeaningController.addListener(() => setState(() {}));
  }

  Future<void> _loadLanguagePrefs() async {
    final defLang = await LanguagePrefs.getDefinitionLanguage();
    final exLang = await LanguagePrefs.getExampleLanguage();
    if (mounted) {
      setState(() {
        _definitionLanguage = defLang;
        _exampleLanguage = exLang;
      });
    }
  }

  Future<void> _loadExistingTags() async {
    final words = await DatabaseHelper.instance.getAllWords();
    final tags = words.expand((w) => w.tags).toSet().toList()..sort();
    if (mounted) setState(() => _existingTags = tags);
  }

  void _onWordChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    final trimmed = value.trim();
    if (trimmed.length < 2) {
      setState(() => _wordSuggestions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _fetchSuggestions(trimmed);
    });
  }

  Future<void> _fetchSuggestions(String prefix) async {
    try {
      final url = Uri.parse(
          'https://api.datamuse.com/sug?s=${Uri.encodeComponent(prefix)}');
      final response = await http.get(url);
      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body) as List;
        setState(() => _wordSuggestions =
            data.take(6).map((e) => e['word'] as String).toList());
      }
    } catch (_) {
      // 자동완성 실패는 UX에 치명적이지 않으므로 조용히 무시
    }
  }

  Future<void> _fetchMeaning() async {
    final word = _wordController.text.trim();
    if (word.isEmpty) return;

    setState(() {
      _isLoading = true;
      _searchResult = null;
      _phonetic = null;
      _notFound = false;
      _networkError = false;
      _networkErrorDetail = null;
      _wordSuggestions = [];
    });

    try {
      final result = await lookupWord(
        word: word,
        definitionLanguage: _definitionLanguage,
        exampleLanguage: _exampleLanguage,
      );
      if (mounted) {
        setState(() {
          _searchResult = result.meaningText;
          _phonetic = result.phonetic;
        });
        _wordController.text = result.word;
      }
    } on LookupNotFoundException {
      if (mounted) setState(() => _notFound = true);
    } on LookupRateLimitException {
      if (mounted) setState(() => _notFound = true);
    } on LookupQuotaExceededException {
      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.of(context).pop();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const PaywallScreen(),
            fullscreenDialog: true,
          ),
        );
      }
      return;
    } on SocketException catch (e) {
      if (mounted) setState(() { _networkError = true; _networkErrorDetail = 'SocketException: $e'; });
    } on http.ClientException catch (e) {
      if (mounted) setState(() { _networkError = true; _networkErrorDetail = 'ClientException: $e'; });
    } on TimeoutException catch (e) {
      if (mounted) setState(() { _networkError = true; _networkErrorDetail = 'TimeoutException: $e'; });
    } catch (e, st) {
      if (mounted) setState(() { _networkError = true; _networkErrorDetail = '${e.runtimeType}: $e\n$st'; });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _selectSuggestion(String word) {
    _wordController.text = word;
    setState(() => _wordSuggestions = []);
    _fetchMeaning();
  }

  void _enterManually() {
    setState(() {
      _isManualEntry = true;
      _notFound = false;
      _wordSuggestions = [];
    });
  }

  void _addTag(String tag) {
    final trimmed = tag.trim();
    if (trimmed.isNotEmpty && !_tags.contains(trimmed)) {
      setState(() => _tags.add(trimmed));
    }
    _tagController.clear();
  }

  Future<bool> _confirmSaveDespiteDuplicate(String wordText) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Already in Word Bank'),
            content: Text(
                '"$wordText" is already saved. Save another copy anyway?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF2C3E50)),
                child: const Text('Save anyway'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _saveWord() async {
    final wordText = _wordController.text.trim();
    if (wordText.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a word before saving.')),
        );
      }
      return;
    }

    if (await DatabaseHelper.instance.wordExists(wordText)) {
      if (!mounted) return;
      final confirmed = await _confirmSaveDespiteDuplicate(wordText);
      if (!confirmed) return;
    }
    final word = Word(
      word: wordText,
      phonetic: _phonetic,
      meaning: _searchResult!,
      context: _contextController.text.trim().isNotEmpty
          ? _contextController.text.trim()
          : null,
      tags: _tags,
    );
    await DatabaseHelper.instance.insertWord(word);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _saveManualWord() async {
    final meaning = _manualMeaningController.text.trim();
    if (meaning.isEmpty) return;

    final wordText = _wordController.text.trim();
    if (wordText.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a word before saving.')),
        );
      }
      return;
    }

    if (await DatabaseHelper.instance.wordExists(wordText)) {
      if (!mounted) return;
      final confirmed = await _confirmSaveDespiteDuplicate(wordText);
      if (!confirmed) return;
    }

    final buffer = StringBuffer();
    buffer.writeln('[$_manualPos]');
    buffer.writeln(meaning);
    final example = _manualExampleController.text.trim();
    if (example.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Example: $example');
    }

    final word = Word(
      word: wordText,
      meaning: buffer.toString().trim(),
      context: _contextController.text.trim().isNotEmpty
          ? _contextController.text.trim()
          : null,
      tags: _tags,
    );
    await DatabaseHelper.instance.insertWord(word);
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _wordController.dispose();
    _contextController.dispose();
    _tagController.dispose();
    _manualMeaningController.dispose();
    _manualExampleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
        left: 24,
        right: 24,
        top: 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Save a New Word',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          if (_searchResult != null) ...[
            // ── API result view ──────────────────────────────────
            TextField(
              controller: _wordController,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C3E50),
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            if (_phonetic != null)
              Text(
                _phonetic!,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black45,
                  fontStyle: FontStyle.italic,
                ),
              ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F3F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _searchResult!,
                style: const TextStyle(
                    fontSize: 15, height: 1.5, color: Color(0xFF2C3E50)),
              ),
            ),
            const SizedBox(height: 16),
            ..._tagSection(),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _saveWord,
              icon: const Icon(Icons.inventory_2_outlined),
              label: const Text('Save to Word Bank',
                  style: TextStyle(fontSize: 16)),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: const Color(0xFF2C3E50),
              ),
            ),
          ] else if (_isManualEntry) ...[
            // ── Manual entry view ────────────────────────────────
            TextField(
              controller: _wordController,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C3E50),
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                hintText: 'Word',
              ),
            ),
            const SizedBox(height: 16),

            // POS selector
            const Text('Part of speech',
                style: TextStyle(fontSize: 12, color: Colors.black45)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: _posList.map((pos) {
                final selected = _manualPos == pos;
                return ChoiceChip(
                  label: Text(pos),
                  selected: selected,
                  onSelected: (_) => setState(() => _manualPos = pos),
                  selectedColor: const Color(0xFF2C3E50),
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : Colors.black87,
                    fontSize: 13,
                  ),
                  checkmarkColor: Colors.white,
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            TextField(
              controller: _manualMeaningController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Definition',
                hintText: 'What does this word mean?',
                floatingLabelBehavior: FloatingLabelBehavior.always,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _manualExampleController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Example sentence (optional)',
                hintText: 'e.g. The term is used in chapter 3.',
                floatingLabelBehavior: FloatingLabelBehavior.always,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            ..._tagSection(),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _manualMeaningController.text.trim().isNotEmpty
                  ? _saveManualWord
                  : null,
              icon: const Icon(Icons.inventory_2_outlined),
              label: const Text('Save to Word Bank',
                  style: TextStyle(fontSize: 16)),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: const Color(0xFF2C3E50),
              ),
            ),
          ] else ...[
            // ── Search view ──────────────────────────────────────
            TextField(
              controller: _wordController,
              autofocus: true,
              enabled: !_isLoading,
              onChanged: _onWordChanged,
              decoration: const InputDecoration(
                labelText: 'Word',
                hintText: 'Enter a word — we\'ll look up the meaning.',
                floatingLabelBehavior: FloatingLabelBehavior.always,
                border: OutlineInputBorder(),
              ),
            ),

            if (_wordSuggestions.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFCDD5DE)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(13),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: _wordSuggestions.map((word) {
                    final isLast = word == _wordSuggestions.last;
                    return InkWell(
                      onTap: () => _selectSuggestion(word),
                      borderRadius: BorderRadius.vertical(
                        top: word == _wordSuggestions.first
                            ? const Radius.circular(8)
                            : Radius.zero,
                        bottom:
                            isLast ? const Radius.circular(8) : Radius.zero,
                      ),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 11),
                        decoration: BoxDecoration(
                          border: isLast
                              ? null
                              : const Border(
                                  bottom: BorderSide(
                                      color: Color(0xFFF1F3F5))),
                        ),
                        child: Text(
                          word,
                          style: const TextStyle(
                              fontSize: 15, color: Color(0xFF2C3E50)),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

            if (_networkError) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFEF9A9A)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.wifi_off, size: 16, color: Color(0xFFC62828)),
                        SizedBox(width: 6),
                        Text(
                          'Network error',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFC62828)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Check your internet connection and try again.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF5D4037)),
                    ),
                    if (_networkErrorDetail != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        _networkErrorDetail!,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF5D4037), fontFamily: 'monospace'),
                      ),
                    ],
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _enterManually,
                      child: const Text(
                        'Enter the definition yourself →',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF2C3E50),
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (_notFound) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFFCC80)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'No definition found for "${_wordController.text.trim()}".',
                      style: const TextStyle(
                          fontSize: 14, color: Color(0xFF5D4037)),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _enterManually,
                      child: const Text(
                        'Enter the definition yourself →',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF2C3E50),
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            if (!_showContextField)
              TextButton.icon(
                onPressed: _isLoading
                    ? null
                    : () => setState(() => _showContextField = true),
                icon: const Icon(Icons.add_comment_outlined, size: 18),
                label: const Text('Add context sentence (optional)'),
                style: TextButton.styleFrom(alignment: Alignment.centerLeft),
              )
            else
              TextField(
                controller: _contextController,
                enabled: !_isLoading,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Context (optional)',
                  hintText: 'Paste the sentence where you found it.',
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  border: OutlineInputBorder(),
                ),
              ),

            const SizedBox(height: 16),
            _LanguageRow(
              definitionLanguage: _definitionLanguage,
              exampleLanguage: _exampleLanguage,
              onDefinitionChanged: (lang) async {
                setState(() => _definitionLanguage = lang);
                await LanguagePrefs.setDefinitionLanguage(lang);
              },
              onExampleChanged: (lang) async {
                setState(() => _exampleLanguage = lang);
                await LanguagePrefs.setExampleLanguage(lang);
              },
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _isLoading ? null : _fetchMeaning,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: const Color(0xFF2C3E50),
              ),
              child: _isLoading
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2)),
                        SizedBox(width: 12),
                        Text('Looking up definition...',
                            style: TextStyle(fontSize: 15)),
                      ],
                    )
                  : const Text('Look Up Definition',
                      style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: _isLoading ? null : _enterManually,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: Color(0xFFCDD5DE)),
                foregroundColor: Colors.black54,
              ),
              child: const Text('Enter manually',
                  style: TextStyle(fontSize: 15)),
            ),
          ],
        ],
      ),
    );
  }


  List<Widget> _tagSection() {
    return [
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _tagController,
              decoration: const InputDecoration(
                labelText: 'Add tags (optional)',
                hintText: 'e.g. literature, philosophy',
                floatingLabelBehavior: FloatingLabelBehavior.always,
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: _addTag,
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: () => _addTag(_tagController.text),
            icon: const Icon(Icons.add),
            style: IconButton.styleFrom(
                backgroundColor: const Color(0xFF2C3E50)),
          ),
        ],
      ),
      if (_tags.isNotEmpty) ...[
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          children: _tags
              .map((tag) => Chip(
                    label: Text(tag),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () => setState(() => _tags.remove(tag)),
                    backgroundColor: const Color(0xFFDDE3EA),
                  ))
              .toList(),
        ),
      ],
      () {
        final suggestions =
            _existingTags.where((t) => !_tags.contains(t)).toList();
        if (suggestions.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            const Text('Previous tags',
                style: TextStyle(fontSize: 12, color: Colors.black45)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: suggestions
                  .map((tag) => ActionChip(
                        label: Text(tag,
                            style: const TextStyle(fontSize: 12)),
                        onPressed: () => _addTag(tag),
                        backgroundColor: Colors.white,
                        side:
                            const BorderSide(color: Color(0xFFCDD5DE)),
                        padding: EdgeInsets.zero,
                      ))
                  .toList(),
            ),
          ],
        );
      }(),
    ];
  }
}

/// Compact row showing the current definition + example language with tap-to-change.
class _LanguageRow extends StatelessWidget {
  final String definitionLanguage;
  final String? exampleLanguage;
  final void Function(String) onDefinitionChanged;
  final void Function(String?) onExampleChanged;

  const _LanguageRow({
    required this.definitionLanguage,
    required this.exampleLanguage,
    required this.onDefinitionChanged,
    required this.onExampleChanged,
  });

  void _pickDefinitionLanguage(BuildContext context) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Text('Definition language',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const Divider(height: 1),
            ...LanguagePrefs.supported.map((lang) => ListTile(
                  title: Text(lang),
                  trailing: lang == definitionLanguage
                      ? const Icon(Icons.check, size: 20)
                      : null,
                  onTap: () => Navigator.pop(ctx, lang),
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (result != null) onDefinitionChanged(result);
  }

  void _pickExampleLanguage(BuildContext context) async {
    final options = <String?>[null, ...LanguagePrefs.supported];
    final labels = ['Same as word', ...LanguagePrefs.supported];

    final result = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Text('Example & synonyms language',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const Divider(height: 1),
            ...List.generate(options.length, (i) {
              final isSelected = options[i] == exampleLanguage;
              return ListTile(
                title: Text(labels[i]),
                trailing: isSelected
                    ? const Icon(Icons.check, size: 20)
                    : null,
                onTap: () =>
                    Navigator.pop(ctx, options[i] ?? '\x00'),
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (result != null) {
      onExampleChanged(result == '\x00' ? null : result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final exLabel = exampleLanguage ?? 'Same as word';
    return Row(
      children: [
        const Icon(Icons.translate, size: 14, color: Colors.black38),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: () => _pickDefinitionLanguage(context),
          child: _LangChip(label: definitionLanguage, hint: 'Definition'),
        ),
        const SizedBox(width: 6),
        const Text('·', style: TextStyle(color: Colors.black38)),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: () => _pickExampleLanguage(context),
          child: _LangChip(label: exLabel, hint: 'Examples'),
        ),
      ],
    );
  }
}

class _LangChip extends StatelessWidget {
  final String label;
  final String hint;

  const _LangChip({required this.label, required this.hint});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3F5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFCDD5DE)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF2C3E50),
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.arrow_drop_down,
              size: 16, color: Color(0xFF2C3E50)),
        ],
      ),
    );
  }
}
