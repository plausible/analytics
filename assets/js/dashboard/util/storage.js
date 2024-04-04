// This module checks if localStorage is available and uses it for persistent frontend storage
// if possible. Localstorage can be blocked by browsers when people block third-party cookies and
// the dashboard is running in embedded mode. In those cases, store stuff in a regular object instead.

const memStore = {}

// https://stackoverflow.com/a/16427747
function testLocalStorageAvailability(){
  try {
    const testItem = 'test';
    localStorage.setItem(testItem, testItem);
    localStorage.removeItem(testItem);
    return true;
  } catch(e) {
    return false;
  }
}

const isLocalStorageAvailable = testLocalStorageAvailability()

export function setItem(key, value) {
  if (isLocalStorageAvailable) {
    window.localStorage.setItem(key, value)
  } else {
    memStore[key] = value
  }
}

export function getItem(key) {
  if (isLocalStorageAvailable) {
    return window.localStorage.getItem(key)
  } else {
    return memStore[key]
  }
}

export function setInterval(site, query, interval) {
  setItem(`interval__${query.period}__${site.domain}`, interval)
}

export function getInterval(site, query) {
  return getItem(`interval__${query.period}__${site.domain}`)
}

export function setMetric(site, metric) {
  setItem(`metric__${site.domain}`, metric)
}

export function getMetric(site) {
  return getItem(`metric__${site.domain}`)
}
