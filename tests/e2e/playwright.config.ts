import { defineConfig, devices } from '@playwright/test';

const baseURL = process.env.APP_URL;
if (!baseURL) {
  throw new Error('Set APP_URL to the deployed app, e.g. https://<env>.outsystemscloud.com/WeatherAirQuality/');
}

export default defineConfig({
  testDir: './tests',
  timeout: 60_000,
  // Personal environments can be slow on a cold start, so give each check more time.
  expect: { timeout: 15_000 },
  retries: process.env.CI ? 1 : 0,
  reporter: [['list'], ['html', { open: 'never' }]],
  use: {
    baseURL,
    navigationTimeout: 30_000,
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
  },
  projects: [{ name: 'chromium', use: { ...devices['Desktop Chrome'] } }],
});
