import { Page } from '@playwright/test'
import { delay } from './test-utils'

type RequestData = Record<string, unknown>
type ShouldIgnoreRequest = (requestData?: RequestData) => boolean

const DEFAULT_RESPONSE = { status: 200, contentType: 'text/plain', body: 'ok' }

interface MockManyRequestsOptions {
  /**
   * Set `scopeMockToPage` to `true` if there is a need to verify that the mock request
   * happens on the passed `page`.
   * Default value is `false`, which means it records requests that open in new tabs as well.
   * Note: You can create two mocks for the same path, one on the page and other on the browser if needed.
   */
  scopeMockToPage?: boolean
  page: Page
  path: string
  /**
   * Response to fulfill the request with.
   * Defaults to DEFAULT_RESPONSE. Allows overriding properties from the default one by one.
   * @see DEFAULT_RESPONSE
   */
  fulfill?: {
    status?: number
    contentType?: string
    body?: string
  }
  /**
   * When there's at least `awaitedRequestCount` unignored requests on this route,
   * getRequestList resolves without waiting for `mockRequestTimeout`.
   * If there's less than `awaitedRequestCount` unignored requests on this route, it
   * takes `mockRequestTimeout` to resolve `getRequestList`.
   * This is so as not miss unexpected requests that are sent slowly.
   */
  awaitedRequestCount: number
  responseDelay?: number
  shouldIgnoreRequest?: ShouldIgnoreRequest | ShouldIgnoreRequest[]
  mockRequestTimeout?: number
}

export async function mockManyRequests({
  scopeMockToPage,
  page,
  path,
  fulfill,
  awaitedRequestCount,
  responseDelay,
  shouldIgnoreRequest,
  mockRequestTimeout = 3000
}: MockManyRequestsOptions) {
  const requestList: unknown[] = []
  const scope = scopeMockToPage ? page : page.context()
  await scope.route(path, async (route, request) => {
    if (responseDelay) {
      await delay(responseDelay)
    }
    const postData = request.postDataJSON()
    if (shouldAllow(postData, shouldIgnoreRequest)) {
      requestList.push(postData)
    }
    await route.fulfill({
      ...DEFAULT_RESPONSE,
      ...fulfill
    })
  })

  const getRequestList = (): Promise<unknown[]> =>
    new Promise((resolve) => {
      let i = 0
      const POLL_INTERVAL_MS = 10
      const interval = setInterval(() => {
        if (i > mockRequestTimeout / POLL_INTERVAL_MS) {
          clearInterval(interval)
          resolve(requestList)
        } else if (requestList.length === awaitedRequestCount) {
          clearInterval(interval)
          resolve(requestList)
        } else {
          i++
        }
      }, POLL_INTERVAL_MS)
    })

  return { getRequestList }
}

function shouldAllow(
  requestData: RequestData,
  ignores: ShouldIgnoreRequest | ShouldIgnoreRequest[] | undefined
) {
  if (Array.isArray(ignores)) {
    return !ignores.some((shouldIgnore) => shouldIgnore(requestData))
  } else if (ignores) {
    return !ignores(requestData)
  } else {
    return true
  }
}
