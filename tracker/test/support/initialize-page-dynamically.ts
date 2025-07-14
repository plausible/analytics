import { Page } from '@playwright/test'
import { ScriptConfig } from './types'
import { compileWebSnippet } from '../../compiler'

interface SharedOptions {
  /** unique ID that becomes part of the dynamic page URL */
  testId: string
  /** optional path to append to the dynamic page URL */
  path?: string
}

interface TemplatedResponse {
  /** string like `<script defer id="plausible" src="/plausible.compat.local.js"></script>` or ScriptConfig to be set to web snippet */
  scriptConfig: ScriptConfig | string
  /** vanilla HTML string, which can contain JS, will be set in the body of the page */
  bodyContent: string
}

interface FullResponse {
  // Full html response
  response: string
}

interface DynamicPageInfo {
  /** the url where the page is served */
  url: string
}

const RESPONSE_BODY_TEMPLATE = `
<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <meta http-equiv="X-UA-Compatible" content="ie=edge" />
    <title>Plausible Playwright tests</title>
    <script>// Plausible script</script>
  </head>
  <body></body>
</html>
`

const PLAUSIBLE_WEB_SNIPPET = compileWebSnippet()

function getConfiguredPlausibleWebSnippet({
  autoCapturePageviews,
  ...injectedScriptConfig
}: ScriptConfig): string {
  const snippet = PLAUSIBLE_WEB_SNIPPET.replace(
    '<%= plausible_script_url %>',
    `/tracker/js/plausible-web.js?script_config=${encodeURIComponent(
      JSON.stringify(injectedScriptConfig)
    )}`
  )
  // This option, if provided, must be lifted to script init(overrides) overrides, otherwise it is ignored. It was not meant to be injected.
  if (autoCapturePageviews !== undefined) {
    return snippet.replace(
      'plausible.init()',
      `plausible.init({"autoCapturePageviews":${JSON.stringify(autoCapturePageviews)}})`
    )
  }
  return snippet
}

export async function initializePageDynamically(
  page: Page,
  options: SharedOptions & (TemplatedResponse | FullResponse)
): Promise<DynamicPageInfo> {
  const url = `/dynamic/${options.testId}${options.path || ''}`
  await page.context().route(url, async (route) => {
    let responseBody: string

    if ('response' in options) {
      responseBody = options.response
    } else {
      responseBody = RESPONSE_BODY_TEMPLATE.replace(
        '<script>// Plausible script</script>',
        typeof options.scriptConfig === 'string'
          ? options.scriptConfig
          : getConfiguredPlausibleWebSnippet(options.scriptConfig)
      ).replace('<body></body>', `<body>${options.bodyContent}</body>`)
    }

    await route.fulfill({
      body: responseBody,
      contentType: 'text/html'
    })
  })
  return { url }
}
