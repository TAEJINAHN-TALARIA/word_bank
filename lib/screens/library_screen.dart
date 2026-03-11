import 'dart:math';
import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/word.dart';
import '../services/language_prefs.dart';
import '../widgets/meaning_display.dart';
import 'add_word_sheet.dart';
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
              ],
      ),
      body: _words.isEmpty
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
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddWordSheet,
        icon: const Icon(Icons.add),
        label: const Text('Add Word'),
      ),
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
