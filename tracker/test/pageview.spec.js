const { test, mockRequest } = require('./support/harness');
const { expect } = require('@playwright/test');

test.describe('Basic installation', () => {
  test('Sends pageview automatically', async ({ page }) => {
    const request = mockRequest(page, '/api/event')

    await page.goto('/simple.html');

    expect((await request).url()).toContain('/api/event')
  });
});
