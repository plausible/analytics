import { Page } from '@playwright/test'
import { ScriptConfig } from './types'

interface DynamicPageOptions {
  scriptConfig: ScriptConfig
  /** vanilla HTML string, which can contain JS, will be set in the body of the page */
  bodyContent: string
}

export function initializePageDynamically(
  page: Page,
  { scriptConfig, bodyContent }: DynamicPageOptions
) {
  return page.addInitScript(
    ({ scriptConfig, bodyContent }) => {
      window.addEventListener('load', function () {
        const scriptElement = this.document.createElement('script')
        scriptElement.setAttribute(
          'src',
          `/tracker/js/plausible-main.js?script_config=${encodeURIComponent(
            JSON.stringify(scriptConfig)
          )}`
        )
        scriptElement.setAttribute('defer', '')
        this.document.body.appendChild(scriptElement)

        const contentElement = this.document.createElement('div')
        contentElement.innerHTML = bodyContent
        this.document.body.appendChild(contentElement)
      })
    },
    { scriptConfig, bodyContent }
  )
}
