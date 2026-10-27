import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { test } from 'node:test';

// Runs the real script with an ephemeral signing key, a faked App Store Connect and no real delays.
const bootstrap = `
import assert from 'node:assert/strict';
import { generateKeyPairSync, verify } from 'node:crypto';
const scenario = JSON.parse(process.env.SCENARIO);
const { privateKey, publicKey } = generateKeyPairSync('ec', { namedCurve: 'prime256v1' });
Object.assign(process.env, {
  ASC_KEY_ID: 'test-key', ASC_ISSUER_ID: 'test-issuer',
  ASC_KEY_P8: Buffer.from(privateKey.export({ type: 'pkcs8', format: 'pem' })).toString('base64'),
});
let clock = 1_000_000;
Date.now = () => clock;
globalThis.setTimeout = (resolve, delay) => { clock += delay; resolve(); };
const build = { id: 'build-42', attributes: { processingState: 'VALID' } };
const assigned = new Set(scenario.assigned || []);
let polls = 0;
let internalPosts = 0;
let detailChecks = 0;
globalThis.fetch = async (url, options) => {
  const jwt = options.headers.authorization.slice(7).split('.');
  assert.equal(JSON.parse(Buffer.from(jwt[1], 'base64url')).iss, 'test-issuer');
  assert(verify('sha256', Buffer.from(jwt.slice(0, 2).join('.')), { key: publicKey, dsaEncoding: 'ieee-p1363' }, Buffer.from(jwt[2], 'base64url')));
  const path = new URL(url).pathname.replace('/v1', '');
  const query = new URL(url).searchParams;
  if (scenario.apiFailure) return new Response('Denied', { status: 403 });
  if (options.method !== 'GET') {
    console.log('WRITE ' + JSON.stringify({ method: options.method, path, body: JSON.parse(options.body) }));
    const group = path.match(/^\\/betaGroups\\/(.+)\\/relationships\\/builds$/)?.[1];
    if (group === 'internal' && scenario.notFoundOnce && internalPosts++ === 0) return new Response('Not found', { status: 404 });
    if (group) assigned.add(group);
    return options.method === 'PATCH' ? Response.json({ data: {} }) : new Response(null, { status: 204 });
  }
  let data;
  if (path === '/apps') {
    assert.equal(query.get('filter[bundleId]'), 'org.musiclink.prototype');
    data = [{ id: 'app' }];
  } else if (path === '/apps/app/betaGroups') {
    data = [
      { id: 'internal', attributes: { name: 'Internal', isInternalGroup: true, hasAccessToAllBuilds: !!scenario.automatic } },
      { id: 'external', attributes: { name: 'External', isInternalGroup: false } },
    ];
  } else if (path === '/builds') {
    assert.equal(query.get('filter[app]'), 'app');
    assert.equal(query.get('filter[version]'), '42');
    assert.equal(query.get('filter[preReleaseVersion.platform]'), 'IOS');
    const group = query.get('filter[betaGroups]');
    if (group) {
      // Automatic distribution shows the build in the group after one more poll
      if (group === 'internal' && scenario.automatic && polls > 1) assigned.add('internal');
      data = assigned.has(group) && !scenario.neverVisible ? [build] : [];
    } else {
      polls++;
      data = scenario.noBuild || (scenario.delayed && polls === 1) ? [] : [{ ...build, attributes: { processingState: scenario.invalid ? 'INVALID' : scenario.delayed && polls === 2 ? 'PROCESSING' : 'VALID' } }];
    }
  } else if (path === '/builds/build-42/buildBetaDetail') {
    detailChecks++;
    const internalBuildState = scenario.internalState || (scenario.waitingInternal && detailChecks === 1 ? 'IN_EXPORT_COMPLIANCE_REVIEW' : assigned.has('internal') ? 'IN_BETA_TESTING' : 'READY_FOR_BETA_TESTING');
    data = { id: 'detail-42', attributes: { internalBuildState, externalBuildState: scenario.reviewState || 'READY_FOR_BETA_SUBMISSION' } };
  } else {
    throw new Error('Unexpected request: ' + url);
  }
  return Response.json({ data });
};
process.argv = ['node', 'testflight.mjs', ...scenario.args];
await import('./testflight.mjs');
console.log('POLLS ' + polls);
`;

function run(scenario) {
  const result = spawnSync(process.execPath, ['--input-type=module', '-e', bootstrap], {
    cwd: import.meta.dirname,
    env: { ...process.env, SCENARIO: JSON.stringify(scenario) },
    encoding: 'utf8',
    timeout: 10_000,
  });
  assert.ifError(result.error);
  return {
    ...result,
    writes: result.stdout
      .split('\n')
      .filter(line => line.startsWith('WRITE '))
      .map(line => JSON.parse(line.slice(6))),
  };
}

const internalOnly = ['42', 'Internal'];
const release = ['42', 'Internal', 'External'];
const assignInternal = { method: 'POST', path: '/betaGroups/internal/relationships/builds', body: { data: [{ type: 'builds', id: 'build-42' }] } };
const assignExternal = { method: 'POST', path: '/betaGroups/external/relationships/builds', body: { data: [{ type: 'builds', id: 'build-42' }] } };
const submit = {
  method: 'POST',
  path: '/betaAppReviewSubmissions',
  body: { data: { type: 'betaAppReviewSubmissions', relationships: { build: { data: { type: 'builds', id: 'build-42' } } } } },
};

test('internal build waits for processing, then assigns it and waits for IN_BETA_TESTING', () => {
  const result = run({ args: internalOnly, delayed: true });
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(result.writes, [assignInternal]);
  assert.match(result.stdout, /POLLS 4/);
  assert.match(result.stdout, /Build 42 is in "Internal"/);
});

test('automatic distribution is waited for, not assigned', () => {
  const result = run({ args: internalOnly, automatic: true });
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(result.writes, []);
});

test('a 404 right after VALID is retried on the next poll', () => {
  const result = run({ args: internalOnly, notFoundOnce: true });
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(result.writes, [assignInternal, assignInternal]);
});

test('waits for the internal export compliance review to finish', () => {
  const result = run({ args: internalOnly, assigned: ['internal'], waitingInternal: true });
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /POLLS 2/);
  assert.deepEqual(result.writes, []);
});

test('--quiet turns off notifications once', () => {
  const result = run({ args: ['--quiet', ...internalOnly], delayed: true });
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(result.writes.map(write => write.method), ['PATCH', 'POST']);
  assert.equal(result.writes[0].path, '/buildBetaDetails/detail-42');
});

test('release assigns internally first, then externally, and submits for the review', () => {
  const result = run({ args: release });
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(result.writes, [assignInternal, assignExternal, submit]);
});

test('retry after the assignments only submits the pending review', () => {
  const result = run({ args: release, assigned: ['internal', 'external'] });
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(result.writes, [submit]);
});

for (const reviewState of ['WAITING_FOR_BETA_REVIEW', 'IN_BETA_REVIEW', 'BETA_APPROVED', 'READY_FOR_BETA_TESTING', 'IN_BETA_TESTING']) {
  test(`retry with ${reviewState} neither assigns nor submits again`, () => {
    const result = run({ args: release, assigned: ['internal', 'external'], reviewState });
    assert.equal(result.status, 0, result.stderr);
    assert.deepEqual(result.writes, []);
  });
}

for (const [scenario, error] of [
  [{ args: ['42', 'External'] }, /at least one internal group/],
  [{ args: ['42', 'Missing'] }, /"Missing" not found/],
  [{ args: release, invalid: true }, /Build 42 is INVALID/],
  [{ args: release, internalState: 'MISSING_EXPORT_COMPLIANCE' }, /cannot be tested internally: MISSING_EXPORT_COMPLIANCE/],
  [{ args: release, noBuild: true }, /within an hour/],
  [{ args: release, assigned: ['internal'], neverVisible: true }, /within an hour/],
  [{ args: release, apiFailure: true }, /403 Denied/],
]) {
  test(`fails without external writes for ${JSON.stringify(scenario)}`, () => {
    const result = run(scenario);
    assert.equal(result.status, 1, result.stderr);
    assert.match(result.stderr, error);
    assert.equal(result.writes.filter(write => write.path.includes('external') || write.path === '/betaAppReviewSubmissions').length, 0);
  });
}

test('missing review prerequisites fail instead of reporting a successful release', () => {
  const result = run({ args: release, assigned: ['internal', 'external'], reviewState: 'MISSING_EXPORT_COMPLIANCE' });
  assert.equal(result.status, 1, result.stderr);
  assert.match(result.stderr, /cannot be submitted.*MISSING_EXPORT_COMPLIANCE/);
  assert.deepEqual(result.writes, []);
});

test('missing arguments print the usage', () => {
  const result = run({ args: ['42'] });
  assert.equal(result.status, 64);
  assert.match(result.stderr, /usage:/);
});
