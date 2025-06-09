import { Page } from '@playwright/test'

type RequestData = Record<string, unknown>
type ShouldIgnoreRequest = (requestData?: RequestData) => boolean

export async function mockManyRequests({
  page,
  path,
  fulfill = {
      status: 202,
      contentType: 'text/plain',
      body: 'ok'
    },
  countOfRequestsToAwait,
  responseDelay,
  shouldIgnoreRequest,
  mockRequestTimeoutMs = 3000
}: {
  page: Page
  path: string
  /** Response to fulfill the request with */
  fulfill?: {
    status: number
    contentType: string
    body: string
  }
  /** 
   * When there's at least `countOfRequestsToAwait` requests on this route, 
   * getRequestList resolves without waiting for `mockRequestTimeoutMs`.
   * If there's less than `countOfRequestsToAwait` requests on this route, it
   * takes `mockRequestTimeoutMs` to resolve getRequestList. 
   * This is so as not miss requests that are yet to be sent.
   */
  countOfRequestsToAwait: number
  responseDelay?: number
  shouldIgnoreRequest?: ShouldIgnoreRequest | ShouldIgnoreRequest[]
  mockRequestTimeoutMs?: number
}) {
  const requestList: unknown[] = []
  await page.route(path, async (route, request) => {
    const postData = request.postDataJSON()
    if (shouldAllow(postData, shouldIgnoreRequest)) {
      requestList.push(postData)
    }
    if (responseDelay) {
      await delay(responseDelay)
    }
    await route.fulfill(fulfill)
  })

  const getRequestList = (): Promise<unknown[]> =>
    new Promise((resolve) => {
      let i = 0
      const POLL_INTERVAL_MS = 10
      const interval = setInterval(() => {
        if (i > mockRequestTimeoutMs / POLL_INTERVAL_MS) {
          clearInterval(interval)
          resolve(requestList)
        } else if (requestList.length === countOfRequestsToAwait) {
          clearInterval(interval)
          resolve(requestList)
        } else {
          i++
        }
      }, POLL_INTERVAL_MS)
    })

  return {getRequestList}
}

function shouldAllow(requestData: RequestData, ignores: ShouldIgnoreRequest | ShouldIgnoreRequest[] | undefined) {
  if (Array.isArray(ignores)) {
    return !ignores.some((shouldIgnore) => shouldIgnore(requestData))
  } else if (ignores) {
    return !ignores(requestData)
  } else {
    return true
  }
}

function delay(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms))
}
