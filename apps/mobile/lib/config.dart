import 'package:flutter/foundation.dart';

bool get isIOS => defaultTargetPlatform == TargetPlatform.iOS;

String get appPlatform => isIOS ? 'ios' : 'android';

const appName = 'Songgate';
// The same as LIVE in packages/shared: true once Songgate is live as 1.0.
// From then on the bug button waits for the test mode switch in the settings.
const live = false;
const appBand = (from: 3.85, to: 4.55);
const apiUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'http://localhost:3000',
);
// The CI run number, the same as the store build number. Local builds have 0 and skip the update check.
const buildNumber = int.fromEnvironment('BUILD_NUMBER');
const appStoreUrl = 'https://apps.apple.com/app/id6819013473';
const playStoreUrl =
    'https://play.google.com/store/apps/details?id=org.pleasance.songgate';
// The supporter purchases in the settings. Stays false until the products are
// approved in App Store Connect and Google Play.
const supportEnabled = false;
// Consumable in-app products, the same IDs in both stores: 0.99, 4.19, 9.99 EUR.
const supportProducts = [
  'org.pleasance.songgate.support.song',
  'org.pleasance.songgate.support.single',
  'org.pleasance.songgate.support.album',
];
