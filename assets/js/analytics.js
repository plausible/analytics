(function(window, apiHost){
  'use strict';

  try {
    function getCookie(name) {
      var cookies = document.cookie ? document.cookie.split('; ') : [];

      for (var i = 0; i < cookies.length; i++) {
        var parts = cookies[i].split('=');
        if (decodeURIComponent(parts[0]) !== name) {
          continue;
        }

        var cookie = parts.slice(1).join('=');
        return decodeURIComponent(cookie);
      }

      return '';
    }

    function setCookie(name, data) {
      data = encodeURIComponent(String(data));
      var str = name + '=' + data + ';path=/';

      document.cookie = str;
    }

    function page() {
      var userAgent = window.navigator.userAgent;
      var referrer = window.document.referrer;
      var screenWidth = window.screen.width;
      var screenHeight = window.screen.height;
      var cookie = getCookie('_nm')

      var url = window.location.protocol + '//' + window.location.hostname + window.location.pathname;
      var postBody = {
        url: url,
        new_visitor: !cookie
      };
      if (userAgent) postBody.user_agent = userAgent;
      if (referrer) postBody.referrer = referrer;
      if (screenWidth) postBody.screen_width = screenWidth;
      if (screenHeight) postBody.screen_height = screenHeight;

      var request = new XMLHttpRequest();
      request.open('POST', apiHost + '/api/page', true);
      request.setRequestHeader('Content-Type', 'text/plain; charset=UTF-8');
      request.send(JSON.stringify(postBody));
      request.onreadystatechange = function() {
        if (request.readyState == XMLHttpRequest.DONE) {
          setCookie('_nm', {foo: 'bar'})
        }
      }
    }

    page()
  } catch (e) {
    console.error(e)
  }
})(window, 'http://lvh.me:8000');
