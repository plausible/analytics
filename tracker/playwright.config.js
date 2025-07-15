// @ts-check
import { defineConfig, devices  } from '@playwright/test'

/**
 * @see https://playwright.dev/docs/test-configuration
 */
export default defineConfig({
  testDir: './test',
  /* Can be overridden in specific tests with test('a longer running test', async () => { test.setTimeout(<longer timeout>); // test content... }) */
  timeout: 10 * 1000, 
  fullyParallel: true,
  /* Fail the build on CI if you accidentally left test.only in the source code. */
  forbidOnly: !!process.env.CI,
  /* Retry on CI only */
  retries: process.env.CI ? 1 : 0,
  /* Reporter to use. See https://playwright.dev/docs/test-reporters */
  reporter: 'list',
  /*
  Shared settings for all the projects below. See https://playwright.dev/docs/api/class-testoptions.
  NOTE: We run the installation support tests on Chrome only because the Browserless /function API
  runs a Chromium-based browser environment.
  */
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },

    {
      name: 'firefox',
      use: { ...devices['Desktop Firefox'] },
      testIgnore: 'test/installation_support/**',
    },

    {
      name: 'webkit',
      use: { ...devices['Desktop Safari'] },
      testIgnore: 'test/installation_support/**',
    },
  ],
  webServer: {
    command: 'npm run start',
    port: 3000,
    reuseExistingServer: !process.env.CI
  },
});
