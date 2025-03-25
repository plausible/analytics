// This module checks if localStorage is available and uses it for persistent frontend storage
// if possible. Localstorage can be blocked by browsers when people block third-party cookies and
// the dashboard is running in embedded mode. In those cases, store stuff in a regular object instead.

const memStore = {}

// https://stackoverflow.com/a/16427747
function testLocalStorageAvailability() {
  try {
    const testItem = 'test'
    localStorage.setItem(testItem, testItem)
    localStorage.removeItem(testItem)
    return true
  } catch (_e) {
    return false
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

export const getDomainScopedStorageKey = (key, domain) => `${key}__${domain}`
