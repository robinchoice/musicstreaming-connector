// Android opens share pages and invites in the app when it is installed (App Links, intent filter in AndroidManifest.xml).
// Signing certificates the app may carry: the upload key of sideloaded APKs and the Play app signing key of Play builds.
const fingerprints = [
  'AE:40:54:49:F1:B0:28:E2:A0:4A:B3:C8:8A:00:EC:F6:ED:65:7E:89:AB:35:68:8B:A2:81:55:CF:92:58:06:CC',
  '09:AD:1C:AD:FA:89:CD:01:E8:1B:CC:AC:63:9F:25:DD:80:A1:D6:65:4F:0C:49:FF:7E:9B:58:F3:06:B1:5B:6F',
];

export const GET = () =>
  Response.json([
    {
      relation: ['delegate_permission/common.handle_all_urls'],
      target: { namespace: 'android_app', package_name: 'org.pleasance.songgate', sha256_cert_fingerprints: fingerprints },
    },
  ]);
