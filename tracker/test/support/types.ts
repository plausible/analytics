export type Options = {
  hashBasedRouting: boolean
  outboundLinks: boolean
  fileDownloads: boolean | { fileExtensions: string[] }
  formSubmissions: boolean
  captureOnLocalhost: boolean
  autoCapturePageviews: boolean
}

export type ScriptConfig = {
  domain: string
  endpoint: string
} & Partial<Options>

export type VerifyV2Args = {
  debug: boolean
  responseHeaders: Record<string, string>
  timeoutMs: number
  cspHostToCheck: string
}

export type VerifyV2Result = {
  data:
    | {
        completed: true
        plausibleIsOnWindow: boolean
        plausibleIsInitialized: boolean
        plausibleVersion: number
        plausibleVariant?: string
        disallowedByCsp: boolean
        cookieBannerLikely: boolean
        testEvent: {
          /**
           * window.plausible (track) callback
           */
          callbackResult?: any
          /**
           * intercepted fetch response status
           */
          responseStatus?: number
          /**
           * error caught during intercepted fetch
           */
          error?: {
            message: string
          }
          /**
           * intercepted fetch request url
           */
          requestUrl?: string
          /**
           * intercepted fetch request body normalized
           */
          normalizedBody?: {
            domain: string
            name: string
            version?: number
          }
        }
      }
    | { completed: false; error: { message: string } }
}
