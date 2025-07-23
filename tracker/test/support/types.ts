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
  cspHostsToCheck: string[]
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
        testEvent: {
          callbackResult?: any
          responseStatus?: number
          error?: { 
            message: string
          }
          url?: string
          normalizedBody?: {
            domain: string
            name: string
            version?: number
          }
          cookieBannerLikely: boolean
        }
      }
    | { completed: false; error: string }
}
