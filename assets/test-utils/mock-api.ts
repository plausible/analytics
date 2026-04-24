export class MockAPI {
  private mocked: Map<string, jest.Mock>
  private fetch: jest.Mock
  private originalFetch: null | unknown = null

  constructor() {
    this.mocked = new Map()
    this.fetch = jest.fn()
  }

  private setHandler(
    method: string,
    urlWithoutQueryString: string,
    handler: jest.Mock
  ) {
    this.mocked.set(
      [method.toLowerCase(), urlWithoutQueryString].join(' '),
      handler
    )
  }

  // sets get handler
  public get(
    urlWithoutQueryString: string,
    responseHandler: typeof fetch | Record<string, unknown> | number | null
  ): jest.Mock {
    const handler: typeof fetch =
      typeof responseHandler === 'function'
        ? responseHandler
        : () =>
            new Promise((resolve) =>
              resolve({
                status: 200,
                ok: true,
                json: async () => responseHandler
              } as Response)
            )
    const jestWrappedHandler = jest.fn(handler)
    this.setHandler('get', urlWithoutQueryString, jestWrappedHandler)
    return jestWrappedHandler
  }

  private getHandler(method: string, urlWithoutQueryString: string) {
    return this.mocked.get([method, urlWithoutQueryString].join(' '))
  }

  public clear() {
    this.mocked = new Map()
    this.fetch.mockClear()
  }

  public start() {
    this.originalFetch = global.fetch
    const mockFetch: typeof global.fetch = async (input, init) => {
      if (typeof input !== 'string') {
        throw new Error(`Unmocked request ${input.toString()}`)
      }
      const method = init?.method ?? 'get'
      const urlWithoutQueryString = input.split('?')[0]
      const handler = this.getHandler(method, urlWithoutQueryString)
      if (!handler) {
        throw new Error(
          `Unmocked request ${method.toString()} ${input.toString()}`
        )
      }
      return handler(input, init)
    }

    global.fetch = this.fetch.mockImplementation(mockFetch)
    return this
  }

  public stop() {
    global.fetch = this.originalFetch as typeof global.fetch
  }
}
