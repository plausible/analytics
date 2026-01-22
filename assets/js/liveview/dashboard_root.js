/**
 * Hook widget delegating navigation events to and from React.
 * Necessary to emulate navigation events in LiveView with pushState
 * manipulation disabled.
 */

import { buildHook } from './hook_builder'

const MODAL_ROUTES = {
  '/pages': '#pages-breakdown-details-modal',
  '/entry-pages': '#entry-pages-breakdown-details-modal',
  '/exit-pages': '#exit-pages-breakdown-details-modal',
  '/sources': '#sources-breakdown-details-modal',
  '/channels': '#channels-breakdown-details-modal',
  '/utm_medium': '#utm-mediums-breakdown-details-modal'
}

function routeModal(uri) {
  // Domain is dropped from URL prefix, because that's what react-dom-router
  // expects.
  const path = '/' + uri.pathname.split('/').slice(2).join('/')

  const modalId = MODAL_ROUTES[path]

  if (modalId) {
    const modal = document.querySelector(modalId)

    if (modal) {
      modal.dispatchEvent(new Event('prima:modal:open'))
    }
  }
}

export default buildHook({
  initialize() {
    const portals = document.querySelectorAll('[data-phx-portal]')
    this.portalTargets = Array.from(portals, (p) => p.dataset.phxPortal)
    this.url = window.location.href

    this.addListener('phx:navigate', window, (info) => {
      if (info.detail?.patch && info.detail?.pop) {
        const uri = new URL(
          (info.detail.href.startsWith('http') ? '' : 'https://example.com') +
            info.detail.href
        )
        routeModal(uri)
      }
    })

    this.addListener('click', document.body, (e) => {
      const link = e.target.closest('[data-phx-link]')
      const type = link && (link.dataset.type || null)

      if (type === 'dashboard-link') {
        const uri = new URL(link.href)
        routeModal(uri)
      }
    })
  }
})
