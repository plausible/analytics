import { Page } from '@playwright/test'

type RequestData = Record<string, unknown>
type ShouldIgnoreRequest = (requestData?: RequestData) => boolean

export async function mockManyRequests({
  page,
  path,
  numberOfRequests,
  responseDelay,
  shouldIgnoreRequest,
  mockRequestTimeout = 3000
}: {
  page: Page
  path: string
  numberOfRequests: number
  responseDelay?: number
  shouldIgnoreRequest?: ShouldIgnoreRequest | ShouldIgnoreRequest[]
  mockRequestTimeout?: number
}) {
  const requestList: any[] = []
  await page.route(path, async (route, request) => {
    const postData = request.postDataJSON()
    if (shouldAllow(postData, shouldIgnoreRequest)) {
      requestList.push(postData)
    }
    if (responseDelay) {
      await delay(responseDelay)
    }
    await route.fulfill({
      status: 202,
      contentType: 'text/plain',
      body: 'ok'
    })
  })

  const getWaitForRequests = () =>
    new Promise((resolve) => {
      let i = 0
      const POLL_INTERVAL_MS = 10
      const interval = setInterval(() => {
        if (i > mockRequestTimeout / POLL_INTERVAL_MS) {
          clearInterval(interval)
          resolve(requestList)
        } else if (requestList.length === numberOfRequests) {
          clearInterval(interval)
          resolve(requestList)
        } else {
          i++
        }
      }, POLL_INTERVAL_MS)
    })

  return getWaitForRequests
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
