const WIDGETS = {
  // 'navigation-tracker': {
  //   initialize: function () {
  //     console.log('Setting up navigation tracker...')
  //
  //     this.listener = window.addEventListener('phx:navigate', () => {
  //       console.log('STATE PUSHED!', document.location)
  //     })
  //   },
  //   cleanup: function () {
  //     if (this.listener) {
  //       console.log('Removing navigation tracker...')
  //       window.removeEventListener('phx:navigate', this.listener)
  //       this.listener = null
  //     }
  //   }
  // },
  'modal-button': {
    initialize: function () {},
    cleanup: function () {}
  },
  'breakdown-tile': {
    initialize: function () {
      console.log('Initializing widget', this.el.id)
      const that = this

      this.url = window.location.href

      this.listeners = []

      const clickListener = this.el.addEventListener('click', (e) => {
        const type = e.target.dataset.type || null

        if (type && type == 'dashboard-link') {
          that.url = e.target.href
          const uri = new URL(that.url)
          that.el.dispatchEvent(
            new CustomEvent('live-navigate', {
              bubbles: true,
              detail: { search: uri.search }
            })
          )

          that.pushEvent('handle_dashboard_params', { url: that.url })

          e.preventDefault()
        }
      })

      this.listeners.push({
        element: this.el,
        event: 'click',
        callback: clickListener
      })

      // const popListener = window.addEventListener('popstate', (e) => {
      //   if (that.url !== window.location.href) {
      //     that.pushEvent('handle_dashboard_params', {
      //       url: window.location.href
      //     })
      //   }
      // })
      //
      // this.listeners.push({
      //   element: window,
      //   event: 'popstatae',
      //   callback: popListener
      // })
      //
      const backListener = window.addEventListener(
        'live-navigate-back',
        (e) => {
          if (
            typeof e.detail.search === 'string' &&
            that.url !== window.location.href
          ) {
            that.pushEvent('handle_dashboard_params', {
              url: window.location.href
            })
          }
        }
      )

      this.listeners.push({
        element: window,
        event: 'live-navigate-back',
        callback: backListener
      })
    },
    cleanup: function () {
      console.log('Cleaning up widget', this.el.id)

      if (this.listeners) {
        console.log('Cleaning up listeners')
        this.listeners.forEach((l) => {
          l.element.removeEventListener(l.event, l.callback)
        })

        this.listeners = null
      }
    }
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
