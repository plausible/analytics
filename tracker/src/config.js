
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
  if (COMPILE_CONFIG) {
    // This will be dynamically replaced by a config json object in the script serving endpoint
    config = "<%= @config_js %>"
    // Explicitly set domain before any overrides are applied as `plausible-web` does not support overriding it
    Object.assign(config, overrides, { domain: config.domain, autoCapturePageviews: overrides.autoCapturePageviews !== false })
  } else {
    config.endpoint = scriptEl.getAttribute('data-api') || defaultEndpoint()
    config.domain = scriptEl.getAttribute('data-domain')
  }
}

export { config, scriptEl }
