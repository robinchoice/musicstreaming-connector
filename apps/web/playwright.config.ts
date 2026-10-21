import { existsSync } from 'node:fs';
import { defineConfig, devices } from '@playwright/test';

// The test runner supplies its temporary DATABASE_URL; the env file fills in other settings.
const envFile = new URL('../../.env', import.meta.url);
if (existsSync(envFile)) process.loadEnvFile(envFile);

// Own ports and fresh servers, so the tests never run against the dev server of another
// worktree or project. Worktrees testing at the same time pick other ports via
// TEST_API_PORT and TEST_WEB_PORT. Keep them below Linux's ephemeral range (32768–60999).
const API_PORT = Number(process.env.TEST_API_PORT ?? 31100);
const WEB_PORT = Number(process.env.TEST_WEB_PORT ?? 31101);
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
      env: { PORT: String(API_PORT), APP_URL: WEB },
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
