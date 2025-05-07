import { test, Page } from '@playwright/test'
import { LOCAL_SERVER_ADDR } from '../support/server'
import { expectPlausibleInAction } from '../support/test-utils'
import { initializePageDynamically } from '../support/initialize-page-dynamically'
import { ScriptConfig } from '../support/types'

const DEFAULT_CONFIG: ScriptConfig = {
  domain: 'example.com',
  endpoint: `${LOCAL_SERVER_ADDR}/api/event`,
  local: true
}

test('does not track form submissions when trackFormSubmissions is disabled', async ({
  page
}, { testId }) => {
  await initializePageDynamically(page, {
    scriptConfig: DEFAULT_CONFIG,
    bodyContent: `
      <div>
        <form onsubmit="event.preventDefault(); console.log('Form submitted')">
          <input type="name"></input><input type="submit" value="Submit" />
        </form>
      </div>
      `
  })

  await expectPlausibleInAction(page, {
    action: async () => {
      await page.goto(`/dynamic/${testId}`)
      await page.click('input[type="submit"]')
    },
    shouldIgnoreRequest: ({ n }) => ['pageview', 'engagement'].includes(n),
    refutedRequests: [
      {
        n: 'WP Form Completions'
      }
    ]
  })
})

test.describe('trackFormSubmissions is enabled', () => {
  test('limitation: does not detect forms submitted using FormElement.submit() method', async ({
    page
  }, { testId }) => {
    await initializePageDynamically(page, {
      scriptConfig: { ...DEFAULT_CONFIG, trackFormSubmissions: true },
      bodyContent: `
      <div>
        <form id="form" onsubmit="event.preventDefault(); console.log('Form submitted')">
          <input type="text" placeholder="User name"></input>
        </form>
        <button id="trigger" onclick="document.getElementById('form').submit()">Submit</button>
      </div>
      `
    })

    await expectPlausibleInAction(page, {
      action: async () => {
        await page.goto(`/dynamic/${testId}`)
        await page.click('button#trigger')
      },
      shouldIgnoreRequest: ({ n }) => ['pageview', 'engagement'].includes(n),
      refutedRequests: [
        {
          n: 'WP Form Completions'
        }
      ]
    })
  })

  test('does not track form submissions that do not pass checkValidity', async ({
    page
  }, { testId }) => {
    await initializePageDynamically(page, {
      scriptConfig: { ...DEFAULT_CONFIG, trackFormSubmissions: true },
      bodyContent: `
      <div>
        <form onsubmit="event.preventDefault(); console.log('Form submitted')">
          <input type="email"></input>
          <input type="submit" value="Submit" />
        </form>
      </div>
      `
    })

    await expectPlausibleInAction(page, {
      action: async () => {
        await page.goto(`/dynamic/${testId}`)
        await page.fill('input[type="email"]', 'invalid email')
        await page.click('input[type="submit"]')
      },
      shouldIgnoreRequest: ({ n }) => ['pageview', 'engagement'].includes(n),
      refutedRequests: [
        {
          n: 'WP Form Completions'
        }
      ]
    })
  })

  test('tracks form submissions that do not pass checkValidity if the form has novalidate attribute', async ({
    page
  }, { testId }) => {
    await initializePageDynamically(page, {
      scriptConfig: { ...DEFAULT_CONFIG, trackFormSubmissions: true },
      bodyContent: `
      <div>
        <form novalidate onsubmit="event.preventDefault(); console.log('Form submitted')">
          <input type="email"></input>
          <input type="submit" value="Submit" />
        </form>
      </div>
      `
    })

    await expectPlausibleInAction(page, {
      action: async () => {
        await page.goto(`/dynamic/${testId}`)
        await page.fill('input[type="email"]', 'invalid email')
        await page.click('input[type="submit"]')
      },
      shouldIgnoreRequest: ({ n }) => ['pageview', 'engagement'].includes(n),
      expectedRequests: [
        {
          n: 'WP Form Completions',
          p: { path: `/dynamic/${testId}` }
        }
      ]
    })
  })

  test('tracks form submissions triggered with submit button', async ({
    page
  }, { testId }) => {
    await initializePageDynamically(page, {
      scriptConfig: { ...DEFAULT_CONFIG, trackFormSubmissions: true },
      bodyContent: `
      <div>
        <form onsubmit="event.preventDefault(); console.log('Form submitted')">
          <input type="name"></input><input type="submit" value="Submit" />
        </form>
      </div>
      `
    })

    await expectPlausibleInAction(page, {
      action: async () => {
        await page.goto(`/dynamic/${testId}`)
        await page.click('input[type="submit"]')
      },
      shouldIgnoreRequest: ({ n }) => ['pageview', 'engagement'].includes(n),
      expectedRequests: [
        {
          n: 'WP Form Completions',
          p: { path: `/dynamic/${testId}` }
        }
      ]
    })
  })

  test('tracks dynamically inserted forms', async ({ page }, { testId }) => {
    await initializePageDynamically(page, {
      scriptConfig: { ...DEFAULT_CONFIG, trackFormSubmissions: true },
      bodyContent: `
      <div>
        <button id="dynamicallyInsertForm" onclick="const form = document.createElement('form'); form.onsubmit = (event) => {event.preventDefault(); console.log('Form submitted')}; const submit = document.createElement('input'); submit.type = 'submit'; submit.value = 'Submit'; form.appendChild(submit); document.body.appendChild(form)">Open form</button>
      </div>
      `
    })

    await expectPlausibleInAction(page, {
      action: async () => {
        await page.goto(`/dynamic/${testId}`)
        await page.click('button#dynamicallyInsertForm')
        await page.click('input[type="submit"]')
      },
      shouldIgnoreRequest: ({ n }) => ['pageview', 'engagement'].includes(n),
      expectedRequests: [
        {
          n: 'WP Form Completions',
          p: { path: `/dynamic/${testId}` }
        }
      ]
    })
  })

  test('tracks forms that use GET method', async ({ page }, { testId }) => {
    await initializePageDynamically(page, {
      scriptConfig: { ...DEFAULT_CONFIG, trackFormSubmissions: true },
      bodyContent: `
      <div>
        <form method="GET">
          <input id="name" type="name" placeholder="Name"></input><input type="submit" value="Submit" />
        </form>
      </div>
      `
    })

    await expectPlausibleInAction(page, {
      action: async () => {
        await page.goto(`/dynamic/${testId}`)
        await page.fill('input[type="name"]', 'Any Name')
        await page.click('input[type="submit"]')
      },
      shouldIgnoreRequest: ({ n }) => ['pageview', 'engagement'].includes(n),
      expectedRequests: [
        {
          n: 'WP Form Completions',
          p: { path: `/dynamic/${testId}` }
        }
      ]
    })
  })

  test('limitation: tracks _all_ forms on the same page, but _records them indistinguishably_', async ({
    page
  }, { testId }) => {
    await initializePageDynamically(page, {
      scriptConfig: { ...DEFAULT_CONFIG, trackFormSubmissions: true },
      bodyContent: `
      <div>
        <form onsubmit="event.preventDefault(); console.log('Form submitted')">
          <h2>Form 1</h2>
          <input type="name"></input><input type="submit" value="Submit" />
        </form>
        <form onsubmit="event.preventDefault(); console.log('Form submitted')">
          <h2>Form 2</h2>
          <input type="email"></input>
        </form>
      </div>
      `
    })

    await expectPlausibleInAction(page, {
      action: async () => {
        await page.goto(`/dynamic/${testId}`)
        await page.click('input[type="submit"]')
      },
      shouldIgnoreRequest: ({ n }) => ['pageview', 'engagement'].includes(n),
      expectedRequests: [
        {
          n: 'WP Form Completions',
          p: { path: `/dynamic/${testId}` }
        }
      ]
    })

    await expectPlausibleInAction(page, {
      action: async () => {
        await page.fill('input[type="email"]', 'customer@example.com')
        await page.keyboard.press('Enter')
      },
      shouldIgnoreRequest: ({ n }) => ['pageview', 'engagement'].includes(n),
      expectedRequests: [
        {
          n: 'WP Form Completions',
          p: { path: `/dynamic/${testId}` }
        }
      ]
    })
  })
})
