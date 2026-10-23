// Developer token for the Apple Music API, an ES256 JWT signed with the MusicKit key.
// Without the three variables Songgate matches Apple Music by text through the iTunes API only.
let cached: { token: string; expires: number } | undefined;

export async function appleMusicToken(env: Record<string, string | undefined> = process.env, now = Date.now()) {
  const { APPLE_MUSIC_TEAM_ID: team, APPLE_MUSIC_KEY_ID: kid, APPLE_MUSIC_KEY_BASE64: key } = env;
  if (!team || !kid || !key) return null;
  if (cached && cached.expires - now > 60 * 60_000) return cached.token;
  const pem = Buffer.from(key, 'base64').toString().replace(/-----[A-Z ]+-----|\s/g, '');
  const signer = await crypto.subtle.importKey('pkcs8', Buffer.from(pem, 'base64'), { name: 'ECDSA', namedCurve: 'P-256' }, false, ['sign']);
  const iat = Math.floor(now / 1000);
  const encode = (value: object) => Buffer.from(JSON.stringify(value)).toString('base64url');
  const unsigned = `${encode({ alg: 'ES256', kid })}.${encode({ iss: team, iat, exp: iat + 12 * 60 * 60 })}`;
  const signature = await crypto.subtle.sign({ name: 'ECDSA', hash: 'SHA-256' }, signer, Buffer.from(unsigned));
  cached = { token: `${unsigned}.${Buffer.from(signature).toString('base64url')}`, expires: now + 12 * 60 * 60_000 };
  return cached.token;
}
