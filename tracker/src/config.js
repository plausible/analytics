if (COMPILE_COMPAT) {
  var scriptEl = document.getElementById('plausible')
} else if (COMPILE_PLAUSIBLE_LEGACY_VARIANT) {
  // eslint-disable-next-line no-redeclare
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

export function getOptionsWithDefaults(initOptions) {
  if (COMPILE_PLAUSIBLE_WEB) {
    return Object.assign(initOptions, {
      autoCapturePageviews: initOptions.autoCapturePageviews !== false,
      logging: initOptions.logging !== false,
      lib: initOptions.lib || 'web',
    })
  }
  if (COMPILE_PLAUSIBLE_NPM) {
    return Object.assign(initOptions, {
      autoCapturePageviews: initOptions.autoCapturePageviews !== false,
      logging: initOptions.logging !== false,
      bindToWindow: initOptions.bindToWindow !== false,
    })
  }
}

export function init(options) {
  if (COMPILE_PLAUSIBLE_WEB) {
    // This will be dynamically replaced by a config json object in the script serving endpoint
    config = "<%= @config_js %>"
    Object.assign(config, options, {
      // Explicitly set domain after other options are applied as `plausible-web` does not support overriding it, except by transformRequest
      domain: config.domain,
    })
  } else if (COMPILE_PLAUSIBLE_NPM) {
    if (config.isInitialized) {
      throw new Error('plausible.init() can only be called once')
    }
    if (!options || !options.domain) {
      throw new Error('plausible.init(): domain argument is required')
    }
    if (!options.endpoint) {
      options.endpoint = 'https://plausible.io/api/event'
    }
    Object.assign(config, options)
    config.isInitialized = true
  } else {
    // Legacy variant
    config.endpoint = scriptEl.getAttribute('data-api') || defaultEndpoint()
    config.domain = scriptEl.getAttribute('data-domain')
    config.logging = true
  }
}

export { config, scriptEl }
