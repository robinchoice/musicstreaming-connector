import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

const platforms = {
  'appleMusic': 'Apple Music',
  'youtubeMusic': 'YouTube Music',
  'spotify': 'Spotify',
  'deezer': 'Deezer',
  'tidal': 'TIDAL',
  'amazonMusic': 'Amazon Music',
};

/// The order of the service tiles, the same as on the web.
const serviceOrder = [
  'spotify',
  'appleMusic',
  'youtubeMusic',
  'deezer',
  'tidal',
  'amazonMusic',
];
const countries = ['DE', 'AT', 'CH', 'US', 'GB'];

bool isPodcast(String kind) => kind == 'podcast' || kind == 'episode';

/// TIDAL has no podcasts. Same as servicesFor in packages/shared.
List<String> servicesFor(String kind) => isPodcast(kind)
    ? serviceOrder.where((platform) => platform != 'tidal').toList()
    : serviceOrder;

/// Apple's podcasts live in Apple Podcasts. Same as serviceName in packages/shared.
String serviceName(String platform, String kind) =>
    platform == 'appleMusic' && isPodcast(kind)
    ? 'Apple Podcasts'
    : platforms[platform] ?? platform;

const _sources = {
  'appleMusic': r'(?:music|podcasts|itunes)\.apple\.com/',
  'youtubeMusic': r'youtu(?:be\.com|\.be)/',
  'spotify': r'open\.spotify\.com/|spotify\.link/',
  'deezer': r'deezer\.com/',
  'tidal': r'tidal\.com/',
};

/// The service a pasted link comes from, before the API has looked at it.
String? sourceOf(String input) => _sources.entries
    .where((entry) => RegExp(entry.value).hasMatch(input))
    .map((entry) => entry.key)
    .firstOrNull;

/// Service marks from Simple Icons (CC0) in their brand colours.
const _logoColors = {
  'appleMusic': Color(0xFFFA243C),
  'youtubeMusic': Color(0xFFFF0033),
  'spotify': Color(0xFF1ED760),
  'deezer': Color(0xFFA238FF),
  'tidal': Color(0xFFFFFFFF),
  'amazonMusic': Color(0xFF25D1DA),
  'applePodcasts': Color(0xFF9933CC),
};

class ServiceLogo extends StatelessWidget {
  final String platform;
  final String kind;
  final double size;
  const ServiceLogo(
    this.platform, {
    super.key,
    this.kind = 'song',
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    final mark = platform == 'appleMusic' && isPodcast(kind)
        ? 'applePodcasts'
        : platform;
    return SvgPicture.asset(
      'assets/logos/$mark.svg',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(_logoColors[mark]!, BlendMode.srcIn),
      excludeFromSemantics: true,
    );
  }
}

/// The best link on every service for a song, an album, a show or an
/// episode, for sharing with friends.
class Song {
  // song, album, podcast or episode
  final String kind;
  final String platform;
  final String title;
  final String artist;
  final String? artworkUrl;
  final String sharePath;
  final Map<String, String> links;
  // false when only a search on that service is left
  final Map<String, bool> found;
  // Other podcast apps, shows and episodes only
  final List<({String name, String url})> apps;
  bool get album => kind == 'album';
  bool get podcast => isPodcast(kind);
  Song.fromJson(Map<String, dynamic> json)
    : kind =
          (json['source'] as Map<String, dynamic>)['kind'] as String? ?? 'song',
      platform =
          (json['source'] as Map<String, dynamic>)['platform'] as String? ?? '',
      title = (json['source'] as Map<String, dynamic>)['title'] as String,
      artist = (json['source'] as Map<String, dynamic>)['artist'] as String,
      artworkUrl =
          (json['source'] as Map<String, dynamic>)['artworkUrl'] as String?,
      sharePath = json['sharePath'] as String,
      links = {
        for (final entry in (json['links'] as Map<String, dynamic>).entries)
          entry.key: (entry.value as Map<String, dynamic>)['url'] as String,
      },
      found = {
        for (final entry in (json['links'] as Map<String, dynamic>).entries)
          entry.key:
              (entry.value as Map<String, dynamic>)['found'] as bool? ?? true,
      },
      apps = [
        for (final app in json['apps'] as List<dynamic>? ?? const [])
          (
            name: (app as Map<String, dynamic>)['name'] as String,
            url: app['url'] as String,
          ),
      ];
}
