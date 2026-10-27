// Hands an uploaded iOS build to TestFlight groups and submits it for the beta
// review when one of them is external. Every assignment mails the group's testers,
// so external groups only get release builds (AGENTS.md, "Deploy"). The build only
// counts as delivered once it is IN_BETA_TESTING and visible in every internal group;
// external groups follow after that. Each step is checked first, so a run that failed
// halfway can be repeated.
//
//   ASC_KEY_ID=… ASC_ISSUER_ID=… ASC_KEY_P8=<base64 .p8> node tool/testflight.mjs [--quiet] <build number> <group>…
//
// --quiet turns off TestFlight's mail and push notification for this build.
import { createPrivateKey, sign } from 'node:crypto';

const args = process.argv.slice(2);
const quiet = args[0] === '--quiet';
const [number, ...names] = quiet ? args.slice(1) : args;
const { ASC_KEY_ID: keyId, ASC_ISSUER_ID: issuer, ASC_KEY_P8: p8 } = process.env;
if (!number || !names.length || !keyId || !issuer || !p8) {
  console.error('usage: ASC_KEY_ID=… ASC_ISSUER_ID=… ASC_KEY_P8=… node tool/testflight.mjs [--quiet] <build number> <group>…');
  process.exit(64);
}
const key = createPrivateKey(Buffer.from(p8, 'base64').toString());

function token() {
  const encode = value => Buffer.from(JSON.stringify(value)).toString('base64url');
  const now = Math.floor(Date.now() / 1000);
  const unsigned = `${encode({ alg: 'ES256', kid: keyId, typ: 'JWT' })}.${encode({ iss: issuer, iat: now, exp: now + 600, aud: 'appstoreconnect-v1' })}`;
  return `${unsigned}.${sign('sha256', Buffer.from(unsigned), { key, dsaEncoding: 'ieee-p1363' }).toString('base64url')}`;
}

async function api(method, path, body) {
  const response = await fetch(`https://api.appstoreconnect.apple.com/v1${path}`, {
    method,
    headers: { authorization: `Bearer ${token()}`, ...(body && { 'content-type': 'application/json' }) },
    body: body && JSON.stringify(body),
    signal: AbortSignal.timeout(30_000),
  });
  if (!response.ok) {
    const error = new Error(`App Store Connect ${method} ${path.split('?')[0]}: ${response.status} ${await response.text()}`);
    error.status = response.status;
    throw error;
  }
  return response.status === 204 ? null : response.json();
}

const app = (await api('GET', '/apps?filter[bundleId]=org.musiclink.prototype')).data[0];
const allGroups = (await api('GET', `/apps/${app.id}/betaGroups?limit=200`)).data;
const groups = names.map(name => {
  const group = allGroups.find(candidate => candidate.attributes.name === name);
  if (!group) throw new Error(`TestFlight group "${name}" not found`);
  return group;
});
const internals = groups.filter(group => group.attributes.isInternalGroup);
const externals = groups.filter(group => !group.attributes.isInternalGroup);
if (!internals.length) throw new Error('Name at least one internal group: external testers only get builds that work internally');

const buildQuery = `/builds?filter[app]=${app.id}&filter[version]=${encodeURIComponent(number)}&filter[preReleaseVersion.platform]=IOS`;
const inGroup = async group => (await api('GET', `${buildQuery}&filter[betaGroups]=${group.id}`)).data.length > 0;
const wait = () => new Promise(resolve => setTimeout(resolve, 60_000));

// Apple needs a few minutes, sometimes more, to process an upload and to make it testable
const deadline = Date.now() + 60 * 60_000;
let build;
let notified = false;
for (;;) {
  build = (await api('GET', `${buildQuery}&limit=1`)).data[0];
  const state = build?.attributes.processingState;
  if (state && state !== 'VALID' && state !== 'PROCESSING') throw new Error(`Build ${number} is ${state}`);
  if (state === 'VALID') {
    const detail = (await api('GET', `/builds/${build.id}/buildBetaDetail`)).data;
    if (quiet && !notified) {
      await api('PATCH', `/buildBetaDetails/${detail.id}`, { data: { type: 'buildBetaDetails', id: detail.id, attributes: { autoNotifyEnabled: false } } });
      console.log(`Build ${number} notifies no testers`);
      notified = true;
    }
    const internalState = detail.attributes.internalBuildState;
    if (!['PROCESSING', 'IN_EXPORT_COMPLIANCE_REVIEW', 'READY_FOR_BETA_TESTING', 'IN_BETA_TESTING'].includes(internalState)) {
      throw new Error(`Build ${number} cannot be tested internally: ${internalState}; check TestFlight and export compliance`);
    }
    let visible = true;
    for (const group of internals) {
      if (await inGroup(group)) continue;
      visible = false;
      // Groups with automatic distribution pick the build up themselves
      if (group.attributes.hasAccessToAllBuilds) continue;
      // Right after VALID Apple may still answer 404 for the build (AGENTS.md, "Pitfalls"): try again later
      try {
        await api('POST', `/betaGroups/${group.id}/relationships/builds`, { data: [{ type: 'builds', id: build.id }] });
      } catch (error) {
        if (error.status !== 404) throw error;
      }
    }
    if (visible && internalState === 'IN_BETA_TESTING') break;
  }
  if (Date.now() >= deadline) throw new Error(`Build ${number} was not processed and visible internally within an hour`);
  console.log(`Waiting for build ${number} to be processed and visible internally …`);
  await wait();
}
for (const group of internals) console.log(`Build ${number} is in "${group.attributes.name}"`);

if (externals.length) {
  for (const group of externals) {
    if (!(await inGroup(group))) await api('POST', `/betaGroups/${group.id}/relationships/builds`, { data: [{ type: 'builds', id: build.id }] });
    console.log(`Build ${number} is in "${group.attributes.name}"`);
  }
  const state = (await api('GET', `/builds/${build.id}/buildBetaDetail`)).data.attributes.externalBuildState;
  if (state === 'READY_FOR_BETA_SUBMISSION') {
    await api('POST', '/betaAppReviewSubmissions', { data: { type: 'betaAppReviewSubmissions', relationships: { build: { data: { type: 'builds', id: build.id } } } } });
    console.log(`Build ${number} is submitted for the beta review; Apple decides on external availability`);
  } else if (['WAITING_FOR_BETA_REVIEW', 'IN_BETA_REVIEW', 'BETA_APPROVED', 'READY_FOR_BETA_TESTING', 'IN_BETA_TESTING'].includes(state)) {
    console.log(`Build ${number} beta review: ${state}`);
  } else {
    throw new Error(`Build ${number} cannot be submitted for the beta review: ${state}; check TestFlight metadata and export compliance`);
  }
}
