import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/word.dart';
import '../services/word_sync_service.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Box? _box;

  static const _kPendingUpsert = 'pending_upsert_ids';
  static const _kPendingDelete = 'pending_delete_ids';

  // 동기화 실패한 ID 추적 — 앱 재시작 후에도 유지됨
  final Set<int> _pendingUpsertIds = {};
  final Set<int> _pendingDeleteIds = {};

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
    // 이전 세션에서 실패한 pending ID 복원
    final prefs = await SharedPreferences.getInstance();
    final upsertList = prefs.getStringList(_kPendingUpsert) ?? [];
    final deleteList = prefs.getStringList(_kPendingDelete) ?? [];
    instance._pendingUpsertIds.addAll(upsertList.map(int.parse));
    instance._pendingDeleteIds.addAll(deleteList.map(int.parse));
  }

  Future<void> _savePendingIds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        _kPendingUpsert, _pendingUpsertIds.map((e) => e.toString()).toList());
    await prefs.setStringList(
        _kPendingDelete, _pendingDeleteIds.map((e) => e.toString()).toList());
  }

  Future<Box> get _openBox async {
    _box ??= await Hive.openBox('words');
    return _box!;
  }

  void _syncUpsert(Word word) {
    WordSyncService.upsertWord(word).catchError((Object e) {
      debugPrint('Sync upsert failed, queuing retry for id=${word.id}: $e');
      if (word.id != null) {
        _pendingUpsertIds.add(word.id!);
        _savePendingIds();
      }
    });
  }

  void _syncDelete(int id) {
    WordSyncService.deleteWord(id).catchError((Object e) {
      debugPrint('Sync delete failed, queuing retry for id=$id: $e');
      _pendingDeleteIds.add(id);
      _savePendingIds();
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

    await _savePendingIds();
  }

  Future<void> insertWord(Word word) async {
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
      updatedAt: DateTime.parse(now),
    );
    _wordIndex.add(word.word.toLowerCase());
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
      'updated_at': DateTime.now().toIso8601String(),
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
    _syncDelete(key);
  }

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
