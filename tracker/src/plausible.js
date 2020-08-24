(function(window, plausibleHost){
  'use strict';

  var location = window.location
  var document = window.document

  var scriptEl = document.querySelector('[src*="' + plausibleHost +'"]')
  var domainAttr = scriptEl && scriptEl.getAttribute('data-domain')
  var CONFIG = {domain: domainAttr || location.hostname}

  function ignore(reason) {
    console.warn('[Plausible] Ignore event: ' + reason);
  }

  function getSourceFromQueryParam() {
    var result = location.search.match(/[?&](ref|source|utm_source)=([^?&]+)/);
    return result ? result[2] : null
  }

  function trigger(eventName, options) {
    if (/^localhost$|^127(?:\.[0-9]+){0,2}\.[0-9]+$|^(?:0*\:)*?:?0*1$/.test(location.hostname) || location.protocol === 'file:') return ignore('running locally');
    if (document.visibilityState === 'prerender') return ignore('prerendering');

    var payload = {}
    payload.n = eventName
    payload.u = location.href
    payload.d = CONFIG['domain']
    payload.r = document.referrer || null
    payload.s = getSourceFromQueryParam()
    payload.w = window.innerWidth

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

    var queue = (window.plausible && window.plausible.q) || []
    window.plausible = trigger
    for (var i = 0; i < queue.length; i++) {
      trigger.apply(this, queue[i])
    }

    page()
  } catch (e) {
    new Image().src = plausibleHost + '/api/error?message=' +  encodeURIComponent(e.message);
  }
})(window, '<%= base_url %>');
