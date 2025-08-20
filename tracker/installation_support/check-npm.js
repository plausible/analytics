export function checkNPM(document) {
  console.log('checkNPM', document, window.plausible)
  if (typeof document === 'object') {
    return window.plausible?.s === 'npm'
  }

  return false
}
