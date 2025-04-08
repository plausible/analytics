/**
 * @returns clears the state that the app stores,
 * to avoid individual tests impacting each other
 */
function clearStoredAppState() {
  localStorage.clear()
}

beforeEach(() => {
  clearStoredAppState()
})
