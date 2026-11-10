// Read-only store status: App Store versions and availability per territory
// (TRADER_STATUS_NOT_PROVIDED = blocked in the EU), TestFlight builds, and the
// Google Play tracks and production countries. Changes nothing; Play edits are
// opened only to read and deleted again.
//
//   ASC_KEY_ID=… ASC_ISSUER_ID=… ASC_KEY_P8=<base64 .p8> \
//   GOOGLE_MUSICLINK_PLAY_KEY_BASE64=<base64 JSON key> node tool/store-status.mjs
import { createPrivateKey, sign } from 'node:crypto';

const env = process.env;
const encode = value => Buffer.from(JSON.stringify(value)).toString('base64url');
const now = () => Math.floor(Date.now() / 1000);

async function get(url, token, method = 'GET') {
  const response = await fetch(url, { method, headers: { authorization: `Bearer ${token}` }, signal: AbortSignal.timeout(30_000) });
  const text = await response.text();
  if (!response.ok) throw new Error(`${method} ${url.split('?')[0]}: ${response.status} ${text.slice(0, 200)}`);
  return text ? JSON.parse(text) : null;
}

async function appStore() {
  const key = createPrivateKey(Buffer.from(env.ASC_KEY_P8, 'base64').toString());
  const token = () => {
    const unsigned = `${encode({ alg: 'ES256', kid: env.ASC_KEY_ID, typ: 'JWT' })}.${encode({ iss: env.ASC_ISSUER_ID, iat: now(), exp: now() + 600, aud: 'appstoreconnect-v1' })}`;
    return `${unsigned}.${sign('sha256', Buffer.from(unsigned), { key, dsaEncoding: 'ieee-p1363' }).toString('base64url')}`;
  };
  const api = path => get(path.startsWith('http') ? path : `https://api.appstoreconnect.apple.com${path}`, token());

  const app = (await api('/v1/apps?filter[bundleId]=org.musiclink.prototype')).data[0];
  console.log(`App Store: ${app.attributes.name} (${app.id})`);
  for (const version of (await api(`/v1/apps/${app.id}/appStoreVersions?limit=5`)).data) {
    console.log(`  version ${version.attributes.versionString}: ${version.attributes.appStoreState}`);
  }
  const availability = await api(`/v1/apps/${app.id}/appAvailabilityV2`);
  const byStatus = {};
  for (let next = `/v2/appAvailabilities/${availability.data.id}/territoryAvailabilities?limit=200&include=territory`; next; ) {
    const page = await api(next);
    for (const entry of page.data) {
      const status = entry.attributes.available ? (entry.attributes.contentStatuses ?? []).join(',') : 'NOT_SELECTED';
      (byStatus[status] ??= []).push(entry.relationships.territory.data.id);
    }
    next = page.links?.next;
  }
  for (const [status, territories] of Object.entries(byStatus)) {
    console.log(`  ${status}: ${territories.length}${territories.length < 40 ? ` (${territories.join(' ')})` : ''}`);
  }
  const builds = await api(`/v1/builds?filter[app]=${app.id}&sort=-uploadedDate&limit=1&include=buildBetaDetail`);
  const build = builds.data[0];
  const beta = builds.included?.find(item => item.type === 'buildBetaDetails')?.attributes;
  console.log(`  newest build ${build.attributes.version}: ${build.attributes.processingState}, internal ${beta?.internalBuildState}, external ${beta?.externalBuildState}`);
}

async function play() {
  const account = JSON.parse(Buffer.from(env.GOOGLE_MUSICLINK_PLAY_KEY_BASE64, 'base64').toString());
  const unsigned = `${encode({ alg: 'RS256', typ: 'JWT' })}.${encode({ iss: account.client_email, scope: 'https://www.googleapis.com/auth/androidpublisher', aud: 'https://oauth2.googleapis.com/token', iat: now(), exp: now() + 600 })}`;
  const assertion = `${unsigned}.${sign('sha256', Buffer.from(unsigned), createPrivateKey(account.private_key)).toString('base64url')}`;
  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion }),
  });
  const token = (await response.json()).access_token;
  const base = 'https://androidpublisher.googleapis.com/androidpublisher/v3/applications/org.pleasance.songgate';

  console.log('Google Play: org.pleasance.songgate');
  const edit = await get(`${base}/edits`, token, 'POST');
  try {
    for (const track of (await get(`${base}/edits/${edit.id}/tracks`, token)).tracks ?? []) {
      for (const release of track.releases ?? []) {
        console.log(`  ${track.track}: ${release.name ?? ''} codes ${(release.versionCodes ?? []).join(',')} ${release.status}`);
      }
    }
    const countries = await get(`${base}/edits/${edit.id}/countryAvailability/production`, token);
    console.log(`  production countries: ${countries.countries?.length ?? 0}${countries.restOfWorld ? ' + rest of world' : ''}`);
  } finally {
    await get(`${base}/edits/${edit.id}`, token, 'DELETE');
  }
}

for (const check of [appStore, play]) {
  try {
    await check();
  } catch (error) {
    console.log(`  ${check.name} failed: ${error.message}`);
    process.exitCode = 1;
  }
}
