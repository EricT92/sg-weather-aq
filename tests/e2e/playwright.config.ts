import { defineConfig, devices } from '@playwright/test';

const baseURL = process.env.APP_URL;
if (!baseURL) {
  throw new Error('Set APP_URL to the deployed app, e.g. https://<env>.outsystemscloud.com/WeatherAirQuality/');
}

export default defineConfig({
  testDir: './tests',
  timeout: 60_000,
  retries: process.env.CI ? 1 : 0,
  reporter: [['list'], ['html', { open: 'never' }]],
  use: {
    baseURL,
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
  },
  projects: [{ name: 'chromium', use: { ...devices['Desktop Chrome'] } }],
});
