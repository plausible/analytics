const PARAMETER_REGEXP = /([:*])(\w+)/g;
const REPLACE_VARIABLE_REGEXP = '([^\/]+)';

export default class Router {
  constructor() {
    this.routes = []
    this._attachLinkHandlers()
    window.addEventListener('popstate', this.resolve.bind(this));
  }

  on(path, handler) {
    const {regex, paramNames} = this._generateRouteRegex(path)
    this.routes.push({regex, paramNames, handler})
    return this
  }

  resolve() {
    const match = this._matchRoute()
    if (match) {
      match.route.handler(match.params)
    }
    return this
  }

  navigate(to) {
    history.pushState({}, '', to)
    this.resolve()
  }

  _matchRoute() {
    const currentPath = window.location.pathname

    for (const route of this.routes) {
      const match = currentPath.replace(/^\/+/, '/').match(route.regex)

      if (match) {
        const params = this._extractParams(match, route.paramNames)
        return {route, params}
      }
    }
  }

  _generateRouteRegex(path) {
    const paramNames = []
    const regex = path.replace(PARAMETER_REGEXP, function (full, dots, name) {
      paramNames.push(name);
      return REPLACE_VARIABLE_REGEXP;
    })
    return {regex: new RegExp(regex), paramNames}
  }

  _extractParams(match, paramNames) {
    return match.slice(1, match.length).reduce(function(params, value, index) {
      if (params === null) params = {};
      params[paramNames[index]] = decodeURIComponent(value);
      return params;
    }, null);
  }

  _attachLinkHandlers() {
    const self = this
    const links = document.querySelectorAll('[data-pushstate]')

    for (const link of links) {
      if (!link.hasListenerAttached) {
        link.addEventListener('click', function (e) {
          if (e.ctrlKey || e.metaKey) {
            return false;
          }

          e.preventDefault();
          const location = link.getAttribute('href');;
          self.navigate(location.replace(/\/+$/, '').replace(/^\/+/, '/'));
        })

        link.hasListenerAttached = true;
      }
    }
  }
}

