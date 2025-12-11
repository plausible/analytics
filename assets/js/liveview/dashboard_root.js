/**
 * Hook widget delegating navigation events to and from React.
 * Necessary to emulate navigation events in LiveView with pushState
 * manipulation disabled.
 */

import { buildHook } from './hook_builder'

export default buildHook({
  initialize() {
    this.url = window.location.href

    this.addListener('click', document.body, (e) => {
      const type = e.target.dataset.type || null

      if (type === 'dashboard-link') {
        this.url = e.target.href
        const uri = new URL(this.url)
        // Domain is dropped from URL prefix, because that's what react-dom-router
        // expects.
        const path = '/' + uri.pathname.split('/').slice(2).join('/')
        this.el.dispatchEvent(
          new CustomEvent('dashboard:live-navigate', {
            bubbles: true,
            detail: { path: path, search: uri.search }
          })
        )

        this.pushEvent('handle_dashboard_params', { url: this.url })

        e.preventDefault()
      }
    })

    // Browser back and forward navigation triggers that event.
    this.addListener('popstate', window, () => {
      if (this.url !== window.location.href) {
        this.pushEvent('handle_dashboard_params', {
          url: window.location.href
        })
      }
    })

    // Navigation events triggered from liveview are propagated via this
    // handler.
    this.addListener('dashboard:live-navigate-back', window, (e) => {
      if (
        typeof e.detail.search === 'string' &&
        this.url !== window.location.href
      ) {
        this.pushEvent('handle_dashboard_params', {
          url: window.location.href
        })
      }
    })
  }
})
