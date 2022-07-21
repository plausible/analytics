// playwright.config.js
// @ts-check
const { devices } = require('@playwright/test');
const { LOCAL_SERVER_ADDR } = require('./server')

/** @type {import('@playwright/test').PlaywrightTestConfig} */
const config = {
  testDir: '../',
  testMatch: '**/*.spec.js',
  // Use globalSetup & globalTearedown only if browserstack.local = true
  globalSetup: require.resolve('./global-setup'),
  globalTeardown: require.resolve('./global-teardown'),
  timeout: 60000,
  use: {
    viewport: null,
    baseURL: LOCAL_SERVER_ADDR
  },
  projects: [
    // -- BrowserStack Projects --
    // name should be of the format browser@browser_version:os os_version@browserstack
    // supported options: https://www.browserstack.com/docs/automate/playwright/browsers-and-os
    {
      name: 'chrome@latest:OSX Big Sur@browserstack',
      use: {
        browserName: 'chromium',
        channel: 'chrome'
      },
    },
    {
      name: 'edge@90:Windows 10@browserstack',
      use: {
        browserName: 'chromium'
      },
    },
    {
      name: 'playwright-firefox@latest:OSX Catalina@browserstack',
      use: {
        browserName: 'firefox',
      },
    },
    {
      name: 'playwright-webkit@latest:Windows 11@browserstack',
      use: {
        browserName: 'webkit',
      },
    },
  ],
};
module.exports = config;
