const platforms = {
  'appleMusic': 'Apple Music',
  'youtubeMusic': 'YouTube Music',
  'spotify': 'Spotify',
};

class Candidate {
  final String title;
  final String url;
  final String? artworkUrl;
  final String? album;
  final int? durationSeconds;
  Candidate.fromJson(Map<String, dynamic> json)
    : title = json['title'] as String,
      url = json['url'] as String,
      artworkUrl = json['artworkUrl'] as String?,
      album = json['album'] as String?,
      durationSeconds = (json['durationSeconds'] as num?)?.round();
  String get details => [
    ?album,
    if (durationSeconds != null)
      '${durationSeconds! ~/ 60}:${(durationSeconds! % 60).toString().padLeft(2, '0')}',
  ].join(' · ');
}

class Conversion {
  final String target;
  final String title;
  final String artist;
  final List<Candidate> candidates;
  Conversion.fromJson(Map<String, dynamic> json)
    : target = json['target'] as String,
      title = (json['source'] as Map<String, dynamic>)['title'] as String,
      artist = (json['source'] as Map<String, dynamic>)['artist'] as String,
      candidates = (json['candidates'] as List)
          .map((item) => Candidate.fromJson(item as Map<String, dynamic>))
          .toList();
}
