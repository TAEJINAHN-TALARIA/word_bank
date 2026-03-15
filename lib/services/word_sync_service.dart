import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/word.dart';

class WordSyncService {
  static const _kPendingUpsert = 'sync_pending_upsert_ids';
  static const _kPendingDelete = 'sync_pending_delete_ids';

  static final Set<int> _pendingUpsertIds = {};
  static final Set<int> _pendingDeleteIds = {};

  /// 앱 시작 시 한 번 호출해 이전 세션의 pending ID를 복원합니다.
  static Future<void> initPendingQueue() async {
    final prefs = await SharedPreferences.getInstance();
    _pendingUpsertIds.addAll(
        (prefs.getStringList(_kPendingUpsert) ?? []).map(int.parse));
    _pendingDeleteIds.addAll(
        (prefs.getStringList(_kPendingDelete) ?? []).map(int.parse));
  }

  static Future<void> _savePendingIds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        _kPendingUpsert, _pendingUpsertIds.map((e) => e.toString()).toList());
    await prefs.setStringList(
        _kPendingDelete, _pendingDeleteIds.map((e) => e.toString()).toList());
  }

  /// upsert를 시도하고 실패 시 pending queue에 등록합니다.
  static Future<void> upsertWordQueued(Word word) async {
    try {
      await upsertWord(word);
      if (word.id != null) _pendingUpsertIds.remove(word.id);
      await _savePendingIds();
    } catch (e) {
      debugPrint('Sync upsert failed, queuing retry for id=${word.id}: $e');
      if (word.id != null) {
        _pendingUpsertIds.add(word.id!);
        await _savePendingIds();
      }
    }
  }

  /// delete를 시도하고 실패 시 pending queue에 등록합니다.
  static Future<void> deleteWordQueued(int id) async {
    try {
      await deleteWord(id);
      _pendingDeleteIds.remove(id);
      await _savePendingIds();
    } catch (e) {
      debugPrint('Sync delete failed, queuing retry for id=$id: $e');
      _pendingDeleteIds.add(id);
      await _savePendingIds();
    }
  }

  /// 이전에 실패한 동기화를 재시도합니다.
  /// [allLocalWords]: 현재 로컬 DB의 모든 단어 목록 (upsert 재시도에 필요).
  static Future<void> retryPendingSync(List<Word> allLocalWords) async {
    final wordById = {
      for (final w in allLocalWords) if (w.id != null) w.id!: w
    };

    final upsertIds = Set<int>.from(_pendingUpsertIds);
    for (final id in upsertIds) {
      final word = wordById[id];
      if (word == null) {
        _pendingUpsertIds.remove(id);
        continue;
      }
      try {
        await upsertWord(word);
        _pendingUpsertIds.remove(id);
      } catch (e) {
        debugPrint('Retry upsert still failed for id=$id: $e');
      }
    }

    final deleteIds = Set<int>.from(_pendingDeleteIds);
    for (final id in deleteIds) {
      try {
        await deleteWord(id);
        _pendingDeleteIds.remove(id);
      } catch (e) {
        debugPrint('Retry delete still failed for id=$id: $e');
      }
    }

    await _savePendingIds();
  }

  static String? _uidOrNull() => FirebaseAuth.instance.currentUser?.uid;

  static DocumentReference<Map<String, dynamic>> _docFor(String uid, int id) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('words')
        .doc(id.toString());
  }

  static Map<String, dynamic> _toFirestore(Word word) {
    final data = <String, dynamic>{
      'local_id': word.id,
      'word': word.word,
      'meaning': word.meaning,
      'media': word.media,
      'tags': word.tags,
      'created_at': Timestamp.fromDate(word.createdAt),
      'updated_at': FieldValue.serverTimestamp(),
    };
    if (word.phonetic != null) data['phonetic'] = word.phonetic;
    if (word.context != null) data['context'] = word.context;
    if (word.meaningJson != null) data['meaning_json'] = word.meaningJson;
    return data;
  }

  static Future<void> upsertWord(Word word) async {
    final uid = _uidOrNull();
    if (uid == null || word.id == null) {
      debugPrint('Firestore upsert skipped: user not signed in');
      return;
    }
    try {
      await _docFor(uid, word.id!).set(_toFirestore(word), SetOptions(merge: true));
    } catch (e) {
      debugPrint('Firestore upsert failed: $e');
    }
  }

  static Future<void> deleteWord(int id) async {
    final uid = _uidOrNull();
    if (uid == null) {
      debugPrint('Firestore delete skipped: user not signed in');
      return;
    }
    try {
      await _docFor(uid, id).delete();
    } catch (e) {
      debugPrint('Firestore delete failed: $e');
    }
  }

  static Future<void> syncAll(List<Word> words) async {
    final uid = _uidOrNull();
    if (uid == null) {
      debugPrint('Firestore batch sync skipped: user not signed in');
      return;
    }
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final word in words) {
        if (word.id == null) continue;
        batch.set(_docFor(uid, word.id!), _toFirestore(word), SetOptions(merge: true));
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Firestore batch sync failed: $e');
    }
  }

  static Word _docToWord(Map<String, dynamic> data) {
    final rawId = data['local_id'];
    final id = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
    final createdAt = (data['created_at'] is Timestamp)
        ? (data['created_at'] as Timestamp).toDate()
        : DateTime.now();
    final updatedAt = (data['updated_at'] is Timestamp)
        ? (data['updated_at'] as Timestamp).toDate()
        : createdAt;
    return Word(
      id: id,
      word: (data['word'] as String?) ?? '',
      phonetic: data['phonetic'] as String?,
      meaning: (data['meaning'] as String?) ?? '',
      meaningJson: data['meaning_json'] != null
          ? Map<String, dynamic>.from(data['meaning_json'] as Map)
          : null,
      media: (data['media'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          const [],
      context: data['context'] as String?,
      tags: (data['tags'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  static Future<List<Word>> fetchAll() async {
    final uid = _uidOrNull();
    if (uid == null) {
      debugPrint('Firestore fetch skipped: user not signed in');
      return [];
    }
    const pageSize = 500;
    final words = <Word>[];
    DocumentSnapshot? lastDoc;
    try {
      while (true) {
        var query = FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('words')
            .orderBy(FieldPath.documentId)
            .limit(pageSize);
        if (lastDoc != null) {
          query = query.startAfterDocument(lastDoc);
        }
        final snap = await query.get();
        for (final doc in snap.docs) {
          final word = _docToWord(doc.data());
          if (word.id != null) words.add(word);
        }
        if (snap.docs.length < pageSize) break;
        lastDoc = snap.docs.last;
      }
      return words;
    } catch (e) {
      debugPrint('Firestore fetch failed: $e');
      return words; // 부분적으로 받아온 데이터라도 반환
    }
  }
}
