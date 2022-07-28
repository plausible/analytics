const { test } = require('./support/harness');
const { mockRequest } = require('./support/test-utils')
const { expect } = require('@playwright/test');

test.describe('Basic installation', () => {
  test('Sends pageview automatically', async ({ page }) => {
    const expectedEventRequest = mockRequest(page, '/api/event')
    
    await page.goto('/simple.html');

    eventRequest = await expectedEventRequest
    expect(eventRequest.url()).toContain('/api/event')
    expect(eventRequest.postDataJSON().n).toEqual('pageview')
  });
});
