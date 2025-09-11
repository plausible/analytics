import { test, expect } from '@playwright/test'
import { initializePageDynamically } from './support/initialize-page-dynamically'
import { mockManyRequests } from './support/mock-many-requests'
import { switchByMode } from './support/test-utils'

const DOMAIN = 'example.com'

for (const mode of ['web', 'esm', 'legacy']) {
  test.describe(`callback results (${mode})`, () => {
    for (const {
      name,
      captureOnLocalhost,
      apiPath,
      mockPath,
      fulfill,
      expectedResult
    } of [
      {
        name: 'on successful request',
        captureOnLocalhost: true,
        apiPath: '/api/event',
        mockPath: `/api/event`,
        fulfill: { status: 202 },
        expectedResult: { status: 202 }
      },
      {
        name: 'on 404',
        captureOnLocalhost: true,
        apiPath: '/api/event',
        mockPath: `/api/event`,
        fulfill: { status: 404 },
        expectedResult: { status: 404 }
      },
      {
        name: 'on network error',
        captureOnLocalhost: true,
        apiPath: 'h://no-exist',
        mockPath: `/api/event`,
        fulfill: { status: 202 },
        expectedResult: { error: expect.any(Error) }
      },
      {
        name: 'on ignored request (because of not having capturing events on localhost)',
        captureOnLocalhost: false,
        apiPath: '/api/event',
        mockPath: `/api/event`,
        fulfill: { status: 202 },
        expectedResult: undefined
      }
    ]) {
      test(`${name}`, async ({ page }, { testId }) => {
        const config = { domain: DOMAIN, endpoint: apiPath, captureOnLocalhost }
        const { url } = await initializePageDynamically(page, {
          testId,
          scriptConfig: switchByMode(
            {
              legacy: `<script data-api="${apiPath}" async id="plausible" data-domain="${DOMAIN}" src="${
                captureOnLocalhost
                  ? '/tracker/js/plausible.compat.local.manual.js'
                  : '/tracker/js/plausible.compat.manual.js'
              }"></script>`,
              web: { domain: DOMAIN, endpoint: apiPath, captureOnLocalhost },
              esm: `<script type="module">import { init, track } from "/tracker/js/npm_package/plausible.js"; init(${JSON.stringify(
                config
              )})</script>`
            },
            mode
          ),
          bodyContent: ''
        })

        await mockManyRequests({
          page,
          path: mockPath,
          fulfill,
          awaitedRequestCount: 1,
          mockRequestTimeout: 2000
        })
        await page.goto(url)
        await page.waitForFunction(() => window.plausible?.l)
        const callbackResult = await page.evaluate(
          () =>
            new Promise((resolve) =>
              // @ts-expect-error - window.plausible is defined
              window.plausible('Purchase', {
                callback: (result) => resolve(result)
              })
            )
        )
        expect(callbackResult).toEqual(expectedResult)
      })
    }
  })
}
