(function(window, apiHost){
  'use strict';

  if (window.PLAUSIBLE_LOCK) {
    console.warn('Looksl like the Plausible script has been included multiple times on this website. Unexpected behaviour may happen.')
    return null
  } else {
    window.PLAUSIBLE_LOCK = true
  };

  try {
    function setCookie(name,value) {
      var date = new Date();
      date.setTime(date.getTime() + (3*365*24*60*60*1000)); // 3 YEARS
      var expires = "; expires=" + date.toUTCString();
      document.cookie = name + "=" + (value || "")  + expires + "; path=/";
    }

    function getCookie(name) {
        var nameEQ = name + "=";
        var ca = document.cookie.split(';');
        for(var i=0;i < ca.length;i++) {
            var c = ca[i];
            while (c.charAt(0)==' ') c = c.substring(1,c.length);
            if (c.indexOf(nameEQ) == 0) return c.substring(nameEQ.length,c.length);
        }
        return null;
    }

    function pseudoUUIDv4() {
      var d = new Date().getTime();
      if (typeof performance !== 'undefined' && typeof performance.now === 'function'){
        d += performance.now(); //use high-precision timer if available
      }
      return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function (c) {
        var r = (d + Math.random() * 16) % 16 | 0;
        d = Math.floor(d / 16);
        return (c === 'x' ? r : (r & 0x3 | 0x8)).toString(16);
      });
    }

    function ignore(reason) {
      if (console && console.warn) console.warn('[Plausible] Ignoring pageview because ' + reason);
    }

    function page(isPushState) {
      var userAgent = window.navigator.userAgent;
      var referrer = !isPushState ? window.document.referrer : null;
      var screenWidth = window.innerWidth;

      // Ignore prerendered pages
      if( 'visibilityState' in window.document && window.document.visibilityState === 'prerender' ) return ignore('document is prerendering');
      // Ignore localhost
      if (/localhost$/.test(window.location.hostname)) return ignore('website is running locally');
      // Ignore local file
      if (window.location.protocol === 'file:') return ignore('website is running locally');
      // Basic bot detection.
      if (userAgent && userAgent.search(/(bot|spider|crawl)/ig) > -1) return ignore('the user-agent is a bot');

      var existingUid = getCookie('nm_uid');
      var uid = existingUid || pseudoUUIDv4();

      var url = window.location.protocol + '//' + window.location.hostname + window.location.pathname + window.location.search;
      var postBody = {
        url: url,
        new_visitor: !existingUid,
        uid: uid
      };

      if (userAgent) postBody.user_agent = userAgent;
      if (referrer) postBody.referrer = referrer;
      if (screenWidth) postBody.screen_width = screenWidth;

      var request = new XMLHttpRequest();
      request.open('POST', apiHost + '/api/page', true);
      request.setRequestHeader('Content-Type', 'text/plain; charset=UTF-8');
      request.send(JSON.stringify(postBody));
      request.onreadystatechange = function() {
        if (request.readyState == XMLHttpRequest.DONE) {
          if (!existingUid) {
            setCookie('nm_uid', uid)
          }
        }
      }
    }

    var dis = window.dispatchEvent;
    var his = window.history;
    var hisPushState = his ? his.pushState : null;
    if (hisPushState && Event && dis) {
      var stateListener = function(type) {
        var orig = his[type];
        return function() {
          var rv = orig.apply(this, arguments);
          var event = new Event(type);
          event.arguments = arguments;
          dis(event);
          return rv;
        };
      };
      his.pushState = stateListener('pushState');
      window.addEventListener('pushState', function() {
        page(true);
      });
    }

    page()
  } catch (e) {
    var url = apiHost + '/api/error';
    if (e && e.message) url = url + '?message=' + encodeURIComponent(e.message);
    new Image().src = url;
    throw e
  }
})(window, BASE_URL);
