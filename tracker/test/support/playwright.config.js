// playwright.config.js
// @ts-check
const { LOCAL_SERVER_ADDR } = require('./server')

/** @type {import('@playwright/test').PlaywrightTestConfig} */
const config = {
  testDir: '../',
  testMatch: '**/*.spec.js',
  // Use globalSetup & globalTearedown only if browserstack.local = true
  globalSetup: require.resolve('./global-setup'),
  globalTeardown: require.resolve('./global-teardown'),
  timeout: 60000,
  retries: 2,
  use: {
    viewport: null,
    baseURL: LOCAL_SERVER_ADDR
  },
  projects: [
    // -- BrowserStack Projects --

    // name should be of the format 'browser@browser_version:os os_version@browserstack'

    // use playwright version (or '1.latest') instead of browser version for `playwright-browser`.

    // see which playwright versions use which browser versions:
    //    https://www.browserstack.com/docs/automate/playwright/playwright-browser-compatibility
    //
    // supported os and browser options:
    //    https://www.browserstack.com/docs/automate/playwright/browsers-and-os

    // Chrome on Mac
    {
      name: 'chrome@latest:OSX Monterey@browserstack',
      use: {
        browserName: 'chromium',
        channel: 'chrome'
      },
    },
    {
      name: 'chrome@86:OSX Mojave@browserstack',
      use: {
        browserName: 'chromium',
        channel: 'chrome'
      },
    },
    // Chrome on Windows
    {
      name: 'chrome@latest:Windows 11@browserstack',
      use: {
        browserName: 'chromium',
        channel: 'chrome'
      },
    },
    {
      name: 'chrome@86:Windows 10@browserstack',
      use: {
        browserName: 'chromium',
        channel: 'chrome'
      },
    },
    // Firefox on Mac
    {
      name: 'playwright-firefox@1.latest:OSX Big Sur@browserstack',
      use: {
        browserName: 'firefox',
      },
    },
    {
      name: 'playwright-firefox@1.18.1:OSX Catalina@browserstack',
      use: {
        browserName: 'firefox',
      },
    },
    // Firefox on Windows
    {
      name: 'playwright-firefox@1.latest:Windows 11@browserstack',
      use: {
        browserName: 'firefox',
      },
    },
    {
      name: 'playwright-firefox@1.18.1:Windows 10@browserstack',
      use: {
        browserName: 'firefox',
      },
    },
    // Safari on Mac
    {
      name: 'playwright-webkit@1.latest:OSX Monterey@browserstack',
      use: {
        browserName: 'webkit',
      },
    },
    {
      name: 'playwright-webkit@1.19.1:OSX Big Sur@browserstack',
      use: {
        browserName: 'webkit',
      },
    },
  ],
};
module.exports = config;
