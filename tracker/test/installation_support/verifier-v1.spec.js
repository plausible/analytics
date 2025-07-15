import { test, expect } from '@playwright/test'
import { verify } from '../support/installation-support-playwright-wrappers'
import { delay } from '../support/test-utils'
import { initializePageDynamically } from '../support/initialize-page-dynamically'
import { compileFile } from '../../compiler'

const SOME_DOMAIN = 'somesite.com'

async function mockEventResponseSuccess(page, responseDelay = 0) {
  await page.context().route('**/api/event', async (route) => {
    if (responseDelay > 0) {
      await delay(responseDelay)
    }

    await route.fulfill({
      status: 202,
      contentType: 'text/plain',
      body: 'ok'
    })
  })
}

test.describe('v1 verifier (basic diagnostics)', () => {
  test('correct installation', async ({ page }, { testId }) => {
    await mockEventResponseSuccess(page)

    const { url } = await initializePageDynamically(page, {
      testId,
      scriptConfig: `<script defer data-domain="${SOME_DOMAIN}" src="/tracker/js/plausible.local.js"></script>`
    })

    const result = await verify(page, {url: url, expectedDataDomain: SOME_DOMAIN})

    expect(result.data.plausibleInstalled).toBe(true)
    expect(result.data.snippetsFoundInHead).toBe(1)
    expect(result.data.snippetsFoundInBody).toBe(0)
    expect(result.data.callbackStatus).toBe(202)
    expect(result.data.dataDomainMismatch).toBe(false)
    expect(result.data.wordpressPlugin).toBe(false)
    expect(result.data.wordpressLikely).toBe(false)
    expect(result.data.cookieBannerLikely).toBe(false)
    expect(result.data.manualScriptExtension).toBe(false)

    // `data.proxyLikely` is mostly expected to be true in tests because
    // any local script src is considered a proxy. More involved behaviour
    // is covered by unit tests under `check-proxy-likely.spec.js`
    expect(result.data.proxyLikely).toBe(true)
  })

  test('handles a dynamically loaded snippet', async ({ page }, { testId }) => {
    await mockEventResponseSuccess(page)

    const { url } = await initializePageDynamically(page, {
      testId,
      response: `
      <html>
        <head></head>
        <body>
          <script>
            const script = document.createElement('script')

            script.defer = true
            script.dataset.domain = '${SOME_DOMAIN}'
            script.src = "/tracker/js/plausible.local.manual.js"

            setTimeout(() => {
              document.getElementsByTagName('head')[0].appendChild(script)
            }, 500)
          </script>
        </body>
      </html>
      `
    })

    const result = await verify(page, {url: url, expectedDataDomain: SOME_DOMAIN, debug: true})

    expect(result.data.plausibleInstalled).toBe(true)
    expect(result.data.snippetsFoundInHead).toBe(1)
    expect(result.data.snippetsFoundInBody).toBe(0)
    expect(result.data.callbackStatus).toBe(202)
    expect(result.data.dataDomainMismatch).toBe(false)
  })

  test('missing snippet', async ({ page }, { testId }) => {
    const { url } = await initializePageDynamically(page, {
      testId,
      scriptConfig: ''
    })

    const result = await verify(page, {url: url, expectedDataDomain: SOME_DOMAIN})

    expect(result.data.plausibleInstalled).toBe(false)
    expect(result.data.callbackStatus).toBe(0)
    expect(result.data.snippetsFoundInHead).toBe(0)
    expect(result.data.snippetsFoundInBody).toBe(0)
    expect(result.data.dataDomainMismatch).toBe(false)
  })

  test('snippet in body', async ({ page }, { testId }) => {
    await mockEventResponseSuccess(page)

    const { url } = await initializePageDynamically(page, {
      testId,
      response: `<body><script defer data-domain="${SOME_DOMAIN}" src="/tracker/js/plausible.local.js"></script></body>`
    })

    const result = await verify(page, {url: url, expectedDataDomain: SOME_DOMAIN})

    expect(result.data.plausibleInstalled).toBe(true)
    expect(result.data.snippetsFoundInHead).toBe(0)
    expect(result.data.snippetsFoundInBody).toBe(1)
    expect(result.data.callbackStatus).toBe(202)
    expect(result.data.dataDomainMismatch).toBe(false)
  })

  test('figures out well placed snippet in a multi-domain setup', async ({ page }, { testId }) => {
    await mockEventResponseSuccess(page)

    const { url } = await initializePageDynamically(page, {
      testId,
      response: `<head><script defer data-domain="example.org,example.com,example.net" src="/tracker/js/plausible.local.js"></script></head>`
    })

    const result = await verify(page, {url: url, expectedDataDomain: "example.com"})

    expect(result.data.plausibleInstalled).toBe(true)
    expect(result.data.snippetsFoundInHead).toBe(1)
    expect(result.data.snippetsFoundInBody).toBe(0)
    expect(result.data.callbackStatus).toBe(202)
    expect(result.data.dataDomainMismatch).toBe(false)
  })

  test('figures out well placed snippet in a multi-domain mismatch', async ({ page }, { testId }) => {
    await mockEventResponseSuccess(page)

    const { url } = await initializePageDynamically(page, {
      testId,
      response: `<head><script defer data-domain="example.org,example.com,example.net" src="/tracker/js/plausible.local.js"></script></head>`
    })

    const result = await verify(page, {url: url, expectedDataDomain: "example.typo"})

    expect(result.data.plausibleInstalled).toBe(true)
    expect(result.data.snippetsFoundInHead).toBe(1)
    expect(result.data.snippetsFoundInBody).toBe(0)
    expect(result.data.callbackStatus).toBe(202)
    expect(result.data.dataDomainMismatch).toBe(true)
  })

  test('proxyLikely is false when every snippet starts with an official plausible.io URL', async ({ page }, { testId }) => {
    const prodScriptLocation = 'https://plausible.io/js/'
    
    mockEventResponseSuccess(page)

    // We speed up the test by serving "just some script"
    // (avoiding the event callback delay in verifier)
    const code = await compileFile({
      name: "plausible.local.js",
      globals: {
        "COMPILE_LOCAL": true,
        "COMPILE_PLAUSIBLE_LEGACY_VARIANT": true
      }
    }, { returnCode: true })
    
    await page.context().route(`${prodScriptLocation}**`, async (route) => {
      await route.fulfill({
        status: 200,
        contentType: 'application/javascript',
        body: code
      })
    })

    const { url } = await initializePageDynamically(page, {
      testId,
      response: `
        <head><script defer src="${prodScriptLocation + 'script.js'}" data-domain="${SOME_DOMAIN}"></script></head>
        <body><script defer src="${prodScriptLocation + 'plausible.outbound-links.js'}" data-domain="${SOME_DOMAIN}"></script></body>
      `
    })

    const result = await verify(page, {url: url, expectedDataDomain: SOME_DOMAIN})

    expect(result.data.proxyLikely).toBe(false)
  })

  test('counting snippets', async ({ page }, { testId }) => {
    await mockEventResponseSuccess(page)

    const { url } = await initializePageDynamically(page, {
      testId,
      response: `
        <head>
        <script defer data-domain="example.com" src="/tracker/js/plausible.local.js"></script>
        <script defer data-domain="example.com" src="/tracker/js/plausible.local.js"></script>
        </head>
        <body>
        <script defer data-domain="example.com" src="/tracker/js/plausible.local.js"></script>
        <script defer data-domain="example.com" src="/tracker/js/plausible.local.js"></script>
        <script defer data-domain="example.com" src="/tracker/js/plausible.local.js"></script>
        </body>
      `
    })

    const result = await verify(page, {url: url, expectedDataDomain: "example.com"})

    expect(result.data.plausibleInstalled).toBe(true)
    expect(result.data.snippetsFoundInHead).toBe(2)
    expect(result.data.snippetsFoundInBody).toBe(3)
    expect(result.data.callbackStatus).toBe(202)
    expect(result.data.dataDomainMismatch).toBe(false)
  })

  test('detects dataDomainMismatch', async ({ page }, { testId }) => {
    await mockEventResponseSuccess(page)

    const { url } = await initializePageDynamically(page, {
      testId,
      scriptConfig: `<script defer data-domain="wrong.com" src="/tracker/js/plausible.local.js"></script>`
    })

    const result = await verify(page, {url: url, expectedDataDomain: 'right.com'})

    expect(result.data.dataDomainMismatch).toBe(true)
  })

  test('dataDomainMismatch is false when data-domain without "www." prefix matches', async ({ page }, { testId }) => {
    await mockEventResponseSuccess(page)

    const { url } = await initializePageDynamically(page, {
      testId,
      scriptConfig: `<script defer data-domain="www.right.com" src="/tracker/js/plausible.local.js"></script>`
    })

    const result = await verify(page, {url: url, expectedDataDomain: 'right.com'})

    expect(result.data.dataDomainMismatch).toBe(false)
  })

})

test.describe('v1 verifier (window.plausible)', () => {
  test('callbackStatus is 404 when /api/event not found', async ({ page }, { testId }) => {
    await page.context().route('**/api/event', async (route) => {
      await route.fulfill({status: 404})
    })

    const { url } = await initializePageDynamically(page, {
      testId,
      scriptConfig: `<script defer data-domain="${SOME_DOMAIN}" src="/tracker/js/plausible.local.js"></script>`
    })

    const result = await verify(page, {url: url, expectedDataDomain: SOME_DOMAIN})

    expect(result.data.plausibleInstalled).toBe(true)
    expect(result.data.callbackStatus).toBe(404)
  })

  test('callBackStatus is 0 when event request times out', async ({ page }, { testId }) => {
    mockEventResponseSuccess(page, 20000)

    const { url } = await initializePageDynamically(page, {
      testId,
      scriptConfig: `<script defer data-domain="${SOME_DOMAIN}" src="/tracker/js/plausible.local.js"></script>`
    })

    const result = await verify(page, {url: url, expectedDataDomain: SOME_DOMAIN})

    expect(result.data.plausibleInstalled).toBe(true)
    expect(result.data.callbackStatus).toBe(0)
  })

  test('callBackStatus is -1 when a network error occurs on sending event', async ({ page }, { testId }) => {
    await page.context().route('**/api/event', async (route) => {
      await route.abort()
    })

    const { url } = await initializePageDynamically(page, {
      testId,
      scriptConfig: `<script defer data-domain="${SOME_DOMAIN}" src="/tracker/js/plausible.local.js"></script>`
    })

    const result = await verify(page, {url: url, expectedDataDomain: SOME_DOMAIN})

    expect(result.data.plausibleInstalled).toBe(true)
    expect(result.data.callbackStatus).toBe(-1)
  })
})

test.describe('v1 verifier (WordPress detection)', () => {
  test('if wordpress plugin detected, wordpressLikely is also true', async ({ page }, { testId }) => {
    await mockEventResponseSuccess(page)

    const { url } = await initializePageDynamically(page, {
      testId,
      response: `
        <head>
          <meta name="plausible-analytics-version" content="2.3.1">
          <script defer data-domain="${SOME_DOMAIN}" src="/tracker/js/plausible.local.js"></script>
        </head>
      `
    })

    const result = await verify(page, {url: url, expectedDataDomain: SOME_DOMAIN})

    expect(result.data.wordpressPlugin).toBe(true)
    expect(result.data.wordpressLikely).toBe(true)
  })

  test('detects wordpressLikely by wp signatures', async ({ page }, { testId }) => {
    await mockEventResponseSuccess(page)

    const { url } = await initializePageDynamically(page, {
      testId,
      response: `
        <head>
          <script defer data-domain="${SOME_DOMAIN}" src="/tracker/js/plausible.local.js"></script>
        </head>
        <body>
          <script src="/wp-content/themes/mytheme/script.js"></script>
        </body>
      `
    })

    const result = await verify(page, {url: url, expectedDataDomain: SOME_DOMAIN})

    expect(result.data.wordpressPlugin).toBe(false)
    expect(result.data.wordpressLikely).toBe(true)
  })
})

test.describe('v1 verifier (GTM detection)', () => {
  test('detects GTM', async ({ page }, { testId }) => {
    await mockEventResponseSuccess(page)

    const { url } = await initializePageDynamically(page, {
      testId,
      response: `
        <html>
        <head>
          <script defer data-domain="${SOME_DOMAIN}" src="/tracker/js/plausible.local.js"></script>
          <!-- Google Tag Manager -->
          <script>
            (function(w,d,s,l,i){w[l]=w[l]||[];w[l].push({'gtm.start':
            new Date().getTime(),event:'gtm.js'});var f=d.getElementsByTagName(s)[0],
            j=d.createElement(s),dl=l!='dataLayer'?'&l='+l:'';j.async=true;j.src=
            'https://www.googletagmanager.com/gtm.js?id='+i+dl;f.parentNode.insertBefore(j,f);
            })(window,document,'script','dataLayer','XXXX');
          </script>
          <!-- End Google Tag Manager -->
        </head>
        <body>Hello</body>
        </html>
      `
    })

    const result = await verify(page, {url: url, expectedDataDomain: SOME_DOMAIN})

    expect(result.data.gtmLikely).toBe(true)
  })
})

test.describe('v1 verifier (cookieBanner detection)', () => {
  test('detects a dynamically loaded cookiebot', async ({ page }, { testId }) => {
    // While in real world the plausible script would be prevented
    // from loading when cookiebot is present, to speed up the test
    // we let it load, but mock a general network error. That is to
    // avoid the a 202 response which skips cookiebot detection.
    await page.context().route('**/api/event', async (route) => {
      // To make sure the banner gets dynamically loaded before the
      // event callback finishes, we mock a 1s delay before aborting.
      await delay(1000)
      await route.abort()
    })

    const { url } = await initializePageDynamically(page, {
      testId,
      response: `
        <html>
          <head>
            <script defer data-domain="${SOME_DOMAIN}" src="/tracker/js/plausible.local.js"></script>
          </head>
          <body>
            <script>
              setTimeout(() => {
                const banner = document.createElement('div')
                banner.id = 'CybotCookiebotDialog'
                document.body.appendChild(banner)
              }, 500);
            </script>
          </body>
        </html>
      `
    })

    const result = await verify(page, {url: url, expectedDataDomain: SOME_DOMAIN})

    expect(result.data.cookieBannerLikely).toBe(true)
  })
})

test.describe('v1 verifier (manualScriptExtension detection)', () => {
  test('manualScriptExtension is true when any snippet src has "manual." in it', async ({ page }, { testId }) => {
    await mockEventResponseSuccess(page)

    const { url } = await initializePageDynamically(page, {
      testId,
      response: `
        <html>
          <head>
            <script defer data-domain="${SOME_DOMAIN}" src="/tracker/js/plausible.local.js"></script>
            <script defer data-domain="${SOME_DOMAIN}" src="/tracker/js/plausible.hash.js"></script>
          </head>
          <body>
            <script defer data-domain="${SOME_DOMAIN}" src="/tracker/js/plausible.manual.js"></script>
          </body>
        </html>
      `
    })

    const result = await verify(page, {url: url, expectedDataDomain: SOME_DOMAIN})

    expect(result.data.manualScriptExtension).toBe(true)
  })
})

test.describe('v1 verifier (unknownAttributes detection)', () => {
  test('unknownAttributes is false when all attrs are known', async ({ page }, { testId }) => {
    await mockEventResponseSuccess(page)

    const { url } = await initializePageDynamically(page, {
      testId,
      response: `
        <html>
          <head>
            <script
              defer
              type="text/javascript"
              data-cfasync="false"
              data-api="some"
              data-include="some"
              data-exclude="some"
              data-domain="${SOME_DOMAIN}"
              src="/tracker/js/plausible.manual.js">
            </script>
          </head>
        </html>
      `
    })

    const result = await verify(page, {url: url, expectedDataDomain: SOME_DOMAIN})

    expect(result.data.unknownAttributes).toBe(false)
  })

  test('unknownAttributes is true when any unknown attributes are present', async ({ page }, { testId }) => {
    await mockEventResponseSuccess(page)

    const { url } = await initializePageDynamically(page, {
      testId,
      response: `
        <html>
          <head>
            <script defer weird="one" data-domain="${SOME_DOMAIN}" src="/tracker/js/script.js"></script>
          </head>
        </html>
      `
    })

    const result = await verify(page, {url: url, expectedDataDomain: SOME_DOMAIN})

    expect(result.data.unknownAttributes).toBe(true)
  })
})

test.describe('v1 verifier (logging)', () => {
  test('console logs in debug mode', async ({ page }, { testId }) => {
    await mockEventResponseSuccess(page)

    let logs = []
    page.context().on('console', msg => msg.type() === 'log' && logs.push(msg.text()))

    const { url } = await initializePageDynamically(page, {
      testId,
      scriptConfig: `<script defer data-domain="${SOME_DOMAIN}" src="/tracker/js/plausible.local.js"></script>`
    })

    await verify(page, {url: url, expectedDataDomain: SOME_DOMAIN, debug: true})

    expect(logs.find(str => str.includes('Starting snippet detection'))).toContain('[Plausible Verification] Starting snippet detection')
    expect(logs.find(str => str.includes('Checking for Plausible function'))).toContain('[Plausible Verification] Checking for Plausible function')
  })

  test('does not log by default', async ({ page }, { testId }) => {
    await mockEventResponseSuccess(page)

    let logs = []
    page.context().on('console', msg => msg.type() === 'log' && logs.push(msg.text()))

    const { url } = await initializePageDynamically(page, {
      testId,
      scriptConfig: `<script defer data-domain="${SOME_DOMAIN}" src="/tracker/js/plausible.local.js"></script>`
    })

    await verify(page, {url: url, expectedDataDomain: SOME_DOMAIN})

    expect(logs.length).toBe(0)
  })
})
