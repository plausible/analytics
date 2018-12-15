(function(window, apiHost){
  'use strict';

  try {
    function setCookie(name,value,minutes) {
        var expires = "";
        if (minutes) {
            var date = new Date();
            date.setTime(date.getTime() + (minutes*60*1000));
            expires = "; expires=" + date.toUTCString();
        }
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
      return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
        var r = Math.random() * 16 | 0, v = c == 'x' ? r : (r & 0x3 | 0x8);
        return v.toString(16);
      });
    }

    function page() {
      var userAgent = window.navigator.userAgent;
      var referrer = window.document.referrer;
      var screenWidth = window.screen.width;
      var screenHeight = window.screen.height;
      var uid = getCookie('nm_uid')
      if (!uid && getCookie('_nm')) { // DELETE THIS SOON
        uid = pseudoUUIDv4();
        setCookie('nm_uid', uid)
      }

      var sid = getCookie('nm_sid')

      var url = window.location.protocol + '//' + window.location.hostname + window.location.pathname;
      var postBody = {
        url: url,
        new_visitor: !uid,
        sid: sid
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
            if (!uid) {
              setCookie('nm_uid', pseudoUUIDv4())
            }
            setCookie('nm_sid', sid || pseudoUUIDv4(), 30)
          }
        }
      }

    page()
  } catch (e) {
    console.error(e)
  }
})(window, BASE_URL);
