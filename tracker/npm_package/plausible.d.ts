// Sets up the tracking library. Can be called once.
export function init(config: PlausibleConfig): void

// Tracks an event, requires `init` to be called first.
export function track(eventName: string, options: PlausibleEventOptions): void

export interface PlausibleConfig {
  // Your site's domain, as declared by you in Plausible's settings.
  domain: string,

  // The URL of the Plausible API endpoint. Defaults to https://plausible.io/api/event
  // See proxying guide at https://plausible.io/docs/proxy/introduction
  endpoint?: string

  // Whether to automatically capture pageviews. Defaults to true.
  autoCapturePageviews?: boolean

  // Whether the page uses hash based routing. Defaults to false.
  // Read more at https://plausible.io/docs/hash-based-routing
  hashBasedRouting?: boolean

  // Whether to track outbound link clicks. Defaults to false.
  outboundLinks?: boolean

  // Whether to track file downloads. Defaults to false.
  fileDownloads?: boolean | { fileExtensions: string[] }

  // Whether to track form submissions. Defaults to false.
  formSubmissions?: boolean

  // Whether to capture events on localhost. Defaults to false.
  captureOnLocalhost?: boolean

  // Whether to log on ignored events. Defaults to true.
  logging?: boolean

  // Custom properties to add to all events tracked.
  // If passed as a function, it will be called when `track` is called.
  customProperties?: CustomProperties | ((eventName: string) => CustomProperties)

  // A function that can be used to transform the payload before it is sent to the API.
  // If the function returns null or any other falsy value, the event will be ignored.
  //
  // This can be used to avoid sending certain types of events, or modifying any event
  // parameters, e.g. to clean URLs of values that should not be recorded.
  transformRequest?: (payload: PlausibleRequestPayload) => PlausibleRequestPayload | null

  // If enabled (the default), the script will set `window.__plausible_npm` variable to true.
  // This is used by the verifier to detect if the script is loaded from npm package.
  setWindowFlag?: boolean
}

export interface PlausibleEventOptions {
  // Custom properties to add to the event.
  // Read more at https://plausible.io/docs/custom-props/introduction
  props?: CustomProperties

  // Whether the tracked event is interactive. Defaults to true.
  // By marking a custom event as non-interactive, it will not be counted towards bounce rate calculations.
  interactive?: boolean

  // Revenue data to add to the event.
  // Read more at https://plausible.io/docs/ecommerce-revenue-tracking
  revenue?: PlausibleEventRevenue

  // Called when request to `endpoint` completes or is ignored.
  // When request is ignored, the result will be undefined.
  // When request was delivered, the result will be an object with the response status code of the request.
  // When there was a network error, the result will be an object with the error object.
  callback?: (result?: { status: number } | { error: unknown } | undefined) => void

  // Overrides the URL of the page that the event is being tracked on.
  // If not provided, `location.href` will be used.
  url?: string
}

export type CustomProperties = Record<string, string>

export type PlausibleEventRevenue = {
  // Revenue amount in `currency`
  amount: number | string,
  // Currency is an ISO 4217 string representing the currency code, e.g. "USD" or "EUR"
  currency: string
}

export type PlausibleRequestPayload = {
  // Event name
  n: string,
  // URL of the event
  u: string,
  // Domain of the event
  d: string,
  // Referrer
  r?: string | null,
  // Custom properties
  p?: CustomProperties,
  // Revenue information
  $?: PlausibleEventRevenue,
  // Whether the event is interactive
  i?: boolean,
} & Record<string, unknown>

// Default file types that are tracked when `fileDownloads` is enabled.
export const DEFAULT_FILE_TYPES: string[]
