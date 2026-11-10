// Android opens share pages and invites in the app when it is installed (App Links, intent filter in AndroidManifest.xml).
// Signing certificates the app may carry: the upload key of sideloaded APKs; Play builds need the Play app signing key too.
const fingerprints = ['AE:40:54:49:F1:B0:28:E2:A0:4A:B3:C8:8A:00:EC:F6:ED:65:7E:89:AB:35:68:8B:A2:81:55:CF:92:58:06:CC'];

export const GET = () =>
  Response.json([
    {
      relation: ['delegate_permission/common.handle_all_urls'],
      target: { namespace: 'android_app', package_name: 'org.pleasance.songgate', sha256_cert_fingerprints: fingerprints },
    },
  ]);
