/*
Tests for plausible-web.js script variant

Unlike in production, we're manually interpolating the script config in this file to
better test the script in isolation of the plausible codebase.
*/

import {
  expectPlausibleInAction,
  isEngagementEvent
} from './support/test-utils'
import { test, expect } from '@playwright/test'
import { LOCAL_SERVER_ADDR } from './support/server'
import {
  getConfiguredPlausibleWebSnippet,
  initializePageDynamically
} from './support/initialize-page-dynamically'

const DEFAULT_CONFIG = {
  domain: 'example.com',
  endpoint: `${LOCAL_SERVER_ADDR}/api/event`,
  captureOnLocalhost: true
}

test('with queue code from the web snippet, tracks `plausible` calls made before the script is loaded', async ({
  page
}, { testId }) => {
  const config = { ...DEFAULT_CONFIG }
  const { url } = await initializePageDynamically(page, {
    testId,
    scriptConfig: config,
    bodyContent:
      '<script>window.plausible("loaded", { props: { plausibleLoadedAtEventTime: window.plausible.l ? true : false }, interactive: false })</script>'
  })
  await expectPlausibleInAction(page, {
    action: () => page.goto(url),
    expectedRequests: [
      {
        n: 'loaded',
        p: { plausibleLoadedAtEventTime: false },
        i: false,
        d: config.domain,
        u: `${LOCAL_SERVER_ADDR}${url}`
      },
      { n: 'pageview', d: config.domain, u: `${LOCAL_SERVER_ADDR}${url}` }
    ]
  })
})

test('handles double-initialization of the script with a console.warn', async ({
  page
}, { testId }) => {
  const config = { ...DEFAULT_CONFIG, customProperties: { init: 1 } }
  const { url } = await initializePageDynamically(page, {
    testId,
    scriptConfig: config,
    bodyContent: `<button onclick="window.plausible('Purchase')">Purchase</button>`
  })
  const messages: [string, string][] = []
  page.on('console', (message) => {
    messages.push([message.type(), message.text()])
  })

  await expectPlausibleInAction(page, {
    action: () => page.goto(url),
    expectedRequests: [{ n: 'pageview', p: { init: 1 } }],
    shouldIgnoreRequest: isEngagementEvent
  })

  await expect(
    page.evaluate(() =>
      (window as any).plausible.init({
        captureOnLocalhost: true,
        customProperties: { init: 2 }
      })
    )
  ).resolves.toBeUndefined()

  expect(messages).toEqual([
    [
      'warning',
      'Plausible analytics script was already initialized, skipping init'
    ]
  ])

  await expectPlausibleInAction(page, {
    action: () => page.click('button'),
    expectedRequests: [{ n: 'Purchase', p: { init: 2 } }] // bug or maybe feature: expected to be { init: 1 }
  })
})

test('if there are two snippets on the page, the second one that loads interacts with the first one, no warning is emitted', async ({ page }, {
  testId
}) => {
  const config = { ...DEFAULT_CONFIG }
  const snippetAlfa = getConfiguredPlausibleWebSnippet({...config, customProperties: { alfa: true }})
  const initCallAlfa = 'plausible.init({"captureOnLocalhost":true,"customProperties":{"alfa":true}})'
  expect(snippetAlfa).toEqual(expect.stringContaining(initCallAlfa)) 
  const snippetBeta = getConfiguredPlausibleWebSnippet({...config, customProperties: { beta: true }})
  const initCallBeta = `plausible.init({"captureOnLocalhost":true,"customProperties":{"beta":true}})`
  expect(snippetBeta).toEqual(expect.stringContaining(initCallBeta))

  const messages: [string, string][] = []
  page.on('console', (message) => {
    messages.push([message.type(), message.text()])
  })

  const { url } = await initializePageDynamically(page, {
    testId,
    scriptConfig: `${snippetAlfa}${snippetBeta}`,
    bodyContent: ''
  })
  await expectPlausibleInAction(page, {
    action: () => page.goto(url),
    expectedRequests: [
      { n: 'pageview', d: config.domain, u: `${LOCAL_SERVER_ADDR}${url}`, p: { beta: true } },
    ],
    shouldIgnoreRequest: isEngagementEvent
  })
  expect(messages).toEqual([])

})

test('if domain is provided in `init`, it is ignored', async ({ page }, {
  testId
}) => {
  const config = { ...DEFAULT_CONFIG }
  const scriptConfig = getConfiguredPlausibleWebSnippet(config)
  const originalInitCall = 'plausible.init({"captureOnLocalhost":true})'
  // verify that the original snippet is what we expect it to be
  expect(scriptConfig).toEqual(expect.stringContaining(originalInitCall)) 
  const initCallWithDomainOverride = `plausible.init({"captureOnLocalhost":true,"domain":"sub.${config.domain}"})`
  const updatedScriptConfig = scriptConfig.replace(
    originalInitCall,
    initCallWithDomainOverride
  )
  // verify that the updated snippet has the domain override
  expect(updatedScriptConfig).toEqual(
    expect.stringContaining(initCallWithDomainOverride)
  )

  const { url } = await initializePageDynamically(page, {
    testId,
    scriptConfig: updatedScriptConfig,
    bodyContent: ''
  })
  await expectPlausibleInAction(page, {
    action: () => page.goto(url),
    expectedRequests: [
      { n: 'pageview', d: config.domain, u: `${LOCAL_SERVER_ADDR}${url}` }
    ],
    shouldIgnoreRequest: isEngagementEvent
  })
})
