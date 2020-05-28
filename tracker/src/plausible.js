(function(window, plausibleHost){
  'use strict';

  var scriptEl = window.document.querySelector('[src*="' + plausibleHost +'"]')
  var domainAttr = scriptEl && scriptEl.getAttribute('data-domain')
  var CONFIG = {domain: domainAttr || window.location.hostname}

  function ignore(reason) {
    console.warn('[Plausible] Ignoring event because ' + reason);
  }

  function getUrl() {
    return window.location.protocol + '//' + window.location.hostname + window.location.pathname + window.location.search;
  }

  function getSourceFromQueryParam() {
    var result = window.location.search.match(/[?&](ref|source|utm_source)=([^?&]+)/);
    return result ? result[2] : null
  }

  function trigger(eventName, options) {
    if (/^localhost$|^127(?:\.[0-9]+){0,2}\.[0-9]+$|^(?:0*\:)*?:?0*1$/.test(window.location.hostname)) return ignore('website is running locally');
    if (window.location.protocol === 'file:') return ignore('website is running locally');
    if (window.document.visibilityState === 'prerender') return ignore('document is prerendering');

    var payload = {}
    payload.name = eventName
    payload.url = getUrl()
    payload.domain = CONFIG['domain']
    payload.referrer = window.document.referrer || null
    payload.source = getSourceFromQueryParam()
    payload.user_agent = window.navigator.userAgent
    payload.screen_width = window.innerWidth

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
})(window, BASE_URL);
