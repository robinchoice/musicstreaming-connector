import { defineConfig, devices } from '@playwright/test';

// Starts the web app like `bun run dev`, or reuses it when it already runs
export default defineConfig({
  testDir: 'tests',
  forbidOnly: !!process.env.CI,
  use: { baseURL: 'http://localhost:5173' },
  projects: [{ name: 'chromium', use: devices['Desktop Chrome'] }],
  webServer: { command: 'bun run dev', url: 'http://localhost:5173', reuseExistingServer: !process.env.CI },
});
