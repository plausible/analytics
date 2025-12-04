/**
 * Hook used for LiveView dashboard. Currently its main purpose
 * is facilitiating migration from React to LiveView.
 */

const WIDGETS = {
  'dashboard-root': {
    initialize: function () {
      this.url = window.location.href

      addListener.bind(this)('click', document.body, (e) => {
        const type = e.target.dataset.type || null

        if (type === 'dashboard-link') {
          this.url = e.target.href
          const uri = new URL(this.url)
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

      addListener.bind(this)('popstate', window, () => {
        if (this.url !== window.location.href) {
          this.pushEvent('handle_dashboard_params', {
            url: window.location.href
          })
        }
      })

      addListener.bind(this)('dashboard:live-navigate-back', window, (e) => {
        if (
          typeof e.detail.search === 'string' &&
          this.url !== window.location.href
        ) {
          this.pushEvent('handle_dashboard_params', {
            url: window.location.href
          })
        }
      })
    },
    cleanup: function () {
      removeListeners.bind(this)()
    }
  },
  tabs: {
    initialize: function () {
      const domain = getDomain(window.location.href)

      addListener.bind(this)('click', this.el, (e) => {
        const button = e.target.closest('button')
        const tab = button && button.dataset.tab

        if (tab) {
          const label = button.dataset.label
          const storageKey = button.dataset.storageKey
          const activeClasses = button.dataset.activeClasses
          const inactiveClasses = button.dataset.inactiveClasses
          const title = this.el
            .closest('[data-tile]')
            .querySelector('[data-title]')

          title.innerText = label

          this.el.querySelectorAll(`button[data-tab] span`).forEach((s) => {
            s.className = inactiveClasses
          })

          button.querySelector('span').className = activeClasses

          if (storageKey) {
            localStorage.setItem(`${storageKey}__${domain}`, tab)
          }
        }
      })
    },
    cleanup: function () {
      removeListeners.bind(this)()
    }
  }
}

function getDomain(url) {
  const uri = typeof url === 'object' ? url : new URL(url)
  return uri.pathname.split('/')[1]
}

function addListener(eventName, listener, callback) {
  this.listeners = this.listeners || []

  listener.addEventListener(eventName, callback)

  this.listeners.push({
    element: listener,
    event: eventName,
    callback: callback
  })
}

function removeListeners() {
  if (this.listeners) {
    this.listeners.forEach((l) => {
      l.element.removeEventListener(l.event, l.callback)
    })

    this.listeners = null
  }
}

export default {
  mounted() {
    this.widget = this.el.getAttribute('data-widget')

    this.initialize()
  },

  updated() {
    this.initialize()
  },

  reconnected() {
    this.initialize()
  },

  destroyed() {
    this.cleanup()
  },

  initialize() {
    this.cleanup()
    WIDGETS[this.widget].initialize.bind(this)()
  },

  cleanup() {
    WIDGETS[this.widget].cleanup.bind(this)()
  }
}
