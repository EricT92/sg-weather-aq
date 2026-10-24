import { test, expect, Page } from '@playwright/test';

/**
 * Smoke tests against the deployed OutSystems app.
 * Widgets are located through `data-testid` attributes added in Service Studio
 * (Widget > Attributes), so tests do not break when styling or widget order changes.
 *
 * Screens:
 *   Dashboard     (./)              - 5 PSI cards, last updated, refresh
 *   RegionDetail  (click a card)    - 24h PSI trend chart for one region
 *   Forecast      (./Forecast)      - 2-hour forecast with area search + condition filter
 */

async function signInIfNeeded(page: Page) {
  // Screens are anonymous today; this keeps the suite working if login is enabled later.
  const username = process.env.E2E_USERNAME;
  const password = process.env.E2E_PASSWORD;
  const loginField = page.locator('#Input_UsernameVal');
  if (username && password && (await loginField.isVisible().catch(() => false))) {
    await loginField.fill(username);
    await page.locator('#Input_PasswordVal').fill(password);
    await page.getByRole('button', { name: /log ?in/i }).click();
  }
}

async function open(page: Page, path: string) {
  await page.goto(path);
  await signInIfNeeded(page);
}

test.describe('Dashboard', () => {
  test.beforeEach(async ({ page }) => {
    await open(page, './');
    await expect(page.getByTestId('psi-card').first()).toBeVisible();
  });

  test('shows one PSI card for each of the five regions', async ({ page }) => {
    await expect(page.getByTestId('psi-card')).toHaveCount(5);
    for (const region of ['North', 'South', 'East', 'West', 'Central']) {
      await expect(page.getByTestId('psi-card').filter({ hasText: new RegExp(region, 'i') })).toHaveCount(1);
    }
  });

  test('labels every PSI card with an NEA health band', async ({ page }) => {
    const bands = /Good|Moderate|Unhealthy|Very Unhealthy|Hazardous/;
    for (const card of await page.getByTestId('psi-card').all()) {
      await expect(card).toContainText(bands);
    }
  });

  test('shows when the data was last refreshed', async ({ page }) => {
    await expect(page.getByTestId('last-updated')).toContainText(/updated/i);
  });

  test('clicking a region card opens its 24-hour trend chart', async ({ page }) => {
    await page.getByTestId('psi-card').filter({ hasText: /East/i }).click();
    await expect(page).toHaveURL(/RegionDetail/i);
    await expect(page.getByText(/East .* PSI last 24 hours/i)).toBeVisible();
    await expect(page.getByTestId('psi-trend')).toBeVisible();
  });
});

test.describe('Forecast', () => {
  test.beforeEach(async ({ page }) => {
    await open(page, './Forecast');
    await expect(page.getByTestId('forecast-row').first()).toBeVisible();
  });

  test('lists the 2-hour forecast for many areas', async ({ page }) => {
    expect(await page.getByTestId('forecast-row').count()).toBeGreaterThan(10);
  });

  test('area search narrows the forecast list', async ({ page }) => {
    const rows = page.getByTestId('forecast-row');
    const before = await rows.count();

    await page.getByTestId('forecast-search').fill('Ang Mo Kio');
    await expect(rows.filter({ hasText: 'Ang Mo Kio' }).first()).toBeVisible();
    await expect.poll(async () => rows.count()).toBeLessThan(before);
  });

  test('search is case-insensitive and partial', async ({ page }) => {
    await page.getByTestId('forecast-search').fill('ang mo');
    await expect(page.getByTestId('forecast-row').filter({ hasText: 'Ang Mo Kio' })).toHaveCount(1);
  });
});
