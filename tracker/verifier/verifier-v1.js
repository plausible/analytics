import { waitForSnippetsV1 } from "./snippet-checks"
import { plausibleFunctionCheck } from "./plausible-function-check"
import { checkDataDomainMismatch } from "./check-data-domain-mismatch"
import { checkProxyLikely } from "./check-proxy-likely"
import { detectWordPress } from "./detect-wp"
import { detectGTM } from "./detect-gtm"

window.verifyPlausibleInstallation = async function(expectedDataDomain, debug) {
  function log(message) {
    if (debug) console.log('[Plausible Verification]', message)
  }

  const [snippetData, plausibleFunctionDiagnostics] = await Promise.all([
    waitForSnippetsV1(log),
    plausibleFunctionCheck(log)
  ])

  const dataDomainMismatch = checkDataDomainMismatch(snippetData.nodes, expectedDataDomain)
  log(`dataDomainMismatch: ${dataDomainMismatch}`)

  const proxyLikely = checkProxyLikely(snippetData.nodes)
  log(`proxyLikely: ${proxyLikely}`)

  const {wordpressPlugin, wordpressLikely} = detectWordPress(document)
  log(`wordpressPlugin: ${wordpressPlugin}`)
  log(`wordpressLikely: ${wordpressLikely}`)

  const gtmLikely = detectGTM(document)
  log(`gtmLikely: ${gtmLikely}`)

  return {
    data: {
      completed: true,
      plausibleInstalled: plausibleFunctionDiagnostics.plausibleInstalled,
      callbackStatus: plausibleFunctionDiagnostics.callbackStatus || 0,
      snippetsFoundInHead: snippetData.counts.head,
      snippetsFoundInBody: snippetData.counts.body,
      dataDomainMismatch: dataDomainMismatch,
      proxyLikely: proxyLikely,
      wordpressPlugin: wordpressPlugin,
      wordpressLikely: wordpressLikely,
      gtmLikely: gtmLikely
    }
  }
}