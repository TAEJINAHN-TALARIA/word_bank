import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/word.dart';

class WordSyncService {
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

  static Future<List<Word>> fetchAll() async {
    final uid = _uidOrNull();
    if (uid == null) {
      debugPrint('Firestore fetch skipped: user not signed in');
      return [];
    }
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('words')
          .get();
      final words = <Word>[];
      for (final doc in snap.docs) {
        final data = doc.data();
        final rawId = data['local_id'];
        final id = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
        if (id == null) continue;
        final createdAt = (data['created_at'] is Timestamp)
            ? (data['created_at'] as Timestamp).toDate()
            : DateTime.now();
        words.add(
          Word(
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
          ),
        );
      }
      return words;
    } catch (e) {
      debugPrint('Firestore fetch failed: $e');
      return [];
    }
  }
}
