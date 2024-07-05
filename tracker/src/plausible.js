(function(){
  'use strict';

  var location = window.location
  var document = window.document

  {{#if compat}}
  var scriptEl = document.getElementById('plausible');
  {{else}}
  var scriptEl = document.currentScript;
  {{/if}}
  var endpoint = scriptEl.getAttribute('data-api') || defaultEndpoint(scriptEl)

  function onIgnoredEvent(reason, options) {
    if (reason) console.warn('Ignoring Event: ' + reason);
    options && options.callback && options.callback()
  }

  function defaultEndpoint(el) {
    {{#if compat}}
    var pathArray = el.src.split( '/' );
    var protocol = pathArray[0];
    var host = pathArray[2];
    return protocol + '//' + host  + '/api/event';
    {{else}}
    return new URL(el.src).origin + '/api/event'
    {{/if}}
  }


  function trigger(eventName, options) {
    {{#unless local}}
    if (/^localhost$|^127(\.[0-9]+){0,2}\.[0-9]+$|^\[::1?\]$/.test(location.hostname) || location.protocol === 'file:') {
      return onIgnoredEvent('localhost', options)
    }
    if ((window._phantom || window.__nightmare || window.navigator.webdriver || window.Cypress) && !window.__plausible) {
      return onIgnoredEvent(null, options)
    }
    {{/unless}}
    try {
      if (window.localStorage.plausible_ignore === 'true') {
        return onIgnoredEvent('localStorage flag', options)
      }
    } catch (e) {

    }
    {{#if exclusions}}
    var dataIncludeAttr = scriptEl && scriptEl.getAttribute('data-include')
    var dataExcludeAttr = scriptEl && scriptEl.getAttribute('data-exclude')

    if (eventName === 'pageview') {
      var isIncluded = !dataIncludeAttr || (dataIncludeAttr && dataIncludeAttr.split(',').some(pathMatches))
      var isExcluded = dataExcludeAttr && dataExcludeAttr.split(',').some(pathMatches)

      if (!isIncluded || isExcluded) return onIgnoredEvent('exclusion rule', options)
    }

    function pathMatches(wildcardPath) {
      var actualPath = location.pathname

      {{#if hash}}
      actualPath += location.hash
      {{/if}}

      return actualPath.match(new RegExp('^' + wildcardPath.trim().replace(/\*\*/g, '.*').replace(/([^\.])\*/g, '$1[^\\s\/]*') + '\/?$'))
    }
    {{/if}}

    var payload = {}
    payload.n = eventName
    {{#if manual}}
    payload.u = options && options.u ? options.u : location.href
    {{else}}
    payload.u = location.href
    {{/if}}
    payload.d = scriptEl.getAttribute('data-domain')
    payload.r = document.referrer || null
    if (options && options.meta) {
      payload.m = JSON.stringify(options.meta)
    }
    if (options && options.props) {
      payload.p = options.props
    }
    {{#if revenue}}
    if (options && options.revenue) {
      payload.$ = options.revenue
    }
    {{/if}}

    {{#if pageview_props}}
    var propAttributes = scriptEl.getAttributeNames().filter(function (name) {
      return name.substring(0, 6) === 'event-'
    })

    var props = payload.p || {}

    propAttributes.forEach(function(attribute) {
      var propKey = attribute.replace('event-', '')
      var propValue = scriptEl.getAttribute(attribute)
      props[propKey] = props[propKey] || propValue
    })

    payload.p = props
    {{/if}}

    {{#if hash}}
    payload.h = 1
    {{/if}}

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

  {{#unless manual}}
    var lastPage;

    function page() {
      {{#unless hash}}
      if (lastPage === location.pathname) return;
      {{/unless}}
      lastPage = location.pathname
      trigger('pageview')
    }

    {{#if hash}}
    window.addEventListener('hashchange', page)
    {{else}}
    var his = window.history
    if (his.pushState) {
      var originalPushState = his['pushState']
      his.pushState = function() {
        originalPushState.apply(this, arguments)
        page();
      }
      window.addEventListener('popstate', page)
    }
    {{/if}}

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
  {{/unless}}

  {{#if (any outbound_links file_downloads tagged_events)}}
  {{> customEvents}}
  {{/if}}

  {{#if live_view}}
    window.addEventListener('phx:navigate', info => trigger('pageview', {u: info.detail.href}))

    // https://hexdocs.pm/phoenix_live_view/bindings.html
    const bindings = ['phx-click', 'phx-click-away', 'phx-change', 'phx-submit', 'phx-feedback-for', 'phx-feedback-group', 
      'phx-disable-with', 'phx-trigger-action', 'phx-auto-recover', 'phx-blur', 'phx-focus', 'phx-window-blur', 'phx-window-focus', 
      'phx-keydown', 'phx-keyup', 'phx-window-keydown', 'phx-window-keyup', 'phx-key', 'phx-viewport-top', 'phx-viewport-bottom', 
      'phx-mounted', 'phx-update', 'phx-remove', 'phx-hook', 'phx-mounted', 'phx-disconnected', 'phx-connected', 'phx-debounce', 
      'phx-throttle', 'phx-track-static'];

    const events = ["phx:page-loading-start", 
      "phx:page-loading-stop", 
      "track-uploads", 
      "phx:live-file:updated"
    ].concat(bindings)
    .concat(bindings.map(name => name.replace('phx-', 'phx:')))
    .concat(bindings.map(name => name.replace('phx-', '')).filter(name => name != 'submit'))
    ;
    events.map((name) => {
      window.addEventListener(name, info => trigger('phx-event', {props: {event: name, detail: new URLSearchParams(info.detail || {}).toString()}}));
    });

    // form submit event
    window.addEventListener("submit", e => trigger("js-submit", {props: {dom_id: e.target.id, ...Object.fromEntries(new FormData(e.target).entries())}}));

    //track socket activity
    if (window.liveSocket)
      window.liveSocket.socket.logger = (kind, msg, data) => {
        if(kind === 'push') trigger('phx-event', {props: {msg, ...data}})
      }
    else
      console && console.error("No liveSocket initialized")
  {{/if}}
})();
