/**
 * Hook widget for optimistic loading of tabs and
 * client-side persistence of selection using localStorage.
 */

import { buildHook } from './hook_builder'

function getDomain(url) {
  const uri = typeof url === 'object' ? url : new URL(url)
  return uri.pathname.split('/')[1]
}

export default buildHook({
  initialize() {
    const domain = getDomain(window.location.href)

    this.addListener('click', this.el, (e) => {
      const button = e.target.closest('button')
      const tab = button && button.dataset.tab
      const span = button && button.querySelector('span')

      if (span && span.dataset.active === 'false') {
        const label = button.dataset.label
        const storageKey = button.dataset.storageKey
        const target = button.dataset.target
        const tile = this.el.closest('[data-tile]')
        const title = tile.querySelector('[data-title]')

        title.innerText = label

        this.el.querySelectorAll(`button[data-tab] span`).forEach((s) => {
          this.js().setAttribute(s, 'data-active', 'false')
        })

        this.js().setAttribute(
          button.querySelector('span'),
          'data-active',
          'true'
        )

        if (storageKey) {
          localStorage.setItem(`${storageKey}__${domain}`, tab)
        }

        this.pushEventTo(target, 'set-tab', { tab: tab })
      }
    })
  }
})
