import { Page } from '@playwright/test'

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
  shouldIgnoreRequest?: (requestData?: Record<string, unknown>) => boolean
  mockRequestTimeout?: number
}) {
  const requestList: any[] = []
  await page.route(path, async (route, request) => {
    const postData = request.postDataJSON()
    if (!shouldIgnoreRequest || !shouldIgnoreRequest(postData)) {
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

function delay(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms))
}
