export type Options = {
    hash: boolean
    local: boolean
    exclusions: boolean
    manual: boolean
    revenue: boolean
    pageviewProps: boolean
    outboundLinks: boolean
    fileDownloads: boolean
    taggedEvents: boolean
    trackFormSubmissions: boolean
  }

export type ScriptConfig = {
    domain: string
    endpoint: string
  } & Partial<Options>
  