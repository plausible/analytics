/**
 * This module contains the code for starting a process
 * that tries to detect Consent Management Platforms (CMPs)
 * and if it finds any, to opt in.
 *
 * This is necessary because it's possible that Plausible script
 * is conditional on the client opting in to tracking cookies.
 */

// Note: these imports are using relative path syntax so rollup would bundle them
import AutoConsent from '../node_modules/@duckduckgo/autoconsent/dist/autoconsent.esm.js'
import usercentricsButton from '../node_modules/@duckduckgo/autoconsent/rules/autoconsent/usercentrics-button.json'
import iubenda from '../node_modules/@duckduckgo/autoconsent/rules/autoconsent/iubenda.json'
import quantcast from '../node_modules/@duckduckgo/autoconsent/rules/autoconsent/quantcast.json'
import { consentomatic } from '../node_modules/@duckduckgo/autoconsent/rules/consentomatic.json'
import cookiebotHandrolled from './autoconsent-rules/autoconsent/cookiebot.json'

const autoconsent = [
  usercentricsButton,
  iubenda,
  cookiebotHandrolled,
  quantcast
]

export function initializeCookieConsentEngine({
  debug,
  onConsentDone,
  onLifecycleUpdate,
  onConsentError
}) {
  const onMessage = (message) => {
    switch (message?.type) {
      case 'autoconsentDone':
        return onConsentDone(message.cmp)
      case 'autoconsentError':
        return onConsentError(message.details)
      case 'report':
        return onLifecycleUpdate(message.state.lifecycle)
      default:
        return
    }
  }

  try {
    const engine = new AutoConsent(
      onMessage,
      {
        enabled: true,
        autoAction: 'optIn',
        disabledCmps: [],
        enablePrehide: false,
        enableCosmeticRules: false,
        enableGeneratedRules: false,
        enableHeuristicDetection: false,
        detectRetries: 2,
        isMainWorld: false,
        prehideTimeout: 0,
        enableFilterList: false,
        visualTest: false,
        logs: {
          lifecycle: debug,
          rulesteps: debug,
          detectionsteps: debug,
          evals: debug,
          errors: debug,
          messages: debug,
          waits: debug
        }
      },
      { autoconsent, consentomatic }
    )

    return { handled: null, engineLifecycle: engine.state.lifecycle }
  } catch (_error) {
    return {
      handled: false,
      error: { message: 'Error initializing cookie consent engine' }
    }
  }
}
