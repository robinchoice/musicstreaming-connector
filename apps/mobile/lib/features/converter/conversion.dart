import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

const platforms = {
  'appleMusic': 'Apple Music',
  'youtubeMusic': 'YouTube Music',
  'spotify': 'Spotify',
  'deezer': 'Deezer',
};

/// The order of the service tiles, the same as on the web.
const serviceOrder = ['spotify', 'appleMusic', 'youtubeMusic', 'deezer'];
const countries = ['DE', 'AT', 'CH', 'US', 'GB'];

const _sources = {
  'appleMusic': r'music\.apple\.com/',
  'youtubeMusic': r'youtu(?:be\.com|\.be)/',
  'spotify': r'open\.spotify\.com/|spotify\.link/',
  'deezer': r'deezer\.com/',
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
};

class ServiceLogo extends StatelessWidget {
  final String platform;
  final double size;
  const ServiceLogo(this.platform, {super.key, this.size = 24});

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/logos/$platform.svg',
    width: size,
    height: size,
    colorFilter: ColorFilter.mode(_logoColors[platform]!, BlendMode.srcIn),
    excludeFromSemantics: true,
  );
}

/// The best link on every service for a song or an album, for sharing with friends.
class Song {
  final bool album;
  final String platform;
  final String title;
  final String artist;
  final String? artworkUrl;
  final String sharePath;
  final Map<String, String> links;
  // false when only a search on that service is left
  final Map<String, bool> found;
  Song.fromJson(Map<String, dynamic> json)
    : album = (json['source'] as Map<String, dynamic>)['kind'] == 'album',
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
      };
}
