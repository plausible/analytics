import { initializePageDynamically } from './support/initialize-page-dynamically'
import {
  expectPlausibleInAction,
  switchByMode,
} from './support/test-utils'
import { expect, test } from '@playwright/test'
import { ScriptConfig } from './support/types'
import { LOCAL_SERVER_ADDR } from './support/server'

const DEFAULT_CONFIG: ScriptConfig = {
  domain: 'example.com',
  endpoint: `${LOCAL_SERVER_ADDR}/api/event`,
  captureOnLocalhost: false
}

for (const mode of ['web', 'esm']) {
  test.describe(`respects "logging" v2 config option (${mode})`, () => {
    test('if logging is not explicitly set, it is treated as true and logs are emitted on ignored events', async ({
      page
    }, { testId }) => {
      const config = { ...DEFAULT_CONFIG }
      const consoleMessages: [string, string][] = []
      page.on('console', (message) => {
        consoleMessages.push([message.type(), message.text()])
      })
      const { url } = await initializePageDynamically(page, {
        testId,
        scriptConfig: switchByMode(
          {
            web: config,
            esm: `<script type="module">import { init, track } from '/tracker/js/npm_package/plausible.js'; init(${JSON.stringify(
              config
            )})</script>`
          },
          mode
        ),
        bodyContent: 'hello world'
      })

      await expectPlausibleInAction(page, {
        action: () => page.goto(url),
        expectedRequests: [],
        refutedRequests: [{ n: 'pageview' }]
      })

      expect(consoleMessages).toEqual([
        ['warning', 'Ignoring Event: localhost']
      ])
    })

    test('if logging is explicitly set to false, logs are not emitted on ignored events', async ({
      page
    }, { testId }) => {
      const config = { ...DEFAULT_CONFIG, logging: false }
      const consoleMessages: [string, string][] = []
      page.on('console', (message) => {
        consoleMessages.push([message.type(), message.text()])
      })
      const { url } = await initializePageDynamically(page, {
        testId,
        scriptConfig: switchByMode(
          {
            web: config,
            esm: `<script type="module">import { init, track } from '/tracker/js/npm_package/plausible.js'; init(${JSON.stringify(
              config
            )})</script>`
          },
          mode
        ),
        bodyContent: 'hello world'
      })

      await expectPlausibleInAction(page, {
        action: () => page.goto(url),
        expectedRequests: [],
        refutedRequests: [{ n: 'pageview' }]
      })

      expect(consoleMessages).toEqual([])
    })
  })
}
