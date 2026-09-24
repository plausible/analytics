import { expect, test, type Page } from '@playwright/test'
import { createHash, randomBytes } from 'crypto'
import { enableFeatureFlag, setupSite } from '../fixtures'
import { expectLiveViewConnected } from '../test-utils'

// Set by playwright.config.ts, which passes the same values on to the server -
// PlausibleWeb.E2E.OAuthClient serves a metadata document built from them, so
// both ends read one definition.
const CLIENT_ID = process.env.E2E_OAUTH_CLIENT_ID!
const CLIENT_NAME = process.env.E2E_OAUTH_CLIENT_NAME!
const REDIRECT_URI = process.env.E2E_OAUTH_REDIRECT_URI!

// The verifier goes unused until the token endpoint exchanges the code - see
// PlausibleWeb.OAuth.TokenController, which still answers 501.
function pkce() {
  const verifier = randomBytes(32).toString('base64url')
  const challenge = createHash('sha256').update(verifier).digest('base64url')

  return { verifier, challenge }
}

function authorizeURL({
  challenge,
  state,
  baseURL
}: {
  challenge: string
  state: string
  baseURL: string
}) {
  const params = new URLSearchParams({
    client_id: CLIENT_ID,
    redirect_uri: REDIRECT_URI,
    response_type: 'code',
    code_challenge: challenge,
    code_challenge_method: 'S256',
    scope: 'sites:read:*',
    state,
    resource: `${baseURL}/mcp`
  })

  return `/login/oauth/authorize?${params}`
}

// Server-rendered markup in this app tags elements `data-test-id`, which is not
// the attribute getByTestId reads.
const clientIdentity = (page: Page) =>
  page.locator('[data-test-id="client-identity"]')

// Nothing listens on the client's loopback redirect_uri, so the navigation the
// authorization response triggers is answered here. The URL is what the test
// reads; the body only has to load.
async function stubClientCallback(page: Page) {
  await page.route(`${REDIRECT_URI}**`, (route) =>
    route.fulfill({
      status: 200,
      contentType: 'text/html',
      body: '<h1>client callback</h1>'
    })
  )
}

async function responseParams(page: Page) {
  await page.waitForURL(`${REDIRECT_URI}**`)

  return new URL(page.url()).searchParams
}

test.describe('OAuth consent screen', () => {
  test('approving returns an authorization code', async ({
    page,
    request,
    baseURL
  }) => {
    await setupSite({ page, request })
    await enableFeatureFlag({ request, flag: 'mcp' })
    await stubClientCallback(page)

    const { challenge } = pkce()

    await page.goto(
      authorizeURL({ challenge, state: 'e2e-state', baseURL: baseURL! }),
      { waitUntil: 'commit' }
    )

    await expectLiveViewConnected(page)

    await expect(clientIdentity(page)).toContainText(CLIENT_NAME)
    await expect(clientIdentity(page)).toContainText(CLIENT_ID)
    await expect(
      page.getByText('Read the list and details of your sites')
    ).toBeVisible()

    await page.getByRole('button', { name: 'Approve' }).click()

    const returned = await responseParams(page)

    expect(returned.get('state')).toEqual('e2e-state')
    expect(returned.get('code')).toBeTruthy()
  })

  test('denying returns access_denied and no code', async ({
    page,
    request,
    baseURL
  }) => {
    await setupSite({ page, request })
    await enableFeatureFlag({ request, flag: 'mcp' })
    await stubClientCallback(page)

    const { challenge } = pkce()

    await page.goto(
      authorizeURL({ challenge, state: 'e2e-state', baseURL: baseURL! }),
      { waitUntil: 'commit' }
    )

    await expectLiveViewConnected(page)

    await page.getByRole('button', { name: 'Deny' }).click()

    const returned = await responseParams(page)

    expect(returned.get('error')).toEqual('access_denied')
    expect(returned.get('state')).toEqual('e2e-state')
    expect(returned.get('code')).toBeNull()
  })
})
