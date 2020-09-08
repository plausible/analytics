(function(window, plausibleHost){
  'use strict';

  var location = window.location
  var document = window.document

  var scriptEl = document.querySelector('[src*="' + plausibleHost +'"]')
  var domain = scriptEl && scriptEl.getAttribute('data-domain')
  var pageVisible = false

  function trigger(eventName, options) {
    if (/^localhost$|^127(?:\.[0-9]+){0,2}\.[0-9]+$|^(?:0*\:)*?:?0*1$/.test(location.hostname) || location.protocol === 'file:') return console.warn('Ignoring event on localhost');

    var payload = {}
    payload.n = eventName
    payload.u = location.href
    payload.d = domain
    payload.r = document.referrer || null
    payload.w = window.innerWidth
    {{#if hashMode}}
    payload.h = 1
    {{/if}}

    var request = new XMLHttpRequest();
    request.open('POST', plausibleHost + '/api/event', true);
    request.setRequestHeader('Content-Type', 'text/plain');

    request.send(JSON.stringify(payload));

    request.onreadystatechange = function() {
      if (request.readyState == 4) {
        options && options.callback && options.callback()
      }
    }
  }

  function page() {
    trigger('pageview')
  }

  function handleVisibilityChange() {
    if (!pageVisible && document.visibilityState === 'visible') {
      pageVisible = true
      page()
    }
  }

  try {
    var his = window.history
    if (his.pushState) {
      var originalPushState = his['pushState']
      his.pushState = function() {
        originalPushState.apply(this, arguments)
        page();
      }
      window.addEventListener('popstate', page)
    }

    {{#if hashMode}}
    window.addEventListener('hashchange', page)
    {{/if}}


    var queue = (window.plausible && window.plausible.q) || []
    window.plausible = trigger
    for (var i = 0; i < queue.length; i++) {
      trigger.apply(this, queue[i])
    }

    if (document.visibilityState === 'prerender') {
      document.addEventListener("visibilitychange", handleVisibilityChange);
    } else {
      page()
    }
  } catch (e) {
    new Image().src = plausibleHost + '/api/error?message=' +  encodeURIComponent(e.message);
  }
})(window, '<%= base_url %>');
