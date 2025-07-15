import { waitForSnippetsV1 } from "./snippet-checks"
import { checkWordPress } from "./check-wordpress"
import { checkGTM } from "./check-gtm"

window.scanPageBeforePlausibleInstallation = async function(detectV1, debug) {
  function log(message) {
    if (debug) console.log('[Plausible Verification]', message)
  }

  const {wordpressPlugin, wordpressLikely} = checkWordPress(document)
  log(`wordpressPlugin: ${wordpressPlugin}`)
  log(`wordpressLikely: ${wordpressLikely}`)

  const gtmLikely = checkGTM(document)
  log(`gtmLikely: ${gtmLikely}`)

  // Cannot implement yet: we should detect the WP plugin version here and
  // decide `v1Detected` based on that. For now we assume WP plugin is v1.
  let v1Detected = wordpressPlugin

  if (!v1Detected && detectV1) {
    const snippetData = await waitForSnippetsV1(log)
    v1Detected = snippetData.counts.all > 0
  }

  return {
    data: {
      completed: true,
      v1Detected: v1Detected,
      wordpressPlugin: wordpressPlugin,
      wordpressLikely: wordpressLikely,
      gtmLikely: gtmLikely,
    }
  }
}