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
