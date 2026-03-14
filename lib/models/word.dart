class Word {
  final int? id;
  final String word;
  final String? phonetic;
  final String meaning;
  final Map<String, dynamic>? meaningJson;
  final List<Map<String, dynamic>> media;
  final String? context;
  final List<String> tags;
  final DateTime createdAt;

  Word({
    this.id,
    required this.word,
    this.phonetic,
    required this.meaning,
    this.meaningJson,
    this.media = const [],
    this.context,
    this.tags = const [],
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'word': word,
        'phonetic': phonetic,
        'meaning': meaning,
        'meaning_json': meaningJson,
        'media': media,
        'context': context,
        'tags': tags.join(','),
        'created_at': createdAt.toIso8601String(),
      };

  factory Word.fromMap(Map<String, dynamic> map) => Word(
        id: map['id'] as int?,
        word: map['word'] as String,
        phonetic: map['phonetic'] as String?,
        meaning: map['meaning'] as String,
        meaningJson: map['meaning_json'] != null
            ? Map<String, dynamic>.from(map['meaning_json'] as Map)
            : null,
        media: (map['media'] as List?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            const [],
        context: map['context'] as String?,
        tags: map['tags'] != null && (map['tags'] as String).isNotEmpty
            ? (map['tags'] as String).split(',')
            : [],
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
