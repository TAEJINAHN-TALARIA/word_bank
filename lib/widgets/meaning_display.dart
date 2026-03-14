import 'package:flutter/material.dart';

class MeaningSection {
  final String pos;
  final List<String> definitions;
  final List<String> examples;
  final List<String> synonyms;
  final List<String> antonyms;

  const MeaningSection({
    required this.pos,
    required this.definitions,
    this.examples = const [],
    this.synonyms = const [],
    this.antonyms = const [],
  });
}

List<MeaningSection> parseMeaningSections(String meaning) {
  final lines = meaning.split('\n');
  final sections = <MeaningSection>[];
  String? currentPos;
  final currentDefinitions = <String>[];
  final currentExamples = <String>[];
  List<String> currentSynonyms = <String>[];
  List<String> currentAntonyms = <String>[];
  bool inExamples = false;

  void flush() {
    if (currentPos == null) return;
    sections.add(MeaningSection(
      pos: currentPos,
      definitions: List<String>.from(currentDefinitions),
      examples: List<String>.from(currentExamples),
      synonyms: List<String>.from(currentSynonyms),
      antonyms: List<String>.from(currentAntonyms),
    ));
    currentDefinitions.clear();
    currentExamples.clear();
    currentSynonyms = <String>[];
    currentAntonyms = <String>[];
    inExamples = false;
  }

  for (final line in lines) {
    final trimmed = line.trim();
    final posMatch = RegExp(r'^\[(.+)\]$').firstMatch(trimmed);
    if (posMatch != null) {
      flush();
      currentPos = posMatch.group(1)!;
    } else if (trimmed == 'Examples:' || trimmed == 'Example:') {
      inExamples = true;
    } else if (trimmed.startsWith('- ')) {
      final item = trimmed.substring(2).trim();
      if (item.isEmpty) continue;
      if (inExamples) {
        currentExamples.add(item);
      } else if (currentPos != null) {
        currentDefinitions.add(item);
      }
    } else if (trimmed.startsWith('Example: ')) {
      final ex = trimmed.substring('Example: '.length).trim();
      if (ex.isNotEmpty) {
        currentExamples.add(ex);
      }
    } else if (trimmed.startsWith('Synonyms: ')) {
      currentSynonyms = trimmed
          .substring('Synonyms: '.length)
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    } else if (trimmed.startsWith('Antonyms: ')) {
      currentAntonyms = trimmed
          .substring('Antonyms: '.length)
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    } else if (currentPos != null) {
      if (trimmed.isNotEmpty) {
        currentDefinitions.add(trimmed);
      }
    }
  }
  flush();
  return sections;
}

// 다국어 POS를 영어 카테고리로 정규화
String _normalizePos(String pos) {
  switch (pos.toLowerCase()) {
    case 'noun':
    case '명사':
    case '名詞':
    case '名词':
    case 'sustantivo':
    case 'nom':
    case 'nomen':
      return 'noun';
    case 'verb':
    case '동사':
    case '動詞':
    case '动词':
    case 'verbo':
    case 'verbe':
      return 'verb';
    case 'adjective':
    case '형용사':
    case '形容詞':
    case '形容词':
    case 'adjetivo':
    case 'adjectif':
    case 'adjektiv':
      return 'adjective';
    case 'adverb':
    case '부사':
    case '副詞':
    case '副词':
    case 'adverbio':
    case 'adverbe':
      return 'adverb';
    default:
      return 'other';
  }
}

Color _posBg(String pos) {
  switch (_normalizePos(pos)) {
    case 'noun':
      return const Color(0xFFBBDEFB);
    case 'verb':
      return const Color(0xFFC8E6C9);
    case 'adjective':
      return const Color(0xFFFFCDD2);
    case 'adverb':
      return const Color(0xFFE1BEE7);
    default:
      return const Color(0xFFE0E0E0);
  }
}

Color _posFg(String pos) {
  switch (_normalizePos(pos)) {
    case 'noun':
      return const Color(0xFF1565C0);
    case 'verb':
      return const Color(0xFF2E7D32);
    case 'adjective':
      return const Color(0xFFC62828);
    case 'adverb':
      return const Color(0xFF6A1B9A);
    default:
      return const Color(0xFF424242);
  }
}

Widget _posChip(String pos) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: _posBg(pos),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        pos,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: _posFg(pos),
        ),
      ),
    );

/// Compact display for word list cards.
class MeaningCardDisplay extends StatelessWidget {
  final String meaning;
  const MeaningCardDisplay({super.key, required this.meaning});

  @override
  Widget build(BuildContext context) {
    final sections = parseMeaningSections(meaning);
    if (sections.isEmpty) {
      return Text(
        meaning,
        style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.5),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sections.take(2).map((s) {
        final def = s.definitions.isNotEmpty ? s.definitions.first : '';
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1, right: 6),
                child: _posChip(s.pos),
              ),
              Expanded(
                child: Text(
                  def.isNotEmpty ? def : '',
                  style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.45),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

/// Full display for word detail sheet.
class MeaningDetailDisplay extends StatelessWidget {
  final String meaning;
  const MeaningDetailDisplay({super.key, required this.meaning});

  @override
  Widget build(BuildContext context) {
    final sections = parseMeaningSections(meaning);
    if (sections.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F3F5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          meaning,
          style: const TextStyle(fontSize: 14, height: 1.6, color: Color(0xFF2C3E50)),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sections.map((s) {
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F3F5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _posChip(s.pos),
              const SizedBox(height: 8),
              if (s.definitions.isNotEmpty)
                ...List.generate(s.definitions.length, (i) {
                  final d = s.definitions[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${i + 1}. ',
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.6,
                            color: Color(0xFF2C3E50),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            d,
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.6,
                              color: Color(0xFF2C3E50),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              if (s.examples.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.format_quote, size: 14, color: Colors.black38),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: s.examples
                            .map(
                              (ex) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  ex,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.black54,
                                    fontStyle: FontStyle.italic,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ],
                ),
              ],
              if (s.synonyms.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'syn',
                      style: TextStyle(fontSize: 11, color: Colors.black38),
                    ),
                    ...s.synonyms.map((syn) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFCDD5DE)),
                          ),
                          child: Text(
                            syn,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF2C3E50),
                            ),
                          ),
                        )),
                  ],
                ),
              ],
              if (s.antonyms.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'ant',
                      style: TextStyle(fontSize: 11, color: Colors.black38),
                    ),
                    ...s.antonyms.map((ant) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFCDD5DE)),
                          ),
                          child: Text(
                            ant,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF2C3E50),
                            ),
                          ),
                        )),
                  ],
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }
}
