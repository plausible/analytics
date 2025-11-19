const WIDGETS = {
  'patch-filters-button': {
    initialize: function () {
      const that = this

      this.listener = this.el.addEventListener('click', () => {
        const filter = that.el.getAttribute('data-filter')

        top.postMessage(
          { type: 'EMBEDDED_LV_PATCH_FILTER', filter: JSON.parse(filter) },
          '*'
        )
      })
    },
    cleanup: function () {
      if (this.listener) {
        that.el.removeEventListener('click', this.listener)
        this.listener = null
      }
    }
  },
  'modal-button': {
    initialize: function () {},
    cleanup: function () {}
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
