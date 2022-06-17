// playwright.config.js
// @ts-check
const { devices } = require('@playwright/test');

/** @type {import('@playwright/test').PlaywrightTestConfig} */
const config = {
  testDir: '../',
  testMatch: '**/*.spec.js',
  // Use globalSetup & globalTearedown only if browserstack.local = true
  globalSetup: require.resolve('./global-setup'),
  globalTeardown: require.resolve('./global-teardown'),
  timeout: 60000,
  use: {
    viewport: null
  },
  projects: [
    // -- BrowserStack Projects --
    // name should be of the format browser@browser_version:os os_version@browserstack
    {
      name: 'chrome@latest:Windows 10@browserstack', // FAIL
      use: {
        browserName: 'chromium',
        channel: 'chrome'
      },
    },
    {
      name: 'edge@90:Windows 10@browserstack', // FAIL
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
      name: 'playwright-webkit@latest:OSX Big Sur@browserstack',
      use: {
        browserName: 'webkit',
      },
    },
  ],
};
module.exports = config;
