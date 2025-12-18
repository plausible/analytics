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

      if (tab && !button.dataset.active) {
        const label = button.dataset.label
        const storageKey = button.dataset.storageKey
        const activeClasses = button.dataset.activeClasses
        const inactiveClasses = button.dataset.inactiveClasses
        const tile = this.el.closest('[data-tile')
        const title = tile.querySelector('[data-title]')

        title.innerText = label

        this.el.querySelectorAll(`button[data-tab]`).forEach((b) => {
          b.querySelector('span').className = inactiveClasses
          b.dataset.active = ''
        })

        button.querySelector('span').className = activeClasses
        button.dataset.active = 'true'

        if (storageKey) {
          localStorage.setItem(`${storageKey}__${domain}`, tab)
        }
      }
    })
  }
})
