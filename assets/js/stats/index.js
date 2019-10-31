import Router from './router'
import * as m from './modal'
import {renderMainGraph, renderComparisons} from './main-graph'

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
      fetchModal(modal, endpoint + window.location.search)
    },
    onClose: function() {
      router.navigate('/' + domain + window.location.search)
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

const domainEl = document.querySelector('[data-site-domain]')
if (domainEl) {
  const domain = domainEl.getAttribute('data-site-domain')

  const promises = []

  promises.push(
    fetch(`/stats/${domain}/main-graph${location.search}`)
      .then(res => res.json())
      .then(res => renderMainGraph(res))
      .then(graphData => fetch(`/api/${domain}/compare${location.search || '?'}&pageviews=${graphData.pageviews}&unique_visitors=${graphData.unique_visitors}`))
      .then(res => res.json())
      .then(res => renderComparisons(res))
  )

  promises.push(
    fetch(`/stats/${domain}/referrers${location.search}`)
      .then(res => res.text())
      .then((res) => {
        document.getElementById('referrer-stats').innerHTML = res
        router.updateLinkHandlers()
      })
  )

  promises.push(
    fetch(`/stats/${domain}/pages${location.search}`)
      .then(res => res.text())
      .then((res) => {
        document.getElementById('pages-stats').innerHTML = res
        router.updateLinkHandlers()
      })
  )

  promises.push(
    fetch(`/stats/${domain}/countries${location.search}`)
      .then(res => res.text())
      .then((res) => {
        document.getElementById('countries-stats').innerHTML = res
        router.updateLinkHandlers()
      })
  )

  Promise.all(promises).then(() => {
    fetch(`/stats/${domain}/screen-sizes${location.search}`)
      .then(res => res.text())
      .then((res) => {
        document.getElementById('screen-sizes-stats').innerHTML = res
        router.updateLinkHandlers()
      })

    fetch(`/stats/${domain}/operating-systems${location.search}`)
      .then(res => res.text())
      .then((res) => {
        document.getElementById('operating-systems-stats').innerHTML = res
        router.updateLinkHandlers()
      })

    fetch(`/stats/${domain}/browsers${location.search}`)
      .then(res => res.text())
      .then((res) => {
        document.getElementById('browsers-stats').innerHTML = res
        router.updateLinkHandlers()
      })

    if (document.getElementById('conversion-stats')) {
      fetch(`/stats/${domain}/conversions${location.search}`)
        .then(res => res.text())
        .then((res) => {
          document.getElementById('conversion-stats').innerHTML = res
          router.updateLinkHandlers()
        })
    }
  })

  setInterval(function() {
    fetch(`/api/${domain}/current-visitors`)
      .then(res => res.json())
      .then((res) => {
        console.log(res)
        document.getElementById('current-visitors').innerHTML = res
      })
  }, 10000)
}
