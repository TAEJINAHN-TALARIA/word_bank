class Word {
  final int? id;
  final String word;
  final String? phonetic;
  final String meaning;
  final String? context;
  final List<String> tags;
  final DateTime createdAt;

  Word({
    this.id,
    required this.word,
    this.phonetic,
    required this.meaning,
    this.context,
    this.tags = const [],
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'word': word,
        'phonetic': phonetic,
        'meaning': meaning,
        'context': context,
        'tags': tags.join(','),
        'created_at': createdAt.toIso8601String(),
      };

  factory Word.fromMap(Map<String, dynamic> map) => Word(
        id: map['id'] as int?,
        word: map['word'] as String,
        phonetic: map['phonetic'] as String?,
        meaning: map['meaning'] as String,
        context: map['context'] as String?,
        tags: map['tags'] != null && (map['tags'] as String).isNotEmpty
            ? (map['tags'] as String).split(',')
            : [],
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
