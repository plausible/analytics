const { test } = require('./support/harness');
const { expect } = require('@playwright/test');

const localServer = 'http://localhost:3000'

async function mockRequest(page, path) {
  return new Promise(async (resolve, reject) => {
    await page.route(path, (route, request) => {

      resolve(request)

      return route.fulfill({
        status: 202,
        contentType: 'text/plain',
        body: 'ok'
      });
    });
  })
}

test.describe('Basic installation', () => {
  test('Sends pageview automatically', async ({ page }) => {
    const request = mockRequest(page, '**/api/event')

    await page.goto(localServer + '/simple.html');

    expect((await request).url()).toEqual('http://localhost:3000/api/event')
  });
});
