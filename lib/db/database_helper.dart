import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/word.dart';
import '../services/word_sync_service.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Box? _box;

  // 동기화 실패한 ID 추적 (upsert: 양수 id, delete: 음수로 인코딩)
  final Set<int> _pendingUpsertIds = {};
  final Set<int> _pendingDeleteIds = {};

  DatabaseHelper._init();

  static Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox('words');
  }

  Future<Box> get _openBox async {
    _box ??= await Hive.openBox('words');
    return _box!;
  }

  void _syncUpsert(Word word) {
    WordSyncService.upsertWord(word).catchError((Object e) {
      debugPrint('Sync upsert failed, queuing retry for id=${word.id}: $e');
      if (word.id != null) _pendingUpsertIds.add(word.id!);
    });
  }

  void _syncDelete(int id) {
    WordSyncService.deleteWord(id).catchError((Object e) {
      debugPrint('Sync delete failed, queuing retry for id=$id: $e');
      _pendingDeleteIds.add(id);
    });
  }

  /// 이전에 실패한 동기화를 재시도합니다. 앱 재시작 또는 네트워크 복구 시 호출하세요.
  Future<void> retryPendingSync() async {
    final box = await _openBox;

    final upsertIds = Set<int>.from(_pendingUpsertIds);
    for (final id in upsertIds) {
      final raw = box.get(id);
      if (raw == null) {
        _pendingUpsertIds.remove(id);
        continue;
      }
      final map = Map<String, dynamic>.from(raw as Map)..['id'] = id;
      final word = Word.fromMap(map);
      try {
        await WordSyncService.upsertWord(word);
        _pendingUpsertIds.remove(id);
      } catch (e) {
        debugPrint('Retry upsert still failed for id=$id: $e');
      }
    }

    final deleteIds = Set<int>.from(_pendingDeleteIds);
    for (final id in deleteIds) {
      try {
        await WordSyncService.deleteWord(id);
        _pendingDeleteIds.remove(id);
      } catch (e) {
        debugPrint('Retry delete still failed for id=$id: $e');
      }
    }
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
    _syncUpsert(synced);
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
    _syncUpsert(word);
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
    _syncDelete(key);
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
