import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../db/database_helper.dart';
import '../models/word.dart';

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
  String? _searchResult;
  String? _phonetic;
  List<String> _existingTags = [];
  List<String> _wordSuggestions = [];
  Timer? _debounce;

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
    _manualMeaningController.addListener(() => setState(() {}));
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
    } catch (_) {}
  }

  Future<void> _fetchMeaning() async {
    final word = _wordController.text.trim();
    if (word.isEmpty) return;

    setState(() {
      _isLoading = true;
      _searchResult = null;
      _phonetic = null;
      _notFound = false;
      _wordSuggestions = [];
    });

    try {
      final url = Uri.parse(
          'https://api.dictionaryapi.dev/api/v2/entries/en/${Uri.encodeComponent(word)}');
      final response = await http.get(url);

      if (response.statusCode == 404) {
        setState(() => _notFound = true);
        return;
      }

      final data = jsonDecode(response.body) as List;
      final entry = data.first as Map<String, dynamic>;
      final meanings = entry['meanings'] as List;

      String? phonetic = entry['phonetic'] as String?;
      if (phonetic == null) {
        final phonetics = entry['phonetics'] as List?;
        if (phonetics != null) {
          for (final p in phonetics) {
            final text = (p as Map<String, dynamic>)['text'] as String?;
            if (text != null && text.isNotEmpty) {
              phonetic = text;
              break;
            }
          }
        }
      }

      final buffer = StringBuffer();
      for (final meaning in meanings.take(2)) {
        final pos = meaning['partOfSpeech'] as String;
        final definitions = meaning['definitions'] as List;
        final firstDef = definitions.first as Map<String, dynamic>;

        buffer.writeln('[$pos]');
        buffer.writeln(firstDef['definition']);

        if (firstDef['example'] != null) {
          buffer.writeln();
          buffer.writeln('Example: ${firstDef['example']}');
        }

        final synonyms = (meaning['synonyms'] as List?)?.take(3).toList();
        if (synonyms != null && synonyms.isNotEmpty) {
          buffer.writeln();
          buffer.writeln('Synonyms: ${synonyms.join(', ')}');
        }

        buffer.writeln();
      }

      final canonical = entry['word'] as String?;
      setState(() {
        _searchResult = buffer.toString().trim();
        _phonetic = phonetic;
      });
      if (canonical != null) _wordController.text = canonical;
    } catch (e) {
      setState(() => _notFound = true);
    } finally {
      setState(() => _isLoading = false);
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

  Future<void> _saveWord() async {
    final word = Word(
      word: _wordController.text.trim(),
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

    final buffer = StringBuffer();
    buffer.writeln('[$_manualPos]');
    buffer.writeln(meaning);
    final example = _manualExampleController.text.trim();
    if (example.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Example: $example');
    }

    final word = Word(
      word: _wordController.text.trim(),
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

            if (_notFound) ...[
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
