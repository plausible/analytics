export function checkNPM(document) {
  if (typeof document === 'object') {
    return window.plausible?.s === 'npm'
  }

  return false
}
