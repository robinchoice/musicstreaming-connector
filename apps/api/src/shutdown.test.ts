import { expect, test } from 'bun:test';
import { createDb } from '@app/db';

const appModule = JSON.stringify(`${import.meta.dir}/app.ts`);

// Isolated processes keep module mocks and OS signals out of the other tests.
function start(entry: 'index', setup: string, env: Record<string, string> = {}) {
  const child = Bun.spawn(
    [
      process.execPath,
      '--eval',
      `import { mock } from 'bun:test';
       ${setup}
       await import(${JSON.stringify(`${import.meta.dir}/${entry}.ts`)});`,
    ],
    {
      env: {
        ...process.env,
        APP_URL: 'http://localhost',
        PORT: '0',
        SMTP_HOST: '',
        SENTRY_DSN: '',
        NODE_ENV: 'test',
        ...env,
      },
      stdout: 'pipe',
      stderr: 'pipe',
    },
  );
  const lines = child.stdout.pipeThrough(new TextDecoderStream()).getReader();
  let output = '';
  async function until(marker: string) {
    while (!output.includes(marker)) {
      const { value, done } = await lines.read();
      if (done) throw new Error(`Child exited before ${marker}: ${output}\n${await child.stderr.text()}`);
      output += value;
    }
    return output;
  }
  return { child, until };
}

for (const signal of ['SIGTERM', 'SIGINT'] as const) {
  test(`API drains an active database request on ${signal}`, async () => {
    const { child, until } = start(
      'index',
      `mock.module(${appModule}, () => ({
         createApp: (_resolver, db) => ({ fetch: async () => {
           console.log('request-started');
           await db.execute('select pg_sleep(0.3)');
           return new Response('complete');
         } })
       }));`,
    );
    try {
      const output = await until('API listening on port ');
      const port = output.match(/API listening on port (\d+)/)![1];
      const response = fetch(`http://localhost:${port}`).then((res) => res.text());
      await until('request-started');
      child.kill(signal);
      expect(await response).toBe('complete');
      expect(await child.exited).toBe(0);
    } finally {
      child.kill('SIGKILL');
      await child.exited;
    }
  }, 20_000);

  test(`API finishes startup before closing on ${signal}`, async () => {
    const db = createDb(process.env.DATABASE_URL);
    const connection = await db.$client.reserve();
    await connection`select pg_advisory_lock(hashtext('migrations'))`;
    const { child, until } = start(
      'index',
      `mock.module(${appModule}, () => ({
         createApp: () => ({ fetch: () => new Response('ready') })
       }));`,
    );
    try {
      await until('Migrating database');
      child.kill(signal);
      await connection`select pg_advisory_unlock(hashtext('migrations'))`;
      await until('API listening on port ');
      expect(await child.exited).toBe(0);
    } finally {
      child.kill('SIGKILL');
      await child.exited;
      await connection`select pg_advisory_unlock_all()`;
      connection.release();
      await db.$client.end();
    }
  }, 20_000);
}
