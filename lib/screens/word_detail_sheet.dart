import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/word.dart';
import '../services/tts_service.dart';
import '../services/word_sync_service.dart';
import '../utils/media_utils.dart';
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
  final _imageUrlController = TextEditingController();
  final _youtubeUrlController = TextEditingController();
  List<Map<String, dynamic>> _mediaItems = [];

  @override
  void initState() {
    super.initState();
    _tags = List.from(widget.word.tags);
    _mediaItems =
        widget.word.media.map((e) => Map<String, dynamic>.from(e)).toList();
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

  void _addMediaItem(String type, String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      _mediaItems.add({'type': type, 'url': trimmed});
    });
  }

  void _addImageUrl() {
    _addMediaItem('image', _imageUrlController.text);
    _imageUrlController.clear();
  }

  void _addYoutubeUrl() {
    _addMediaItem('youtube', _youtubeUrlController.text);
    _youtubeUrlController.clear();
  }


  Future<void> _saveChanges() async {
    final updatedMeaningJson = widget.word.meaningJson != null
        ? {
            ...widget.word.meaningJson!,
            'media': buildMediaPayload(_mediaItems),
          }
        : null;
    final updated = Word(
      id: widget.word.id,
      word: widget.word.word,
      phonetic: widget.word.phonetic,
      meaning: widget.word.meaning,
      meaningJson: updatedMeaningJson,
      media: _mediaItems,
      context: _contextController.text.trim().isNotEmpty
          ? _contextController.text.trim()
          : null,
      tags: _tags,
      createdAt: widget.word.createdAt,
    );
    await DatabaseHelper.instance.updateWord(updated);
    WordSyncService.upsertWordQueued(updated);
    widget.onUpdated();
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _contextController.dispose();
    _tagController.dispose();
    _imageUrlController.dispose();
    _youtubeUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).viewPadding.bottom +
            32,
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
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          widget.word.word,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2C3E50),
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          onPressed: () =>
                              TtsService.instance.speak(widget.word.word),
                          icon: const Icon(Icons.volume_up_outlined),
                          iconSize: 22,
                          color: Colors.black38,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
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
                    _mediaItems = widget.word.media
                        .map((e) => Map<String, dynamic>.from(e))
                        .toList();
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
            if (widget.word.media.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text('Media',
                  style: TextStyle(fontSize: 12, color: Colors.black45)),
              const SizedBox(height: 6),
              _MediaSection(items: widget.word.media),
            ],
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
            const SizedBox(height: 12),
            const Text('Media',
                style: TextStyle(fontSize: 12, color: Colors.black45)),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _imageUrlController,
                    decoration: const InputDecoration(
                      labelText: 'Image URL',
                      hintText: 'https://...',
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _addImageUrl,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF2C3E50)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _youtubeUrlController,
                    decoration: const InputDecoration(
                      labelText: 'YouTube URL',
                      hintText: 'https://youtu.be/...',
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _addYoutubeUrl,
                  icon: const Icon(Icons.ondemand_video_outlined),
                  style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF2C3E50)),
                ),
              ],
            ),
            if (_mediaItems.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: _mediaItems.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final item = entry.value;
                  final label = '${item['type']}: ${item['url']}';
                  return Chip(
                    label: Text(label, style: const TextStyle(fontSize: 12)),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () =>
                        setState(() => _mediaItems.removeAt(idx)),
                    backgroundColor: const Color(0xFFEFF3F6),
                  );
                }).toList(),
              ),
            ],
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

class _MediaSection extends StatelessWidget {
  final List<Map<String, dynamic>> items;

  const _MediaSection({required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items.map((item) {
        final type = item['type'] as String? ?? 'link';
        final url = item['url'] as String? ?? '';
        if (type == 'image') {
          return _MediaCard(
            icon: Icons.image_outlined,
            title: 'Image',
            url: url,
            preview: Image.network(
              url,
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox(
                height: 160,
                child: Center(child: Icon(Icons.broken_image_outlined)),
              ),
            ),
          );
        }
        if (type == 'youtube') {
          final thumb = _youtubeThumbnail(url);
          return _MediaCard(
            icon: Icons.ondemand_video_outlined,
            title: 'YouTube',
            url: url,
            preview: thumb == null
                ? null
                : Image.network(
                    thumb,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox(
                      height: 160,
                      child:
                          Center(child: Icon(Icons.ondemand_video_outlined)),
                    ),
                  ),
          );
        }
        return _MediaCard(
          icon: Icons.link,
          title: 'Link',
          url: url,
        );
      }).toList(),
    );
  }

  String? _youtubeThumbnail(String url) {
    try {
      final uri = Uri.parse(url);
      String? id;
      if (uri.host.contains('youtu.be')) {
        id = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
      } else if (uri.host.contains('youtube.com')) {
        id = uri.queryParameters['v'];
      }
      if (id == null || id.isEmpty) return null;
      return 'https://img.youtube.com/vi/$id/0.jpg';
    } catch (_) {
      return null;
    }
  }
}

class _MediaCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String url;
  final Widget? preview;

  const _MediaCard({
    required this.icon,
    required this.title,
    required this.url,
    this.preview,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: const Color(0xFF2C3E50)),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF2C3E50),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (preview != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: preview!,
            ),
          ],
          if (url.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              url,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
