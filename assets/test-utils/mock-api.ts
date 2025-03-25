export class MockAPI {
  private mocked: Map<string, () => Promise<Response>>
  private fetch: jest.Mock
  private originalFetch: null | unknown = null

  constructor() {
    this.mocked = new Map()
    this.fetch = jest.fn()
  }

  private setHandler(
    method: string,
    url: string,
    handler: () => Promise<Response>
  ) {
    this.mocked.set([method.toLowerCase(), url].join(' '), handler)
  }

  public get(url: string, response: (() => Promise<Response>) | unknown) {
    const handler =
      typeof response === 'function'
        ? (response as () => Promise<Response>)
        : () =>
            new Promise<Response>((resolve) =>
              resolve({
                status: 200,
                ok: true,
                json: async () => response
              } as Response)
            )
    this.setHandler('get', url, handler)
    return this
  }

  private getHandler(method: string, url: string) {
    return this.mocked.get([method, url].join(' '))
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

      const handler = this.getHandler(method, input)
      if (!handler) {
        throw new Error(
          `Unmocked request ${method.toString()} ${input.toString()}`
        )
      }
      return handler()
    }

    global.fetch = this.fetch.mockImplementation(mockFetch)
    return this
  }

  public stop() {
    global.fetch = this.originalFetch as typeof global.fetch
  }
}
