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
      const tabKey = button && button.dataset.tabKey

      if (button && button.closest('div').dataset.active === 'false') {
        const storageKey = button.dataset.storageKey
        const target = button.dataset.target

        this.el.querySelectorAll(`button[data-tab-key]`).forEach((b) => {
          if (b.dataset.tabKey === tabKey) {
            this.js().setAttribute(b.closest('div'), 'data-active', 'true')
            this.js().setAttribute(
              b.querySelector('span'),
              'data-active',
              'true'
            )
          } else {
            this.js().setAttribute(b.closest('div'), 'data-active', 'false')
            this.js().setAttribute(
              b.querySelector('span'),
              'data-active',
              'false'
            )
          }
        })

        if (storageKey) {
          localStorage.setItem(`${storageKey}__${domain}`, tabKey)
        }

        this.pushEventTo(target, 'set-tab', { tab: tabKey })
      }
    })
  }
})
