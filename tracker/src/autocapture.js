import { config, location, document } from './config'

export function init(trigger) {
  var lastPage;

  function page(isSPANavigation) {
    if (!(COMPILE_HASH && (!COMPILE_CONFIG || config.hashBasedRouting))) {
      if (isSPANavigation && lastPage === location.pathname) return;
    }

    lastPage = location.pathname
    trigger('pageview')
  }

  var onSPANavigation = function () { page(true) }

  if (COMPILE_HASH && (!COMPILE_CONFIG || config.hashBasedRouting)) {
    window.addEventListener('hashchange', onSPANavigation)
  } else {
    var his = window.history
    if (his.pushState) {
      var originalPushState = his['pushState']
      his.pushState = function () {
        originalPushState.apply(this, arguments)
        onSPANavigation();
      }
      window.addEventListener('popstate', onSPANavigation)
    }
  }

  function handleVisibilityChange() {
    if (!lastPage && document.visibilityState === 'visible') {
      page()
    }
  }

  if (document.visibilityState === 'hidden' || document.visibilityState === 'prerender') {
    document.addEventListener('visibilitychange', handleVisibilityChange);
  } else {
    page()
  }

  window.addEventListener('pageshow', function (event) {
    if (event.persisted) {
      // Page was restored from bfcache - trigger a pageview
      page();
    }
  })
}
