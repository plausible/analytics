export type Options = {
  hashBasedRouting: boolean
  outboundLinks: boolean
  fileDownloads: boolean | { fileExtensions: string[] }
  formSubmissions: boolean
  captureOnLocalhost: boolean
  autoCapturePageviews: boolean
  customProperties: Record<string, any> | ((eventName: string) => Record<string, any>)
  transformRequest: (payload: unknown) => unknown,
  logging: boolean
}

export type ScriptConfig = {
  domain: string
  endpoint: string
} & Partial<Options>
