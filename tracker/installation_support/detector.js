import { waitForPlausibleFunction } from "./plausible-function-check"
import { checkWordPress } from "./check-wordpress"
import { checkGTM } from "./check-gtm"
import { checkNPM } from "./check-npm"

window.scanPageBeforePlausibleInstallation = async function({ detectV1, debug, timeoutMs }) {
  function log(message) {
    if (debug) console.log('[Plausible Verification]', message)
  }

  let v1Detected = null

  if (detectV1) {
    log('Waiting for Plausible function...')
    const plausibleFound = await waitForPlausibleFunction(timeoutMs)
    log(`plausibleFound: ${plausibleFound}`)
    v1Detected = plausibleFound && typeof window.plausible.s === 'undefined'
    log(`v1Detected: ${v1Detected}`)
  }

  const {wordpressPlugin, wordpressLikely} = checkWordPress(document)
  log(`wordpressPlugin: ${wordpressPlugin}`)
  log(`wordpressLikely: ${wordpressLikely}`)

  const gtmLikely = checkGTM(document)
  log(`gtmLikely: ${gtmLikely}`)

  const npm = checkNPM(document)
  log(`npm: ${npm}`)

  return {
    data: {
      completed: true,
      v1Detected: v1Detected,
      wordpressPlugin: wordpressPlugin,
      wordpressLikely: wordpressLikely,
      gtmLikely: gtmLikely,
      npm: npm
    }
  }
}
