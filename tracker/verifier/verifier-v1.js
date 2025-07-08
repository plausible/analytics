import { waitForSnippetsV1 } from "./snippet-checks"
import { plausibleFunctionCheck } from "./plausible-function-check"
import { checkDataDomainMismatch } from "./check-data-domain-mismatch"
import { checkProxyLikely } from "./check-proxy-likely"
import { checkWordPress } from "./check-wordpress"
import { checkGTM } from "./check-gtm"

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

  const {wordpressPlugin, wordpressLikely} = checkWordPress(document)
  log(`wordpressPlugin: ${wordpressPlugin}`)
  log(`wordpressLikely: ${wordpressLikely}`)

  const gtmLikely = checkGTM(document)
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