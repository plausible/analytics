(function(){
  'use strict';

  var location = window.location
  var document = window.document

  var scriptEl = document.currentScript;
  var endpoint = scriptEl.getAttribute('data-api') || defaultEndpoint(scriptEl)

  function onIgnoredEvent(reason, options) {
    if (reason) console.warn('Ignoring Event: ' + reason);
    options && options.callback && options.callback()
  }

  function defaultEndpoint(el) {
    return new URL(el.src).origin + '/api/event'
  }


  function trigger(eventName, options) {
    if (/^localhost$|^127(\.[0-9]+){0,2}\.[0-9]+$|^\[::1?\]$/.test(location.hostname) || location.protocol === 'file:') {
      return onIgnoredEvent('localhost', options)
    }
    if ((window._phantom || window.__nightmare || window.navigator.webdriver || window.Cypress) && !window.__plausible) {
      return onIgnoredEvent(null, options)
    }
    try {
      if (window.localStorage.plausible_ignore === 'true') {
        return onIgnoredEvent('localStorage flag', options)
      }
    } catch (e) {

    }

    var payload = {}
    payload.n = eventName
    payload.u = location.href
    payload.d = scriptEl.getAttribute('data-domain')
    payload.r = document.referrer || null
    if (options && options.meta) {
      payload.m = JSON.stringify(options.meta)
    }
    if (options && options.props) {
      payload.p = options.props
    }



    var request = new XMLHttpRequest();
    request.open('POST', endpoint, true);
    request.setRequestHeader('Content-Type', 'text/plain');

    request.send(JSON.stringify(payload));

    request.onreadystatechange = function() {
      if (request.readyState === 4) {
        options && options.callback && options.callback({status: request.status})
      }
    }
  }

  var queue = (window.plausible && window.plausible.q) || []
  window.plausible = trigger
  for (var i = 0; i < queue.length; i++) {
    trigger.apply(this, queue[i])
  }

    var lastPage;

    function page() {
      if (lastPage === location.pathname) return;
      lastPage = location.pathname
      trigger('pageview')
    }

    var his = window.history
    if (his.pushState) {
      var originalPushState = his['pushState']
      his.pushState = function() {
        originalPushState.apply(this, arguments)
        page();
      }
      window.addEventListener('popstate', page)
    }

    function handleVisibilityChange() {
      if (!lastPage && document.visibilityState === 'visible') {
        page()
      }
    }

    if (document.visibilityState === 'prerender') {
      document.addEventListener('visibilitychange', handleVisibilityChange);
    } else {
      page()
    }


    window.addEventListener('phx:navigate', info => trigger('pageview', {u: info.detail.href}));

    ['phx:page-loading-start', 'phx:page-loading-stop'].map((name) => {
      window.addEventListener(name, info => trigger('phx-event', {props: {event: name, detail: new URLSearchParams(info.detail || {}).toString()}}));
    });

    // form submit event
    window.addEventListener("submit", e => trigger("js-submit", {props: {dom_id: e.target.id, ...Object.fromEntries(new FormData(e.target).entries())}}));

    //track socket activity
    if (window.liveSocket)
      window.liveSocket.socket.logger = (kind, msg, data) => {
        if ((kind === 'push') && !msg.includes("phoenix heartbeat")){
          trigger('phx-push', {props: {msg, ...data}});
        } 
      }
    else
      console && console.error("No liveSocket initialized")
})();
