const platforms = {
  'appleMusic': 'Apple Music',
  'youtubeMusic': 'YouTube Music',
  'spotify': 'Spotify',
  'deezer': 'Deezer',
};
const countries = ['DE', 'AT', 'CH', 'US', 'GB'];

const _sources = {
  'appleMusic': r'music\.apple\.com/',
  'youtubeMusic': r'youtu(?:be\.com|\.be)/',
  'spotify': r'open\.spotify\.com/',
  'deezer': r'deezer\.com/',
};

List<String> targetsFor(String input) {
  final source = _sources.entries
      .where((entry) => RegExp(entry.value).hasMatch(input))
      .map((entry) => entry.key)
      .firstOrNull;
  return platforms.keys.where((platform) => platform != source).toList();
}

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

/// The best link on every service, for sharing with friends.
class Song {
  final String title;
  final String artist;
  final String? artworkUrl;
  final String sharePath;
  final Map<String, String> links;
  Song.fromJson(Map<String, dynamic> json)
    : title = (json['source'] as Map<String, dynamic>)['title'] as String,
      artist = (json['source'] as Map<String, dynamic>)['artist'] as String,
      artworkUrl =
          (json['source'] as Map<String, dynamic>)['artworkUrl'] as String?,
      sharePath = json['sharePath'] as String,
      links = {
        for (final entry in (json['links'] as Map<String, dynamic>).entries)
          entry.key: (entry.value as Map<String, dynamic>)['url'] as String,
      };
}
