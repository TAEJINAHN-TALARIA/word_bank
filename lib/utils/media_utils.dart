/// media item 리스트를 Firestore/저장 포맷으로 변환합니다.
/// items: [{'type': 'image'|'youtube', 'url': '...'}]
Map<String, List<Map<String, dynamic>>> buildMediaPayload(
    List<Map<String, dynamic>> items) {
  final photos = <Map<String, dynamic>>[];
  final youtube = <Map<String, dynamic>>[];
  for (final item in items) {
    final type = item['type'];
    if (type == 'image') {
      photos.add({'url': item['url']});
    } else if (type == 'youtube') {
      youtube.add({'url': item['url']});
    }
  }
  return {'photos': photos, 'youtube': youtube};
}
