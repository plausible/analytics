/**
 * Checks if the CSP policy disallows the given host/domain.
 * @param {Record<string, string>} responseHeaders - Response headers with keys normalized to lowercase like { "x-foo": "bar" }
 * @param {string} hostToCheck - Domain/host to check. Must be provided.
 * @returns {boolean}
 */
export function checkDisallowedByCSP(responseHeaders, hostToCheck) {
  if (!hostToCheck || typeof hostToCheck !== 'string') {
    throw new Error('hostToCheck must be a non-empty string')
  }
  const policy = responseHeaders?.['content-security-policy']
  if (!policy) return false

  const directives = policy.split(';')

  const allowed = directives.some((directive) => {
    const d = directive.trim()
    // Check for the provided host/domain
    return d.includes(hostToCheck)
  })

  return !allowed
}
