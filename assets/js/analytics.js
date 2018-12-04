(function(window, apiHost){
  try {
    var userAgent = window.navigator.userAgent;
    var referrer = window.document.referrer;
    var screenWidth = window.screen.width;
    var screenHeight = window.screen.height;

    function page() {
      var url = window.location.protocol + '//' + 'gigride.live' + window.location.pathname;
      var postBody = {url: url};
      if (userAgent) postBody.user_agent = userAgent;
      if (referrer) postBody.referrer = referrer;
      if (screenWidth) postBody.screen_width = screenWidth;
      if (screenHeight) postBody.screen_height = screenHeight;

      var request = new XMLHttpRequest();
      request.open('POST', apiHost + '/api/page', true);
      request.setRequestHeader('Content-Type', 'text/plain; charset=UTF-8');
      request.send(JSON.stringify(postBody));
    }

    page()
  } catch (e) {
    console.error(e)
  }
})(window, 'http://localhost:8000');
