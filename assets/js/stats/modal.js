const SPINNER = `
<div class="loading my-48 mx-auto"><div></div></div>
`

const EMPTY_MODAL = `
<div class="modal micromodal-slide" id="stats-modal" aria-hidden="true">
  <div class="modal__overlay" tabindex="-1" data-micromodal-close>
    <div class="modal__container"></div>
  </div>
</div>
`

let el, instance;

export function showModal(callbacks) {
  if (!el) {
    const modal = document.createElement('div')
    modal.innerHTML = EMPTY_MODAL
    document.body.append(modal)
    el = modal
  }

  MicroModal.show('stats-modal', {
    disableFocus: true,
    disableScroll: true,
    onShow: function(modal, e) {
      instance = this
      callbacks.onShow(modal)
    },
    onClose: function(modal) {
      setModalBody(modal, '')
      callbacks.onClose(modal)
    }
  })
}

export function setModalBody(modal, body) {
  modal.children[0].children[0].innerHTML = body
}

export function ensureModalClosed() {
  if (instance) {
    const currentOnClose = instance.onClose
    instance.onClose = function() {}
    MicroModal.close('stats-modal')
  }
}
