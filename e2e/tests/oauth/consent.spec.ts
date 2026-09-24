import { test, expect } from '@playwright/test'
import { createHash, randomBytes } from 'crypto'
import { setupSite } from '../fixtures'
import { expectLiveViewConnected } from '../test-utils'

// Defined in config/.env.e2e_test, which the server loads and this process
// inherits - the same route BASE_URL takes. PlausibleWeb.E2E.OAuthClient serves
// a metadata document built from these, so both ends read one definition.
function env(name: string): string {
  const value = process.env[name]

  if (!value) {
    throw new Error(
      `${name} is not set - these tests are run via \`mix test.e2e\``
    )
  }

  return value
}

const CLIENT_ID = env('E2E_OAUTH_CLIENT_ID')
const CLIENT_NAME = env('E2E_OAUTH_CLIENT_NAME')
const REDIRECT_URI = env('E2E_OAUTH_REDIRECT_URI')

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
const clientIdentity = (page: import('@playwright/test').Page) =>
  page.locator('[data-test-id="client-identity"]')

// Nothing listens on the client's loopback redirect_uri, so the navigation the
// authorization response triggers is answered here. The URL is what the test
// reads; the body only has to load.
async function stubClientCallback(page: import('@playwright/test').Page) {
  await page.route(`${REDIRECT_URI}**`, (route) =>
    route.fulfill({
      status: 200,
      contentType: 'text/html',
      body: '<h1>client callback</h1>'
    })
  )
}

async function responseParams(page: import('@playwright/test').Page) {
  await page.waitForURL(`${REDIRECT_URI}**`)

  return new URL(page.url()).searchParams
}

test.describe('OAuth consent screen', () => {
  test('approving returns a code that exchanges for an access token', async ({
    page,
    request,
    baseURL
  }) => {
    await setupSite({ page, request })
    await stubClientCallback(page)

    const { verifier, challenge } = pkce()

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

    const code = returned.get('code')
    expect(code).toBeTruthy()

    const response = await request.post('/login/oauth/token', {
      form: {
        grant_type: 'authorization_code',
        client_id: CLIENT_ID,
        code: code!,
        code_verifier: verifier,
        redirect_uri: REDIRECT_URI,
        resource: `${baseURL}/mcp`
      }
    })

    expect(response.ok()).toBeTruthy()

    const token = await response.json()

    expect(token.token_type).toEqual('Bearer')
    expect(token.scope).toEqual('sites:read:*')
    expect(token.access_token).toBeTruthy()
  })

  test('denying returns access_denied and no code', async ({
    page,
    request,
    baseURL
  }) => {
    await setupSite({ page, request })
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
