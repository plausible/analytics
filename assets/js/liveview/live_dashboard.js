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
      this.listener = this.el.addEventListener('click', (e) => {
        const type = e.target.dataset.type || null

        if (type && type == 'dashboard-link') {
          const url = new URL(e.target.href)
          this.el.dispatchEvent(
            new CustomEvent('live-navigate', {
              bubbles: true,
              detail: { search: url.search }
            })
          )

          this.pushEvent('handle_dashboard_params', { url: url.toString() })

          e.preventDefault()
        }
      })


      this.backListener = window.addEventListener('live-navigate-back', (e) => {
        if (typeof e.detail.search === 'string') {
          console.log('live-navigate-back', e.detail.search)
          this.pushEvent('handle_dashboard_params', { url: window.location.href })
        }
      })
    },
    cleanup: function () {
      if (this.listener) {
        window.removeEventListener('live-navigate', this.listener)
        this.listener = null
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
