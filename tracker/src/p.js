// NOTE: This file is deprecated and only kept around so we don't break compatibility
// with some early customers. This script uses a cookie but this was an old version of Plausible.
// Current script can be found in the tracker/src/plausible.js file

(function(){
  'use strict';

  var scriptEl = window.document.currentScript;
  var plausibleHost = new URL(scriptEl.src).origin

  function setCookie(name,value) {
    var date = new Date();
    date.setTime(date.getTime() + (3*365*24*60*60*1000)); // 3 YEARS
    var expires = "; expires=" + date.toUTCString();
    document.cookie = name + "=" + (value || "")  + expires + "; samesite=strict; path=/";
  }

  function getCookie(name) {
    var matches = document.cookie.match(new RegExp(
      "(?:^|; )" + name.replace(/([\.$?*|{}\(\)\[\]\\\/\+^])/g, '\\$1') + "=([^;]*)"
    ));
    return matches ? decodeURIComponent(matches[1]) : null;
  }

  function ignore(reason) {
    console.warn('[Plausible] Ignoring event because ' + reason);
  }

  function getUserData() {
    var userData = JSON.parse(getCookie('plausible_user'))

    if (userData) {
      return {
        initial_referrer: userData.initial_referrer && decodeURIComponent(userData.initial_referrer),
        initial_source: userData.initial_source && decodeURIComponent(userData.initial_source)
      }
    } else {
      userData = {
        initial_referrer: window.document.referrer || null,
        initial_source: getSourceFromQueryParam(),
      }

      setCookie('plausible_user', JSON.stringify({
        initial_referrer: userData.initial_referrer && encodeURIComponent(userData.initial_referrer),
        initial_source: userData.initial_source && encodeURIComponent(userData.initial_source),
      }))

      return userData
    }
  }

  function trigger(eventName, options) {
    if (/^localhost$|^127(?:\.[0-9]+){0,2}\.[0-9]+$|^(?:0*\:)*?:?0*1$/.test(window.location.hostname)) return ignore('website is running locally');
    if (window.location.protocol === 'file:') return ignore('website is running locally');
    if (window.document.visibilityState === 'prerender') return ignore('document is prerendering');

    var payload = CONFIG['trackAcquisition'] ? getUserData() : {}
    payload.n = eventName
    payload.u = window.location.href
    payload.d = CONFIG['domain']
    payload.r = window.document.referrer || null
    payload.w = window.innerWidth

    var request = new XMLHttpRequest();
    request.open('POST', plausibleHost + '/api/event', true);
    request.setRequestHeader('Content-Type', 'text/plain');

    request.send(JSON.stringify(payload));

    request.onreadystatechange = function() {
      if (request.readyState == XMLHttpRequest.DONE) {
        options && options.callback && options.callback()
      }
    }
  }

  function page(options) {
    trigger('pageview', options)
  }

  function trackPushState() {
    var his = window.history
    if (his.pushState) {
      var originalFn = his['pushState']
      his.pushState = function() {
        originalFn.apply(this, arguments)
        page();
      }
    }
    window.addEventListener('popstate', page)
  }

  function configure(key, val) {
    CONFIG[key] = val
  }

  try {
    var CONFIG = {
      domain: window.location.hostname
    }

    var functions = {
      page: page,
      trigger: trigger,
      trackPushState: trackPushState,
      configure: configure
    }

    var queue = window.plausible.q || []

    window.plausible = function() {
      var args = [].slice.call(arguments);
      var funcName = args.shift();
      functions[funcName].apply(this, args);
    };

    for (var i = 0; i < queue.length; i++) {
      window.plausible.apply(this, queue[i])
    }
  } catch (e) {
    new Image().src = plausibleHost + '/api/error?message=' +  encodeURIComponent(e.message);
  }
})();
