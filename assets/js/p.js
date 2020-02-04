(function(window, plausibleHost){
  'use strict';

  try {
    const CONFIG = {
      domain: window.location.hostname
    }

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
      console.warn('[Plausible] Ignoring event because ' + reason);
    }

    function getUrl() {
      return window.location.protocol + '//' + window.location.hostname + window.location.pathname + window.location.search;
    }

    function getUserData() {
      var userData = JSON.parse(getCookie('plausible_user'))

      if (userData) {
        userData.new_visitor = false
        userData.user_agent = decodeURIComponent(userData.user_agent)
        userData.referrer = decodeURIComponent(userData.referrer)
        return userData
      } else {
        return {
          uid: pseudoUUIDv4(),
          new_visitor: true,
          user_agent: window.navigator.userAgent,
          referrer: window.document.referrer,
          screen_width: window.innerWidth
        }
      }
    }

    function setUserData(payload) {
      setCookie('plausible_user', JSON.stringify({
        uid: payload.uid,
        user_agent: encodeURIComponent(payload.user_agent),
        referrer: encodeURIComponent(payload.referrer),
        screen_width: payload.screen_width
      }))
    }

    function trigger(eventName, options) {
      if (/localhost$/.test(window.location.hostname)) return ignore('website is running locally');
      if (window.location.protocol === 'file:') return ignore('website is running locally');
      if (window.document.visibilityState === 'prerender') return ignore('document is prerendering');

      var payload = getUserData()
      payload.name = eventName
      payload.url = getUrl()
      payload.domain = CONFIG['domain']

      var request = new XMLHttpRequest();
      request.open('POST', plausibleHost + '/api/event', true);
      request.setRequestHeader('Content-Type', 'text/plain');

      request.send(JSON.stringify(payload));

      request.onreadystatechange = function() {
        if (request.readyState == XMLHttpRequest.DONE) {
          setUserData(payload)
          options && options.callback && options.callback()
        }
      }

    }

    function onUnload() {
      var userData = getUserData()
      navigator.sendBeacon(plausibleHost + '/api/unload', JSON.stringify({uid: userData.uid}));
    }

    function page(options) {
      trigger('pageview', options)
      window.addEventListener('unload', onUnload, false);
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
    }

    function configure(key, val) {
      CONFIG[key] = val
    }

    const functions = {
      page: page,
      trigger: trigger,
      trackPushState: trackPushState,
      configure: configure
    }

    const queue = window.plausible.q || []

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
})(window, BASE_URL);
