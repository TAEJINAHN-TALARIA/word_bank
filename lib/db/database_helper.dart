import 'package:hive_flutter/hive_flutter.dart';
import '../models/word.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Box? _box;

  // wordExists() O(1) 조회를 위한 인메모리 인덱스
  final Set<String> _wordIndex = {};

  DatabaseHelper._init();

  static Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox('words');
    // 기존 데이터로 인덱스 초기화
    for (final v in _box!.values) {
      final word = (Map<String, dynamic>.from(v as Map)['word'] as String?)?.toLowerCase();
      if (word != null) instance._wordIndex.add(word);
    }
  }

  Future<Box> get _openBox async {
    _box ??= await Hive.openBox('words');
    return _box!;
  }

  /// 단어를 로컬 DB에 저장하고 ID가 부여된 [Word]를 반환합니다.
  Future<Word> insertWord(Word word) async {
    final box = await _openBox;
    final now = DateTime.now().toIso8601String();
    final id = await box.add({
      'word': word.word,
      'phonetic': word.phonetic,
      'meaning': word.meaning,
      'meaning_json': word.meaningJson,
      'media': word.media,
      'context': word.context,
      'tags': word.tags.join(','),
      'created_at': word.createdAt.toIso8601String(),
      'updated_at': now,
    });
    _wordIndex.add(word.word.toLowerCase());
    return Word(
      id: id,
      word: word.word,
      phonetic: word.phonetic,
      meaning: word.meaning,
      meaningJson: word.meaningJson,
      media: word.media,
      context: word.context,
      tags: word.tags,
      createdAt: word.createdAt,
      updatedAt: DateTime.parse(now),
    );
  }

  Future<void> updateWord(Word word) async {
    final box = await _openBox;
    await box.put(word.id, {
      'word': word.word,
      'phonetic': word.phonetic,
      'meaning': word.meaning,
      'meaning_json': word.meaningJson,
      'media': word.media,
      'context': word.context,
      'tags': word.tags.join(','),
      'created_at': word.createdAt.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Word>> getAllWords() async {
    final box = await _openBox;
    final words = <Word>[];
    for (final key in box.keys) {
      final map = Map<String, dynamic>.from(box.get(key) as Map);
      map['id'] = key as int;
      words.add(Word.fromMap(map));
    }
    words.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return words;
  }

  Future<bool> wordExists(String word) async {
    return _wordIndex.contains(word.toLowerCase());
  }

  Future<void> deleteWord(int key) async {
    final box = await _openBox;
    final raw = box.get(key);
    if (raw != null) {
      final word = (Map<String, dynamic>.from(raw as Map)['word'] as String?)?.toLowerCase();
      if (word != null) _wordIndex.remove(word);
    }
    await box.delete(key);
  }

  /// 클라우드에서 받아온 단어를 로컬에 저장합니다. sync를 트리거하지 않습니다.
  Future<void> upsertWordFromCloud(Word word) async {
    if (word.id == null) return;
    final box = await _openBox;
    _wordIndex.add(word.word.toLowerCase());
    await box.put(word.id, {
      'word': word.word,
      'phonetic': word.phonetic,
      'meaning': word.meaning,
      'meaning_json': word.meaningJson,
      'media': word.media,
      'context': word.context,
      'tags': word.tags.join(','),
      'created_at': word.createdAt.toIso8601String(),
      'updated_at': word.updatedAt.toIso8601String(),
    });
  }
}
