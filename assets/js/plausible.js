(function(window, plausibleHost){
  'use strict';

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
      console.warn('[Plausible] Ignoring pageview because ' + reason);
    }

    function getUrl() {
      return window.location.protocol + '//' + window.location.hostname + window.location.pathname + window.location.search;
    }

    function page() {
      if (/localhost$/.test(window.location.hostname)) return ignore('website is running locally');
      if (window.location.protocol === 'file:') return ignore('website is running locally');
      if (window.document.visibilityState === 'prerender') return ignore('document is prerendering');

      var existingUid = getCookie('nm_uid');

      var request = new XMLHttpRequest();
      request.open('POST', plausibleHost + '/api/page', true);
      request.setRequestHeader('Content-Type', 'text/plain');
      var uid = existingUid || pseudoUUIDv4()

      request.send(JSON.stringify({
        url: getUrl(),
        new_visitor: !existingUid,
        uid: uid,
        user_agent: window.navigator.userAgent,
        referrer: window.document.referrer,
        screen_width: window.innerWidth
      }));

      request.onreadystatechange = function() {
        if (request.readyState == XMLHttpRequest.DONE) {
          if (!existingUid) {
            setCookie('nm_uid', uid)
          }
        }
      }
    }

    var his = window.history
    if (his.pushState) {
      var originalFn = his['pushState']
      his.pushState = function() {
        originalFn.apply(this, arguments)
        page();
      }
    }

    page()
  } catch (e) {
    new Image().src = plausibleHost + '/api/error?message=' +  encodeURIComponent(e.message);
  }
})(window, BASE_URL);
