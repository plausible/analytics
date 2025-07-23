/**
 * Checks if the CSP policy disallows the given hosts/domains or subdomains.
 * @param {Record<string, string>} responseHeaders
 * @param {string[]} hostsToCheck - Array of domains/hosts to check. Must be provided.
 * @returns {boolean}
 */
export function checkDisallowedByCSP(responseHeaders, hostsToCheck) {
  if (!Array.isArray(hostsToCheck) || hostsToCheck.length === 0) {
    throw new Error('hostsToCheck must be a non-empty array')
  }
  const policy = responseHeaders?.['content-security-policy']
  if (!policy) return false

  const directives = policy.split(';')

  const allowed = directives.some((directive) => {
    const d = directive.trim()
    // Check for any of the provided hosts/domains
    if (hostsToCheck.some((domain) => d.includes(domain))) return true
    return false
  })

  return !allowed
}
