const { test, mockRequest } = require('./support/harness');
const { expect } = require('@playwright/test');
const outboundURL = 'https://awesome.website.com'

test.describe('Outbound link click', () => {
  test('sends event and navigates to outbound URL', async ({ page }) => {    
    await page.goto('/outbound-link.html')
    
    const expectedEventRequest = mockRequest(page, '/api/event')
    const expectedNavigationRequest = mockRequest(page, outboundURL)

    await page.click('#outbound-link', {button: 'left'})

    const payload = (await expectedEventRequest).postDataJSON()
    expect(payload.n).toEqual('Outbound Link: Click')
    expect(payload.p.url).toContain(outboundURL)

    expect((await expectedNavigationRequest).url()).toContain(outboundURL)
  });
});
