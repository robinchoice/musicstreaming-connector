import { existsSync } from 'node:fs';
import { defineConfig, devices } from '@playwright/test';

// The API needs DATABASE_URL. The CI sets it directly.
const envFile = new URL('../../.env', import.meta.url);
if (existsSync(envFile)) process.loadEnvFile(envFile);

// Own ports and fresh servers, so the tests never run against the dev server of another
// worktree or project. Worktrees testing at the same time pick other ports via
// TEST_API_PORT and TEST_WEB_PORT.
const API_PORT = Number(process.env.TEST_API_PORT ?? 53100);
const WEB_PORT = Number(process.env.TEST_WEB_PORT ?? 54100);
const API = `http://localhost:${API_PORT}`;
const WEB = `http://localhost:${WEB_PORT}`;

export default defineConfig({
  testDir: 'tests',
  forbidOnly: !!process.env.CI,
  use: { baseURL: WEB },
  projects: [{ name: 'chromium', use: devices['Desktop Chrome'] }],
  webServer: [
    {
      command: 'bun src/index.ts',
      cwd: '../api',
      env: { PORT: String(API_PORT) },
      url: `${API}/api/health`,
      reuseExistingServer: false,
    },
    // The production build, not vite dev: tests see the app as it runs live
    {
      command: 'bunx vite build --logLevel error && bun build/index.js',
      env: {
        NODE_ENV: 'production',
        PORT: String(WEB_PORT),
        ORIGIN: WEB,
        BODY_SIZE_LIMIT: '8M',
        API_INTERNAL_URL: API,
      },
      url: `${WEB}/health`,
      timeout: 180_000,
      reuseExistingServer: false,
    },
  ],
});
