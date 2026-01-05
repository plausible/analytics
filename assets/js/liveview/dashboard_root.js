/**
 * Hook widget delegating navigation events to and from React.
 * Necessary to emulate navigation events in LiveView with pushState
 * manipulation disabled.
 */

import { buildHook } from './hook_builder'

function navigateWithLoader(url) {
  this.portalTargets.map((target) => {
    this.js().addClass(document.querySelector(target), 'phx-navigation-loading')

    this.pushEvent('handle_dashboard_params', { url: url }, () => {
      this.js().removeClass(
        document.querySelector(target),
        'phx-navigation-loading'
      )
    })
  })
}

export default buildHook({
  initialize() {
    this.url = window.location.href

    const portals = document.querySelectorAll('[data-phx-portal]')
    this.portalTargets = Array.from(portals, (p) => p.dataset.phxPortal)

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

        navigateWithLoader.bind(this)(this.url)

        e.preventDefault()
      }
    })

    // Browser back and forward navigation triggers that event.
    this.addListener('popstate', window, () => {
      if (this.url !== window.location.href) {
        navigateWithLoader.bind(this)(window.location.href)
      }
    })

    // Navigation events triggered from liveview are propagated via this
    // handler.
    this.addListener('dashboard:live-navigate-back', window, (e) => {
      if (
        typeof e.detail.search === 'string' &&
        this.url !== window.location.href
      ) {
        navigateWithLoader.bind(this)(window.location.href)
      }
    })
  }
})
