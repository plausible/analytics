import { waitForBootstrappers, getPlausibleInitScriptSrcs, getPlausibleInitScriptDomains } from "./snippet-checks"
import { plausibleFunctionCheckV2 } from "./plausible-function-check"
import { checkWordPress } from "./check-wordpress"
import { checkGTM } from "./check-gtm"
import { checkCookieBanner } from "./check-cookie-banner"
import { isPlausibleIoSrc } from "./check-proxy-likely"

window.verifyPlausibleInstallation = async function(expectedDataDomain, debug) {
  function log(message) {
    if (debug) console.log('[Plausible v2 Verification]', message)
  }

  const bootstrapperScripts = await waitForBootstrappers(log);
  const plausibleFunctionDiagnostics = await plausibleFunctionCheckV2(log)

  const plausibleInstalled = plausibleFunctionDiagnostics.plausibleInstalled
  const callbackStatus = plausibleFunctionDiagnostics.callbackStatus || 0

  const dataDomainMismatch = expectedDataDomain && !getPlausibleInitScriptDomains(bootstrapperScripts).some(domain => domain === expectedDataDomain)
  log(`dataDomainMismatch: ${dataDomainMismatch}`)

  const manualScriptExtension = false // not needed
  log(`manualScriptExtension: ${manualScriptExtension}`)

  const unknownAttributes = false // does not matter
  log(`unknownAttributes: ${unknownAttributes}`)

  const scriptSrcsInBootstrappers = bootstrapperScripts.flatMap(getPlausibleInitScriptSrcs)
  log(`scriptSrcsInBootstrappers: ${scriptSrcsInBootstrappers}`)

  const proxyLikely = scriptSrcsInBootstrappers.length > 0 && !scriptSrcsInBootstrappers.some(isPlausibleIoSrc)
  log(`proxyLikely: ${proxyLikely}`)

  const {wordpressPlugin, wordpressLikely} = checkWordPress(document)
  log(`wordpressPlugin: ${wordpressPlugin}`)
  log(`wordpressLikely: ${wordpressLikely}`)

  const gtmLikely = checkGTM(document)
  log(`gtmLikely: ${gtmLikely}`)

  let cookieBannerLikely

  if (plausibleInstalled && [200, 202].includes(callbackStatus)) {
    cookieBannerLikely = false
  } else {
    cookieBannerLikely = checkCookieBanner()
  }

  log(`cookieBannerLikely: ${cookieBannerLikely}`)

  return {
    data: {
      completed: true,
      plausibleInstalled: plausibleFunctionDiagnostics.plausibleInstalled,
      callbackStatus: plausibleFunctionDiagnostics.callbackStatus || 0,
      snippetsFoundInHead: bootstrapperScripts.length ? 1 : 0, // todo: not needed
      snippetsFoundInBody: 0, // todo: not needed
      dataDomainMismatch: dataDomainMismatch,
      proxyLikely: proxyLikely,
      wordpressPlugin: wordpressPlugin,
      wordpressLikely: wordpressLikely,
      gtmLikely: gtmLikely,
      cookieBannerLikely: cookieBannerLikely,
      manualScriptExtension: manualScriptExtension,
      unknownAttributes: unknownAttributes
    }
  }
}