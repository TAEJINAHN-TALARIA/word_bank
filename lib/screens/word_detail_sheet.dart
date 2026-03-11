import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/word.dart';
import '../widgets/meaning_display.dart';

class WordDetailSheet extends StatefulWidget {
  final Word word;
  final VoidCallback onUpdated;

  const WordDetailSheet(
      {super.key, required this.word, required this.onUpdated});

  @override
  State<WordDetailSheet> createState() => _WordDetailSheetState();
}

class _WordDetailSheetState extends State<WordDetailSheet> {
  bool _isEditing = false;
  late List<String> _tags;
  late TextEditingController _contextController;
  final _tagController = TextEditingController();
  List<String> _existingTags = [];

  @override
  void initState() {
    super.initState();
    _tags = List.from(widget.word.tags);
    _contextController =
        TextEditingController(text: widget.word.context ?? '');
    _loadExistingTags();
  }

  Future<void> _loadExistingTags() async {
    final words = await DatabaseHelper.instance.getAllWords();
    final tags = words.expand((w) => w.tags).toSet().toList()..sort();
    if (mounted) setState(() => _existingTags = tags);
  }

  void _addTag(String tag) {
    final trimmed = tag.trim();
    if (trimmed.isNotEmpty && !_tags.contains(trimmed)) {
      setState(() => _tags.add(trimmed));
    }
    _tagController.clear();
  }

  Future<void> _saveChanges() async {
    final updated = Word(
      id: widget.word.id,
      word: widget.word.word,
      phonetic: widget.word.phonetic,
      meaning: widget.word.meaning,
      context: _contextController.text.trim().isNotEmpty
          ? _contextController.text.trim()
          : null,
      tags: _tags,
      createdAt: widget.word.createdAt,
    );
    await DatabaseHelper.instance.updateWord(updated);
    widget.onUpdated();
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _contextController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
        left: 24,
        right: 24,
        top: 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Word header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.word.word,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                    if (widget.word.phonetic != null)
                      Text(
                        widget.word.phonetic!,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.black45,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () => setState(() {
                  _isEditing = !_isEditing;
                  if (!_isEditing) {
                    _tags = List.from(widget.word.tags);
                    _contextController.text = widget.word.context ?? '';
                  }
                }),
                icon: Icon(
                    _isEditing ? Icons.close : Icons.edit_outlined,
                    size: 18),
                label: Text(_isEditing ? 'Cancel' : 'Edit'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Meaning
          MeaningDetailDisplay(meaning: widget.word.meaning),

          // View mode: context + tags
          if (!_isEditing) ...[
            if (widget.word.context != null) ...[
              const SizedBox(height: 14),
              const Text('Context',
                  style: TextStyle(fontSize: 12, color: Colors.black45)),
              const SizedBox(height: 4),
              Text(
                '"${widget.word.context!}"',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                  fontStyle: FontStyle.italic,
                  height: 1.5,
                ),
              ),
            ],
            if (widget.word.tags.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 6,
                children: widget.word.tags
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

          // Edit mode
          if (_isEditing) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _contextController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Context (optional)',
                hintText: 'Paste the sentence where you found it.',
                floatingLabelBehavior: FloatingLabelBehavior.always,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _tagController,
                    decoration: const InputDecoration(
                      labelText: 'Tags',
                      hintText: 'Add a tag',
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
                          onDeleted: () =>
                              setState(() => _tags.remove(tag)),
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
                      style:
                          TextStyle(fontSize: 12, color: Colors.black45)),
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
                              side: const BorderSide(
                                  color: Color(0xFFCDD5DE)),
                              padding: EdgeInsets.zero,
                            ))
                        .toList(),
                  ),
                ],
              );
            }(),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saveChanges,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: const Color(0xFF2C3E50),
              ),
              child: const Text('Save Changes',
                  style: TextStyle(fontSize: 16)),
            ),
          ],
        ],
      ),
    );
  }
}
