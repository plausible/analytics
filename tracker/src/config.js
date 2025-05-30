var location = window.location
var document = window.document

if (COMPILE_COMPAT) {
  var scriptEl = document.getElementById('plausible')
} else {
  var scriptEl = document.currentScript
}

var config = {}

function defaultEndpoint() {
  if (COMPILE_COMPAT) {
    var pathArray = scriptEl.src.split('/');
    var protocol = pathArray[0];
    var host = pathArray[2];
    return protocol + '//' + host + '/api/event';
  } else {
    return new URL(scriptEl.src).origin + '/api/event'
  }
}

export function init(overrides) {
  if (COMPILE_PLAUSIBLE_WEB) {
    // This will be dynamically replaced by a config json object in the script serving endpoint
    config = "<%= @config_js %>"
    Object.assign(config, overrides, {
      // Explicitly set domain before any overrides are applied as `plausible-web` does not support overriding it
      domain: config.domain,
      // autoCapturePageviews defaults to `true`
      autoCapturePageviews: overrides.autoCapturePageviews !== false
    })
  } else if (COMPILE_PLAUSIBLE_NPM) {
    if (config.isInitialized) {
      throw new Error('plausible.init() can only be called once')
    }
    if (!overrides || !overrides.domain) {
      throw new Error('plausible.init(): domain argument is required')
    }
    if (!overrides.endpoint) {
      overrides.endpoint = 'https://plausible.io/api/event'
    }
    Object.assign(config, overrides, {
      autoCapturePageviews: overrides.autoCapturePageviews !== false
    })
    config.isInitialized = true
  } else {
    config.endpoint = scriptEl.getAttribute('data-api') || defaultEndpoint()
    config.domain = scriptEl.getAttribute('data-domain')
  }
}

export { config, scriptEl, location, document }
