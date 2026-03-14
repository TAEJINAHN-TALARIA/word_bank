import 'dart:async';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/word.dart';
import '../services/word_sync_service.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Box? _box;

  DatabaseHelper._init();

  static Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox('words');
  }

  Future<Box> get _openBox async {
    _box ??= await Hive.openBox('words');
    return _box!;
  }

  Future<void> insertWord(Word word) async {
    final box = await _openBox;
    final id = await box.add({
      'word': word.word,
      'phonetic': word.phonetic,
      'meaning': word.meaning,
      'meaning_json': word.meaningJson,
      'media': word.media,
      'context': word.context,
      'tags': word.tags.join(','),
      'created_at': word.createdAt.toIso8601String(),
    });
    final synced = Word(
      id: id,
      word: word.word,
      phonetic: word.phonetic,
      meaning: word.meaning,
      meaningJson: word.meaningJson,
      media: word.media,
      context: word.context,
      tags: word.tags,
      createdAt: word.createdAt,
    );
    unawaited(WordSyncService.upsertWord(synced));
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
    });
    unawaited(WordSyncService.upsertWord(word));
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
    final box = await _openBox;
    return box.values.any((v) {
      final map = Map<String, dynamic>.from(v as Map);
      return (map['word'] as String).toLowerCase() == word.toLowerCase();
    });
  }

  Future<void> deleteWord(int key) async {
    final box = await _openBox;
    await box.delete(key);
    unawaited(WordSyncService.deleteWord(key));
  }

  Future<void> upsertWordFromCloud(Word word) async {
    if (word.id == null) return;
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
    });
  }
}
