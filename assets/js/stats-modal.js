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

const MODAL_PATHS = {
  'referrer-modal': '/referrers',
  'pages-modal': '/pages',
  'screens-modal': '/screens',
  'operating-systems-modal': '/operating-systems',
  'browsers-modal': '/browsers',
}

const MODAL_ANIMATION_DURATION_MS = 200

function delayAtLeast(promise, time) {
  const delayed = new Promise((resolve) => setTimeout(resolve, time))
  return Promise.all([promise, delayed]).then(function(val) { return val[0] })
}

function fetchModal(modal, triggerId) {
  const path = MODAL_PATHS[triggerId]

  if (path) {
    const promise = fetch("/plausible.io" + path + location.search)
    modal.children[0].children[0].innerHTML = SPINNER

    delayAtLeast(promise, MODAL_ANIMATION_DURATION_MS)
      .then(function(res) {
        return res.text()
      }).then(function(res) {
        modal.children[0].children[0].innerHTML = res
      })
  }
}

function showModal(triggerId) {
  MicroModal.show('stats-modal', {
    disableFocus: true,
    awaitCloseAnimation: true,
    onShow: function(modal, e) {
      Object.assign(document.body.style, {overflow: 'hidden', height: '100vh'})
      fetchModal(modal, triggerId)
    },
    onClose: function(modal) {
      Object.assign(document.body.style, {overflow: '', height: ''})
      setTimeout(function() { modal.children[0].children[0].innerHTML = '' }, MODAL_ANIMATION_DURATION_MS + 200)
    }
  })
}

const triggers = document.querySelectorAll('[data-micromodal-trigger]')

for (const trigger of triggers) {
  trigger.addEventListener('click', function() {
    const modal = document.createElement('div')
    modal.innerHTML = EMPTY_MODAL
    document.body.append(modal)

    showModal(trigger.getAttribute('data-micromodal-trigger'))
  })
}

