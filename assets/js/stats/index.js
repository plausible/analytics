import Router from './router'
import * as m from './modal'

const SPINNER = `
<div class="loading my-48 mx-auto"><div></div></div>
`

function delayAtLeast(promise, time) {
  const delayed = new Promise((resolve) => setTimeout(resolve, time))
  return Promise.all([promise, delayed]).then(function(val) { return val[0] })
}

function fetchModal(modal, path) {
  const promise = fetch(path)
  m.setModalBody(modal, SPINNER)

  delayAtLeast(promise, 200)
    .then(function(res) {
      return res.text()
    }).then(function(res) {
      m.setModalBody(modal, res)
    })
}

const router = new Router()

router
  .on('/:domain/referrers', function(params) {
    m.showModal({
      onShow: function(modal) {
        fetchModal(modal, '/api/plausible.io/referrers')
      },
      onClose: function() {
        router.navigate('/' + params.domain)
      }
    })
  })
  .on('/:domain', function() {
    m.ensureModalClosed()
  })
  .resolve();
