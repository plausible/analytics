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
      router.updateLinkHandlers()
    })
}

const router = new Router()

function showModal(domain, endpoint) {
  m.showModal({
    onShow: function(modal) {
      fetchModal(modal, endpoint)
    },
    onClose: function() {
      router.navigate('/' + domain)
    }
  })
}

router
  .on('/:domain/referrers/:referrer', function(params) {
    showModal(params.domain, `/api/${params.domain}/referrers/${params.referrer}`)
  })
  .on('/:domain/referrers', function(params) {
    showModal(params.domain, `/api/${params.domain}/referrers`)
  })
  .on('/:domain/pages', function(params) {
    showModal(params.domain, `/api/${params.domain}/pages`)
  })
  .on('/:domain/countries', function(params) {
    showModal(params.domain, `/api/${params.domain}/countries`)
  })
  .on('/:domain/operating-systems', function(params) {
    showModal(params.domain, `/api/${params.domain}/operating-systems`)
  })
  .on('/:domain/browsers', function(params) {
    showModal(params.domain, `/api/${params.domain}/browsers`)
  })
  .on('/:domain', function() {
    m.ensureModalClosed()
  })
  .resolve();
